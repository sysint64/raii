import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raii/cupertino.dart';
import 'package:raii/raii.dart';
import 'package:raii/src/debug.dart';

void main() {
  late RaiiManager myRaiiManager;

  setUp(() {
    myRaiiManager = RaiiManager();
    debugTraceEvents = [];
  });

  group('Extensions', () {
    test('CupertinoTabController.withLifecycle', () {
      final resource = CupertinoTabController().withLifecycle(
        myRaiiManager,
        debugLabel: 'CupertinoTabController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: CupertinoTabController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: CupertinoTabController',
      );
    });

    test('RestorableCupertinoTabController.withLifecycle', () {
      final resource = RestorableCupertinoTabController().withLifecycle(
        myRaiiManager,
        debugLabel: 'RestorableCupertinoTabController',
      );

      myRaiiManager.initLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Init lifecycle: RestorableCupertinoTabController',
      );
      myRaiiManager.disposeLifecycle();
      expect(
        debugTraceEvents?.last,
        '[RAII] Dispose lifecycle: RestorableCupertinoTabController',
      );
    });
  });
}
