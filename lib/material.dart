/// RAII extensions for Material Design specific components and controllers.
///
/// This library provides lifecycle management extensions for various Material Design
/// widgets and controllers, ensuring proper resource cleanup through the RAII pattern.
library;

import 'package:flutter/material.dart';
import 'package:raii/flutter.dart';
import 'package:raii/raii.dart';

/// Extension for managing [DataTableSource] lifecycle.
///
/// Example:
/// ```dart
/// class MyDataSource extends DataTableSource {
///   // ... implementation
/// }
///
/// final dataSource = MyDataSource()
///   .withLifecycle(this, debugLabel: 'TableDataSource');
/// ```
extension DataTableSourceExt on DataTableSource {
  /// Attaches this data source to a [LifecycleAware] object for automatic disposal.
  DataTableSource withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [WidgetStatesController] lifecycle.
///
/// Example:
/// ```dart
/// final statesController = WidgetStatesController()
///   .withLifecycle(this, debugLabel: 'ButtonStates');
/// ```
extension WidgetStatesControllerExt on WidgetStatesController {
  /// Attaches this states controller to a [LifecycleAware] object for automatic disposal.
  WidgetStatesController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [SearchController] lifecycle.
///
/// Example:
/// ```dart
/// final searchController = SearchController()
///   .withLifecycle(this, debugLabel: 'SearchBar');
/// ```
extension SearchControllerExt on SearchController {
  /// Attaches this search controller to a [LifecycleAware] object for automatic disposal.
  SearchController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [TabController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
///   late final tabController = TabController(length: 3, vsync: this)
///     .withLifecycle(this, debugLabel: 'TabBar');
/// }
/// ```
extension TabControllerExt on TabController {
  /// Attaches this tab controller to a [LifecycleAware] object for automatic disposal.
  TabController withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableTimeOfDay] lifecycle.
///
/// Example:
/// ```dart
/// final timeValue = RestorableTimeOfDay(TimeOfDay.now())
///   .withLifecycle(this, debugLabel: 'SelectedTime');
/// ```
extension RestorableTimeOfDayExt on RestorableTimeOfDay {
  /// Attaches this restorable time value to a [LifecycleAware] object for automatic disposal.
  RestorableTimeOfDay withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [ToggleablePainter] lifecycle.
///
/// Example:
/// ```dart
/// final painter = CustomToggleablePainter()
///   .withLifecycle(this, debugLabel: 'CheckboxPainter');
/// ```
extension ToggleablePainterExt on ToggleablePainter {
  /// Attaches this toggleable painter to a [LifecycleAware] object for automatic disposal.
  ToggleablePainter withLifecycle(
    LifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    DisposeableLifecycle.attach(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}
