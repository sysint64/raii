import 'package:flutter/cupertino.dart';
import 'package:raii/flutter.dart';
import 'package:raii/raii.dart';

extension CupertinoTabControllerRaiiExt on CupertinoTabController {
  CupertinoTabController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}

extension RestorableCupertinoTabControllerRaiiExt on RestorableCupertinoTabController {
  RestorableCupertinoTabController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? tag,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      tag: tag,
    );

    return this;
  }
}
