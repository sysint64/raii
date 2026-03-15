import 'dart:async';

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
      'throw AlreadyDisposedException '
      'when try to dispose twice',
      () {
        resource.initLifecycle();
        resource.disposeLifecycle();
        expect(
          () => resource.disposeLifecycle(),
          throwsA(isA<AlreadyDisposedException>()),
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
          throwsA(isA<AlreadyInitializedException>()),
        );
      },
    );

    test(
      'throw state error exception '
      'when try to dispose non initialized resource',
      () {
        expect(
          () => resource.disposeLifecycle(),
          throwsA(isA<NotInitializedException>()),
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
        final controller = StreamController<int>();
        controller.add(1);
        // ignore: avoid_print
        final subscription = controller.stream.listen((it) => print(it));
        controller.close();
        subscription.cancel();

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
      'dispose all resources '
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
      'throw ManagerDisposedException '
      'when try register resource on disposed manager',
      () {
        myRaiiManager.initLifecycle();

        myRaiiManager.registerLifecycle(resourceA);
        myRaiiManager.registerLifecycle(resourceB);
        myRaiiManager.disposeLifecycle();

        expect(
          () => myRaiiManager.registerLifecycle(resourceC),
          throwsA(isA<ManagerDisposedException>()),
        );
      },
    );

    test(
      'throw AlreadyDisposedException '
      'when try to dispose twice',
      () {
        myRaiiManager.initLifecycle();
        myRaiiManager.disposeLifecycle();
        expect(
          () => myRaiiManager.disposeLifecycle(),
          throwsA(isA<AlreadyDisposedException>()),
        );
      },
    );

    test(
      'throw AlreadyInitializedException '
      'when try to init twice',
      () {
        myRaiiManager.initLifecycle();
        expect(
          () => myRaiiManager.initLifecycle(),
          throwsA(isA<AlreadyInitializedException>()),
        );
      },
    );

    test(
      'throw NotInitializedException '
      'when try to dispose non initialized',
      () {
        expect(
          () => myRaiiManager.disposeLifecycle(),
          throwsA(isA<NotInitializedException>()),
        );
      },
    );
  });

  group('takeLifecycle', () {
    late RaiiManager ownerA;
    late RaiiManager ownerB;
    late _MyResource resource;

    setUp(() {
      ownerA = RaiiManager()..initLifecycle();
      ownerB = RaiiManager()..initLifecycle();
      resource = _MyResource();
    });

    test(
      'resource stays mounted '
      'when transferred to new owner',
      () {
        ownerA.registerLifecycle(resource);

        expect(resource.isLifecycleMounted(), true);
        expect(resource.state, _MyResourceState.init);

        ownerB.takeLifecycle(resource);

        expect(resource.isLifecycleMounted(), true);
        expect(resource.state, _MyResourceState.init);
      },
    );

    test(
      'resource is removed from old owner '
      'when transferred',
      () {
        ownerA.registerLifecycle(resource);

        expect(ownerA.registeredLifecycles, contains(resource));

        ownerB.takeLifecycle(resource);

        expect(ownerA.registeredLifecycles, isNot(contains(resource)));
      },
    );

    test(
      'resource is added to new owner '
      'when transferred',
      () {
        ownerA.registerLifecycle(resource);

        expect(ownerB.registeredLifecycles, isNot(contains(resource)));

        ownerB.takeLifecycle(resource);

        expect(ownerB.registeredLifecycles, contains(resource));
      },
    );

    test(
      'resource is not disposed '
      'when old owner is disposed after transfer',
      () {
        ownerA.registerLifecycle(resource);

        ownerB.takeLifecycle(resource);
        ownerA.disposeLifecycle();

        expect(resource.isLifecycleMounted(), true);
        expect(resource.state, _MyResourceState.init);
      },
    );

    test(
      'resource is disposed '
      'when new owner is disposed after transfer',
      () {
        ownerA.registerLifecycle(resource);

        ownerB.takeLifecycle(resource);
        ownerB.disposeLifecycle();

        expect(resource.isLifecycleMounted(), false);
        expect(resource.state, _MyResourceState.disposed);
      },
    );

    test(
      'holder reference is updated '
      'when transferred',
      () {
        ownerA.registerLifecycle(resource);

        expect(resource.raiiHolder, ownerA);

        ownerB.takeLifecycle(resource);

        expect(resource.raiiHolder, ownerB);
      },
    );

    test(
      'throw NotInitializedException '
      'when try to take disposed resource',
      () {
        ownerA.registerLifecycle(resource);
        ownerA.disposeLifecycle();

        expect(
          () => ownerB.takeLifecycle(resource),
          throwsA(isA<NotInitializedException>()),
        );
      },
    );

    test(
      'throw NotInitializedException '
      'when try to transfer non initialized resource',
      () {
        final uninitResource = _MyResource();

        expect(
          () => ownerB.takeLifecycle(uninitResource),
          throwsA(isA<NotInitializedException>()),
        );
      },
    );

    test(
      'resource is owned by last owner '
      'when transferred multiple times',
      () {
        final ownerC = RaiiManager()..initLifecycle();

        ownerA.registerLifecycle(resource);
        ownerB.takeLifecycle(resource);
        ownerC.takeLifecycle(resource);

        expect(ownerA.registeredLifecycles, isNot(contains(resource)));
        expect(ownerB.registeredLifecycles, isNot(contains(resource)));
        expect(ownerC.registeredLifecycles, contains(resource));
        expect(resource.raiiHolder, ownerC);
        expect(resource.isLifecycleMounted(), true);

        ownerC.disposeLifecycle();
        expect(resource.state, _MyResourceState.disposed);
      },
    );

    test(
      'manager and its children are moved '
      'when manager is transferred between owners',
      () {
        final parent1 = RaiiManager()..initLifecycle();
        final parent2 = RaiiManager()..initLifecycle();
        final childManager = RaiiManager();
        final childResource = _MyResource();

        parent1.registerLifecycle(childManager);
        childManager.registerLifecycle(childResource);

        expect(childResource.isLifecycleMounted(), true);

        parent2.takeLifecycle(childManager);

        expect(parent1.registeredLifecycles, isNot(contains(childManager)));
        expect(parent2.registeredLifecycles, contains(childManager));
        expect(childManager.isLifecycleMounted(), true);
        expect(childResource.isLifecycleMounted(), true);

        // Disposing parent1 should not affect childManager or its children
        parent1.disposeLifecycle();
        expect(childManager.isLifecycleMounted(), true);
        expect(childResource.isLifecycleMounted(), true);

        // Disposing parent2 should dispose childManager and its children
        parent2.disposeLifecycle();
        expect(childManager.isLifecycleMounted(), false);
        expect(childResource.isLifecycleMounted(), false);
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

        RaiiBox.withLifecycle(
          myRaiiManager,
          instance: 'Resource',
          debugLabel: 'Resource',
          init: (instance, _) => data = '$instance: init',
          dispose: (instance, _) => data = '$instance: dispose',
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

        RaiiBox.withLifecycle(
          myRaiiManager,
          instance: 'Resource',
          debugLabel: 'Resource',
          init: (instance, _) => data = '$instance: init',
          dispose: (instance, _) => data = '$instance: dispose',
        );

        myRaiiManager.initLifecycle();
        myRaiiManager.disposeLifecycle();
        expect(data, 'Resource: dispose');
      },
    );
  });
}
