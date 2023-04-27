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

  static String random64HexChars() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return hex.encode(randomBytes);
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

  static hexEncode(String input) {
    return hex.encode(utf8.encode(input));
  }
}
