/// Custom exceptions for RAII lifecycle management.
///
/// These exceptions provide more granular control over lifecycle error handling,
/// allowing callers to catch and handle specific error cases rather than using
/// generic [StateError].
library;

/// Base exception for all RAII lifecycle-related errors.
///
/// This allows catching all RAII-specific exceptions with a single catch clause:
/// ```dart
/// try {
///   lifecycle.disposeLifecycle();
/// } on RaiiLifecycleException {
///   // Handle any lifecycle error
/// }
/// ```
abstract class RaiiLifecycleException implements Exception {
  /// Creates a lifecycle exception with the given [message].
  const RaiiLifecycleException(this.message);

  /// A description of the error.
  final String message;

  @override
  String toString() => 'RaiiLifecycleException: $message';
}

/// Exception thrown when attempting to initialize an already initialized lifecycle.
///
/// This typically indicates a programming error where [initLifecycle] was called
/// multiple times on the same object.
///
/// **Example:**
/// ```dart
/// final manager = RaiiManager();
/// manager.initLifecycle();
///
/// try {
///   manager.initLifecycle(); // Throws!
/// } on AlreadyInitializedException catch (e) {
///   print('Already initialized: ${e.message}');
///   // Optionally ignore if you don't care about double-init
/// }
/// ```
class AlreadyInitializedException extends RaiiLifecycleException {
  /// Creates an exception for when lifecycle is already initialized.
  const AlreadyInitializedException([
    super.message = 'Cannot initialize: lifecycle is already initialized',
  ]);

  @override
  String toString() => 'AlreadyInitializedException: $message';
}

/// Exception thrown when attempting to dispose an already disposed lifecycle.
///
/// This typically indicates a programming error where [disposeLifecycle] was called
/// multiple times on the same object.
///
/// **Example:**
/// ```dart
/// final manager = RaiiManager()..initLifecycle();
/// manager.disposeLifecycle();
///
/// try {
///   manager.disposeLifecycle(); // Throws!
/// } on AlreadyDisposedException catch (e) {
///   print('Already disposed: ${e.message}');
///   // Can safely ignore if you don't care about double-dispose
/// }
/// ```
///
/// **Lenient disposal pattern:**
/// ```dart
/// void safeDispose(RaiiLifecycle lifecycle) {
///   try {
///     lifecycle.disposeLifecycle();
///   } on AlreadyDisposedException {
///     // Ignore - already cleaned up
///   }
/// }
/// ```
class AlreadyDisposedException extends RaiiLifecycleException {
  /// Creates an exception for when lifecycle is already disposed.
  const AlreadyDisposedException([
    super.message = 'Cannot dispose: lifecycle is already disposed',
  ]);

  @override
  String toString() => 'AlreadyDisposedException: $message';
}

/// Exception thrown when attempting to dispose a lifecycle that was never initialized.
///
/// This indicates that [disposeLifecycle] was called without first calling [initLifecycle].
///
/// **Example:**
/// ```dart
/// final manager = RaiiManager();
/// // Forgot to call initLifecycle()
///
/// try {
///   manager.disposeLifecycle(); // Throws!
/// } on NotInitializedException catch (e) {
///   print('Not initialized: ${e.message}');
/// }
/// ```
class NotInitializedException extends RaiiLifecycleException {
  /// Creates an exception for when attempting to dispose an uninitialized lifecycle.
  const NotInitializedException([
    super.message = 'Cannot dispose: lifecycle was never initialized',
  ]);

  @override
  String toString() => 'NotInitializedException: $message';
}

/// Exception thrown when attempting to register a lifecycle with a disposed manager.
///
/// This indicates that you're trying to add a child to a manager that has already
/// been disposed and can no longer manage resources.
///
/// **Example:**
/// ```dart
/// final manager = RaiiManager()..initLifecycle();
/// manager.disposeLifecycle();
///
/// try {
///   // Trying to register after disposal
///   RaiiBox.withLifecycle(manager, instance: 'resource'); // Throws!
/// } on ManagerDisposedException catch (e) {
///   print('Manager is disposed: ${e.message}');
/// }
/// ```
class ManagerDisposedException extends RaiiLifecycleException {
  /// Creates an exception for when attempting to use a disposed manager.
  const ManagerDisposedException([
    super.message = 'Cannot register lifecycle: manager is disposed',
  ]);

  @override
  String toString() => 'ManagerDisposedException: $message';
}

/// Exception thrown when a lifecycle operation fails during disposal.
///
/// This is used to wrap exceptions that occur during disposal callbacks,
/// particularly when disposing children in a manager.
///
/// **Example:**
/// ```dart
/// final manager = RaiiManager()..initLifecycle();
///
/// RaiiBox.withLifecycle(
///   manager,
///   instance: 'resource',
///   dispose: (_, __) {
///     throw Exception('Disposal failed!');
///   },
/// );
///
/// try {
///   manager.disposeLifecycle();
/// } on DisposalFailedException catch (e) {
///   print('Disposal error: ${e.message}');
///   print('Original error: ${e.originalException}');
/// }
/// ```
class DisposalFailedException extends RaiiLifecycleException {
  /// Creates an exception wrapping a disposal failure.
  const DisposalFailedException(
    super.message, {
    this.originalException,
    this.originalStackTrace,
  });

  /// The original exception that caused the disposal failure.
  final Object? originalException;

  /// The original stack trace from the disposal failure.
  final StackTrace? originalStackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('DisposalFailedException: $message');
    if (originalException != null) {
      buffer.write('\nCaused by: $originalException');
    }
    return buffer.toString();
  }
}
