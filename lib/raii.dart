library raii;

import 'package:flutter/foundation.dart';

abstract class Lifecycle {
  void initLifecycle();

  void disposeLifecycle();

  bool isLifecycleMounted();
}

abstract class LifecycleAware implements Lifecycle {
  void registerLifecycle(Lifecycle lifecycle);
}

class LifecycleAwareContainer with LifecycleAwareMixin {}

mixin LifecycleMixin implements Lifecycle {
  var _isLifecycleMounted = false;

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
}

mixin LifecycleAwareMixin implements LifecycleAware {
  @visibleForTesting
  final registeredLifecycles = <Lifecycle>[];
  bool _init = false;
  bool _isLifecycleMounted = false;

  @override
  bool isLifecycleMounted() => _isLifecycleMounted;

  @override
  @mustCallSuper
  void registerLifecycle(Lifecycle lifecycle) {
    registeredLifecycles.add(lifecycle);

    if (_init) {
      lifecycle.initLifecycle();
    }
  }

  @override
  @mustCallSuper
  void initLifecycle() {
    for (final lifecycle in registeredLifecycles) {
      lifecycle.initLifecycle();
    }
    _init = true;
  }

  @override
  @mustCallSuper
  void disposeLifecycle() {
    for (final lifecycle in registeredLifecycles) {
      lifecycle.disposeLifecycle();
    }

    registeredLifecycles.clear();
    _isLifecycleMounted = false;
  }
}
