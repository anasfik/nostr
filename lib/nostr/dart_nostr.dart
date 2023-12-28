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
  /// {@macro nostr_service}
  static final Nostr _instance = Nostr._();

  /// {@macro nostr_service}
  static Nostr get instance => _instance;

  late final utils;

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
