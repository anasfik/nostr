import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'base/nostr.dart';
import 'core/key_pairs.dart';
import 'core/registry.dart';
import 'core/utils.dart';
import 'model/request/close.dart';
import 'model/event.dart';

import 'model/request/request.dart';

/// {@template nostr_service}
/// This class is responsible for handling the connection to all relays.
/// {@endtemplate}
class Nostr implements NostrServiceBase {
  /// {@macro nostr_service}
  static final Nostr _instance = Nostr._();

  /// {@macro nostr_service}
  static Nostr get instance => _instance;

  /// This is the controller which will receive all events from all relays.
  final _streamController = StreamController<NostrEvent>.broadcast();

  /// This is the stream which will have all events from all relays.
  Stream<NostrEvent> get stream => _streamController.stream;

  /// {@macro nostr_service}
  Nostr._();

  /// You can use this method to generate a key pair for your end users.
  /// it returns the private key of the generated key pair.
  @override
  String generatePrivateKey() {
    final nostrKeyPairs = generateKeyPair();
    NostrClientUtils.log(
      "generated key pairs, with it's public key is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs.private;
  }

  @override
  NostrKeyPairs generateKeyPair() {
    final nostrKeyPairs = NostrKeyPairs.generate();
    NostrClientUtils.log(
      "generated key pairs, with it's public key is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs;
  }

  /// This method is responsible for initializing the connection to all relays.
  /// It takes a list of relays urls, then it connects to each relay and registers it for future use.
  /// You will need to call this method before using any other method, as example, in your `main()` method to make sure that the connection is established before using any other method.
  /// ```dart
  /// void main() async {
  ///  await Nostr.instance.init(relaysUrl: ["wss://relay.damus.io"]);
  /// // ...
  /// runApp(MyApp()); // if it is a flutter app
  /// }
  /// ```
  /// You can also use this method to re-connect to all relays in case of a connection failure.
  Future<void> init({
    required List<String> relaysUrl,
    void Function(String relayUrl, dynamic receivedData)? onRelayListening,
    void Function(String relayUrl, Object? error)? onRelayError,
    void Function(String relayUrl)? onRelayDone,
  }) async {
    assert(
      relaysUrl.isNotEmpty,
      "initiating relays with an empty list doesn't make sense, please provide at least one relay url.",
    );

    for (String relay in relaysUrl) {
      NostrRegistry.registerRelayWebSocket(
        relayUrl: relay,
        webSocket: await WebSocket.connect(relay),
      );
      NostrClientUtils.log(
        "the websocket for the relay with url: $relay, is registered.",
      );
      NostrClientUtils.log(
        "listening to the websocket for the relay with url: $relay...",
      );
      NostrRegistry.getRelayWebSocket(relayUrl: relay)!.listen((d) {
        if (onRelayListening != null) {
          onRelayListening(relay, d);
        }

        if (NostrEvent.canBeDeserializedEvent(d)) {
          _streamController.sink.add(NostrEvent.fromRelayMessage(d));
          NostrClientUtils.log(
              "received event with content: ${NostrEvent.fromRelayMessage(d).content} from relay: $relay");
        } else {
          NostrClientUtils.log(
              "received non-event message from relay: $relay, message: $d");
        }
        // else if (NostrEOSE.canBeDeserialized(d)) {
        //   print(
        //       "EOS from relay $relay with id: ${NostrEOSE.fromRelayMessage(d).subscriptionId}");
        // }
      }, onError: (error) {
        if (onRelayError != null) {
          onRelayError(relay, error);
        }
        NostrClientUtils.log(
          "web socket of relay with $relay had an error: $error",
          error,
        );
      }, onDone: () {
        if (onRelayDone != null) {
          onRelayDone(relay);
        }
        NostrClientUtils.log("""
web socket of relay with $relay is done:
close code: ${NostrRegistry.getRelayWebSocket(relayUrl: relay)!.closeCode}.
close reason: ${NostrRegistry.getRelayWebSocket(relayUrl: relay)!.closeReason}.
""");
      });
    }
  }

  @override
  void sendEventToRelays(NostrEvent event) async {
    final serialized = event.serialized();

    _runFunctionOverRelationIteration((current) {
      current.value.add(serialized);
      NostrClientUtils.log(
        "event with id: ${event.id} is sent to relay with url: ${current.key}",
      );
    });
  }

  @override
  Stream<NostrEvent> startEventsSubscription({
    required NostrRequest request,
  }) {
    final serialized = request.serialized();

    _runFunctionOverRelationIteration((current) {
      current.value.add(serialized);
      NostrClientUtils.log(
        "request with subscription id: ${request.subscriptionId} is sent to relay with url: ${current.key}",
      );
    });

    return stream.where((event) {
      return event.subscriptionId == request.subscriptionId;
    });
  }

  @override
  void closeEventsSubscription(String subscriptionId) {
    final close = NostrRequestClose(subscriptionId: subscriptionId);
    final serialized = close.serialized();

    _runFunctionOverRelationIteration((current) {
      current.value.add(serialized);
      NostrClientUtils.log(
        "close request with subscription id: $subscriptionId is sent to relay with url: ${current.key}",
      );
    });
  }

  void _runFunctionOverRelationIteration(
    Function(MapEntry<String, WebSocket>) function,
  ) {
    for (int index = 0;
        index < NostrRegistry.allRelaysEntries().length;
        index++) {
      final entries = NostrRegistry.allRelaysEntries();
      final current = entries[index];
      function(current);
    }
  }

  @override
  void disableLogs() {
    NostrClientUtils.disableLogs();
  }

  @override
  void enableLogs() {
    NostrClientUtils.enableLogs();
  }
}
