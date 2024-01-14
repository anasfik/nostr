import 'dart:core';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';

import 'base/nostr.dart';
import 'core/utils.dart';
import 'instance/keys/keys.dart';
import 'instance/tlv/tlv_utils.dart';
import 'instance/utils/utils.dart';

/// {@template nostr_service}
/// This class is responsible for handling the connection to all relays.
/// {@endtemplate}
class Nostr implements NostrServiceBase {
  /// Weither this instance resources are disposed or not.
  bool _isDisposed = false;

  /// {@macro nostr_service}
  static final Nostr _instance = Nostr._();

  /// {@macro nostr_service}
  static Nostr get instance => _instance;

  /// {@macro nostr_client_utils}
  late final NostrClientUtils utils;

  /// {@macro nostr_service}
  factory Nostr() {
    //  utils.log("A Nostr instance created successfully.");
    return Nostr._();
  }

  /// {@macro nostr_service}
  Nostr._() {
    utils = NostrClientUtils();
  }

  /// This method will disable the logs of the library.
  @override
  void disableLogs() {
    utils.disableLogs();
  }

  /// This method will enable the logs of the library.
  @override
  void enableLogs() {
    utils.enableLogs();
  }

  /// Clears and frees all the resources used by this instance.
  @override
  Future<bool> dispose() async {
    if (!_isDisposed) {
      _isDisposed = true;
      utils.log("A Nostr instance disposed successfully.");
    }

    return await relaysService.freeAllResources();
  }

  /// {@macro nostr_keys}
  late final keysService = NostrKeys(
    utils: utils,
  );

  /// {@macro nostr_relays}
  late final relaysService = NostrRelays(
    utils: utils,
  );

  /// {@macro nostr_utils}
  late final utilsService = NostrUtils(
    utils: utils,
  );

  /// {@macro nostr_tlv}
  final tlv = NostrTLV();
}
