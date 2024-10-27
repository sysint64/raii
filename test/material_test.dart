import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:raii/material.dart';
import 'package:raii/raii.dart';
import 'package:raii/src/debug.dart';

class _MockTabController extends Mock implements TabController {}

void main() {
  late RaiiManager myRaiiManager;

  setUp(() {
    myRaiiManager = RaiiManager();
    debugTraceEvents = [];
  });

  group('Extensions', () {
    test('WidgetStatesController.withLifecycle', () {
      final resource = WidgetStatesController().withLifecycle(
        myRaiiManager,
        debugLabel: 'WidgetStatesController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: WidgetStatesController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: WidgetStatesController',
      );
    });

    test('SearchController.withLifecycle', () {
      final resource = SearchController().withLifecycle(
        myRaiiManager,
        debugLabel: 'SearchController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: SearchController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: SearchController',
      );
    });

    test('TabController.withLifecycle', () {
      final resource = _MockTabController().withLifecycle(
        myRaiiManager,
        debugLabel: 'TabController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: TabController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: TabController',
      );
    });

    test('RestorableTimeOfDay.withLifecycle', () {
      final resource = RestorableTimeOfDay(TimeOfDay.now()).withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableTimeOfDay',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableTimeOfDay',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableTimeOfDay',
      );
    });
  });
}
