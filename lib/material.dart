import 'package:flutter/material.dart';
import 'package:raii/flutter.dart';
import 'package:raii/raii.dart';

extension DataTableSourceExt on DataTableSource {
  DataTableSource withLifecycle(
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

extension MaterialStatesControllerExt on MaterialStatesController {
  MaterialStatesController withLifecycle(
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

extension SearchControllerExt on SearchController {
  SearchController withLifecycle(
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

extension TabControllerExt on TabController {
  TabController withLifecycle(
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

extension RestorableTimeOfDayExt on RestorableTimeOfDay {
  RestorableTimeOfDay withLifecycle(
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

extension ToggleablePainterExt on ToggleablePainter {
  ToggleablePainter withLifecycle(
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
