import 'package:flutter/material.dart';
import 'package:raii/flutter.dart';
import 'package:raii/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAII Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RaiiHomePage(),
    );
  }
}

class RaiiHomePage extends StatefulWidget {
  const RaiiHomePage({super.key});

  @override
  State<RaiiHomePage> createState() => _RaiiHomePageState();
}

class _RaiiHomePageState extends State<RaiiHomePage>
    with TickerProviderStateMixin, RaiiStateMixin {
  // Controllers with automatic lifecycle management
  late final tabController = TabController(length: 3, vsync: this)
      .withLifecycle(this, debugLabel: 'Tabs');

  late final scrollController =
      ScrollController().withLifecycle(this, debugLabel: 'Scroll');

  late final textController =
      TextEditingController().withLifecycle(this, debugLabel: 'TextInput');

  late final focusNode =
      FocusNode().withLifecycle(this, debugLabel: 'FocusNode');

  late final animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  ).withLifecycle(
    this,
    debugLabel: 'Animation',
  );

  late final animation = CurvedAnimation(
    parent: animationController,
    curve: Curves.easeInOut,
  );

  @override
  void initLifecycle() {
    super.initLifecycle();

    // Register app lifecycle observer
    WidgetsBinding.instance.addObserverWithLifeycle(
      this,
      AppLifecycleObserver(onResume: _handleAppResume),
      debugLabel: 'AppLifecycle',
    );

    // Listen to tab changes
    tabController.addListenerWithLifecycle(
      this,
      _handleTabChange,
      debugLabel: 'TabListener',
    );

    // Listen to scroll updates
    scrollController.addListenerWithLifecycle(
      this,
      _handleScroll,
      debugLabel: 'ScrollListener',
    );

    // Listen to text changes
    textController.addListenerWithLifecycle(
      this,
      _handleTextChange,
      debugLabel: 'TextListener',
    );

    // Listen to focus changes
    focusNode.addListenerWithLifecycle(
      this,
      _handleFocusChange,
      debugLabel: 'FocusListener',
    );

    // Listen to animation updates
    animation.addListenerWithLifecycle(
      this,
      _handleAnimationUpdate,
      debugLabel: 'AnimationListener',
    );
  }

  void _handleAppResume() {
    debugPrint('App resumed - restoring state');
  }

  void _handleTabChange() {
    debugPrint('Tab changed: ${tabController.index}');
  }

  void _handleScroll() {
    debugPrint('Scroll position: ${scrollController.offset}');
  }

  void _handleTextChange() {
    debugPrint('Text changed: ${textController.text}');
  }

  void _handleFocusChange() {
    debugPrint('Focus changed: ${focusNode.hasFocus}');
  }

  void _handleAnimationUpdate() {
    debugPrint('Animation value: ${animation.value}');
    setState(() {});
  }

  void _toggleAnimation() {
    if (animationController.status == AnimationStatus.completed) {
      animationController.reverse();
    } else {
      animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAII Example'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Home'),
            Tab(icon: Icon(Icons.list), text: 'List'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          // Home tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: textController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Type something',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Transform.scale(
                    scale: 1.0 + animation.value * 0.5,
                    child: ElevatedButton(
                      onPressed: _toggleAnimation,
                      child: const Text('Animate Me'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List tab
          ListView.builder(
            controller: scrollController,
            itemCount: 100,
            itemBuilder: (context, index) => ListTile(
              title: Text('Item $index'),
            ),
          ),
          // Settings tab
          const Center(
            child: Text('Settings Content'),
          ),
        ],
      ),
    );
  }
}

class AppLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResume;

  AppLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('App resumed');
        onResume();
        break;
      case AppLifecycleState.inactive:
        debugPrint('App inactive');
        break;
      case AppLifecycleState.paused:
        debugPrint('App paused - saving state');
        break;
      case AppLifecycleState.detached:
        debugPrint('App detached');
        break;
      case AppLifecycleState.hidden:
        debugPrint('App hidden');
        break;
    }
  }

  @override
  void didChangePlatformBrightness() {
    debugPrint('Brightness changed');
  }
}
