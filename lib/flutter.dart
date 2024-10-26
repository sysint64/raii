/// A Flutter library that provides RAII (Resource Acquisition Is Initialization) pattern
/// implementation for managing the lifecycle of disposable resources.
///
/// This library offers a systematic approach to resource management in Flutter applications
/// by automatically handling the initialization and disposal of resources. It helps prevent
/// memory leaks and ensures proper cleanup of resources when they are no longer needed.
///
/// Key features:
/// - Automatic resource disposal through lifecycle management
/// - Fluent API for resource registration
/// - Debug logging support for lifecycle events
/// - Type-safe resource management
/// - Integration with Flutter's widget lifecycle
///
/// The library provides support for many Flutter resources including:
/// - Controllers (Animation, Text, Scroll, etc.)
/// - Notifiers and Listeners
/// - Focus management
/// - Restoration framework
/// - Platform features
/// - Painters and Renderers
///
/// Example usage:
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
///   // Resources are automatically disposed when the widget is disposed
///   late final controller = AnimationController(vsync: this)
///     .withLifecycle(this, debugLabel: 'MyAnimation');
///
///   late final textController = TextEditingController()
///     .withLifecycle(this, debugLabel: 'TextInput');
///
///   @override
///   void onLifecycleAttach() {
///     // Register listeners with automatic cleanup
///     ListenableListenerLifecycle.attach(
///       this,
///       listenable: controller,
///       onListen: () => setState(() {}),
///       debugLabel: 'AnimationListener',
///     );
///   }
/// }
/// ```
///
/// The library follows these principles:
/// 1. Resources should be acquired and initialized at construction time
/// 2. Resources should be automatically released when no longer needed
/// 3. Resource cleanup should be deterministic and predictable
/// 4. The API should be simple and intuitive to use
library;

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raii/raii.dart';

/// A [LifecycleAware] that provides access to a [BuildContext].
///
/// This abstract class extends [LifecycleAware] and adds requirement for implementers
/// to provide a [BuildContext]. This is useful when lifecycle operations need access
/// to the widget tree, such as showing dialogs, accessing inherited widgets, or
/// using other context-dependent Flutter features.
///
/// Example usage:
/// ```dart
/// class MyWidgetState extends State<MyWidget> implements LifecycleAwareWithContext {
///   @override
///   BuildContext get context => super.context;
///
///   // Implement other LifecycleAware methods...
/// }
/// ```
abstract class LifecycleAwareWithContext extends LifecycleAware {
  BuildContext get context;
}

/// A mixin that implements [LifecycleAwareWithContext] for [StatefulWidget] states.
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
/// ```dart
/// // Correct order:
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
///   // ...
/// }
///
/// // Incorrect order - will cause incorrect resources disposal:
/// class MyWidgetState extends State<MyWidget>
///     with LifecycleAwareWidgetStateMixin, TickerProviderStateMixin {
///   // ...
/// }
/// ```
///
/// Example usage:
/// ```dart
/// class MyWidgetState extends
///     with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
///   late final _animationController = AnimationController(
///     vsync: this,
///     duration: const Duration(milliseconds: 300),
///   ).withLifecycle(this);
///
///   @override
///   void onLifecycleAttach() {
///     ListenableListenerLifecycle.attach(
///       this,
///       listenable: _animationController,
///       onListen: () {
///         // Update state when animation happens.
///       },
///     );
///   }
///   // ...
/// }
/// ```
mixin LifecycleAwareWidgetStateMixin<T extends StatefulWidget> on State<T>
    implements LifecycleAwareWithContext {
  final _registeredLifecycles = <Lifecycle>[];
  final _initedServices = <Lifecycle>[];

  bool _attached = false;
  bool _isLifecycleMounted = false;

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  @override
  void initLifecycle() {
    _isLifecycleMounted = true;
  }

  @override
  void disposeLifecycle() {
    _isLifecycleMounted = false;
  }

  @override
  void didChangeDependencies() {
    // Initialize any pending lifecycle objects
    for (final service in _registeredLifecycles) {
      if (!_initedServices.contains(service)) {
        service.initLifecycle();
        _initedServices.add(service);
      }
    }

    // Perform one-time lifecycle attachment
    if (!_attached) {
      _attached = true;
      initLifecycle();
      onLifecycleAttach();
    }

    super.didChangeDependencies();
  }

  /// Called once when the lifecycle is first attached.
  ///
  /// Override this method to register any initial lifecycles or perform
  /// other one-time setup that requires [BuildContext] to be available.
  void onLifecycleAttach() {}

  @override
  void dispose() {
    for (final lifecycle in _registeredLifecycles) {
      lifecycle.disposeLifecycle();
    }
    disposeLifecycle();
    super.dispose();
  }

  @override
  void registerLifecycle(Lifecycle lifecycle) {
    if (mounted && !_initedServices.contains(lifecycle)) {
      _registeredLifecycles.add(lifecycle);
      lifecycle.initLifecycle();
      _initedServices.add(lifecycle);
    }

    if (!mounted) {
      lifecycle.disposeLifecycle();
    }
  }
}

/// A lifecycle implementation that wraps a dispose callback and manages its lifecycle.
///
/// This class is the core implementation behind the RAII pattern used by various Flutter
/// extensions. It provides a way to attach any disposable resource to a [LifecycleAware]
/// object, ensuring proper cleanup when the lifecycle ends.
///
/// Example:
/// ```dart
/// // Direct usage (though extensions are preferred)
/// final controller = TextEditingController();
/// DisposeableLifecycle.attach(
///   lifecycleAware,
///   dispose: controller.dispose,
///   debugLabel: 'TextController',
/// );
///
/// // More complex disposal logic
/// DisposeableLifecycle.attach(
///   lifecycleAware,
///   dispose: () {
///     controller.removeListener(onChanged);
///     controller.dispose();
///   },
///   debugLabel: 'TextControllerWithListener',
/// );
/// ```
class DisposeableLifecycle with LifecycleMixin {
  /// Creates a [DisposeableLifecycle] and attaches it to the provided [lifecycleAware].
  ///
  /// The [dispose] callback will be called during [disposeLifecycle], ensuring
  /// that the resource is properly cleaned up when the lifecycle ends.
  DisposeableLifecycle.attach(
    LifecycleAware lifecycleAware, {
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
      debugPrint('[RAII] Init lifecycle: $debugLabel');
    }
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      debugPrint('[RAII] Dispose lifecycle: $debugLabel');
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
/// Example:
/// ```dart
/// // Basic usage with ValueNotifier
/// final counter = ValueNotifier(0).withLifecycle(lifecycleAware);
/// ListenableListenerLifecycle.attach(
///   lifecycleAware,
///   listenable: counter,
///   onListen: () => print('Counter changed: ${counter.value}'),
///   debugLabel: 'CounterListener',
/// );
///
/// // Usage with animation controller
/// final animation = AnimationController(vsync: this)
///   .withLifecycle(lifecycleAware);
/// ListenableListenerLifecycle.attach(
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
/// ListenableListenerLifecycle.attach(
///   lifecycleAware,
///   listenable: user,
///   onListen: () => print('User updated: ${user.name}'),
///   debugLabel: 'UserModelListener',
/// );
/// ```
class ListenableListenerLifecycle<T extends Listenable> with LifecycleMixin {
  /// Creates a [ListenableListenerLifecycle] and attaches it to the provided [lifecycleAware].
  ///
  /// The listener will be automatically added during initialization and removed
  /// during disposal, ensuring proper cleanup of event handlers.
  ListenableListenerLifecycle.attach(
    LifecycleAware lifecycleAware, {
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
      debugPrint('[RAII] Init lifecycle: $debugLabel');
    }
    listenable.addListener(onListen);
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      debugPrint('[RAII] Dispose lifecycle: $debugLabel');
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
/// Example:
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
/// WidgetsBindingObserverLifecycle.attach(
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
/// WidgetsBindingObserverLifecycle.attach(
///   lifecycleAware,
///   settingsObserver,
///   debugLabel: 'SystemSettings',
/// );
/// ```
class WidgetsBindingObserverLifecycle with LifecycleMixin {
  /// Creates a [WidgetsBindingObserverLifecycle] and attaches it to the provided [lifecycleAware].
  ///
  /// The observer will be automatically registered with [WidgetsBinding.instance]
  /// during initialization and removed during disposal.
  WidgetsBindingObserverLifecycle.attach(
    LifecycleAware lifecycleAware,
    this.observer, {
    this.debugLabel,
  }) {
    lifecycleAware.registerLifecycle(this);
  }

  /// The observer that will be registered with [WidgetsBinding.instance].
  final WidgetsBindingObserver observer;

  /// Optional label for debugging purposes.
  ///
  /// When provided, lifecycle events will be logged to the console with this label.
  final String? debugLabel;

  @override
  void initLifecycle() {
    super.initLifecycle();
    if (debugLabel != null) {
      debugPrint('[RAII] Init lifecycle: $debugLabel');
    }
    WidgetsBinding.instance.addObserver(observer);
  }

  @override
  void disposeLifecycle() {
    if (debugLabel != null) {
      debugPrint('[RAII] Dispose lifecycle: $debugLabel');
    }
    WidgetsBinding.instance.removeObserver(observer);
    super.disposeLifecycle();
  }
}

/// Extension for managing [StreamSubscription] lifecycle.
///
/// Example usage:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   @override
///   void onLifecycleAttach() {
///     myStream.listen(onData).withLifecycle(
///       this,
///       debugLabel: 'MyStreamSubscription',
///     );
///   }
/// }
/// ```
extension StreamSubscriptionLifecycleRaiiExt<T> on StreamSubscription<T> {
  /// Attaches this [StreamSubscription] to a [LifecycleAware] object.
  ///
  /// The subscription will be automatically cancelled when the lifecycle is disposed.
  ///
  /// Returns the original [StreamSubscription] for chaining.
  StreamSubscription<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    _StreamSubscriptionLifecycle.attach(
      lifecycleAware,
      sub: this,
      debugLabel: debugLabel,
    );

    return this;
  }
}

class _StreamSubscriptionLifecycle<T> with LifecycleMixin {
  _StreamSubscriptionLifecycle(this.sub, this.debugLabel);

  _StreamSubscriptionLifecycle.attach(
    LifecycleAware lifecycleAware, {
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
      debugPrint('[RAII] Dispose lifecycle: $debugLabel');
    }
    sub.cancel();

    super.disposeLifecycle();
  }

  @override
  void initLifecycle() {
    super.initLifecycle();

    if (debugLabel != null) {
      debugPrint('[RAII] Init lifecycle: $debugLabel');
    }
  }
}

/// Extension for managing [ScrollController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final scrollController = ScrollController()
///     .withLifecycle(this, debugLabel: 'MyScrollController');
/// }
/// ```
extension ScrollControllerRaiiExt on ScrollController {
  /// Attaches this controller to a [LifecycleAware] object for automatic disposal.
  ///
  /// The controller will be disposed when the lifecycle is disposed.
  ScrollController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: () => dispose(),
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension for managing [AnimationController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
///   late final animationController = AnimationController(vsync: this)
///     .withLifecycle(this, debugLabel: 'MyAnimationController');
/// }
/// ```
extension AnimationControllerRaiiExt on AnimationController {
  /// Attaches this controller to a [LifecycleAware] object for automatic disposal.
  ///
  /// The controller will be disposed when the lifecycle is disposed.
  AnimationController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
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
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
///   late final ticker = Ticker(onTick)
///     .withLifecycle(this, debugLabel: 'MyTicker');
/// }
/// ```
extension TickerRaiiExt on Ticker {
  /// Attaches this ticker to a [LifecycleAware] object for automatic cleanup.
  ///
  /// The ticker will be stopped and disposed when the lifecycle is disposed.
  Ticker withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
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
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final counterNotifier = ValueNotifier<int>(0)
///     .withLifecycle(this, debugLabel: 'MyValueNotifier');
/// }
/// ```
extension ValueNotifierRaiiExt<T> on ValueNotifier<T> {
  /// Attaches this notifier to a [LifecycleAware] object for automatic disposal.
  ///
  /// The notifier will be disposed when the lifecycle is disposed.
  ValueNotifier<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension for managing [RenderEditablePainter] lifecycle.
///
/// Example:
/// ```dart
/// final painter = CustomRenderEditablePainter()
///   .withLifecycle(this, debugLabel: 'MyPainter');
/// ```
extension RenderEditablePainterRaiiExt on RenderEditablePainter {
  /// Attaches this painter to a [LifecycleAware] object for automatic disposal.
  RenderEditablePainter withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension for managing [MouseTracker] lifecycle.
///
/// Example:
/// ```dart
/// final mouseTracker = MouseTracker()
///   .withLifecycle(this, debugLabel: 'MouseTracker');
/// ```
extension MouseTrackerRaiiExt on MouseTracker {
  /// Attaches this mouse tracker to a [LifecycleAware] object for automatic disposal.
  MouseTracker withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension for managing [ViewportOffset] lifecycle.
///
/// Example:
/// ```dart
/// final viewportOffset = ViewportOffset.fixed(0)
///   .withLifecycle(this, debugLabel: 'ViewportOffset');
/// ```
extension ViewportOffsetRaiiExt on ViewportOffset {
  /// Attaches this viewport offset to a [LifecycleAware] object for automatic disposal.
  ViewportOffset withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension for managing [SemanticsOwner] lifecycle.
///
/// Example:
/// ```dart
/// final semanticsOwner = SemanticsOwner()
///   .withLifecycle(this, debugLabel: 'SemanticsOwner');
/// ```
extension SemanticsOwnerRaiiExt on SemanticsOwner {
  /// Attaches this semantics owner to a [LifecycleAware] object for automatic disposal.
  SemanticsOwner withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );

    return this;
  }
}

/// Extension for managing [RestorationManager] lifecycle.
///
/// Example:
/// ```dart
/// final restorationManager = RestorationManager()
///   .withLifecycle(this, debugLabel: 'RestorationManager');
/// ```
extension RestorationManagerRaiiExt on RestorationManager {
  /// Attaches this restoration manager to a [LifecycleAware] object for automatic disposal.
  RestorationManager withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [KeepAliveHandle] lifecycle.
///
/// Example:
/// ```dart
/// final keepAliveHandle = KeepAliveHandle()
///   .withLifecycle(this, debugLabel: 'KeepAliveHandle');
/// ```
extension KeepAliveHandleRaiiExt on KeepAliveHandle {
  /// Attaches this keep alive handle to a [LifecycleAware] object for automatic disposal.
  KeepAliveHandle withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [DraggableScrollableController] lifecycle.
///
/// Example:
/// ```dart
/// final draggableController = DraggableScrollableController()
///   .withLifecycle(this, debugLabel: 'DraggableController');
/// ```
extension DraggableScrollableControllerRaiiExt
    on DraggableScrollableController {
  /// Attaches this controller to a [LifecycleAware] object for automatic disposal.
  DraggableScrollableController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [TextEditingController] lifecycle.
///
/// Example:
/// ```dart
/// final textController = TextEditingController()
///   .withLifecycle(this, debugLabel: 'TextController');
/// ```
extension TextEditingControllerRaiiExt on TextEditingController {
  /// Attaches this controller to a [LifecycleAware] object for automatic disposal.
  TextEditingController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [FocusNode] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final focusNode = FocusNode()
///     .withLifecycle(this, debugLabel: 'FocusNode');
/// }
/// ```
extension FocusNodeRaiiExt on FocusNode {
  /// Attaches this focus node to a [LifecycleAware] object for automatic disposal.
  FocusNode withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [FocusScopeNode] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   final focusScope = FocusScopeNode()
///     .withLifecycle(this, debugLabel: 'FocusScope');
/// }
/// ```
extension FocusScopeNodeRaiiExt on FocusScopeNode {
  /// Attaches this focus scope node to a [LifecycleAware] object for automatic disposal.
  FocusScopeNode withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [FocusManager] lifecycle.
///
/// Example:
/// ```dart
/// final focusManager = FocusManager()
///   .withLifecycle(this, debugLabel: 'FocusManager');
/// ```
extension FocusManagerRaiiExt on FocusManager {
  /// Attaches this focus manager to a [LifecycleAware] object for automatic disposal.
  FocusManager withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [TransformationController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final transformationController = TransformationController()
///     .withLifecycle(this, debugLabel: 'TransformationController');
/// }
/// ```
extension TransformationControllerRaiiExt on TransformationController {
  /// Attaches this controller to a [LifecycleAware] object for automatic disposal.
  TransformationController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [FixedExtentScrollController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final scrollController = FixedExtentScrollController()
///     .withLifecycle(this, debugLabel: 'FixedExtentController');
/// }
/// ```
extension FixedExtentScrollControllerRaiiExt on FixedExtentScrollController {
  /// Attaches this controller to a [LifecycleAware] object for automatic disposal.
  FixedExtentScrollController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableRouteFuture] lifecycle.
///
/// Example:
/// ```dart
/// final routeFuture = RestorableRouteFuture<String>(
///   onPresent: (navigator, arguments) => navigator.pushNamed('/route'),
/// ).withLifecycle(this, debugLabel: 'RouteFuture');
/// ```
extension RestorableRouteFutureRaiiExt<T> on RestorableRouteFuture<T> {
  /// Attaches this restorable route future to a [LifecycleAware] object for automatic disposal.
  RestorableRouteFuture<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [SliverOverlapAbsorberHandle] lifecycle.
///
/// Example:
/// ```dart
/// final absorberHandle = SliverOverlapAbsorberHandle()
///   .withLifecycle(this, debugLabel: 'AbsorberHandle');
/// ```
extension SliverOverlapAbsorberHandleRaiiExt on SliverOverlapAbsorberHandle {
  /// Attaches this sliver overlap absorber handle to a [LifecycleAware] object for automatic disposal.
  SliverOverlapAbsorberHandle withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [PageController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final pageController = PageController(initialPage: 0)
///     .withLifecycle(this, debugLabel: 'PageController');
/// }
/// ```
extension PageControllerRaiiExt on PageController {
  /// Attaches this page controller to a [LifecycleAware] object for automatic disposal.
  PageController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableProperty] lifecycle.
///
/// Example:
/// ```dart
/// final property = MyRestorableProperty<String>()
///   .withLifecycle(this, debugLabel: 'RestorableProperty');
/// ```
extension RestorablePropertyRaiiExt<T> on RestorableProperty<T> {
  /// Attaches this restorable property to a [LifecycleAware] object for automatic disposal.
  RestorableProperty<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableValue] lifecycle.
///
/// Example:
/// ```dart
/// final value = RestorableString('initial')
///   .withLifecycle(this, debugLabel: 'RestorableValue');
/// ```
extension RestorableValueRaiiExt<T> on RestorableValue<T> {
  /// Attaches this restorable value to a [LifecycleAware] object for automatic disposal.
  RestorableValue<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableNum] lifecycle.
///
/// Example:
/// ```dart
/// final number = RestorableDouble(0.0)
///   .withLifecycle(this, debugLabel: 'RestorableNum');
/// ```
extension RestorableNumRaiiExt<T extends num> on RestorableNum<T> {
  /// Attaches this restorable number to a [LifecycleAware] object for automatic disposal.
  RestorableNum<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableDouble] lifecycle.
///
/// Example:
/// ```dart
/// final price = RestorableDouble(0.0)
///   .withLifecycle(this, debugLabel: 'Price');
/// ```
extension RestorableDoubleRaiiExt on RestorableDouble {
  /// Attaches this restorable double to a [LifecycleAware] object for automatic disposal.
  RestorableDouble withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableInt] lifecycle.
///
/// Example:
/// ```dart
/// final counter = RestorableInt(0)
///   .withLifecycle(this, debugLabel: 'Counter');
/// ```
extension RestorableIntRaiiExt on RestorableInt {
  /// Attaches this restorable integer to a [LifecycleAware] object for automatic disposal.
  RestorableInt withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableString] lifecycle.
///
/// Example:
/// ```dart
/// final name = RestorableString('')
///   .withLifecycle(this, debugLabel: 'Name');
/// ```
extension RestorableStringRaiiExt on RestorableString {
  /// Attaches this restorable string to a [LifecycleAware] object for automatic disposal.
  RestorableString withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableBool] lifecycle.
///
/// Example:
/// ```dart
/// final isEnabled = RestorableBool(false)
///   .withLifecycle(this, debugLabel: 'IsEnabled');
/// ```
extension RestorableBoolRaiiExt on RestorableBool {
  /// Attaches this restorable boolean to a [LifecycleAware] object for automatic disposal.
  RestorableBool withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing nullable [RestorableBoolN] lifecycle.
///
/// Example:
/// ```dart
/// final isSelected = RestorableBoolN(null)
///   .withLifecycle(this, debugLabel: 'IsSelected');
/// ```
extension RestorableBoolNRaiiExt on RestorableBoolN {
  /// Attaches this nullable restorable boolean to a [LifecycleAware] object for automatic disposal.
  RestorableBoolN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing nullable [RestorableNumN] lifecycle.
///
/// Example:
/// ```dart
/// final quantity = RestorableNumN(null)
///   .withLifecycle(this, debugLabel: 'Quantity');
/// ```
extension RestorableNumNRaiiExt on RestorableNumN {
  /// Attaches this nullable restorable number to a [LifecycleAware] object for automatic disposal.
  RestorableNumN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing nullable [RestorableDoubleN] lifecycle.
///
/// Example:
/// ```dart
/// final rating = RestorableDoubleN(null)
///   .withLifecycle(this, debugLabel: 'Rating');
/// ```
extension RestorableDoubleNRaiiExt on RestorableDoubleN {
  /// Attaches this nullable restorable double to a [LifecycleAware] object for automatic disposal.
  RestorableDoubleN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing nullable [RestorableIntN] lifecycle.
///
/// Example:
/// ```dart
/// final index = RestorableIntN(null)
///   .withLifecycle(this, debugLabel: 'Index');
/// ```
extension RestorableIntNRaiiExt on RestorableIntN {
  /// Attaches this nullable restorable integer to a [LifecycleAware] object for automatic disposal.
  RestorableIntN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing nullable [RestorableStringN] lifecycle.
///
/// Example:
/// ```dart
/// final description = RestorableStringN(null)
///   .withLifecycle(this, debugLabel: 'Description');
/// ```
extension RestorableStringNRaiiExt on RestorableStringN {
  /// Attaches this nullable restorable string to a [LifecycleAware] object for automatic disposal.
  RestorableStringN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableDateTime] lifecycle.
///
/// Example:
/// ```dart
/// final createdAt = RestorableDateTime(DateTime.now())
///   .withLifecycle(this, debugLabel: 'CreatedAt');
/// ```
extension RestorableDateTimeExt on RestorableDateTime {
  /// Attaches this restorable date time to a [LifecycleAware] object for automatic disposal.
  RestorableDateTime withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing nullable [RestorableDateTimeN] lifecycle.
///
/// Example:
/// ```dart
/// final lastModified = RestorableDateTimeN(null)
///   .withLifecycle(this, debugLabel: 'LastModified');
/// ```
extension RestorableDateTimeNExt on RestorableDateTimeN {
  /// Attaches this nullable restorable date time to a [LifecycleAware] object.
  RestorableDateTimeN withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableListenable] lifecycle.
///
/// Example:
/// ```dart
/// final customListenable = RestorableListenable<MyListenable>(
///   () => MyListenable(),
/// ).withLifecycle(this, debugLabel: 'CustomListenable');
/// ```
extension RestorableListenableRaiiExt<T extends Listenable>
    on RestorableListenable<T> {
  /// Attaches this restorable listenable to a [LifecycleAware] object.
  RestorableListenable<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableChangeNotifier] lifecycle.
///
/// Example:
/// ```dart
/// final model = RestorableChangeNotifier<MyModel>(
///   () => MyModel(),
/// ).withLifecycle(this, debugLabel: 'Model');
/// ```
extension RestorableChangeNotifierRaiiExt<T extends ChangeNotifier>
    on RestorableChangeNotifier<T> {
  /// Attaches this restorable change notifier to a [LifecycleAware] object.
  RestorableChangeNotifier<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableTextEditingController] lifecycle.
///
/// Example:
/// ```dart
/// final textController = RestorableTextEditingController(text: 'Initial')
///   .withLifecycle(this, debugLabel: 'TextController');
/// ```
extension RestorableTextEditingControllerExt
    on RestorableTextEditingController {
  /// Attaches this restorable text editing controller to a [LifecycleAware] object.
  RestorableTextEditingController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing nullable [RestorableEnumN] lifecycle.
///
/// Example:
/// ```dart
/// final status = RestorableEnumN<Status>(null)
///   .withLifecycle(this, debugLabel: 'Status');
/// ```
extension RestorableEnumNRaiiExt<T extends Enum> on RestorableEnumN<T> {
  /// Attaches this nullable restorable enum to a [LifecycleAware] object.
  RestorableEnumN<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableEnum] lifecycle.
///
/// Example:
/// ```dart
/// final priority = RestorableEnum<Priority>(Priority.medium)
///   .withLifecycle(this, debugLabel: 'Priority');
/// ```
extension RestorableEnumRaiiExt<T extends Enum> on RestorableEnum<T> {
  /// Attaches this restorable enum to a [LifecycleAware] object.
  RestorableEnum<T> withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [PlatformRouteInformationProvider] lifecycle.
///
/// Example:
/// ```dart
/// final routeProvider = PlatformRouteInformationProvider(
///   initialRouteInformation: RouteInformation(location: '/'),
/// ).withLifecycle(this, debugLabel: 'RouteProvider');
/// ```
extension PlatformRouteInformationProviderRaiiExt
    on PlatformRouteInformationProvider {
  /// Attaches this route information provider to a [LifecycleAware] object.
  PlatformRouteInformationProvider withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [TrackingScrollController] lifecycle.
///
/// Example:
/// ```dart
/// final trackingController = TrackingScrollController()
///   .withLifecycle(this, debugLabel: 'TrackingController');
/// ```
extension TrackingScrollControllerRaiiExt on TrackingScrollController {
  /// Attaches this tracking scroll controller to a [LifecycleAware] object.
  TrackingScrollController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [ScrollPosition] lifecycle.
///
/// Example:
/// ```dart
/// final scrollPosition = ScrollPosition(
///   physics: AlwaysScrollableScrollPhysics(),
///   context: context,
/// ).withLifecycle(this, debugLabel: 'ScrollPosition');
/// ```
extension ScrollPositionRaiiExt on ScrollPosition {
  /// Attaches this scroll position to a [LifecycleAware] object.
  ScrollPosition withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [ScrollPositionWithSingleContext] lifecycle.
///
/// Example:
/// ```dart
/// final scrollPosition = ScrollPositionWithSingleContext(
///   physics: AlwaysScrollableScrollPhysics(),
///   context: context,
/// ).withLifecycle(this, debugLabel: 'ScrollPosition');
/// ```
extension ScrollPositionWithSingleContextRaiiExt
    on ScrollPositionWithSingleContext {
  /// Attaches this scroll position to a [LifecycleAware] object.
  ScrollPositionWithSingleContext withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [ScrollbarPainter] lifecycle.
///
/// Example:
/// ```dart
/// final scrollbarPainter = ScrollbarPainter(
///   color: Colors.grey,
///   textDirection: TextDirection.ltr,
/// ).withLifecycle(this, debugLabel: 'ScrollbarPainter');
/// ```
extension ScrollbarPainterRaiiExt on ScrollbarPainter {
  /// Attaches this scrollbar painter to a [LifecycleAware] object.
  ScrollbarPainter withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [MultiSelectableSelectionContainerDelegate] lifecycle.
///
/// Example:
/// ```dart
/// final selectionDelegate = MultiSelectableSelectionContainerDelegate()
///   .withLifecycle(this, debugLabel: 'SelectionDelegate');
/// ```
extension MultiSelectableSelectionContainerDelegateRaiiExt
    on MultiSelectableSelectionContainerDelegate {
  /// Attaches this selection delegate to a [LifecycleAware] object.
  MultiSelectableSelectionContainerDelegate withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [ShortcutManager] lifecycle.
///
/// Example:
/// ```dart
/// final shortcuts = ShortcutManager()
///   .withLifecycle(this, debugLabel: 'ShortcutManager');
/// ```
extension ShortcutManagerRaiiExt on ShortcutManager {
  /// Attaches this shortcut manager to a [LifecycleAware] object.
  ShortcutManager withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [ShortcutRegistry] lifecycle.
///
/// Example:
/// ```dart
/// final registry = ShortcutRegistry()
///   .withLifecycle(this, debugLabel: 'ShortcutRegistry');
/// ```
extension ShortcutRegistryRaiiExt on ShortcutRegistry {
  /// Attaches this shortcut registry to a [LifecycleAware] object.
  ShortcutRegistry withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [SnapshotController] lifecycle.
///
/// Example:
/// ```dart
/// final snapshotController = SnapshotController()
///   .withLifecycle(this, debugLabel: 'SnapshotController');
/// ```
extension SnapshotControllerRaiiExt on SnapshotController {
  /// Attaches this snapshot controller to a [LifecycleAware] object.
  SnapshotController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [SnapshotPainter] lifecycle.
///
/// Example:
/// ```dart
/// final snapshotPainter = SnapshotPainter()
///   .withLifecycle(this, debugLabel: 'SnapshotPainter');
/// ```
extension SnapshotPainterRaiiExt on SnapshotPainter {
  /// Attaches this snapshot painter to a [LifecycleAware] object.
  SnapshotPainter withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [ClipboardStatusNotifier] lifecycle.
///
/// Example:
/// ```dart
/// final clipboardStatus = ClipboardStatusNotifier()
///   .withLifecycle(this, debugLabel: 'ClipboardStatus');
/// ```
extension ClipboardStatusNotifierRaiiExt on ClipboardStatusNotifier {
  /// Attaches this clipboard status notifier to a [LifecycleAware] object.
  ClipboardStatusNotifier withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [UndoHistoryController] lifecycle.
///
/// Example:
/// ```dart
/// final undoController = UndoHistoryController()
///   .withLifecycle(this, debugLabel: 'UndoController');
/// ```
extension UndoHistoryControllerRaiiExt on UndoHistoryController {
  /// Attaches this undo history controller to a [LifecycleAware] object.
  UndoHistoryController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}
