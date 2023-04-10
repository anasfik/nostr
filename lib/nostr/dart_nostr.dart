import 'dart:core';
import 'dart:io';
import 'package:dart_nostr/nostr/instance/relays/relays.dart';

import 'base/nostr.dart';
import 'core/utils.dart';
import 'instance/keys/keys.dart';

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

  /// This method is responsible for initializing the connection to all relays.
  /// It takes a [List<String>] of relays urls, then it connects to each relay and registers it for future use, if [relayUrl] is empty, it will throw an [AssertionError] since it doesn't make sense to connect to an empty list of relays.
  ///
  ///
  /// The [WebSocket]s of the relays will start being listened to get events from them immediately after calling this method, unless you set the [lazyListeningToRelays] parameter to `true`, then you will have to call the [startListeningToRelays] method to start listening to the relays manually.
  ///
  ///
  /// You can also pass a callback to the [onRelayListening] parameter to be notified when a relay starts listening to it's websocket.
  ///
  ///
  /// You can also pass a callback to the [onRelayError] parameter to be notified when a relay websocket throws an error.
  ///
  ///
  /// You can also pass a callback to the [onRelayDone] parameter to be notified when a relay websocket is closed.
  ///
  ///
  /// You will need to call this method before using any other method, as example, in your `main()` method to make sure that the connection is established before using any other method.
  /// ```dart
  /// void main() async {
  ///  await Nostr.instance.init(relaysUrl: ["wss://relay.damus.io"]);
  /// // ...
  /// runApp(MyApp()); // if it is a flutter app
  /// }
  /// ```
  ///
  /// You can also use this method to re-connect to all relays in case of a connection failure.

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
  final NostrKeys keys = NostrKeys();

  /// {@macro nostr_relays}
  final NostrRelays service = NostrRelays();
}
