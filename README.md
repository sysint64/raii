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
    with SingleTickerProviderStateMixin, RaiiStateMixin {
  // Resources are automatically disposed when the widget is disposed
  late final controller = AnimationController(vsync: this)
    .withLifecycle(this, debugLabel: 'MyAnimation');

  late final textController = TextEditingController()
    .withLifecycle(this, debugLabel: 'TextInput');

  // Works like initState() but runs when widget is mounted and
  // context is accesible, you are free to move it to `initState`
  // if you don't need context access.
  @override
  void initLifecycle() {
    super.initLifecycle();

    // Register listeners with automatic cleanup
    controller.addListenerWithLifecycle(
      this,
      () => setState(() {}),
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

#### Using RaiiBox (Wrapper Approach)

```dart
class MyCustomResource {
  void initialize() { /* ... */ }

  void cleanup() { /* ... */ }
}

// Usage in a widget state
class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
  late final resource = RaiiBox.withLifecycle(
    this,
    instance: MyCustomResource(),
    init: (r) => r.initialize(),
    dispose: (r) => r.cleanup(),
    debugLabel: 'CustomResource',
  );
  // The resource will be automatically initialized and disposed
  // with the widget's lifecycle
}

// Alternative usage with RaiiManager
final raiiManager = RaiiManager();
final resource = RaiiBox.withLifecycle(
  raiiManager,
  instance: MyCustomResource(),
  init: (r) => r.initialize(),
  dispose: (r) => r.cleanup(),
  debugLabel: 'CustomResource',
);

// When done
raiiManager.disposeLifecycle(); // Will properly clean up the resource
```

#### Direct Lifecycle Implementation

```dart
// Implementing lifecycle directly in your resource class
class ManagedResource with RaiiLifecycleMixin {
  late final Socket _socket;
  late final StreamSubscription _subscription;

  // Named constructor that immediately attaches to a lifecycle manager
  ManagedResource.withLifecycle(RaiiLifecycleAware lifecycleAware) {
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
class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
  late final resource = ManagedResource.withLifecycle(this);
  // The resource will be automatically initialized and disposed
  // with the widget's lifecycle
}

// Alternative usage with RaiiManager
final raiiManager = RaiiManager();
final resource = ManagedResource.withLifecycle(raiiManager);

// When done
raiiManager.disposeLifecycle(); // Will properly clean up the resource
```

Choose `RaiiBox` when:
- You need to add lifecycle to an existing class
- You don't control the resource's source code

Choose direct `RaiiLifecycleMixin` implementation when:
- You're creating a new resource class
- You prefer explicit lifecycle management in your class
- You want a cleaner API with `.withLifecycle` constructor pattern

## More Examples

### Stream Management

```dart
// Automatic stream subscription cleanup
myStream.listen(onData).withLifecycle(
  this,
  debugLabel: 'MyStreamSubscription',
);
```

### Listenable Management

```dart
class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
  late final valueNotifier = ValueNotifier<int>(0)
    .withLifecycle(this, debugLabel: 'Counter');

  @override
  void onLifecycleAttach() {
    // Simple listener
    valueNotifier.addListenerWithLifecycle(
      this,
      setState(() {}),
      debugLabel: 'ValueNotifierListener',
    );

    // Multiple listeners for the same listenable
    valueNotifier.addListenerWithLifecycle(
      this,
      updateUI,
      debugLabel: 'UIListener',
    );

    valueNotifier.addListenerWithLifecycle(
      this,
      saveToPreferences,
      debugLabel: 'StorageListener',
    );

    // Listening to animation controller
    final controller = AnimationController(vsync: this)
      .withLifecycle(this, debugLabel: 'Animation');

    controller.addListenerWithLifecycle(
      this,
      () => debugPrint('Animation value: ${controller.value}'),
      debugLabel: 'AnimationListener',
    );
  }
}
```

### App Lifecycle Observer

```dart
class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
  @override
  void initLifecycle() {
    super.initLifecycle();

    // Basic app lifecycle observer
    final observer = AppStateObserver();
    WidgetsBinding.instance.addObserverWithLifeycle(
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
class TimerWidgetState extends State<TimerWidget> with RaiiStateMixin {
  late final periodicTimer = RaiiBox.withLifecycle(
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
final globalResource = MyGlobalResource.withLifecycle(
  alwaysAliveRaiiManager,
);
```

## Important Notes

### Mixin Order

When using `RaiiStateMixin` with `TickerProviderStateMixin`, the order matters:

```dart
// Correct order:
class MyWidgetState extends State<MyWidget>
    with TickerProviderStateMixin, RaiiStateMixin {
  // ...
}

// Incorrect order - will cause incorrect resources disposal:
class MyWidgetState extends State<MyWidget>
    with RaiiStateMixin, TickerProviderStateMixin {
  // ...
}
```

### Debug Labels

Debug labels help track lifecycle events in the console:

```dart
[RAII] Init lifecycle: MyAnimation
[RAII] Init lifecycle: TextInput
...
[RAII] Dispose lifecycle: TextInput
[RAII] Dispose lifecycle: MyAnimation
```

## Additional Resources

### Core Concepts

- `RaiiLifecycle` - Base interface for objects with manageable lifecycles
- `RaiiLifecycleAware` - Interface for objects that aware about other lifecycles
- `RaiiLifecycleMixin` - Basic lifecycle implementation
- `RaiiManagerMixin` - Implementation for managing multiple lifecycles, it implements `RaiiLifecycleAware` interface.
- `RaiiBox` - Container for managing custom resources

## License

Licensed under the MIT ([LICENSE](LICENSE) or <https://mit-license.org/>)
