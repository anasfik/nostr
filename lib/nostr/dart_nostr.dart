import 'dart:core';

import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:dart_nostr/nostr/service/services.dart';

/// {@template nostr_service}
/// This class is responsible for handling the connection to all relays.
/// {@endtemplate}
class Nostr {
  /// {@macro nostr_service}
  factory Nostr({
    NostrDebugOptions? debugOptions,
  }) {
    //  utils.log("A Nostr instance created successfully.");
    return Nostr._(
      debugOptions: debugOptions,
    );
  }

  /// {@macro nostr_service}
  Nostr._({
    NostrDebugOptions? debugOptions,
  }) {
    debugOptions ??= NostrDebugOptions.generate();

    _logger = NostrLogger(passedDebugOptions: debugOptions);
  }

  /// Wether this instance resources are disposed or not.
  bool _isDisposed = false;

  //
  /// {@macro nostr_service}
  static final Nostr _instance = Nostr._(
    debugOptions: NostrDebugOptions.general(),
  );

  /// {@macro nostr_service}
  static Nostr get instance => _instance;

  /// This method will disable the logs of the library.

  void disableLogs() {
    _logger.disableLogs();
  }

  /// This method will enable the logs of the library.

  void enableLogs() {
    _logger.enableLogs();
  }

  /// {@macro nostr_client_utils}
  late final NostrLogger _logger;

  late final services = NostrServices(
    logger: _logger,
  );
}

mixin LifeCycleManager on Nostr {
  /// Clears and frees all the resources used by this instance.

  Future<bool> dispose() async {
    if (_isDisposed) {
      _logger.log('This Nostr instance is already disposed.');
      return true;
    }

    _isDisposed = true;

    _logger.log('A Nostr instance disposed successfully.');

    await Future.wait<dynamic>([
      services.keys.freeAllResources(),
      services.relays.freeAllResources(),
    ]);

    return true;
  }
}
