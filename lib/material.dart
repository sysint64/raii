/// RAII extensions for Material Design specific components and controllers.
///
/// This library provides lifecycle management extensions for various Material Design
/// widgets and controllers, ensuring proper resource cleanup through the RAII pattern.
library;

import 'package:flutter/material.dart';
import 'package:raii/flutter.dart';
import 'package:raii/raii.dart';

/// Extension for managing [WidgetStatesController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final statesController = WidgetStatesController()
///   .withLifecycle(this, debugLabel: 'ButtonStates');
/// ```
extension WidgetStatesControllerRaiiExt on WidgetStatesController {
  /// Attaches this states controller to a [RaiiLifecycleAware] object for automatic disposal.
  WidgetStatesController withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [SearchController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final searchController = SearchController()
///   .withLifecycle(this, debugLabel: 'SearchBar');
/// ```
extension SearchControllerRaiiExt on SearchController {
  /// Attaches this search controller to a [RaiiLifecycleAware] object for automatic disposal.
  SearchController withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [TabController] lifecycle.
///
/// **Example:**
///
/// ```dart
/// class MyWidgetState extends State<MyWidget>
///     with TickerProviderStateMixin, LifecycleAwareWidgetStateMixin {
///   late final tabController = TabController(length: 3, vsync: this)
///     .withLifecycle(this, debugLabel: 'TabBar');
/// }
/// ```
extension TabControllerRaiiExt on TabController {
  /// Attaches this tab controller to a [RaiiLifecycleAware] object for automatic disposal.
  TabController withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}

/// Extension for managing [RestorableTimeOfDay] lifecycle.
///
/// **Example:**
///
/// ```dart
/// final timeValue = RestorableTimeOfDay(TimeOfDay.now())
///   .withLifecycle(this, debugLabel: 'SelectedTime');
/// ```
extension RestorableTimeOfDayRaiiExt on RestorableTimeOfDay {
  /// Attaches this restorable time value to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableTimeOfDay withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    RaiiDisposeable.withLifecycle(
      lifecycleAware,
      dispose: dispose,
      debugLabel: debugLabel,
    );
    return this;
  }
}
