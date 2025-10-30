import 'dart:async';

import 'package:raii/raii.dart';
import 'package:raii/src/debug.dart';

/// A managed [Timer] that integrates with the RAII lifecycle system.
///
/// [RaiiTimer] wraps a standard [Timer] and provides automatic cancellation
/// when its parent lifecycle is disposed. This prevents common issues like
/// timers firing after their associated widget or component has been disposed.
///
/// The timer can be cancelled manually by calling [cancel], or it will be
/// automatically cancelled when the parent [RaiiLifecycleAware] is disposed.
///
/// Example usage:
/// ```dart
/// class NotificationManager with RaiiLifecycleMixin {
///   void scheduleNotification() {
///     // Create timer using the extension method
///     final timer = Timer(Duration(seconds: 5), () {
///       showNotification('Your task is ready!');
///     }).withLifecycle(this);
///
///     // Can manually cancel if needed
///     if (userCancelled) {
///       timer.cancel();
///     }
///
///     // Can check timer state
///     if (timer.isActive) {
///       print('Timer is still running');
///     }
///   }
///
///   void schedulePeriodicTask() {
///     final timer = Timer.periodic(Duration(seconds: 1), (t) {
///       print('Tick: ${t.tick}');
///     }).withLifecycle(this);
///
///     // Access the timer's tick count
///     print('Current tick: ${timer.tick}');
///   }
/// }
/// ```
///
/// The timer follows this lifecycle:
/// 1. Created via [RaiiTimer.withLifecycle] (typically through [TimerRaiiExt.withLifecycle])
/// 2. Registered with parent [RaiiLifecycleAware]
/// 3. Timer runs until completion, manual cancellation, or parent disposal
/// 4. On disposal: timer is cancelled, lifecycle is cleaned up, and unregistered from parent
///
/// See also:
/// - [Timer] - The underlying Dart timer being wrapped
/// - [TimerRaiiExt.withLifecycle] - Extension method to create managed timers
/// - [RaiiBox] - Similar pattern for managing other resources
class RaiiTimer with RaiiLifecycleMixin {
  /// Creates a new [RaiiTimer] and attaches it to the given [lifecycleAware].
  ///
  /// The timer is automatically registered with [lifecycleAware] and will be
  /// cancelled when [lifecycleAware] is disposed.
  ///
  /// Parameters:
  /// - [lifecycleAware]: The parent lifecycle that will manage this timer
  /// - [timer]: The underlying [Timer] instance to manage
  /// - [debugLabel]: Optional label for debugging lifecycle events
  ///
  /// Example:
  /// ```dart
  /// // Typically created through the extension method:
  /// final timer = Timer(Duration(seconds: 5), () => print('Done!'))
  ///     .withLifecycle(this, debugLabel: 'MyTimer');
  ///
  /// // But can be created directly:
  /// final raiiTimer = RaiiTimer.withLifecycle(
  ///   myComponent,
  ///   timer: Timer(Duration(seconds: 5), () => print('Done!')),
  ///   debugLabel: 'MyTimer',
  /// );
  /// ```
  ///
  /// Note: In most cases, prefer using [TimerRaiiExt.withLifecycle] extension
  /// method instead of creating [RaiiTimer] instances directly.
  RaiiTimer.withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    required Timer timer,
    this.debugLabel,
  })  : _lifecycleAware = lifecycleAware,
        _timer = timer {
    _lifecycleAware.registerLifecycle(this);
  }

  final RaiiLifecycleAware _lifecycleAware;
  final Timer _timer;

  /// Optional label for debugging purposes.
  ///
  /// When provided, lifecycle events will be logged to the console with this label,
  /// making it easier to track timer creation and cancellation during development.
  ///
  /// Example output:
  /// ```
  /// [RAII] Init lifecycle: MyTimer
  /// [RAII] Dispose lifecycle: MyTimer
  /// ```
  final String? debugLabel;

  /// Cancels the timer and disposes its lifecycle.
  ///
  /// This method safely cancels the timer and performs proper lifecycle cleanup:
  /// - Checks if the timer is still active and lifecycle is mounted
  /// - Cancels the underlying timer
  /// - Unregisters from the parent lifecycle
  /// - Performs lifecycle cleanup
  ///
  /// After calling [cancel], the timer will not fire and [isActive] will return false.
  ///
  /// This method is safe to call multiple times or after the timer has already
  /// completed. It only performs disposal if the timer is both active and the
  /// lifecycle is still mounted.
  ///
  /// Example:
  /// ```dart
  /// final timer = Timer(Duration(seconds: 10), () => print('Hello'))
  ///     .withLifecycle(this);
  ///
  /// // User cancelled the operation
  /// timer.cancel();
  ///
  /// print(timer.isActive); // false
  ///
  /// // Safe to call again - no-op
  /// timer.cancel();
  /// ```
  void cancel() {
    if (isActive && isLifecycleMounted()) {
      disposeLifecycle();
    }
  }

  /// The number of times the timer has fired.
  ///
  /// For one-time timers (created with [Timer]), this will be 0 before firing
  /// and 1 after firing.
  ///
  /// For periodic timers (created with [Timer.periodic]), this increments
  /// each time the callback is invoked.
  ///
  /// Example:
  /// ```dart
  /// final timer = Timer.periodic(Duration(seconds: 1), (t) {
  ///   print('Tick ${t.tick}');
  /// }).withLifecycle(this);
  ///
  /// // Later, check how many times it has fired
  /// print('Timer has fired ${timer.tick} times');
  /// ```
  int get tick => _timer.tick;

  /// Whether the timer is still active and waiting to fire.
  ///
  /// Returns `true` if the timer has not yet fired (for one-time timers) or
  /// has not been cancelled (for periodic timers).
  ///
  /// Returns `false` if the timer has completed or been cancelled.
  ///
  /// Example:
  /// ```dart
  /// final timer = Timer(Duration(seconds: 5), () => print('Done'))
  ///     .withLifecycle(this);
  ///
  /// print(timer.isActive); // true
  ///
  /// timer.cancel();
  /// print(timer.isActive); // false
  /// ```
  bool get isActive => _timer.isActive;

  @override
  void initLifecycle() {
    super.initLifecycle();

    if (debugLabel != null) {
      raiiTrace('[RAII] Init lifecycle: $debugLabel');
    }
  }

  @override
  void disposeLifecycle() {
    super.disposeLifecycle();

    if (debugLabel != null) {
      raiiTrace('[RAII] Dispose lifecycle: $debugLabel');
    }
    _timer.cancel();
    _lifecycleAware.unregisterLifecycle(this);
  }
}

/// Extension on [Timer] that adds RAII lifecycle management capabilities.
///
/// This extension allows you to attach any [Timer] to a [RaiiLifecycleAware]
/// object, ensuring automatic cancellation when the lifecycle is disposed.
///
/// Example:
/// ```dart
/// class MyComponent with RaiiLifecycleMixin {
///   void setupTimers() {
///     // One-time timer
///     Timer(Duration(seconds: 5), () {
///       print('Executed after 5 seconds');
///     }).withLifecycle(this);
///
///     // Periodic timer
///     Timer.periodic(Duration(seconds: 1), (timer) {
///       print('Tick: ${timer.tick}');
///     }).withLifecycle(this, debugLabel: 'PeriodicTick');
///
///     // All timers are automatically cancelled when disposeLifecycle() is called
///   }
/// }
/// ```
extension TimerRaiiExt on Timer {
  /// Attaches this timer to a [RaiiLifecycleAware] for automatic lifecycle management.
  ///
  /// The timer will be automatically cancelled when [lifecycleAware] is disposed,
  /// preventing callbacks from executing after the lifecycle has ended.
  ///
  /// Parameters:
  /// - [lifecycleAware]: The parent lifecycle that will manage this timer
  /// - [debugLabel]: Optional label for debugging lifecycle events
  ///
  /// Returns a [RaiiTimer] that wraps this timer and provides additional
  /// lifecycle management features.
  ///
  /// Example:
  /// ```dart
  /// // Basic usage
  /// Timer(Duration(seconds: 3), () => print('Hello'))
  ///     .withLifecycle(this);
  ///
  /// // With debug label
  /// Timer.periodic(Duration(seconds: 1), (t) => print('Tick'))
  ///     .withLifecycle(this, debugLabel: 'HeartbeatTimer');
  ///
  /// // Store reference for manual cancellation
  /// final timer = Timer(Duration(seconds: 10), () => print('Done'))
  ///     .withLifecycle(this);
  /// timer.cancel(); // Can cancel manually if needed
  /// ```
  RaiiTimer withLifecycle(
    RaiiLifecycleAware lifecycleAware, {
    String? debugLabel,
  }) {
    return RaiiTimer.withLifecycle(
      lifecycleAware,
      timer: this,
      debugLabel: debugLabel,
    );
  }
}
