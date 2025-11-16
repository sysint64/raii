/// Core library providing RAII (Resource Acquisition Is Initialization) pattern implementation
/// for Dart/Flutter applications.
///
/// This library provides a foundation for managing object lifecycles through a systematic
/// approach to resource initialization and cleanup. It implements the RAII pattern,
/// ensuring that resources are properly managed throughout their lifetime.
///
/// The library follows these core principles:
/// - Explicit lifecycle management through clear interfaces
/// - Hierarchical resource management where parent objects manage their children
/// - Automatic cleanup of resources when they're no longer needed
/// - LIFO disposal order (last registered, first disposed)
///
/// **Basic usage:**
///
/// ```dart
/// // Create a lifecycle container
/// final raiiManager = RaiiManager()..initLifecycle();
///
/// // Wrap a resource that needs lifecycle management
/// final resource = RaiiBox.withLifecycle(
///   raiiManager,
///   instance: MyResource(),
///   init: (r) => r.initialize(),
///   dispose: (r) => r.cleanup(),
///   debugLabel: 'MyResource',
/// );
///
/// // When done, dispose the `raiiManager` to cleanup all managed resources
/// raiiManager.disposeLifecycle();
/// ```
///
/// For long-lived resources that should exist for the entire application lifetime,
/// use [alwaysAliveRaiiManager]:
///
/// ```dart
/// final globalResource = RaiiBox.withLifecycle(
///   alwaysAliveRaiiManager,
///   instance: MyGlobalResource(),
///   debugLabel: 'GlobalResource',
/// );
/// ```
///
/// This library serves as the foundation for more specific lifecycle management
/// implementations in Flutter widgets, controllers, and other disposable resources.
/// It provides the core abstractions that other libraries build upon to provide
/// type-safe, automatic resource management.
library;

import 'package:flutter/foundation.dart';

import 'src/debug.dart';
import 'src/exceptions.dart';

// Export exceptions so users can catch them
export 'src/exceptions.dart';

/// Defines the interface for objects that have a lifecycle.
///
/// Implementers of this interface can be managed by [RaiiLifecycleAware] objects,
/// which will handle their initialization and disposal automatically.
abstract interface class RaiiLifecycle {
  /// Initializes the lifecycle of this object.
  ///
  /// This should be called when the object needs to be initialized
  /// or its resources need to be set up.
  ///
  /// Throws [StateError] if called when already initialized.
  void initLifecycle();

  /// Disposes of any resources held by this object.
  ///
  /// This should be called when the object is no longer needed
  /// to clean up any resources and prevent memory leaks.
  ///
  /// **Exception Safety:** Implementations should strive to complete
  /// disposal even if individual cleanup operations fail.
  ///
  /// Throws [StateError] if called when not initialized.
  void disposeLifecycle();

  /// Returns whether this object's lifecycle is currently mounted.
  ///
  /// Returns `true` if the object has been initialized and not yet disposed,
  /// `false` otherwise.
  bool isLifecycleMounted();
}

/// Interface for lifecycle objects that track their parent holder.
///
/// This interface enables automatic unregistration of lifecycle objects from
/// their parent when disposed. When a lifecycle implements this interface,
/// it maintains a reference to its parent [RaiiLifecycleAware] and can
/// automatically unregister itself during disposal.
///
/// ## Purpose
///
/// Without holder tracking, disposed lifecycles remain registered with their
/// parent, leading to:
/// - Memory leaks (parent keeps references to disposed objects)
/// - Double disposal attempts (parent tries to dispose already-disposed objects)
/// - Stale object access
///
/// With holder tracking, lifecycles automatically clean up their parent
/// relationship, preventing these issues.
///
/// ## How It Works
///
/// 1. When registered: Parent calls [setRaiiHolder] to establish relationship
/// 2. During use: Lifecycle maintains reference via [raiiHolder]
/// 3. When disposed: Lifecycle calls `raiiHolder?.unregisterLifecycle(this)`
/// 4. Parent cleared: Parent calls [clearRaiiHolder] to prevent stale references
///
/// ## Usage
///
/// Most users don't interact with this interface directly. Instead, use
/// [RaiiLifecycleMixin] which implements this interface automatically:
///
/// ```dart
/// class MyResource with RaiiLifecycleMixin {
///   // Holder tracking is automatic
///
///   @override
///   void disposeLifecycle() {
///     cleanup();
///     super.disposeLifecycle();  // Auto-unregisters from parent
///   }
/// }
/// ```
///
/// ## Manual Implementation
///
/// If you need custom holder tracking behavior:
///
/// ```dart
/// class CustomResource implements RaiiLifecycle, RaiiLifecycleHolderTracker {
///   RaiiLifecycleAware? _holder;
///
///   @override
///   RaiiLifecycleAware? get raiiHolder => _holder;
///
///   @override
///   void setRaiiHolder(RaiiLifecycleAware holder) {
///     _holder = holder;
///   }
///
///   @override
///   void clearRaiiHolder() {
///     _holder = null;
///   }
///
///   @override
///   void disposeLifecycle() {
///     cleanup();
///     _holder?.unregisterLifecycle(this);  // Auto-unregister
///   }
/// }
/// ```
///
/// Or use [RaiiLifecycleHolderTrackerMixin] instead.
///
/// ## Lifecycle Constraints
///
/// - A lifecycle can only be registered with one holder at a time
/// - Attempting to register with a different holder throws [StateError]
/// - Must unregister from current holder before registering with a new one
abstract interface class RaiiLifecycleHolderTracker {
  /// The holder that manages this lifecycle.
  ///
  /// Set automatically when registered with a [RaiiLifecycleAware] via
  /// [setRaiiHolder]. This reference is used to automatically unregister
  /// during disposal.
  RaiiLifecycleAware? get raiiHolder;

  /// Sets the holder for this lifecycle.
  ///
  /// This is called internally by [RaiiLifecycleAware.registerLifecycle]
  /// to establish the parent-child relationship. The holder reference is
  /// used during disposal to automatically unregister.
  ///
  /// Throws [StateError] if this lifecycle is already registered with a
  /// different holder. A lifecycle must be unregistered from its current
  /// holder before being registered with a new one.
  ///
  /// **Note:** This is an internal API and should not be called directly
  /// by users. Use [RaiiLifecycleAware.registerLifecycle] instead.
  void setRaiiHolder(RaiiLifecycleAware holder);

  /// Clears the holder reference.
  ///
  /// Called internally by [RaiiLifecycleAware.unregisterLifecycle] and
  /// during parent disposal to prevent stale references.
  ///
  /// **Note:** This is an internal API and should not be called directly
  /// by users.
  void clearRaiiHolder();
}

/// An interface for objects that can manage the lifecycle of other [RaiiLifecycle] objects.
///
/// Implementers of this interface can register and manage multiple [RaiiLifecycle] objects,
/// ensuring they are properly initialized and disposed of according to the container's lifecycle.
///
/// ## Initialization Behavior
///
/// When a lifecycle is registered with [registerLifecycle]:
/// - If the manager is already initialized, the child is initialized immediately
/// - If the manager is not yet initialized, the child will be initialized when
///   the manager's [initLifecycle] is called
///
/// ## Disposal Behavior
///
/// When [disposeLifecycle] is called, all registered lifecycles are disposed
/// in reverse registration order (LIFO: last-in, first-out). This ensures that
/// dependencies are disposed in the correct order.
///
/// ## Exception Safety
///
/// Disposal continues even if individual child disposals throw exceptions,
/// ensuring all resources are cleaned up.
abstract interface class RaiiLifecycleAware extends RaiiLifecycle {
  /// Registers a [RaiiLifecycle] object to be managed by this container.
  ///
  /// The registered object will be initialized immediately if this container
  /// is already initialized, or when the container is initialized later.
  ///
  /// Throws [StateError] if the manager has been disposed.
  void registerLifecycle(RaiiLifecycle lifecycle);

  /// Un-registers a [RaiiLifecycle] object from this container.
  ///
  /// The lifecycle will be disposed if it is still mounted.
  /// This is typically called when manually cancelling or disposing
  /// a child resource before the parent is disposed.
  ///
  /// Returns `true` if the lifecycle was registered and successfully removed,
  /// `false` if it was not registered.
  bool unregisterLifecycle(RaiiLifecycle lifecycle);
}

/// A globally accessible [RaiiManager] that never gets disposed.
///
/// Useful for managing resources that need to exist
/// for the entire application lifetime.
///
/// **Example:**
/// ```dart
/// // Register a global resource
/// final analytics = RaiiBox.withLifecycle(
///   alwaysAliveRaiiManager,
///   instance: AnalyticsService(),
///   init: (service) => service.initialize(),
///   debugLabel: 'Analytics',
/// );
/// ```
final alwaysAliveRaiiManager = _AlwaysAliveRaiiManager()..initLifecycle();

class _AlwaysAliveRaiiManager with RaiiManagerMixin {
  @override
  // ignore: must_call_super
  void disposeLifecycle() {
    throw StateError(
      'This manager cannot be disposed as it must remain active '
      'throughout the entire application lifecycle',
    );
  }
}

/// A concrete implementation of [RaiiLifecycleAware] that can manage multiple lifecycles.
///
/// This class uses [RaiiManagerMixin] to provide the basic implementation.
///
/// **Example:**
/// ```dart
/// final manager = RaiiManager()..initLifecycle();
///
/// final resource1 = RaiiBox.withLifecycle(manager, instance: Resource1());
/// final resource2 = RaiiBox.withLifecycle(manager, instance: Resource2());
///
/// // When done, dispose all resources
/// manager.disposeLifecycle(); // Disposes resource2, then resource1 (LIFO)
/// ```
class RaiiManager with RaiiManagerMixin {}

/// Mixin implementation of [RaiiLifecycleHolderTracker].
///
/// This mixin provides a standard implementation of holder tracking with
/// proper validation and state management. Most lifecycle objects should
/// use this mixin rather than implementing the interface manually.
///
/// Attempting to register with a different holder throws [StateError]:
/// ```
mixin RaiiLifecycleHolderTrackerMixin implements RaiiLifecycleHolderTracker {
  RaiiLifecycleAware? _holder;

  @override
  RaiiLifecycleAware? get raiiHolder => _holder;

  @override
  void setRaiiHolder(RaiiLifecycleAware holder) {
    if (_holder != null && _holder != holder) {
      throw StateError(
        'Lifecycle is already registered with a different holder. '
        'Unregister from the current holder before registering with a new one.',
      );
    }
    _holder = holder;
  }

  @override
  void clearRaiiHolder() {
    _holder = null;
  }
}

/// A mixin that implements the [RaiiLifecycle] interface with basic lifecycle state tracking.
///
/// Provides a base implementation for objects that need lifecycle management but don't
/// need to manage other lifecycles.
///
/// This mixin automatically tracks its holder (the [RaiiLifecycleAware] that registered it)
/// and unregisters itself during disposal, eliminating the need for manual unregistration
/// in every lifecycle class.
///
/// **Example:**
/// ```dart
/// class MyResource with RaiiLifecycleMixin {
///   MyResource.withLifecycle(RaiiLifecycleAware holder) {
///     holder.registerLifecycle(this);  // Holder is tracked automatically
///   }
///
///   @override
///   void disposeLifecycle() {
///     _connection.close();
///     super.disposeLifecycle();  // Automatically unregisters from holder
///   }
/// }
/// ```
mixin RaiiLifecycleMixin implements RaiiLifecycle, RaiiLifecycleHolderTracker {
  var _isLifecycleMounted = false;
  var _isDisposed = false;

  RaiiLifecycleAware? _holder;

  @override
  RaiiLifecycleAware? get raiiHolder => _holder;

  @override
  void setRaiiHolder(RaiiLifecycleAware holder) {
    if (_holder != null && _holder != holder) {
      throw StateError(
        'Lifecycle is already registered with a different holder. '
        'Unregister from the current holder before registering with a new one.',
      );
    }
    _holder = holder;
  }

  @override
  void clearRaiiHolder() {
    _holder = null;
  }

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  /// Whether this lifecycle has been disposed.
  ///
  /// This is the inverse of [isLifecycleMounted] and is provided
  /// as a convenience for more readable code.
  bool get isDisposed => _isDisposed;

  @override
  @mustCallSuper
  void initLifecycle() {
    if (_isLifecycleMounted) {
      throw const AlreadyInitializedException();
    }

    _isLifecycleMounted = true;
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    if (_isDisposed) {
      throw const AlreadyDisposedException();
    }

    if (!_isLifecycleMounted) {
      throw const NotInitializedException();
    }

    // Automatically unregister from holder if we have one.
    _holder?.unregisterLifecycle(this);

    _isLifecycleMounted = false;
    _isDisposed = true;
  }
}

/// A mixin that implements the [RaiiLifecycleAware] interface with support for managing
/// multiple lifecycle objects.
///
/// This mixin maintains a list of registered lifecycles and ensures they are properly
/// initialized and disposed of according to the container's lifecycle.
///
/// ## Disposal Order
///
/// Children are disposed in reverse registration order (LIFO). This mirrors
/// constructor/destructor semantics and is safer when there are dependencies
/// between resources.
///
/// ## Exception Safety
///
/// If a child's disposal throws an exception, it is caught and reported via
/// [FlutterError.reportError], and disposal continues for remaining children.
mixin RaiiManagerMixin
    implements RaiiLifecycleAware, RaiiLifecycleHolderTracker {
  /// All active lifecycles, can be useful for testing.
  @visibleForTesting
  final registeredLifecycles = <RaiiLifecycle>[];

  bool _isLifecycleMounted = false;
  bool _isDisposed = false;

  RaiiLifecycleAware? _holder;

  @override
  RaiiLifecycleAware? get raiiHolder => _holder;

  @override
  void setRaiiHolder(RaiiLifecycleAware holder) {
    if (_holder != null && _holder != holder) {
      throw StateError(
        'Lifecycle is already registered with a different holder. '
        'Unregister from the current holder before registering with a new one.',
      );
    }
    _holder = holder;
  }

  @override
  void clearRaiiHolder() {
    _holder = null;
  }

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  /// Whether this manager has been disposed.
  bool get isDisposed => _isDisposed;

  /// Returns the number of currently registered child lifecycles.
  ///
  /// Useful for debugging and testing.
  int get childCount => registeredLifecycles.length;

  @override
  @mustCallSuper
  void registerLifecycle(RaiiLifecycle lifecycle) {
    if (isDisposed) {
      throw const ManagerDisposedException();
    }

    if (registeredLifecycles.contains(lifecycle)) {
      return;
    }

    registeredLifecycles.add(lifecycle);

    // Set holder reference for automatic unregistration during disposal
    if (lifecycle is RaiiLifecycleHolderTracker) {
      (lifecycle as RaiiLifecycleHolderTracker).setRaiiHolder(this);
    }

    // Initialize immediately if manager is already initialized
    if (_isLifecycleMounted) {
      lifecycle.initLifecycle();
    }
  }

  @override
  @mustCallSuper
  bool unregisterLifecycle(RaiiLifecycle lifecycle) {
    final removed = registeredLifecycles.remove(lifecycle);

    if (!removed) {
      // Not an error - might have been removed already or never registered
      return false;
    }

    // Clear holder reference to prevent stale references
    if (lifecycle is RaiiLifecycleHolderTracker) {
      (lifecycle as RaiiLifecycleHolderTracker).clearRaiiHolder();
    }

    // Dispose if still mounted (only happens outside disposal loop)
    if (lifecycle.isLifecycleMounted()) {
      lifecycle.disposeLifecycle();
    }

    return true;
  }

  @override
  @mustCallSuper
  void initLifecycle() {
    if (_isLifecycleMounted) {
      throw const AlreadyInitializedException();
    }

    // Initialize all registered children
    for (final lifecycle in registeredLifecycles) {
      lifecycle.initLifecycle();
    }

    _isLifecycleMounted = true;
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    if (_isDisposed) {
      throw const AlreadyDisposedException();
    }

    if (!_isLifecycleMounted) {
      throw const NotInitializedException();
    }

    // Dispose in reverse order (LIFO: last registered, first disposed)
    final lifecycles = registeredLifecycles.reversed.toList();

    // Clear list and mark as unmounted before disposal to prevent
    // re-registration during disposal callbacks
    registeredLifecycles.clear();

    // Automatically unregister from holder if we have one.
    _holder?.unregisterLifecycle(this);

    _isLifecycleMounted = false;
    _isDisposed = true;

    // Dispose all children, catching exceptions to ensure all get disposed
    for (final lifecycle in lifecycles) {
      try {
        if (lifecycle.isLifecycleMounted()) {
          // Clear holder reference BEFORE calling disposeLifecycle
          // This prevents the child's super.disposeLifecycle() from calling
          // unregisterLifecycle, since _holder will be null
          if (lifecycle is RaiiLifecycleHolderTracker) {
            (lifecycle as RaiiLifecycleHolderTracker).clearRaiiHolder();
          }

          lifecycle.disposeLifecycle();
        }
      } on AlreadyDisposedException {
        // Ignore - child was already disposed, which is fine
        continue;
      } catch (e, stack) {
        // Report other errors but continue disposing remaining lifecycles
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: DisposalFailedException(
              'Failed to dispose child lifecycle',
              originalException: e,
              originalStackTrace: stack,
            ),
            stack: stack,
            library: 'raii',
            context: ErrorDescription(
              'while disposing lifecycle in RaiiManagerMixin',
            ),
          ),
        );
      }
    }
  }
}

/// A container class that wraps an instance with lifecycle management capabilities.
///
/// This class is useful for adding lifecycle management to objects that don't
/// implement [RaiiLifecycle] themselves. It can execute custom initialization and
/// disposal logic for the wrapped instance.
///
/// **Example:**
/// ```dart
/// final connection = RaiiBox.withLifecycle(
///   manager,
///   instance: DatabaseConnection(),
///   init: (conn, _) => conn.connect(),
///   dispose: (conn, _) => conn.disconnect(),
///   debugLabel: 'DbConnection',
/// );
///
/// // Access the wrapped instance
/// connection.instance.query('SELECT * FROM users');
/// ```
class RaiiBox<T> with RaiiLifecycleMixin {
  /// Creates a new instance and attaches it to the given [lifecycleAware].
  ///
  /// Parameters:
  /// - [lifecycleAware]: The parent lifecycle that will manage this box
  /// - [instance]: The object to wrap with lifecycle management
  /// - [init]: Optional initialization function called when lifecycle is initialized
  /// - [dispose]: Optional disposal function called when lifecycle is disposed
  /// - [debugLabel]: Optional label for debugging lifecycle events
  RaiiBox.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required this.instance,
    this.init,
    this.dispose,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// Simpler factory constructor for objects that just need disposal.
  ///
  /// Use this when you don't need initialization logic or access to the
  /// [RaiiLifecycle] in callbacks.
  ///
  /// **Example:**
  /// ```dart
  /// final timer = RaiiBox.disposable(
  ///   manager,
  ///   Timer.periodic(Duration(seconds: 1), (_) => print('tick')),
  ///   dispose: (t) => t.cancel(),
  ///   debugLabel: 'HeartbeatTimer',
  /// );
  /// ```
  factory RaiiBox.disposable(
    RaiiLifecycleAware lifecycleAware,
    T instance, {
    void Function(T)? dispose,
    String? debugLabel,
  }) {
    return RaiiBox.withLifecycle(
      lifecycleAware,
      instance: instance,
      dispose: dispose != null ? (inst, _) => dispose(inst) : null,
      debugLabel: debugLabel,
    );
  }

  /// Function called to initialize the wrapped instance.
  ///
  /// Receives both the instance and the lifecycle for advanced use cases.
  final void Function(T instance, RaiiLifecycle lifecycle)? init;

  /// Function called to dispose of the wrapped instance.
  ///
  /// Receives both the instance and the lifecycle for advanced use cases.
  final void Function(T instance, RaiiLifecycle lifecycle)? dispose;

  /// Optional label for debugging purposes.
  ///
  /// When provided, lifecycle events will be logged to the console with this label.
  final String? debugLabel;

  /// The wrapped instance being managed.
  final T instance;

  @override
  void initLifecycle() {
    super.initLifecycle();

    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
    init?.call(instance, this);
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }

    // Dispose instance before unmounting lifecycle (symmetric with init)
    dispose?.call(instance, this);

    super.disposeLifecycle();
  }
}

/// Helper class for managing simple disposable resources.
///
/// This is used internally by extension methods but can also be used directly
/// for wrapping objects that have a `dispose()` method.
///
/// **Example:**
/// ```dart
/// final sub = myStream.listen(print);
/// RaiiDisposeable.withLifecycle(
///   manager,
///   dispose: () => sub.cancel(),
///   debugLabel: 'StreamSubscription',
/// );
/// ```
class RaiiDisposeable with RaiiLifecycleMixin {
  /// Creates a disposable resource attached to the given [lifecycleAware].
  RaiiDisposeable.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required this.dispose,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// Function called to dispose the resource.
  final void Function() dispose;

  /// Optional label for debugging purposes.
  final String? debugLabel;

  @override
  void initLifecycle() {
    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
    super.initLifecycle();
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }
    dispose();
    super.disposeLifecycle();
  }
}
