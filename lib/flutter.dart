/// A Flutter library that provides RAII pattern implementation for managing
/// the lifecycle of disposable resources.
///
/// This library offers a systematic approach to resource management in Flutter applications
/// by automatically handling the initialization and disposal of resources. It helps prevent
/// memory leaks and ensures proper cleanup of resources when they are no longer needed.
///
/// **Key features:**
///
/// - Automatic resource disposal through lifecycle management
/// - Fluent API for resource registration
/// - Debug logging support for lifecycle events
/// - Type-safe resource management
/// - Integration with Flutter's widget lifecycle
///
/// **The library provides support for many Flutter resources including:**
///
/// - Controllers (Animation, Text, Scroll, etc.)
/// - Notifiers and Listeners
/// - Streams
/// - App lifecycle
///
/// **Example usage:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, RaiiStateMixin {
///   // Resources are automatically disposed when the widget is disposed
///   late final controller = AnimationController(vsync: this)
///     .withLifecycle(this, debugLabel: 'MyAnimation');
///
///   late final textController = TextEditingController()
///     .withLifecycle(this, debugLabel: 'TextInput');
///
///   @override
///   void initLifecycle() {
///     super.initLifecycle();
///
///     // Register listeners with automatic cleanup
///     controller.addListenerWithLifecycle(
///       this,
///       () => setState(() {}),
///       debugLabel: 'AnimationListener',
///     );
///   }
/// }
/// ```
///
/// **The library follows these principles:**
///
/// - Resources should be acquired and initialized at construction time
/// - Resources should be automatically released when no longer needed
/// - Resource cleanup should be deterministic and predictable
/// - The API should be simple and intuitive to use
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:raii/raii.dart';
import 'package:raii/src/debug.dart';

/// Extension of [RaiiLifecycleAware] that provides access to build context.
abstract class RaiiLifecycleAwareWithContext implements RaiiLifecycleAware {
  /// Flutter build context.
  BuildContext get context;
}

/// A mixin that implements [RaiiLifecycleAware] for [StatefulWidget] states.
///
/// This mixin provides lifecycle management capabilities to widget states, automatically
/// handling initialization and disposal of registered lifecycles in sync with the
/// widget's lifecycle.
///
/// The lifecycle initialization is deferred until [didChangeDependencies] to ensure
/// that inherited dependencies are available. This is particularly important when
/// lifecycles need access to inherited widgets or other context-dependent resources.
///
/// Important: When using this mixin with [TickerProviderStateMixin] or
/// [SingleTickerProviderStateMixin], you must declare them before this mixin:
///
/// ```dart
/// // Correct order:
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, RaiiStateMixin {
///   // ...
/// }
///
/// // Incorrect order - will cause incorrect resources disposal:
///     with RaiiStateMixin, TickerProviderStateMixin {
///   // ...
/// }
/// ```
///
/// **Example usage:**
///
/// ```dart
/// class MyWidgetState extends
///     with TickerProviderStateMixin, RaiiStateMixin {
///   late final _animationController = AnimationController(
///     vsync: this,
///     duration: const Duration(milliseconds: 300),
///   ).withLifecycle(this);
///
///   @override
///   void initLifecycle() {
///     super.initLifecycle();
///
///     _animationController.addListenerWithLifecycle(
///       this,
///       () {
///         // Update state when animation happens.
///       },
///     );
///   }
///   // ...
/// }
/// ```
mixin RaiiStateMixin<T extends StatefulWidget> on State<T>
    implements RaiiLifecycleAwareWithContext, RaiiLifecycleHolderTracker {
  final _pendingLifecycles = <RaiiLifecycle>{};

  bool _attached = false;
  late final _raiiManager = RaiiManager();

  @override
  RaiiLifecycleAware? get raiiHolder => _raiiManager.raiiHolder;

  @override
  void setRaiiHolder(RaiiLifecycleAware holder) {
    _raiiManager.setRaiiHolder(holder);
  }

  @override
  void clearRaiiHolder() {
    _raiiManager.clearRaiiHolder();
  }

  @override
  bool isLifecycleMounted() => _raiiManager.isLifecycleMounted();

  @override
  @mustCallSuper
  void initLifecycle() {
    _raiiManager.initLifecycle();
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    _raiiManager.disposeLifecycle();
  }

  @override
  void didChangeDependencies() {
    // Perform one-time lifecycle attachment
    if (!_attached) {
      initLifecycle();

      // Initialize any pending lifecycle objects
      for (final lifecycle in _pendingLifecycles) {
        _raiiManager.registerLifecycle(lifecycle);
      }

      _pendingLifecycles.clear();
      _attached = true;
    }

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    disposeLifecycle();

    // Warn about pending lifecycles that were never initialized
    if (_pendingLifecycles.isNotEmpty) {
      raiiTrace(
        '[RAII] ${_pendingLifecycles.length} pending lifecycles never attached',
      );
      _pendingLifecycles.clear();
    }

    super.dispose();
  }

  @override
  @mustCallSuper
  void registerLifecycle(RaiiLifecycle lifecycle) {
    if (_raiiManager.isDisposed) {
      throw const ManagerDisposedException();
    }

    if (_attached) {
      _raiiManager.registerLifecycle(lifecycle);
    } else {
      _pendingLifecycles.add(lifecycle);
    }
  }

  @override
  @mustCallSuper
  bool unregisterLifecycle(RaiiLifecycle lifecycle) {
    // Check pending first
    if (_pendingLifecycles.remove(lifecycle)) {
      return true;
    }

    return _raiiManager.unregisterLifecycle(lifecycle);
  }
}

/// A lifecycle implementation that manages the lifecycle of a listener attached to a [Listenable].
///
/// This class provides automatic management of listeners for any [Listenable] object
/// (such as [ChangeNotifier], [ValueNotifier], or custom implementations). It ensures
/// that listeners are properly added during initialization and removed during disposal.
///
/// **Example:**
///
/// ```dart
/// // Basic usage with ValueNotifier
/// final counter = ValueNotifier(0).withLifecycle(lifecycleAware);
/// RaiiListenableListener.withLifecycle(
///   lifecycleAware,
///   listenable: counter,
///   onListen: () => print('Counter changed: ${counter.value}'),
///   debugLabel: 'CounterListener',
/// );
///
/// // Usage with animation controller
/// final animation = AnimationController(vsync: this)
///   .withLifecycle(lifecycleAware);
/// RaiiListenableListener.withLifecycle(
///   lifecycleAware,
///   listenable: animation,
///   onListen: () => print('Animation value: ${animation.value}'),
///   debugLabel: 'AnimationListener',
/// );
///
/// // Usage with custom ChangeNotifier
/// class UserModel extends ChangeNotifier {
///   String name = '';
///   void updateName(String newName) {
///     name = newName;
///     notifyListeners();
///   }
/// }
///
/// final user = UserModel();
/// RaiiListenableListener.withLifecycle(
///   lifecycleAware,
///   listenable: user,
///   onListen: () => print('User updated: ${user.name}'),
///   debugLabel: 'UserModelListener',
/// );
/// ```
class RaiiListenableListener<T extends Listenable> with RaiiLifecycleMixin {
  /// Creates a [RaiiListenableListener] and attaches it to the provided [lifecycleAware].
  ///
  /// The listener will be automatically added during initialization and removed
  /// during disposal, ensuring proper cleanup of event handlers.
  RaiiListenableListener.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required this.listenable,
    required this.onListen,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// The listenable object to which the listener will be attached.
  final T listenable;

  /// Optional label for debugging purposes.
  ///
  /// When provided, lifecycle events will be logged to the console with this label.
  final String? debugLabel;

  /// The callback that will be executed when the listenable notifies its listeners.
  final VoidCallback onListen;

  @override
  void initLifecycle() {
    super.initLifecycle();
    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
    listenable.addListener(onListen);
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }
    listenable.removeListener(onListen);
    super.disposeLifecycle();
  }
}

/// A lifecycle implementation that manages the lifecycle of a [WidgetsBindingObserver].
///
/// This class automatically handles registration and removal of [WidgetsBindingObserver]s
/// with the [WidgetsBinding] instance. It's particularly useful for managing app lifecycle
/// events, keyboard visibility changes, system settings changes, and other app-wide events.
///
/// See also [WidgetsBindingRaiiExt].
///
/// **Example:**
///
/// ```dart
/// // Basic app lifecycle observer
/// class AppLifecycleObserver with WidgetsBindingObserver {
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     switch (state) {
///       case AppLifecycleState.resumed:
///         print('App resumed');
///         break;
///       case AppLifecycleState.inactive:
///         print('App inactive');
///         break;
///       case AppLifecycleState.paused:
///         print('App paused');
///         break;
///       case AppLifecycleState.detached:
///         print('App detached');
///         break;
///     }
///   }
/// }
///
/// // Attach the observer
/// final lifecycleObserver = AppLifecycleObserver();
/// RaiiWidgetsBindingObserver.withLifecycle(
///   lifecycleAware,
///   lifecycleObserver,
///   debugLabel: 'AppLifecycle',
/// );
///
/// // System settings observer
/// class SystemSettingsObserver with WidgetsBindingObserver {
///   @override
///   void didChangePlatformBrightness() {
///     print('Brightness changed');
///   }
///
///   @override
///   void didChangeLocales(List<Locale>? locales) {
///     print('Locales changed');
///   }
/// }
///
/// // Attach the system observer
/// final settingsObserver = SystemSettingsObserver();
/// RaiiWidgetsBindingObserver.withLifecycle(
///   lifecycleAware,
///   WidgetsBinding.instance,
///   settingsObserver,
///   debugLabel: 'SystemSettings',
/// );
/// ```
class RaiiWidgetsBindingObserver with RaiiLifecycleMixin {
  /// Creates a [RaiiWidgetsBindingObserver] and attaches it to the provided [lifecycleAware].
  ///
  /// The observer will be automatically registered with [WidgetsBinding.instance]
  /// during initialization and removed during disposal.
  RaiiWidgetsBindingObserver.withLifecycle(
    RaiiLifecycleAware lifecycleAware,
    this.widgetsBinding,
    this.observer, {
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// The observer that will be registered with [WidgetsBinding.instance].
  final WidgetsBindingObserver observer;

  /// Widgets Binding instance.
  ///
  /// This instance is typically accessed via [WidgetsBinding.instance], but can be
  /// injected here for testing or specialized use cases.
  final WidgetsBinding widgetsBinding;

  /// Optional label for debugging purposes.
  ///
  /// When provided, lifecycle events will be logged to the console with this label.
  final String? debugLabel;

  @override
  void initLifecycle() {
    super.initLifecycle();
    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
    widgetsBinding.addObserver(observer);
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }
    widgetsBinding.removeObserver(observer);
    super.disposeLifecycle();
  }
}

/// Extension for managing [StreamSubscription] lifecycle.
///
/// **Example usage:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   @override
///   void initLifecycle() {
///     super.initLifecycle();
///
///     myStream.listen(onData).withLifecycle(
///       this,
///       debugLabel: 'MyStreamSubscription',
///     );
///   }
/// }
/// ```
extension StreamSubscriptionLifecycleRaiiExt<T> on StreamSubscription<T> {
  /// Attaches this [StreamSubscription] to a [RaiiLifecycleAware] object.
  ///
  /// The subscription will be automatically cancelled when the lifecycle is disposed.
  ///
  /// Returns the original [StreamSubscription] for chaining.
  StreamSubscription<T> withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    _StreamSubscriptionRaiiLifecycle.withLifecycle(
      lifecycleAware,
      sub: this,
      debugLabel: debugLabel,
    );

    return this;
  }
}

class _StreamSubscriptionRaiiLifecycle<T> with RaiiLifecycleMixin {
  _StreamSubscriptionRaiiLifecycle.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required this.sub,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  final StreamSubscription<T> sub;
  final String? debugLabel;

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }
    sub.cancel();

    super.disposeLifecycle();
  }

  @override
  void initLifecycle() {
    super.initLifecycle();

    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
  }
}

/// Extension for managing types that extends [ChangeNotifier] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, RaiiStateMixin {
///   late final tabController = TabController(length: 3, vsync: this)
///       .withLifecycle(this, debugLabel: 'Tabs');
///
///   late final scrollController =
///       ScrollController().withLifecycle(this, debugLabel: 'Scroll');
///
///   late final textController =
///       TextEditingController().withLifecycle(this, debugLabel: 'TextInput');
///
///   late final focusNode =
///       FocusNode().withLifecycle(this, debugLabel: 'FocusNode');
/// }
/// ```
extension ChangeNotifierExt<T extends ChangeNotifier> on T {
  /// Attaches this change notifier to a [RaiiLifecycleAware] object for automatic disposal.
  ///
  /// The change notifier will be disposed when the lifecycle is disposed.
  T withLifecycle(RaiiLifecycleAware lifecycleAware, {String? debugLabel}) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [AnimationController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, RaiiStateMixin {
///   late final animationController = AnimationController(vsync: this)
///     .withLifecycle(this, debugLabel: 'MyAnimationController');
/// }
/// ```
extension AnimationControllerRaiiExt on AnimationController {
  /// Attaches this controller to a [RaiiLifecycleAware] object for automatic disposal.
  ///
  /// The controller will be disposed when the lifecycle is disposed.
  AnimationController withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension for managing [Ticker] lifecycle.
///
/// This extension ensures both stopping and disposing of the ticker.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, RaiiStateMixin {
///   late final ticker = Ticker(onTick)
///     .withLifecycle(this, debugLabel: 'MyTicker');
/// }
/// ```
extension TickerRaiiExt on Ticker {
  /// Attaches this ticker to a [RaiiLifecycleAware] object for automatic cleanup.
  ///
  /// The ticker will be stopped and disposed when the lifecycle is disposed.
  Ticker withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: () {
        stop();
        dispose();
      },
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension that provides a more direct way to add lifecycle-managed
/// listeners to any [Listenable] object (such as [ChangeNotifier],
/// [ValueNotifier],or [AnimationController]).
extension ListenableRaiiExt on Listenable {
  /// Adds a listener that will be automatically removed
  /// when the [lifecycleAware] is disposed.
  void addListenerWithLifecycle(
    RaiiLifecycleAware lifecycleAware,
    VoidCallback onListen, {
    String? debugLabel,
  }) {
    RaiiListenableListener.withLifecycle(
      lifecycleAware,
      listenable: this,
      onListen: onListen,
      debugLabel: debugLabel,
    );
  }
}

/// Extension that provides a more direct way to add lifecycle-managed
/// status listeners to Animation object.
extension AnimationRaiiExt<T> on Animation<T> {
  /// Adds a status listener that will be automatically removed
  /// when the [lifecycleAware] is disposed.
  void addStatusListenerWithLifecycle(
    RaiiLifecycleAware lifecycleAware,
    AnimationStatusListener onListen, {
    String? debugLabel,
  }) {
    _AnimationStatusListener.withLifecycle(
      lifecycleAware,
      listenable: this,
      onListen: onListen,
      debugLabel: debugLabel,
    );
  }
}

class _AnimationStatusListener<T> with RaiiLifecycleMixin {
  _AnimationStatusListener.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required this.listenable,
    required this.onListen,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  final Animation<T> listenable;

  final String? debugLabel;

  final AnimationStatusListener onListen;

  @override
  void initLifecycle() {
    super.initLifecycle();
    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
    listenable.addStatusListener(onListen);
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }
    listenable.removeStatusListener(onListen);
    super.disposeLifecycle();
  }
}

/// Extension that provides a more direct way to add lifecycle-managed
/// observers to the [WidgetsBinding] instance.
///
/// **Example:**
///
/// ```dart
/// // Basic app lifecycle observer
/// class AppLifecycleObserver with WidgetsBindingObserver {
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     switch (state) {
///       case AppLifecycleState.resumed:
///         print('App resumed');
///         break;
///       case AppLifecycleState.inactive:
///         print('App inactive');
///         break;
///       case AppLifecycleState.paused:
///         print('App paused');
///         break;
///       case AppLifecycleState.detached:
///         print('App detached');
///         break;
///     }
///   }
/// }
///
/// // Attach the observer
/// final lifecycleObserver = AppLifecycleObserver();
/// WidgetsBinding.instance.addObserverWithLifecycle(
///   lifecycleAware,
///   lifecycleObserver,
///   debugLabel: 'AppLifecycle',
/// );
///
/// // System settings observer
/// class SystemSettingsObserver with WidgetsBindingObserver {
///   @override
///   void didChangePlatformBrightness() {
///     print('Brightness changed');
///   }
///
///   @override
///   void didChangeLocales(List<Locale>? locales) {
///     print('Locales changed');
///   }
/// }
///
/// // Attach the system observer
/// final settingsObserver = SystemSettingsObserver();
/// WidgetsBinding.instance.addObserverWithLifecycle(
///   lifecycleAware,
///   settingsObserver,
/// );
/// ```
extension WidgetsBindingRaiiExt on WidgetsBinding {
  /// Adds a listener that will be automatically removed
  /// when the [lifecycleAware] is disposed.
  void addObserverWithLifecycle(
    RaiiLifecycleAware lifecycleAware,
    WidgetsBindingObserver observer, {
    String? debugLabel,
  }) {
    RaiiWidgetsBindingObserver.withLifecycle(
      lifecycleAware,
      this,
      observer,
      debugLabel: debugLabel,
    );
  }
}

/// A managed [Timer] that integrates with the RAII lifecycle system.
///
/// [RaiiTimer] wraps a standard [Timer] and provides automatic cancellation
/// when its parent lifecycle is disposed. This prevents common issues like
/// timers firing after their associated widget or component has been disposed.
///
/// The timer can be cancelled manually by calling [cancel], or it will be
/// automatically cancelled when the parent [RaiiLifecycleAware] is disposed.
///
/// Example usage:
/// ```dart
/// class NotificationManager with RaiiLifecycleMixin {
///   void scheduleNotification() {
///     // Create timer using the extension method
///     final timer = Timer(Duration(seconds: 5), () {
///       showNotification('Your task is ready!');
///     }).withLifecycle(this);
///
///     // Can manually cancel if needed
///     if (userCancelled) {
///       timer.cancel();
///     }
///
///     // Can check timer state
///     if (timer.isActive) {
///       print('Timer is still running');
///     }
///   }
///
///   void schedulePeriodicTask() {
///     final timer = Timer.periodic(Duration(seconds: 1), (t) {
///       print('Tick: ${t.tick}');
///     }).withLifecycle(this);
///
///     // Access the timer's tick count
///     print('Current tick: ${timer.tick}');
///   }
/// }
/// ```
///
/// The timer follows this lifecycle:
/// 1. Created via [RaiiTimer.withLifecycle] (typically through [TimerRaiiExt.withLifecycle])
/// 2. Registered with parent [RaiiLifecycleAware]
/// 3. Timer runs until completion, manual cancellation, or parent disposal
/// 4. On disposal: timer is cancelled, lifecycle is cleaned up, and unregistered from parent
///
/// See also:
/// - [Timer] - The underlying Dart timer being wrapped
/// - [TimerRaiiExt.withLifecycle] - Extension method to create managed timers
/// - [RaiiBox] - Similar pattern for managing other resources
class RaiiTimer with RaiiLifecycleMixin {
  /// Creates a new [RaiiTimer] and attaches it to the given [lifecycleAware].
  ///
  /// The timer is automatically registered with [lifecycleAware] and will be
  /// cancelled when [lifecycleAware] is disposed.
  ///
  /// Parameters:
  /// - [lifecycleAware]: The parent lifecycle that will manage this timer
  /// - [timer]: The underlying [Timer] instance to manage
  /// - [debugLabel]: Optional label for debugging lifecycle events
  ///
  /// Example:
  /// ```dart
  /// // Typically created through the extension method:
  /// final timer = Timer(Duration(seconds: 5), () => print('Done!'))
  ///     .withLifecycle(this, debugLabel: 'MyTimer');
  ///
  /// // But can be created directly:
  /// final raiiTimer = RaiiTimer.withLifecycle(
  ///   myComponent,
  ///   timer: Timer(Duration(seconds: 5), () => print('Done!')),
  ///   debugLabel: 'MyTimer',
  /// );
  /// ```
  ///
  /// Note: In most cases, prefer using [TimerRaiiExt.withLifecycle] extension
  /// method instead of creating [RaiiTimer] instances directly.
  RaiiTimer.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required Timer timer,
    this.debugLabel,
  })  : _lifecycleAware = lifecycleAware,
        _timer = timer {
    _lifecycleAware.registerLifecycle(this);
  }

  final RaiiLifecycleAware _lifecycleAware;
  final Timer _timer;

  /// Optional label for debugging purposes.
  ///
  /// When provided, lifecycle events will be logged to the console with this label,
  /// making it easier to track timer creation and cancellation during development.
  ///
  /// Example output:
  /// ```
  /// [RAII] Init lifecycle: MyTimer
  /// [RAII] Dispose lifecycle: MyTimer
  /// ```
  final String? debugLabel;

  /// Cancels the timer and disposes its lifecycle.
  ///
  /// This method safely cancels the timer and performs proper lifecycle cleanup:
  /// - Checks if the timer is still active and lifecycle is mounted
  /// - Cancels the underlying timer
  /// - Unregisters from the parent lifecycle
  /// - Performs lifecycle cleanup
  ///
  /// After calling [cancel], the timer will not fire and [isActive] will return false.
  ///
  /// This method is safe to call multiple times or after the timer has already
  /// completed. It only performs disposal if the timer is both active and the
  /// lifecycle is still mounted.
  ///
  /// Example:
  /// ```dart
  /// final timer = Timer(Duration(seconds: 10), () => print('Hello'))
  ///     .withLifecycle(this);
  ///
  /// // User cancelled the operation
  /// timer.cancel();
  ///
  /// print(timer.isActive); // false
  ///
  /// // Safe to call again - no-op
  /// timer.cancel();
  /// ```
  void cancel() {
    if (isActive && isLifecycleMounted()) {
      _lifecycleAware.unregisterLifecycle(this);
      disposeLifecycle();
    }
  }

  /// The number of times the timer has fired.
  ///
  /// For one-time timers (created with [Timer]), this will be 0 before firing
  /// and 1 after firing.
  ///
  /// For periodic timers (created with [Timer.periodic]), this increments
  /// each time the callback is invoked.
  ///
  /// Example:
  /// ```dart
  /// final timer = Timer.periodic(Duration(seconds: 1), (t) {
  ///   print('Tick ${t.tick}');
  /// }).withLifecycle(this);
  ///
  /// // Later, check how many times it has fired
  /// print('Timer has fired ${timer.tick} times');
  /// ```
  int get tick => _timer.tick;

  /// Whether the timer is still active and waiting to fire.
  ///
  /// Returns `true` if the timer has not yet fired (for one-time timers) or
  /// has not been cancelled (for periodic timers).
  ///
  /// Returns `false` if the timer has completed or been cancelled.
  ///
  /// Example:
  /// ```dart
  /// final timer = Timer(Duration(seconds: 5), () => print('Done'))
  ///     .withLifecycle(this);
  ///
  /// print(timer.isActive); // true
  ///
  /// timer.cancel();
  /// print(timer.isActive); // false
  /// ```
  bool get isActive => _timer.isActive;

  @override
  void initLifecycle() {
    super.initLifecycle();

    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
  }

  @override
  void disposeLifecycle() {
    super.disposeLifecycle();

    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }
    _timer.cancel();
  }
}

/// Extension on [Timer] that adds RAII lifecycle management capabilities.
///
/// This extension allows you to attach any [Timer] to a [RaiiLifecycleAware]
/// object, ensuring automatic cancellation when the lifecycle is disposed.
///
/// Example:
/// ```dart
/// class MyComponent with RaiiLifecycleMixin {
///   void setupTimers() {
///     // One-time timer
///     Timer(Duration(seconds: 5), () {
///       print('Executed after 5 seconds');
///     }).withLifecycle(this);
///
///     // Periodic timer
///     Timer.periodic(Duration(seconds: 1), (timer) {
///       print('Tick: ${timer.tick}');
///     }).withLifecycle(this, debugLabel: 'PeriodicTick');
///
///     // All timers are automatically cancelled when disposeLifecycle() is called
///   }
/// }
/// ```
extension TimerRaiiExt on Timer {
  /// Attaches this timer to a [RaiiLifecycleAware] for automatic lifecycle management.
  ///
  /// The timer will be automatically cancelled when [lifecycleAware] is disposed,
  /// preventing callbacks from executing after the lifecycle has ended.
  ///
  /// Parameters:
  /// - [lifecycleAware]: The parent lifecycle that will manage this timer
  /// - [debugLabel]: Optional label for debugging lifecycle events
  ///
  /// Returns a [RaiiTimer] that wraps this timer and provides additional
  /// lifecycle management features.
  ///
  /// Example:
  /// ```dart
  /// // Basic usage
  /// Timer(Duration(seconds: 3), () => print('Hello'))
  ///     .withLifecycle(this);
  ///
  /// // With debug label
  /// Timer.periodic(Duration(seconds: 1), (t) => print('Tick'))
  ///     .withLifecycle(this, debugLabel: 'HeartbeatTimer');
  ///
  /// // Store reference for manual cancellation
  /// final timer = Timer(Duration(seconds: 10), () => print('Done'))
  ///     .withLifecycle(this);
  /// timer.cancel(); // Can cancel manually if needed
  /// ```
  RaiiTimer withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    return RaiiTimer.withLifecycle(
      lifecycleAware,
      timer: this,
      debugLabel: debugLabel,
    );
  }
}
