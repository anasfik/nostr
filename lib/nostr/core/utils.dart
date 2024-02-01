import 'dart:developer' as dev;

/// {@template nostr_client_utils}
/// General utils to be used in a whole [Nostr] instance.
/// {@endtemplate}
class NostrClientUtils {
  /// Whether logs are enabled or not.
  bool _isLogsEnabled = true;

  /// Disables logs.
  void disableLogs() {
    _isLogsEnabled = false;
  }

  /// Enables logs.
  void enableLogs() {
    _isLogsEnabled = true;
  }

  /// Logs a message, and an optional error.
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
