import 'dart:core';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';

import 'base/nostr.dart';
import 'core/utils.dart';
import 'instance/keys/keys.dart';
import 'instance/utils/utils.dart';

/// {@template nostr_service}
/// This class is responsible for handling the connection to all relays.
/// {@endtemplate}
class Nostr implements NostrServiceBase {
  /// {@macro nostr_service}
  static final Nostr _instance = Nostr._();

  /// {@macro nostr_service}
  static Nostr get instance => _instance;

  /// {@macro nostr_service}
  Nostr._();

  /// This method will disable the logs of the library.
  @override
  void disableLogs() {
    NostrClientUtils.disableLogs();
  }

  /// This method will enable the logs of the library.
  @override
  void enableLogs() {
    NostrClientUtils.enableLogs();
  }

  /// {@macro nostr_keys}
  final NostrKeys keysService = NostrKeys();

  /// {@macro nostr_relays}
  final NostrRelays relaysService = NostrRelays();

  /// {@macro nostr_utils}
  final NostrUtils utilsService = NostrUtils();
}
