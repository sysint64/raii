# raii

A Flutter package that provides RAII (Resource Acquisition Is Initialization) pattern implementation for managing object lifecycles and ensuring proper resource cleanup.

## Features

- Automatic resource disposal through lifecycle management
- Fluent API for resource registration
- Debug logging support for lifecycle events
- Type-safe resource management
- Integration with Flutter's widget lifecycle
- Support for Material and Cupertino components
- Built-in support for common Flutter resources:
  - Controllers (Animation, Text, Scroll, etc.)
  - Notifiers and Listeners
  - Focus management
  - Restoration framework
  - Platform features
  - Painters and Renderers

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  raii: ^0.1.0
```

## Usage

### Basic Widget State Management

```dart
class MyWidgetState extends State<MyWidget>
    with SingleTickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
  // Resources are automatically disposed when the widget is disposed
  late final controller = AnimationController(vsync: this)
    .withLifecycle(this, debugLabel: 'MyAnimation');

  late final textController = TextEditingController()
    .withLifecycle(this, debugLabel: 'TextInput');

  @override
  void onLifecycleAttach() {
    // Register listeners with automatic cleanup
    ListenableListenerLifecycle.attach(
      this,
      listenable: controller,
      onListen: () => setState(() {}),
      debugLabel: 'AnimationListener',
    );
  }
}
```

### Material Components

```dart
// Tab Controller
late final tabController = TabController(length: 3, vsync: this)
  .withLifecycle(this, debugLabel: 'TabBar');

// Search Controller
late final searchController = SearchController()
  .withLifecycle(this, debugLabel: 'SearchBar');

// Data Table Source
final dataSource = MyDataSource()
  .withLifecycle(this, debugLabel: 'TableDataSource');
```

### Cupertino Components

```dart
// Cupertino Tab Controller
late final cupertinoTabs = CupertinoTabController(initialIndex: 0)
  .withLifecycle(this, debugLabel: 'CupertinoTabs');

// Restorable Tab Controller
late final restorableTabs = RestorableCupertinoTabController(initialIndex: 0)
  .withLifecycle(this, debugLabel: 'RestorableTabs');
```

### Custom Resource Management

#### Using LifecycleBox (Wrapper Approach)

```dart
class MyCustomResource {
  void initialize() { /* ... */ }
  void cleanup() { /* ... */ }
}

// Usage in a widget - cleaner syntax with .attach constructor
class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
  late final resource = LifecycleBox.attach(
    this,
    instance: MyCustomResource(),
    init: (r) => r.initialize(),
    dispose: (r) => r.cleanup(),
    debugLabel: 'CustomResource',
  );
  // The resource will be automatically initialized and disposed
  // with the widget's lifecycle
}

// Alternative usage with any LifecycleAware container
final container = LifecycleAwareContainer();
final resource = LifecycleBox.attach(
  container,
  instance: MyCustomResource(),
  init: (r) => r.initialize(),
  dispose: (r) => r.cleanup(),
  debugLabel: 'CustomResource',
);

// When done
container.disposeLifecycle(); // Will properly clean up the resource
```

#### Direct Lifecycle Implementation

```dart
// Implementing lifecycle directly in your resource class
class ManagedResource with LifecycleMixin {
  late final Socket _socket;
  late final StreamSubscription _subscription;

  // Do not allow construct resource without attaching it to a lifecycle
  ManagedResource._();

  // Named constructor that immediately attaches to a lifecycle manager
  ManagedResource.attach(LifecycleAware lifecycleAware) {
    lifecycleAware.registerLifecycle(this);
  }

  @override
  void initLifecycle() {
    super.initLifecycle();

    // Initialize resources
    _socket = Socket.connect(...);
    _subscription = _socket.listen(...);

    debugPrint('ManagedResource: Initialized socket and subscription');
  }

  @override
  void disposeLifecycle() {
    // Clean up resources
    _subscription.cancel();
    _socket.close();

    debugPrint('ManagedResource: Cleaned up socket and subscription');
    super.disposeLifecycle();
  }
}

// Usage in a widget - cleaner syntax with .attach constructor
class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
  late final resource = ManagedResource.attach(this);
  // The resource will be automatically initialized and disposed
  // with the widget's lifecycle
}

// Alternative usage with any LifecycleAware container
final container = LifecycleAwareContainer();
final resource = ManagedResource.attach(container);

// When done
container.disposeLifecycle(); // Will properly clean up the resource
```

The `LifecycleMixin` approach offers several advantages:
1. Direct control over resource lifecycle
2. More granular initialization and cleanup logic
3. Ability to manage multiple internal resources
4. Better encapsulation of resource management logic
5. Type safety and IDE support for lifecycle methods
6. Clean syntax with `.attach` constructor pattern

Choose `LifecycleBox` when:
- You need to add lifecycle to an existing class
- You don't control the resource's source code
- You have simple init/cleanup requirements

Choose direct `LifecycleMixin` implementation when:
- You're creating a new resource class
- You need complex initialization/cleanup logic
- You want to manage multiple internal resources
- You prefer explicit lifecycle management in your class
- You want a cleaner API with `.attach` constructor pattern

### Stream Management

```dart
// Automatic stream subscription cleanup
myStream.listen(onData).withLifecycle(
  this,
  debugLabel: 'MyStreamSubscription',
);
```

### Listenable Management

`ListenableListenerLifecycle` class provides automatic management of listeners for any `Listenable` object (such as `ChangeNotifier`, `ValueNotifier`, or custom implementations). It ensures that listeners are properly added during initialization and removed during disposal.

```dart
class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
  late final valueNotifier = ValueNotifier<int>(0)
    .withLifecycle(this, debugLabel: 'Counter');

  @override
  void onLifecycleAttach() {
    // Simple listener
    ListenableListenerLifecycle.attach(
      this,
      listenable: valueNotifier,
      onListen: () => setState(() {}),
      debugLabel: 'ValueNotifierListener',
    );

    // Multiple listeners for the same listenable
    ListenableListenerLifecycle.attach(
      this,
      listenable: valueNotifier,
      onListen: updateUI,
      debugLabel: 'UIListener',
    );

    ListenableListenerLifecycle.attach(
      this,
      listenable: valueNotifier,
      onListen: saveToPreferences,
      debugLabel: 'StorageListener',
    );

    // Listening to animation controller
    final controller = AnimationController(vsync: this)
      .withLifecycle(this, debugLabel: 'Animation');

    ListenableListenerLifecycle.attach(
      this,
      listenable: controller,
      onListen: () => debugPrint('Animation value: ${controller.value}'),
      debugLabel: 'AnimationListener',
    );
  }
}
```

### App Lifecycle Observer

`WidgetsBindingObserverLifecycle` class automatically handles registration and removal of `WidgetsBindingObserver`s with the `WidgetsBinding` instance. It's particularly useful for managing app lifecycle events, keyboard visibility changes, system settings changes, and other app-wide events.

```dart
class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
  @override
  void onLifecycleAttach() {
    // Basic app lifecycle observer
    final observer = AppStateObserver();
    WidgetsBindingObserverLifecycle.attach(
      this,
      observer,
      debugLabel: 'AppLifecycle',
    );
  }
}

class AppStateObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('App resumed - restore resources');
        break;
      case AppLifecycleState.inactive:
        debugPrint('App inactive - pause updates');
        break;
      case AppLifecycleState.paused:
        debugPrint('App paused - save state');
        break;
      case AppLifecycleState.detached:
        debugPrint('App detached - cleanup');
        break;
    }
  }

  @override
  void didChangePlatformBrightness() {
    debugPrint('Brightness changed');
  }
}
```

### Timer Management

```dart
class TimerWidgetState extends State<TimerWidget> with LifecycleAwareWidgetStateMixin {
  late final periodicTimer = LifecycleBox.attach(
    this,
    instance: Timer.periodic(
      Duration(seconds: 1),
      (_) => debugPrint('Timer tick'),
    ),
    dispose: (timer) => timer.cancel(),
    debugLabel: 'PeriodicTimer',
  );
}
```

### Global Resources

```dart
// Resources that live for the entire application lifetime
final globalResource = MyGlobalResource.attach(
  alwaysAliveLifecycleAwareContainer,
);
```

## Important Notes

### Mixin Order

When using `LifecycleAwareWidgetStateMixin` with `TickerProviderStateMixin`, the order matters:

```dart
// Correct order:
class MyWidgetState extends State<MyWidget>
    with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
  // ...
}

// Incorrect order - will cause incorrect resources disposal:
class MyWidgetState extends State<MyWidget>
    with LifecycleAwareWidgetStateMixin, TickerProviderStateMixin {
  // ...
}
```

### Debug Labels

Debug labels help track lifecycle events in the console:

```dart
[RAII] Init lifecycle: MyAnimation
[RAII] Init lifecycle: TextInput
[RAII] Dispose lifecycle: TextInput
[RAII] Dispose lifecycle: MyAnimation
```

## Additional Resources

### Core Concepts

- `Lifecycle` - Base interface for objects with manageable lifecycles
- `LifecycleAware` - Interface for objects that can manage other lifecycles
- `LifecycleMixin` - Basic lifecycle implementation
- `LifecycleAwareMixin` - Implementation for managing multiple lifecycles
- `LifecycleBox` - Container for managing custom resources

### Best Practices

1. Always provide debug labels for easier debugging
2. Follow the correct mixin order when using with `TickerProviderStateMixin`
3. Use `late final` for controller declarations to ensure single initialization
4. Register listeners in `onLifecycleAttach` rather than `initState`
5. Use `alwaysAliveLifecycleAwareContainer` sparingly, only for truly global resources

## License

Licensed under the MIT ([LICENSE](LICENSE) or <https://mit-license.org/>)
