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
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final tabController = CupertinoTabController(initialIndex: 0)
///     .withLifecycle(this, debugLabel: 'CupertinoTabs');
/// }
/// ```
extension CupertinoTabControllerRaiiExt on CupertinoTabController {
  /// Attaches this tab controller to a [LifecycleAware] object for automatic disposal.
  CupertinoTabController withLifecycle(
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

/// Extension for managing [RestorableCupertinoTabController] lifecycle.
///
/// Example:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with LifecycleAwareWidgetStateMixin {
///   late final tabController = RestorableCupertinoTabController(initialIndex: 0)
///     .withLifecycle(this, debugLabel: 'RestorableCupertinoTabs');
/// }
/// ```
extension RestorableCupertinoTabControllerRaiiExt
    on RestorableCupertinoTabController {
  /// Attaches this restorable tab controller to a [LifecycleAware] object for automatic disposal.
  RestorableCupertinoTabController withLifecycle(
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
