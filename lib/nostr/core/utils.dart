import 'dart:developer' as dev;

final class NostrClientUtils {
  bool _isLogsEnabled = true;

  void disableLogs() {
    _isLogsEnabled = false;
  }

  void enableLogs() {
    _isLogsEnabled = true;
  }

  void log(String message, [Object? error]) {
    if (_isLogsEnabled) {
      dev.log(
        message,
        name: "Nostr${error != null ? "Error" : ""}",
        error: error,
      );
    }
  }
}
