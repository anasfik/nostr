import 'dart:developer' as dev;

import 'package:dart_nostr/nostr/model/debug_options.dart';

/// {@template nostr_client_utils}
/// General utils to be used in a whole [Nostr] instance.
/// {@endtemplate}
class NostrLogger {
  final NostrDebugOptions passedDebugOptions;
  late NostrDebugOptions _debugOptions;

  NostrLogger({
    required this.passedDebugOptions,
  }) {
    _debugOptions = passedDebugOptions;
  }

  NostrDebugOptions get debugOptions => _debugOptions;

  /// Disables logs.
  void disableLogs() {
    _debugOptions = _debugOptions.copyWith(isLogsEnabled: false);
  }

  /// Enables logs.
  void enableLogs() {
    _debugOptions = _debugOptions.copyWith(isLogsEnabled: true);
  }

  /// Logs a message, and an optional error.
  void log(String message, [Object? error]) {
    final isLogsEnabled = _debugOptions.isLogsEnabled;

    if (!isLogsEnabled) {
      return;
    }

    final tag = _debugOptions.tag;

    var logDisplayName = tag;

    if (error != null) {
      logDisplayName = '$tag$error';
    }

    dev.log(
      message,
      name: logDisplayName,
      error: error,
    );
  }
}
