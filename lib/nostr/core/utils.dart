
import 'dart:developer' as dev;

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
