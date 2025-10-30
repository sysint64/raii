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
///
/// **Basic usage:**
///
/// ```dart
/// // Create a lifecycle container
/// final raiiManager = RaiiManager();
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

/// Defines the interface for objects that have a lifecycle.
///
/// Implementers of this interface can be managed by [RaiiLifecycleAware] objects,
/// which will handle their initialization and disposal automatically.
abstract class RaiiLifecycle {
  /// Initializes the lifecycle of this object.
  ///
  /// This should be called when the object needs to be initialized
  /// or its resources need to be set up.
  void initLifecycle();

  /// Disposes of any resources held by this object.
  ///
  /// This should be called when the object is no longer needed
  /// to clean up any resources and prevent memory leaks.
  void disposeLifecycle();

  /// Returns whether this object's lifecycle is currently mounted.
  ///
  /// Returns `true` if the object has been initialized and not yet disposed,
  /// `false` otherwise.
  bool isLifecycleMounted();
}

/// An interface for objects that can manage the lifecycle of other [RaiiLifecycle] objects.
///
/// Implementers of this interface can register and manage multiple [RaiiLifecycle] objects,
/// ensuring they are properly initialized and disposed of according to the container's lifecycle.
abstract class RaiiLifecycleAware implements RaiiLifecycle {
  /// Registers a [RaiiLifecycle] object to be managed by this container.
  ///
  /// The registered object will be initialized if this container is already initialized,
  /// and will be disposed when this container is disposed.
  void registerLifecycle(RaiiLifecycle lifecycle);

  /// Un-registers a [RaiiLifecycle] object from this container.
  ///
  /// The registered object will be disposed if this [lifecycle] is still mounted.
  void unregisterLifecycle(RaiiLifecycle lifecycle);
}

/// A globally accessible [RaiiManager] that never gets disposed.
///
/// Useful for managing resources that need to exist
/// for the entire application lifetime.
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
class RaiiManager with RaiiManagerMixin {}

/// A mixin that implements the [RaiiLifecycle] interface with basic lifecycle state tracking.
///
/// Provides a base implementation for objects that need lifecycle management but don't
/// need to manage other lifecycles.
mixin RaiiLifecycleMixin implements RaiiLifecycle {
  var _isLifecycleMounted = false;

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  @override
  @mustCallSuper
  void initLifecycle() {
    if (_isLifecycleMounted) {
      throw StateError('Init when lifecycle is already mounted');
    }

    _isLifecycleMounted = true;
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    if (!_isLifecycleMounted) {
      throw StateError('Dispose when lifecycle is not mounted');
    }

    _isLifecycleMounted = false;
  }
}

/// A mixin that implements the [RaiiLifecycleAware] interface with support for managing
/// multiple lifecycle objects.
///
/// This mixin maintains a list of registered lifecycles and ensures they are properly
/// initialized and disposed of according to the container's lifecycle.
mixin RaiiManagerMixin implements RaiiLifecycleAware {
  final _registeredLifecycles = <RaiiLifecycle>[];
  bool _init = false;
  bool _isLifecycleMounted = false;

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  @override
  @mustCallSuper
  void registerLifecycle(RaiiLifecycle lifecycle) {
    if (!_isLifecycleMounted && _init) {
      throw StateError('Try to register lifecycle when manager is disposed');
    }

    _registeredLifecycles.add(lifecycle);

    if (_init) {
      lifecycle.initLifecycle();
    }
  }

  @override
  void unregisterLifecycle(RaiiLifecycle lifecycle) {
    _registeredLifecycles.remove(lifecycle);

    if (lifecycle.isLifecycleMounted()) {
      lifecycle.disposeLifecycle();
    }
  }

  @override
  @mustCallSuper
  void initLifecycle() {
    if (_isLifecycleMounted) {
      throw StateError('Init when lifecycle is already mounted');
    }

    for (final lifecycle in _registeredLifecycles) {
      lifecycle.initLifecycle();
    }
    _init = true;
    _isLifecycleMounted = true;
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    if (!_isLifecycleMounted) {
      throw StateError('Dispose when lifecycle is not mounted');
    }

    for (final lifecycle in _registeredLifecycles) {
      lifecycle.disposeLifecycle();
    }

    _registeredLifecycles.clear();
    _isLifecycleMounted = false;
  }
}

/// A container class that wraps an instance with lifecycle management capabilities.
///
/// This class is useful for adding lifecycle management to objects that don't
/// implement [RaiiLifecycle] themselves. It can execute custom initialization and
/// disposal logic for the wrapped instance.
class RaiiBox<T> with RaiiLifecycleMixin {
  /// Creates a new instance and attaches it to the given [lifecycleAware].
  RaiiBox.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required this.instance,
    this.init,
    this.dispose,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// Function called to initialize the wrapped instance.
  final void Function(T instance, RaiiLifecycle lifecycle)? init;

  /// Function called to dispose of the wrapped instance.
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
    dispose?.call(instance, this);
    super.disposeLifecycle();
  }
}
