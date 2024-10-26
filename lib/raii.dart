/// Core library providing RAII (Resource Acquisition Is Initialization) pattern implementation
/// for Dart/Flutter applications.
///
/// This library provides a foundation for managing object lifecycles through a systematic
/// approach to resource initialization and cleanup. It implements the RAII pattern,
/// ensuring that resources are properly managed throughout their lifetime.
///
/// The library follows these core principles:
/// 1. Explicit lifecycle management through clear interfaces
/// 2. Hierarchical resource management where parent objects manage their children
/// 3. Automatic cleanup of resources when they're no longer needed
///
/// Basic usage:
/// ```dart
/// // Create a lifecycle container
/// final container = LifecycleAwareContainer();
///
/// // Wrap a resource that needs lifecycle management
/// final resource = LifecycleBox.attach(
///   container,
///   instance: MyResource(),
///   init: (r) => r.initialize(),
///   dispose: (r) => r.cleanup(),
///   debugLabel: 'MyResource',
/// );
///
/// // When done, dispose the container to cleanup all managed resources
/// container.disposeLifecycle();
/// ```
///
/// For long-lived resources that should exist for the entire application lifetime,
/// use [alwaysAliveLifecycleAwareContainer]:
/// ```dart
/// final globalResource = LifecycleBox.attach(
///   alwaysAliveLifecycleAwareContainer,
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

/// Defines the interface for objects that have a lifecycle.
///
/// Implementers of this interface can be managed by [LifecycleAware] objects,
/// which will handle their initialization and disposal automatically.
abstract class Lifecycle {
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

/// An interface for objects that can manage the lifecycle of other [Lifecycle] objects.
///
/// Implementers of this interface can register and manage multiple [Lifecycle] objects,
/// ensuring they are properly initialized and disposed of according to the container's lifecycle.
abstract class LifecycleAware implements Lifecycle {
  /// Registers a [Lifecycle] object to be managed by this container.
  ///
  /// The registered object will be initialized if this container is already initialized,
  /// and will be disposed when this container is disposed.
  void registerLifecycle(Lifecycle lifecycle);
}

/// A globally accessible [LifecycleAwareContainer] that never gets disposed.
///
/// Useful for managing resources that need to exist
/// for the entire application lifetime.
final alwaysAliveLifecycleAwareContainer = LifecycleAwareContainer();

/// A concrete implementation of [LifecycleAware] that can manage multiple lifecycles.
///
/// This class uses [LifecycleAwareMixin] to provide the basic implementation.
class LifecycleAwareContainer with LifecycleAwareMixin {}

/// A mixin that implements the [Lifecycle] interface with basic lifecycle state tracking.
///
/// Provides a base implementation for objects that need lifecycle management but don't
/// need to manage other lifecycles.
mixin LifecycleMixin implements Lifecycle {
  var _isLifecycleMounted = false;

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  @override
  @mustCallSuper
  void initLifecycle() {
    _isLifecycleMounted = true;
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    _isLifecycleMounted = false;
  }
}

/// A mixin that implements the [LifecycleAware] interface with support for managing
/// multiple lifecycle objects.
///
/// This mixin maintains a list of registered lifecycles and ensures they are properly
/// initialized and disposed of according to the container's lifecycle.
mixin LifecycleAwareMixin implements LifecycleAware {
  @visibleForTesting
  final registeredLifecycles = <Lifecycle>[];
  bool _init = false;
  bool _isLifecycleMounted = false;

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  @override
  @mustCallSuper
  void registerLifecycle(Lifecycle lifecycle) {
    registeredLifecycles.add(lifecycle);

    if (_init) {
      lifecycle.initLifecycle();
    }
  }

  @override
  @mustCallSuper
  void initLifecycle() {
    for (final lifecycle in registeredLifecycles) {
      lifecycle.initLifecycle();
    }
    _init = true;
    _isLifecycleMounted = true;
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    for (final lifecycle in registeredLifecycles) {
      lifecycle.disposeLifecycle();
    }

    registeredLifecycles.clear();
    _isLifecycleMounted = false;
  }
}

/// A container class that wraps an instance with lifecycle management capabilities.
///
/// This class is useful for adding lifecycle management to objects that don't
/// implement [Lifecycle] themselves. It can execute custom initialization and
/// disposal logic for the wrapped instance.
class LifecycleBox<T> with LifecycleMixin {
  /// Creates a new instance and attaches it to the given [lifecycleAware].
  LifecycleBox.attach(
    LifecycleAware lifecycleAware, {
    required this.instance,
    this.init,
    this.dispose,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// Function called to initialize the wrapped instance.
  final void Function(T instance)? init;

  /// Function called to dispose of the wrapped instance.
  final void Function(T instance)? dispose;

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
      debugPrint('[RAII] Init lifecycle: $debugLabel');
    }
    init?.call(instance);
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      debugPrint('[RAII] Dispose lifecycle: $debugLabel');
    }
    dispose?.call(instance);
    super.disposeLifecycle();
  }
}
