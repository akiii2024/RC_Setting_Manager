import 'package:flutter/foundation.dart';

void debugLog(Object? message, [StackTrace? stackTrace]) {
  if (!kDebugMode) {
    return;
  }

  debugPrint(message?.toString());
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace);
  }
}
