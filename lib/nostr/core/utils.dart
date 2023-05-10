import 'dart:convert';
import 'dart:math';

import 'dart:developer' as dev;
import 'package:convert/convert.dart';

abstract class NostrClientUtils {
  static bool _isLogsEnabled = true;

  static void disableLogs() {
    _isLogsEnabled = false;
  }

  static void enableLogs() {
    _isLogsEnabled = true;
  }

  static log(String message, [Object? error]) {
    if (_isLogsEnabled) {
      dev.log(
        message,
        name: "Nostr${error != null ? "Error" : ""}",
        error: error,
      );
    }
  }
}
