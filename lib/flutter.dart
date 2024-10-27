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

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raii/raii.dart';
import 'package:raii/src/debug.dart';

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
/// class MyWidgetState extends State<MyWidget>
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
    implements RaiiLifecycleAware {
  final _registeredLifecycles = <RaiiLifecycle>[];
  final _initedLifecycles = <RaiiLifecycle>[];

  bool _attached = false;
  bool _isLifecycleMounted = false;

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

  @override
  void didChangeDependencies() {
    // Initialize any pending lifecycle objects
    for (final lifecycle in _registeredLifecycles) {
      if (!_initedLifecycles.contains(lifecycle)) {
        lifecycle.initLifecycle();
        _initedLifecycles.add(lifecycle);
      }
    }

    // Perform one-time lifecycle attachment
    if (!_attached) {
      _attached = true;
      initLifecycle();
    }

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    for (final lifecycle in _registeredLifecycles) {
      lifecycle.disposeLifecycle();
    }
    disposeLifecycle();
    super.dispose();
  }

  @override
  void registerLifecycle(RaiiLifecycle lifecycle) {
    if (!_initedLifecycles.contains(lifecycle)) {
      _registeredLifecycles.add(lifecycle);

      if (mounted) {
        lifecycle.initLifecycle();
        _initedLifecycles.add(lifecycle);
      }
    }
  }
}

/// A lifecycle implementation that wraps a dispose callback and manages its lifecycle.
///
/// This class is the core implementation behind the RAII pattern used by various Flutter
/// extensions. It provides a way to attach any disposable resource to a [RaiiLifecycleAware]
/// object, ensuring proper cleanup when the lifecycle ends.
///
/// **Example:**
///
/// ```dart
/// // Direct usage (though extensions are preferred)
/// final controller = TextEditingController();
/// RaiiDisposeable.withLifecycle(
///   lifecycleAware,
///   dispose: controller.dispose,
///   debugLabel: 'TextController',
/// );
///
/// // More complex disposal logic
/// RaiiDisposeable.withLifecycle(
///   lifecycleAware,
///   dispose: () {
///     controller.removeListener(onChanged);
///     controller.dispose();
///   },
///   debugLabel: 'TextControllerWithListener',
/// );
/// ```
class RaiiDisposeable with RaiiLifecycleMixin {
  /// Creates a [RaiiDisposeable] and attaches it to the provided [lifecycleAware].
  ///
  /// The [dispose] callback will be called during [disposeLifecycle], ensuring
  /// that the resource is properly cleaned up when the lifecycle ends.
  RaiiDisposeable.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required this.dispose,
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// The callback to execute when disposing of the resource.
  final VoidCallback dispose;

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

/// Extension for managing [ScrollController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final scrollController = ScrollController()
///     .withLifecycle(this, debugLabel: 'MyScrollController');
/// }
/// ```
extension ScrollControllerRaiiExt on ScrollController {
  /// Attaches this controller to a [RaiiLifecycleAware] object for automatic disposal.
  ///
  /// The controller will be disposed when the lifecycle is disposed.
  ScrollController withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: () => dispose(),
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

/// Extension for managing [ValueNotifier] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final counterNotifier = ValueNotifier<int>(0)
///     .withLifecycle(this, debugLabel: 'MyValueNotifier');
/// }
/// ```
extension ValueNotifierRaiiExt<T> on ValueNotifier<T> {
  /// Attaches this notifier to a [RaiiLifecycleAware] object for automatic disposal.
  ///
  /// The notifier will be disposed when the lifecycle is disposed.
  ValueNotifier<T> withLifecycle(
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

/// Extension for managing [MouseTracker] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final mouseTracker = MouseTracker(...)
///   .withLifecycle(this, debugLabel: 'MouseTracker');
/// ```
extension MouseTrackerRaiiExt on MouseTracker {
  /// Attaches this mouse tracker to a [RaiiLifecycleAware] object for automatic disposal.
  MouseTracker withLifecycle(
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

/// Extension for managing [ViewportOffset] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final viewportOffset = ViewportOffset.fixed(0)
///   .withLifecycle(this, debugLabel: 'ViewportOffset');
/// ```
extension ViewportOffsetRaiiExt on ViewportOffset {
  /// Attaches this viewport offset to a [RaiiLifecycleAware] object for automatic disposal.
  ViewportOffset withLifecycle(
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

/// Extension for managing [SemanticsOwner] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final semanticsOwner = SemanticsOwner(...)
///   .withLifecycle(this, debugLabel: 'SemanticsOwner');
/// ```
extension SemanticsOwnerRaiiExt on SemanticsOwner {
  /// Attaches this semantics owner to a [RaiiLifecycleAware] object for automatic disposal.
  SemanticsOwner withLifecycle(
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

/// Extension for managing [RestorationManager] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final restorationManager = RestorationManager()
///   .withLifecycle(this, debugLabel: 'RestorationManager');
/// ```
extension RestorationManagerRaiiExt on RestorationManager {
  /// Attaches this restoration manager to a [RaiiLifecycleAware] object for automatic disposal.
  RestorationManager withLifecycle(
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

/// Extension for managing [KeepAliveHandle] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final keepAliveHandle = KeepAliveHandle()
///   .withLifecycle(this, debugLabel: 'KeepAliveHandle');
/// ```
extension KeepAliveHandleRaiiExt on KeepAliveHandle {
  /// Attaches this keep alive handle to a [RaiiLifecycleAware] object for automatic disposal.
  KeepAliveHandle withLifecycle(
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

/// Extension for managing [DraggableScrollableController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final draggableController = DraggableScrollableController()
///   .withLifecycle(this, debugLabel: 'DraggableController');
/// ```
extension DraggableScrollableControllerRaiiExt
    on DraggableScrollableController {
  /// Attaches this controller to a [RaiiLifecycleAware] object for automatic disposal.
  DraggableScrollableController withLifecycle(
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

/// Extension for managing [TextEditingController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final textController = TextEditingController()
///   .withLifecycle(this, debugLabel: 'TextController');
/// ```
extension TextEditingControllerRaiiExt on TextEditingController {
  /// Attaches this controller to a [RaiiLifecycleAware] object for automatic disposal.
  TextEditingController withLifecycle(
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

/// Extension for managing [FocusNode] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final focusNode = FocusNode()
///     .withLifecycle(this, debugLabel: 'FocusNode');
/// }
/// ```
extension FocusNodeRaiiExt on FocusNode {
  /// Attaches this focus node to a [RaiiLifecycleAware] object for automatic disposal.
  FocusNode withLifecycle(
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

/// Extension for managing [FocusScopeNode] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   final focusScope = FocusScopeNode()
///     .withLifecycle(this, debugLabel: 'FocusScope');
/// }
/// ```
extension FocusScopeNodeRaiiExt on FocusScopeNode {
  /// Attaches this focus scope node to a [RaiiLifecycleAware] object for automatic disposal.
  FocusScopeNode withLifecycle(
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

/// Extension for managing [FocusManager] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final focusManager = FocusManager()
///   .withLifecycle(this, debugLabel: 'FocusManager');
/// ```
extension FocusManagerRaiiExt on FocusManager {
  /// Attaches this focus manager to a [RaiiLifecycleAware] object for automatic disposal.
  FocusManager withLifecycle(
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

/// Extension for managing [TransformationController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final transformationController = TransformationController()
///     .withLifecycle(this, debugLabel: 'TransformationController');
/// }
/// ```
extension TransformationControllerRaiiExt on TransformationController {
  /// Attaches this controller to a [RaiiLifecycleAware] object for automatic disposal.
  TransformationController withLifecycle(
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

/// Extension for managing [FixedExtentScrollController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final scrollController = FixedExtentScrollController()
///     .withLifecycle(this, debugLabel: 'FixedExtentController');
/// }
/// ```
extension FixedExtentScrollControllerRaiiExt on FixedExtentScrollController {
  /// Attaches this controller to a [RaiiLifecycleAware] object for automatic disposal.
  FixedExtentScrollController withLifecycle(
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

/// Extension for managing [RestorableRouteFuture] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final routeFuture = RestorableRouteFuture<String>(
///   onPresent: (navigator, arguments) => navigator.pushNamed('/route'),
/// ).withLifecycle(this, debugLabel: 'RouteFuture');
/// ```
extension RestorableRouteFutureRaiiExt<T> on RestorableRouteFuture<T> {
  /// Attaches this restorable route future to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableRouteFuture<T> withLifecycle(
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

/// Extension for managing [SliverOverlapAbsorberHandle] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final absorberHandle = SliverOverlapAbsorberHandle()
///   .withLifecycle(this, debugLabel: 'AbsorberHandle');
/// ```
extension SliverOverlapAbsorberHandleRaiiExt on SliverOverlapAbsorberHandle {
  /// Attaches this sliver overlap absorber handle to a [RaiiLifecycleAware] object for automatic disposal.
  SliverOverlapAbsorberHandle withLifecycle(
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

/// Extension for managing [PageController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final pageController = PageController(initialPage: 0)
///     .withLifecycle(this, debugLabel: 'PageController');
/// }
/// ```
extension PageControllerRaiiExt on PageController {
  /// Attaches this page controller to a [RaiiLifecycleAware] object for automatic disposal.
  PageController withLifecycle(
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

/// Extension for managing [RestorableNum] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final number = RestorableNum(0.0)
///   .withLifecycle(this, debugLabel: 'RestorableNum');
/// ```
extension RestorableNumRaiiExt<T extends num> on RestorableNum<T> {
  /// Attaches this restorable number to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableNum<T> withLifecycle(
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

/// Extension for managing [RestorableDouble] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final price = RestorableDouble(0.0)
///   .withLifecycle(this, debugLabel: 'Price');
/// ```
extension RestorableDoubleRaiiExt on RestorableDouble {
  /// Attaches this restorable double to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableDouble withLifecycle(
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

/// Extension for managing [RestorableInt] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final counter = RestorableInt(0)
///   .withLifecycle(this, debugLabel: 'Counter');
/// ```
extension RestorableIntRaiiExt on RestorableInt {
  /// Attaches this restorable integer to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableInt withLifecycle(
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

/// Extension for managing [RestorableString] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final name = RestorableString('')
///   .withLifecycle(this, debugLabel: 'Name');
/// ```
extension RestorableStringRaiiExt on RestorableString {
  /// Attaches this restorable string to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableString withLifecycle(
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

/// Extension for managing [RestorableBool] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final isEnabled = RestorableBool(false)
///   .withLifecycle(this, debugLabel: 'IsEnabled');
/// ```
extension RestorableBoolRaiiExt on RestorableBool {
  /// Attaches this restorable boolean to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableBool withLifecycle(
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

/// Extension for managing nullable [RestorableBoolN] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final isSelected = RestorableBoolN(null)
///   .withLifecycle(this, debugLabel: 'IsSelected');
/// ```
extension RestorableBoolNRaiiExt on RestorableBoolN {
  /// Attaches this nullable restorable boolean to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableBoolN withLifecycle(
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

/// Extension for managing nullable [RestorableNumN] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final quantity = RestorableNumN(null)
///   .withLifecycle(this, debugLabel: 'Quantity');
/// ```
extension RestorableNumNRaiiExt<T extends num?> on RestorableNumN<T> {
  /// Attaches this nullable restorable number to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableNumN<T> withLifecycle(
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

/// Extension for managing nullable [RestorableDoubleN] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final rating = RestorableDoubleN(null)
///   .withLifecycle(this, debugLabel: 'Rating');
/// ```
extension RestorableDoubleNRaiiExt on RestorableDoubleN {
  /// Attaches this nullable restorable double to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableDoubleN withLifecycle(
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

/// Extension for managing nullable [RestorableIntN] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final index = RestorableIntN(null)
///   .withLifecycle(this, debugLabel: 'Index');
/// ```
extension RestorableIntNRaiiExt on RestorableIntN {
  /// Attaches this nullable restorable integer to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableIntN withLifecycle(
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

/// Extension for managing nullable [RestorableStringN] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final description = RestorableStringN(null)
///   .withLifecycle(this, debugLabel: 'Description');
/// ```
extension RestorableStringNRaiiExt on RestorableStringN {
  /// Attaches this nullable restorable string to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableStringN withLifecycle(
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

/// Extension for managing [RestorableDateTime] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final createdAt = RestorableDateTime(DateTime.now())
///   .withLifecycle(this, debugLabel: 'CreatedAt');
/// ```
extension RestorableDateTimeRaiiExt on RestorableDateTime {
  /// Attaches this restorable date time to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableDateTime withLifecycle(
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

/// Extension for managing nullable [RestorableDateTimeN] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final lastModified = RestorableDateTimeN(null)
///   .withLifecycle(this, debugLabel: 'LastModified');
/// ```
extension RestorableDateTimeNRaiiExt on RestorableDateTimeN {
  /// Attaches this nullable restorable date time to a [RaiiLifecycleAware] object.
  RestorableDateTimeN withLifecycle(
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

/// Extension for managing [RestorableTextEditingController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final textController = RestorableTextEditingController(text: 'Initial')
///   .withLifecycle(this, debugLabel: 'TextController');
/// ```
extension RestorableTextEditingControllerRaiiExt
    on RestorableTextEditingController {
  /// Attaches this restorable text editing controller to a [RaiiLifecycleAware] object.
  RestorableTextEditingController withLifecycle(
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

/// Extension for managing nullable [RestorableEnumN] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final status = RestorableEnumN<Status>(null)
///   .withLifecycle(this, debugLabel: 'Status');
/// ```
extension RestorableEnumNRaiiRaiiExt<T extends Enum> on RestorableEnumN<T> {
  /// Attaches this nullable restorable enum to a [RaiiLifecycleAware] object.
  RestorableEnumN<T> withLifecycle(
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

/// Extension for managing [RestorableEnum] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final priority = RestorableEnum<Priority>(Priority.medium)
///   .withLifecycle(this, debugLabel: 'Priority');
/// ```
extension RestorableEnumRaiiExt<T extends Enum> on RestorableEnum<T> {
  /// Attaches this restorable enum to a [RaiiLifecycleAware] object.
  RestorableEnum<T> withLifecycle(
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

/// Extension for managing [PlatformRouteInformationProvider] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final routeProvider = PlatformRouteInformationProvider(
///   initialRouteInformation: RouteInformation(location: '/'),
/// ).withLifecycle(this, debugLabel: 'RouteProvider');
/// ```
extension PlatformRouteInformationProviderRaiiExt
    on PlatformRouteInformationProvider {
  /// Attaches this route information provider to a [RaiiLifecycleAware] object.
  PlatformRouteInformationProvider withLifecycle(
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

/// Extension for managing [TrackingScrollController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final trackingController = TrackingScrollController()
///   .withLifecycle(this, debugLabel: 'TrackingController');
/// ```
extension TrackingScrollControllerRaiiExt on TrackingScrollController {
  /// Attaches this tracking scroll controller to a [RaiiLifecycleAware] object.
  TrackingScrollController withLifecycle(
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

/// Extension for managing [ScrollPosition] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final scrollPosition = ScrollPosition(
///   physics: AlwaysScrollableScrollPhysics(),
///   context: context,
/// ).withLifecycle(this, debugLabel: 'ScrollPosition');
/// ```
extension ScrollPositionRaiiExt on ScrollPosition {
  /// Attaches this scroll position to a [RaiiLifecycleAware] object.
  ScrollPosition withLifecycle(
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

/// Extension for managing [ScrollPositionWithSingleContext] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final scrollPosition = ScrollPositionWithSingleContext(
///   physics: AlwaysScrollableScrollPhysics(),
///   context: context,
/// ).withLifecycle(this, debugLabel: 'ScrollPosition');
/// ```
extension ScrollPositionWithSingleContextRaiiExt
    on ScrollPositionWithSingleContext {
  /// Attaches this scroll position to a [RaiiLifecycleAware] object.
  ScrollPositionWithSingleContext withLifecycle(
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

/// Extension for managing [ScrollbarPainter] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final scrollbarPainter = ScrollbarPainter(
///   color: Colors.grey,
///   textDirection: TextDirection.ltr,
/// ).withLifecycle(this, debugLabel: 'ScrollbarPainter');
/// ```
extension ScrollbarPainterRaiiExt on ScrollbarPainter {
  /// Attaches this scrollbar painter to a [RaiiLifecycleAware] object.
  ScrollbarPainter withLifecycle(
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

/// Extension for managing [ShortcutManager] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final shortcuts = ShortcutManager()
///   .withLifecycle(this, debugLabel: 'ShortcutManager');
/// ```
extension ShortcutManagerRaiiExt on ShortcutManager {
  /// Attaches this shortcut manager to a [RaiiLifecycleAware] object.
  ShortcutManager withLifecycle(
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

/// Extension for managing [ShortcutRegistry] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final registry = ShortcutRegistry()
///   .withLifecycle(this, debugLabel: 'ShortcutRegistry');
/// ```
extension ShortcutRegistryRaiiExt on ShortcutRegistry {
  /// Attaches this shortcut registry to a [RaiiLifecycleAware] object.
  ShortcutRegistry withLifecycle(
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

/// Extension for managing [SnapshotController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final snapshotController = SnapshotController()
///   .withLifecycle(this, debugLabel: 'SnapshotController');
/// ```
extension SnapshotControllerRaiiExt on SnapshotController {
  /// Attaches this snapshot controller to a [RaiiLifecycleAware] object.
  SnapshotController withLifecycle(
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

/// Extension for managing [ClipboardStatusNotifier] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final clipboardStatus = ClipboardStatusNotifier()
///   .withLifecycle(this, debugLabel: 'ClipboardStatus');
/// ```
extension ClipboardStatusNotifierRaiiExt on ClipboardStatusNotifier {
  /// Attaches this clipboard status notifier to a [RaiiLifecycleAware] object.
  ClipboardStatusNotifier withLifecycle(
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

/// Extension for managing [UndoHistoryController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final undoController = UndoHistoryController()
///   .withLifecycle(this, debugLabel: 'UndoController');
/// ```
extension UndoHistoryControllerRaiiExt on UndoHistoryController {
  /// Attaches this undo history controller to a [RaiiLifecycleAware] object.
  UndoHistoryController withLifecycle(
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
/// WidgetsBinding.instance.addObserverWithLifeycle(
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
/// WidgetsBinding.instance.addObserverWithLifeycle(
///   lifecycleAware,
///   settingsObserver,
/// );
/// ```
extension WidgetsBindingRaiiExt on WidgetsBinding {
  /// Adds a listener that will be automatically removed
  /// when the [lifecycleAware] is disposed.
  void addObserverWithLifeycle(
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
