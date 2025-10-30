import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:raii/flutter.dart';
import 'package:raii/raii.dart';
import 'package:raii/src/debug.dart';

class _MockWidgetsBinding extends Mock implements WidgetsBinding {}

class _MockRestorableEnum extends Mock implements RestorableEnum {}

class _MockRestorableEnumN extends Mock implements RestorableEnumN {}

class _MockScrollPosition extends Mock implements ScrollPosition {}

class _MockScrollbarPainter extends Mock implements ScrollbarPainter {}

class _MockScrollPositionWithSingleContext extends Mock
    implements ScrollPositionWithSingleContext {}

class _MockPlatformRouteInformationProvider extends Mock
    implements PlatformRouteInformationProvider {}

class _MockTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}

class _TestResources implements RaiiLifecycle {
  int initializedCount = 0;
  int disposedCount = 0;

  @override
  bool isLifecycleMounted() => initializedCount > 0 && disposedCount == 0;

  @override
  void initLifecycle() {
    initializedCount += 1;
  }

  @override
  void disposeLifecycle() {
    disposedCount += 1;
  }
}

class _UserModel extends ChangeNotifier {
  String name = '';

  void updateName(String newName) {
    name = newName;
    notifyListeners();
  }
}

class _TestWidget extends StatefulWidget {
  const _TestWidget({
    this.onCreateState,
  });

  final void Function(_TestWidgetState state)? onCreateState;

  @override
  // ignore: no_logic_in_create_state
  _TestWidgetState createState() {
    final state = _TestWidgetState();
    onCreateState?.call(state);
    return state;
  }
}

class _TestWidgetState extends State<_TestWidget> with RaiiStateMixin {
  _TestWidgetState();

  bool initLifecycleCalled = false;
  bool disposeLifecycleCalled = false;

  @override
  void initLifecycle() {
    super.initLifecycle();

    initLifecycleCalled = true;
  }

  @override
  void disposeLifecycle() {
    super.disposeLifecycle();
    disposeLifecycleCalled = true;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _TestWidgetsBindingObserver with WidgetsBindingObserver {
  bool didChangeAppLifecycleStateCalled = false;
  AppLifecycleState? lastLifecycleState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    didChangeAppLifecycleStateCalled = true;
    lastLifecycleState = state;
  }
}

void main() {
  late RaiiManager myRaiiManager;

  setUp(() {
    myRaiiManager = RaiiManager();
    debugTraceEvents = [];
  });

  group('$RaiiStateMixin', () {
    testWidgets(
      'lifecycle states are properly tracked',
      (tester) async {
        late _TestWidgetState state;

        await tester.pumpWidget(
          _TestWidget(onCreateState: (s) {
            state = s;

            expect(state.isLifecycleMounted(), false);
            expect(state.initLifecycleCalled, false);
          }),
        );

        await tester.pump();
        expect(state.isLifecycleMounted(), true);
        expect(state.initLifecycleCalled, true);

        await tester.pumpWidget(const SizedBox());
        expect(state.isLifecycleMounted(), false);
        expect(state.disposeLifecycleCalled, true);
      },
    );

    testWidgets(
      'properly manages lifecycle objects '
      'when registerLifecycle',
      (tester) async {
        late _TestWidgetState state;
        final resource = _TestResources();

        await tester.pumpWidget(
          _TestWidget(
            onCreateState: (s) => state = s,
          ),
        );
        await tester.pump();

        // Register lifecycle when mounted
        state.registerLifecycle(resource);
        expect(resource.initializedCount, 1);
        expect(resource.disposedCount, 0);

        // Dispose widget and verify lifecycle is disposed
        await tester.pumpWidget(const SizedBox());
        expect(resource.disposedCount, 1);
      },
    );

    testWidgets(
      'multiple lifecycles are managed correctly',
      (tester) async {
        late _TestWidgetState state;
        final lifecycles = List.generate(3, (_) => _TestResources());

        await tester.pumpWidget(
          _TestWidget(
            onCreateState: (s) => state = s,
          ),
        );
        await tester.pump();

        // Register multiple lifecycles
        for (final lifecycle in lifecycles) {
          state.registerLifecycle(lifecycle);
        }

        // Verify all are initialized
        for (final lifecycle in lifecycles) {
          expect(lifecycle.initializedCount, 1);
          expect(lifecycle.disposedCount, 0);
        }

        // Dispose widget and verify all are disposed
        await tester.pumpWidget(const SizedBox());
        for (final lifecycle in lifecycles) {
          expect(lifecycle.disposedCount, 1);
        }
      },
    );

    testWidgets(
      'handles duplicate registrations '
      'when registerLifecycle',
      (tester) async {
        late _TestWidgetState state;
        final lifecycle = _TestResources();

        await tester.pumpWidget(
          _TestWidget(
            onCreateState: (s) => state = s,
          ),
        );
        await tester.pump();

        // Register same lifecycle twice
        state.registerLifecycle(lifecycle);
        state.registerLifecycle(lifecycle);

        // Should only be initialized once
        expect(lifecycle.initializedCount, 1);

        // Should only be disposed once
        await tester.pumpWidget(const SizedBox());
        expect(lifecycle.disposedCount, 1);
      },
    );

    testWidgets(
      'initialize pending lifecycles '
      'when didChangeDependencies',
      (tester) async {
        late _TestWidgetState state;
        final lifecycle = _TestResources();

        await tester.pumpWidget(
          _TestWidget(
            onCreateState: (s) {
              state = s;

              // Add lifecycle before didChangeDependencies
              state.registerLifecycle(lifecycle);
              expect(lifecycle.initializedCount, 0);
            },
          ),
        );

        // After pump, didChangeDependencies should initialize lifecycle
        await tester.pumpAndSettle();
        expect(lifecycle.initializedCount, 1);
      },
    );
  });

  group('$RaiiDisposeable', () {
    test(
      'do nothing '
      'when initLifecycle',
      () {
        String data = 'not disposed';
        RaiiDisposeable.withLifecycle(
          myRaiiManager,
          debugLabel: 'My label',
          dispose: () => data = 'disposed',
        );
        myRaiiManager.initLifecycle();
        expect(data, 'not disposed');
      },
    );

    test(
      'call dispose '
      'when disposeLifecycle',
      () {
        String data = 'not disposed';
        RaiiDisposeable.withLifecycle(
          myRaiiManager,
          debugLabel: 'My label',
          dispose: () => data = 'disposed',
        );
        myRaiiManager.initLifecycle();
        myRaiiManager.disposeLifecycle();
        expect(data, 'disposed');
      },
    );
  });

  group('WidgetsBindingRaiiExt', () {
    late _MockWidgetsBinding mockBinding;
    late _TestWidgetsBindingObserver observer1;
    late _TestWidgetsBindingObserver observer2;
    late List<WidgetsBindingObserver> registeredObservers;

    setUp(() {
      mockBinding = _MockWidgetsBinding();
      observer1 = _TestWidgetsBindingObserver();
      observer2 = _TestWidgetsBindingObserver();
      registeredObservers = [];

      when(() => mockBinding.addObserver(observer1)).thenAnswer(
        (_) => registeredObservers.add(observer1),
      );
      when(() => mockBinding.addObserver(observer2)).thenAnswer(
        (_) => registeredObservers.add(observer2),
      );

      when(() => mockBinding.removeObserver(observer1)).thenAnswer(
        (_) => registeredObservers.remove(observer1),
      );
      when(() => mockBinding.removeObserver(observer2)).thenAnswer(
        (_) => registeredObservers.remove(observer2),
      );
    });

    testWidgets(
      'register observer '
      'when lifecycle is mounted',
      (tester) async {
        late _TestWidgetState state;

        await tester.pumpWidget(
          _TestWidget(
            onCreateState: (s) => state = s,
          ),
        );
        await tester.pump();

        // Add observer
        mockBinding.addObserverWithLifecycle(
          state,
          observer1,
          debugLabel: 'TestObserver',
        );

        // Verify observer was registered
        verify(() => mockBinding.addObserver(observer1)).called(1);
        expect(registeredObservers, contains(observer1));
      },
    );

    testWidgets(
      'remove observer '
      'when lifecycle is disposed',
      (tester) async {
        late _TestWidgetState state;

        await tester.pumpWidget(
          _TestWidget(
            onCreateState: (s) => state = s,
          ),
        );
        await tester.pump();

        // Add observer
        mockBinding.addObserverWithLifecycle(
          state,
          observer1,
          debugLabel: 'TestObserver',
        );

        // Dispose widget
        await tester.pumpWidget(const SizedBox());

        // Verify observer was removed
        verify(() => mockBinding.removeObserver(observer1)).called(1);
        expect(registeredObservers, isEmpty);
      },
    );

    testWidgets(
      'observer receives lifecycle events '
      'when registered',
      (tester) async {
        late _TestWidgetState state;

        await tester.pumpWidget(
          _TestWidget(
            onCreateState: (s) => state = s,
          ),
        );
        await tester.pump();

        // Add observer
        mockBinding.addObserverWithLifecycle(
          state,
          observer1,
          debugLabel: 'TestObserver',
        );

        // Simulate lifecycle event
        for (final registeredObserver in registeredObservers) {
          registeredObserver
              .didChangeAppLifecycleState(AppLifecycleState.paused);
        }

        // Verify observer received event
        expect(observer1.didChangeAppLifecycleStateCalled, true);
        expect(observer1.lastLifecycleState, AppLifecycleState.paused);
      },
    );
  });

  group('AnimationRaiiExt', () {
    test('addStatusListenerWithLifecycle adds and removes listener', () {
      final controller = AnimationController(
        vsync: _MockTickerProvider(),
        duration: const Duration(milliseconds: 100),
      );

      AnimationStatus? capturedStatus;
      int listenerCallCount = 0;

      controller.addStatusListenerWithLifecycle(
        myRaiiManager,
        (status) {
          capturedStatus = status;
          listenerCallCount++;
        },
        debugLabel: 'TestAnimationStatusListener',
      );

      // Initialize lifecycle
      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: TestAnimationStatusListener',
      );

      // Set controller to middle position so reverse() will work
      controller.value = 0.5;

      // Trigger status changes
      controller.forward();
      expect(capturedStatus, AnimationStatus.forward);
      expect(listenerCallCount, 1);

      controller.reverse();
      expect(capturedStatus, AnimationStatus.reverse);
      expect(listenerCallCount, 2);

      // Dispose lifecycle
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: TestAnimationStatusListener',
      );

      // Verify listener is removed after disposal
      final previousCallCount = listenerCallCount;
      controller.forward();
      expect(listenerCallCount, previousCallCount); // Should not increment

      controller.dispose();
    });

    test('addStatusListenerWithLifecycle works with multiple listeners', () {
      final controller = AnimationController(
        vsync: _MockTickerProvider(),
        duration: const Duration(milliseconds: 100),
      );

      int listener1Count = 0;
      int listener2Count = 0;

      controller.addStatusListenerWithLifecycle(
        myRaiiManager,
        (status) => listener1Count++,
        debugLabel: 'Listener1',
      );

      controller.addStatusListenerWithLifecycle(
        myRaiiManager,
        (status) => listener2Count++,
        debugLabel: 'Listener2',
      );

      myRaiiManager.initLifecycle();

      // Trigger status change
      controller.forward();
      expect(listener1Count, 1);
      expect(listener2Count, 1);

      // Dispose and verify both listeners are removed
      myRaiiManager.disposeLifecycle();

      controller.reverse();
      expect(listener1Count, 1); // Should not increment
      expect(listener2Count, 1); // Should not increment

      controller.dispose();
    });

    test('addStatusListenerWithLifecycle tracks animation status changes', () {
      final controller = AnimationController(
        vsync: _MockTickerProvider(),
        duration: const Duration(milliseconds: 100),
      );

      final capturedStatuses = <AnimationStatus>[];

      controller.addStatusListenerWithLifecycle(
        myRaiiManager,
        (status) => capturedStatuses.add(status),
        debugLabel: 'StatusTracker',
      );

      myRaiiManager.initLifecycle();

      // Test forward status
      controller.value = 0.5;
      controller.forward();
      expect(capturedStatuses, contains(AnimationStatus.forward));

      // Test reverse status
      controller.reverse();
      expect(capturedStatuses, contains(AnimationStatus.reverse));

      // Test dismissed status
      controller.value = 0.0;
      expect(capturedStatuses, contains(AnimationStatus.dismissed));

      // Test completed status
      controller.value = 1.0;
      expect(capturedStatuses, contains(AnimationStatus.completed));

      myRaiiManager.disposeLifecycle();
      controller.dispose();
    });

    test('addStatusListenerWithLifecycle with Tween animation', () {
      final controller = AnimationController(
        vsync: _MockTickerProvider(),
        duration: const Duration(milliseconds: 100),
      );

      final animation = Tween<double>(begin: 0.0, end: 1.0).animate(controller);
      final statuses = <AnimationStatus>[];

      animation.addStatusListenerWithLifecycle(
        myRaiiManager,
        (status) => statuses.add(status),
        debugLabel: 'TweenAnimation',
      );

      myRaiiManager.initLifecycle();

      controller.forward();
      expect(statuses, contains(AnimationStatus.forward));

      myRaiiManager.disposeLifecycle();

      // Verify listener removed from tween animation
      final countBefore = statuses.length;
      controller.reverse();
      expect(statuses.length, countBefore);

      controller.dispose();
    });
  });

  group('Extensions', () {
    test('Listenable.addListenerWithLifecycle', () {
      final user = _UserModel();
      String userName = '';

      user.addListenerWithLifecycle(
        myRaiiManager,
        () => userName = user.name,
        debugLabel: 'User',
      );

      myRaiiManager.initLifecycle();

      user.updateName('John');
      expect(userName, 'John');

      user.updateName('Mari');
      expect(userName, 'Mari');

      myRaiiManager.disposeLifecycle();

      user.updateName('Ann');
      expect(userName, 'Mari');
    });

    test('StreamSubscription.withLifecycle', () async {
      final streamController = StreamController<String>();
      String userName = '';

      streamController.stream
          .listen((name) => userName = name)
          .withLifecycle(myRaiiManager, debugLabel: 'User names');

      myRaiiManager.initLifecycle();

      streamController.add('John');
      await pumpEventQueue();
      expect(userName, 'John');

      streamController.add('Mari');
      await pumpEventQueue();
      expect(userName, 'Mari');

      myRaiiManager.disposeLifecycle();

      streamController.add('Ann');
      await pumpEventQueue();
      expect(userName, 'Mari');

      await streamController.close();
    });

    test('ValueNotifier.withLifecycle', () {
      final notifier = ValueNotifier<int>(42).withLifecycle(
        myRaiiManager,
        debugLabel: 'test',
      );

      myRaiiManager.initLifecycle();

      expect(notifier.value, equals(42));
      notifier.value = 100;
      expect(notifier.value, equals(100));

      myRaiiManager.disposeLifecycle();
      expect(() => notifier.value = 200, throwsFlutterError);
    });

    test('ScrollController.withLifecycle', () {
      ScrollController().withLifecycle(
        myRaiiManager,
        debugLabel: 'ScrollController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ScrollController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ScrollController',
      );
    });

    test('AnimationController.withLifecycle', () {
      AnimationController(
        vsync: _MockTickerProvider(),
      ).withLifecycle(
        myRaiiManager,
        debugLabel: 'AnimationController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: AnimationController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: AnimationController',
      );
    });

    test('Ticker.withLifecycle', () {
      Ticker((_) {}).withLifecycle(
        myRaiiManager,
        debugLabel: 'Ticker',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: Ticker',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: Ticker',
      );
    });

    test('MouseTracker.withLifecycle', () {
      MouseTracker((_, __) => HitTestResult()).withLifecycle(
        myRaiiManager,
        debugLabel: 'MouseTracker',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: MouseTracker',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: MouseTracker',
      );
    });

    test('ViewportOffset.withLifecycle', () {
      ViewportOffset.fixed(0).withLifecycle(
        myRaiiManager,
        debugLabel: 'ViewportOffset',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ViewportOffset',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ViewportOffset',
      );
    });

    test('SemanticsOwner.withLifecycle', () {
      SemanticsOwner(
        onSemanticsUpdate: (_) {},
      ).withLifecycle(
        myRaiiManager,
        debugLabel: 'SemanticsOwner',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: SemanticsOwner',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: SemanticsOwner',
      );
    });

    test('RestorationManager.withLifecycle', () {
      RestorationManager().withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorationManager',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorationManager',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorationManager',
      );
    });

    test('KeepAliveHandle.withLifecycle', () {
      KeepAliveHandle().withLifecycle(
        myRaiiManager,
        debugLabel: 'KeepAliveHandle',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: KeepAliveHandle',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: KeepAliveHandle',
      );
    });

    test('DraggableScrollableController.withLifecycle', () {
      DraggableScrollableController().withLifecycle(
        myRaiiManager,
        debugLabel: 'DraggableScrollableController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: DraggableScrollableController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: DraggableScrollableController',
      );
    });

    test('TextEditingController.withLifecycle', () {
      TextEditingController().withLifecycle(
        myRaiiManager,
        debugLabel: 'TextEditingController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: TextEditingController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: TextEditingController',
      );
    });

    test('FocusNode.withLifecycle', () {
      FocusNode().withLifecycle(
        myRaiiManager,
        debugLabel: 'FocusNode',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: FocusNode',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: FocusNode',
      );
    });

    test('FocusScopeNode.withLifecycle', () {
      FocusScopeNode().withLifecycle(
        myRaiiManager,
        debugLabel: 'FocusScopeNode',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: FocusScopeNode',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: FocusScopeNode',
      );
    });

    test('FocusManager.withLifecycle', () {
      FocusManager().withLifecycle(
        myRaiiManager,
        debugLabel: 'FocusManager',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: FocusManager',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: FocusManager',
      );
    });

    test('TransformationController.withLifecycle', () {
      TransformationController().withLifecycle(
        myRaiiManager,
        debugLabel: 'TransformationController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: TransformationController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: TransformationController',
      );
    });

    test('FixedExtentScrollController.withLifecycle', () {
      FixedExtentScrollController().withLifecycle(
        myRaiiManager,
        debugLabel: 'FixedExtentScrollController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: FixedExtentScrollController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: FixedExtentScrollController',
      );
    });

    test('RestorableRouteFuture.withLifecycle', () {
      RestorableRouteFuture(
        onPresent: (_, __) => "",
      ).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableRouteFuture',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableRouteFuture',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableRouteFuture',
      );
    });

    test('SliverOverlapAbsorberHandle.withLifecycle', () {
      SliverOverlapAbsorberHandle().withLifecycle(
        myRaiiManager,
        debugLabel: 'SliverOverlapAbsorberHandle',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: SliverOverlapAbsorberHandle',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: SliverOverlapAbsorberHandle',
      );
    });

    test('PageController.withLifecycle', () {
      PageController().withLifecycle(
        myRaiiManager,
        debugLabel: 'PageController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: PageController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: PageController',
      );
    });

    test('RestorableNum.withLifecycle', () {
      RestorableNum(0.0).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableNum',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableNum',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableNum',
      );
    });

    test('RestorableDouble.withLifecycle', () {
      RestorableDouble(0.0).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableDouble',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableDouble',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableDouble',
      );
    });

    test('RestorableInt.withLifecycle', () {
      RestorableInt(0).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableInt',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableInt',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableInt',
      );
    });

    test('RestorableString.withLifecycle', () {
      RestorableString('').withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableString',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableString',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableString',
      );
    });

    test('RestorableBool.withLifecycle', () {
      RestorableBool(true).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableBool',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableBool',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableBool',
      );
    });

    test('RestorableBoolN.withLifecycle', () {
      RestorableBoolN(null).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableBoolN',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableBoolN',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableBoolN',
      );
    });

    test('RestorableNumN.withLifecycle', () {
      RestorableNumN(null).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableNumN',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableNumN',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableNumN',
      );
    });

    test('RestorableDoubleN.withLifecycle', () {
      RestorableDoubleN(null).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableDoubleN',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableDoubleN',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableDoubleN',
      );
    });

    test('RestorableIntN.withLifecycle', () {
      RestorableIntN(null).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableIntN',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableIntN',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableIntN',
      );
    });

    test('RestorableStringN.withLifecycle', () {
      RestorableStringN(null).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableStringN',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableStringN',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableStringN',
      );
    });

    test('RestorableDateTime.withLifecycle', () {
      RestorableDateTime(DateTime.now()).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableDateTime',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableDateTime',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableDateTime',
      );
    });

    test('RestorableDateTimeN.withLifecycle', () {
      RestorableDateTimeN(null).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableDateTimeN',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableDateTimeN',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableDateTimeN',
      );
    });

    test('RestorableTextEditingController.withLifecycle', () {
      RestorableTextEditingController().withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableTextEditingController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableTextEditingController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableTextEditingController',
      );
    });

    test('RestorableEnumN.withLifecycle', () {
      _MockRestorableEnumN().withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableEnumN',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableEnumN',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableEnumN',
      );
    });

    test('RestorableEnum.withLifecycle', () {
      _MockRestorableEnum().withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableEnum',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableEnum',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableEnum',
      );
    });

    test('RestorableEnum.withLifecycle', () {
      _MockRestorableEnum().withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableEnum',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableEnum',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableEnum',
      );
    });

    test('PlatformRouteInformationProvider.withLifecycle', () {
      _MockPlatformRouteInformationProvider().withLifecycle(
        myRaiiManager,
        debugLabel: 'PlatformRouteInformationProvider',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: PlatformRouteInformationProvider',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: PlatformRouteInformationProvider',
      );
    });

    test('TrackingScrollController.withLifecycle', () {
      TrackingScrollController().withLifecycle(
        myRaiiManager,
        debugLabel: 'TrackingScrollController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: TrackingScrollController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: TrackingScrollController',
      );
    });

    test('ScrollPosition.withLifecycle', () {
      _MockScrollPosition().withLifecycle(
        myRaiiManager,
        debugLabel: 'ScrollPosition',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ScrollPosition',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ScrollPosition',
      );
    });

    test('ScrollPositionWithSingleContext.withLifecycle', () {
      _MockScrollPositionWithSingleContext().withLifecycle(
        myRaiiManager,
        debugLabel: 'ScrollPositionWithSingleContext',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ScrollPositionWithSingleContext',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ScrollPositionWithSingleContext',
      );
    });

    test('ScrollbarPainter.withLifecycle', () {
      _MockScrollbarPainter().withLifecycle(
        myRaiiManager,
        debugLabel: 'ScrollbarPainter',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ScrollbarPainter',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ScrollbarPainter',
      );
    });

    test('ShortcutManager.withLifecycle', () {
      ShortcutManager().withLifecycle(
        myRaiiManager,
        debugLabel: 'ShortcutManager',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ShortcutManager',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ShortcutManager',
      );
    });

    test('ShortcutRegistry.withLifecycle', () {
      ShortcutRegistry().withLifecycle(
        myRaiiManager,
        debugLabel: 'ShortcutRegistry',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ShortcutRegistry',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ShortcutRegistry',
      );
    });

    test('SnapshotController.withLifecycle', () {
      SnapshotController().withLifecycle(
        myRaiiManager,
        debugLabel: 'SnapshotController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: SnapshotController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: SnapshotController',
      );
    });

    test('ClipboardStatusNotifier.withLifecycle', () {
      ClipboardStatusNotifier().withLifecycle(
        myRaiiManager,
        debugLabel: 'ClipboardStatusNotifier',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: ClipboardStatusNotifier',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: ClipboardStatusNotifier',
      );
    });

    test('UndoHistoryController.withLifecycle', () {
      UndoHistoryController().withLifecycle(
        myRaiiManager,
        debugLabel: 'UndoHistoryController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: UndoHistoryController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: UndoHistoryController',
      );
    });
  });
}
