/// RAII extensions for Cupertino (iOS-style) specific components and controllers.
///
/// This library provides lifecycle management extensions for Cupertino widgets
/// and controllers, ensuring proper resource cleanup through the RAII pattern.
library;

import 'package:flutter/cupertino.dart';
import 'package:raii/flutter.dart';
import 'package:raii/raii.dart';

/// Extension for managing [CupertinoTabController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final tabController = CupertinoTabController(initialIndex: 0)
///     .withLifecycle(this, debugLabel: 'CupertinoTabs');
/// }
/// ```
extension CupertinoTabControllerRaiiExt on CupertinoTabController {
  /// Attaches this tab controller to a [RaiiLifecycleAware] object for automatic disposal.
  CupertinoTabController withLifecycle(
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

/// Extension for managing [RestorableCupertinoTabController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with RaiiStateMixin {
///   late final tabController = RestorableCupertinoTabController(initialIndex: 0)
///     .withLifecycle(this, debugLabel: 'RestorableCupertinoTabs');
/// }
/// ```
extension RestorableCupertinoTabControllerRaiiExt
    on RestorableCupertinoTabController {
  /// Attaches this restorable tab controller to a [RaiiLifecycleAware] object for automatic disposal.
  RestorableCupertinoTabController withLifecycle(
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
