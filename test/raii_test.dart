import 'package:flutter_test/flutter_test.dart';

import 'package:raii/raii.dart';

enum _MyResourceState {
  waitInit,
  init,
  disposed,
}

class _MyResource with RaiiLifecycleMixin {
  _MyResource();

  var state = _MyResourceState.waitInit;

  @override
  void initLifecycle() {
    super.initLifecycle();

    state = _MyResourceState.init;
  }

  @override
  void disposeLifecycle() {
    state = _MyResourceState.disposed;

    super.disposeLifecycle();
  }
}

void main() {
  test(
    'throw state error exception '
    'when try to dispose alwaysAliveRaiiManager',
    () {
      expect(
        () => alwaysAliveRaiiManager.disposeLifecycle(),
        throwsA(isA<StateError>()),
      );
    },
  );

  group('$RaiiLifecycleMixin', () {
    late _MyResource resource;

    setUp(() {
      resource = _MyResource();
    });

    test(
      'resource lifecycle isLifecycleMounted == false '
      'when lifecycle is not initialized',
      () {
        expect(resource.isLifecycleMounted(), false);
      },
    );

    test(
      'resource lifecycle isLifecycleMounted == true '
      'when lifecycle is initialized',
      () {
        resource.initLifecycle();
        expect(resource.isLifecycleMounted(), true);
      },
    );

    test(
      'resource lifecycle isLifecycleMounted == false '
      'when lifecycle is initialized '
      'and disposed after',
      () {
        resource.initLifecycle();
        resource.disposeLifecycle();
        expect(resource.isLifecycleMounted(), false);
      },
    );

    test(
      'throw state error exception '
      'when try to dispose twice',
      () {
        resource.initLifecycle();
        resource.disposeLifecycle();
        expect(
          () => resource.disposeLifecycle(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'throw state error exception '
      'when try to init twice',
      () {
        resource.initLifecycle();
        expect(
          () => resource.initLifecycle(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'throw state error exception '
      'when try to dispose non initialized resource',
      () {
        expect(
          () => resource.disposeLifecycle(),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('$RaiiManagerMixin', () {
    late _MyResource resourceA;
    late _MyResource resourceB;
    late _MyResource resourceC;
    late RaiiManager myRaiiManager;

    setUp(() {
      myRaiiManager = RaiiManager();
      resourceA = _MyResource();
      resourceB = _MyResource();
      resourceC = _MyResource();
    });

    test(
      'manager\'s lifecycle is mounted '
      'when initLifecycle',
      () {
        myRaiiManager.initLifecycle();

        expect(myRaiiManager.isLifecycleMounted(), true);
      },
    );

    test(
      'manager\'s lifecycle is not mounted '
      'when before initLifecycle call',
      () {
        expect(myRaiiManager.isLifecycleMounted(), false);
      },
    );

    test(
      'manager\'s lifecycle is not mounted '
      'when initLifecycle '
      'and disposeLifecycle after',
      () {
        myRaiiManager.initLifecycle();
        myRaiiManager.disposeLifecycle();
        expect(myRaiiManager.isLifecycleMounted(), false);
      },
    );

    test(
      'initialize resources '
      'when initLifecycle of manager',
      () {
        myRaiiManager.registerLifecycle(resourceA);
        myRaiiManager.registerLifecycle(resourceB);
        myRaiiManager.registerLifecycle(resourceC);

        expect(resourceA.state, _MyResourceState.waitInit);
        expect(resourceB.state, _MyResourceState.waitInit);
        expect(resourceC.state, _MyResourceState.waitInit);

        myRaiiManager.initLifecycle();

        expect(resourceA.state, _MyResourceState.init);
        expect(resourceB.state, _MyResourceState.init);
        expect(resourceC.state, _MyResourceState.init);
      },
    );

    test(
      'initialize resources '
      'when register resources after manager initialized',
      () {
        myRaiiManager.registerLifecycle(resourceA);
        expect(resourceA.state, _MyResourceState.waitInit);

        myRaiiManager.initLifecycle();
        expect(resourceA.state, _MyResourceState.init);

        myRaiiManager.registerLifecycle(resourceB);
        expect(resourceB.state, _MyResourceState.init);

        myRaiiManager.registerLifecycle(resourceC);
        expect(resourceC.state, _MyResourceState.init);
      },
    );

    test(
      'dispoase all resources '
      'when disposeLifecycle',
      () {
        myRaiiManager.initLifecycle();

        myRaiiManager.registerLifecycle(resourceA);
        myRaiiManager.registerLifecycle(resourceB);
        myRaiiManager.registerLifecycle(resourceC);

        myRaiiManager.disposeLifecycle();

        expect(resourceA.state, _MyResourceState.disposed);
        expect(resourceB.state, _MyResourceState.disposed);
        expect(resourceC.state, _MyResourceState.disposed);
      },
    );

    test(
      'throw a state error '
      'when try register resource on disposed manager',
      () {
        myRaiiManager.initLifecycle();

        myRaiiManager.registerLifecycle(resourceA);
        myRaiiManager.registerLifecycle(resourceB);
        myRaiiManager.disposeLifecycle();

        expect(
          () => myRaiiManager.registerLifecycle(resourceC),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'throw state error exception '
      'when try to dispose twice',
      () {
        myRaiiManager.initLifecycle();
        myRaiiManager.disposeLifecycle();
        expect(
          () => myRaiiManager.disposeLifecycle(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'throw state error exception '
      'when try to init twice',
      () {
        myRaiiManager.initLifecycle();
        expect(
          () => myRaiiManager.initLifecycle(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'throw state error exception '
      'when try to dispose non initialized',
      () {
        expect(
          () => myRaiiManager.disposeLifecycle(),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('RaiiBox', () {
    late RaiiManager myRaiiManager;

    setUp(() {
      myRaiiManager = RaiiManager();
    });

    test(
      'automatically init resource '
      'when manager init lifecycle',
      () {
        String data = '';

        final resource = RaiiBox.withLifecycle(
          myRaiiManager,
          instance: 'Resource',
          debugLabel: 'Resource',
          init: (instance) => data = '$instance: init',
          dispose: (instance) => data = '$instance: dispose',
        );

        myRaiiManager.initLifecycle();
        expect(data, 'Resource: init');
      },
    );

    test(
      'automatically dispose resource '
      'when manager dispose lifecycle',
      () {
        String data = '';

        final resource = RaiiBox.withLifecycle(
          myRaiiManager,
          instance: 'Resource',
          debugLabel: 'Resource',
          init: (instance) => data = '$instance: init',
          dispose: (instance) => data = '$instance: dispose',
        );

        myRaiiManager.initLifecycle();
        myRaiiManager.disposeLifecycle();
        expect(data, 'Resource: dispose');
      },
    );
  });
}
