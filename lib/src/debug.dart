import 'package:flutter/foundation.dart';

List<String>? debugTraceEvents;

void raiiTrace(String message) {
  debugPrint(message);
  debugTraceEvents?.add(message);
}
