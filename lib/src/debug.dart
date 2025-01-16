import 'package:flutter/foundation.dart';

/// Trace information for debug purposes.
List<String>? debugTraceEvents;

/// Log some debug information.
void raiiTrace(String message) {
  debugPrint(message);
  debugTraceEvents?.add(message);
}
