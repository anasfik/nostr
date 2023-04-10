import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'base/nostr.dart';
import 'core/key_pairs.dart';
import 'core/registry.dart';
import 'core/utils.dart';
import 'model/request/close.dart';
import 'model/event.dart';
import 'model/request/eose.dart';
import 'model/request/request.dart';

/// {@template nostr_service}
/// This class is responsible for handling the connection to all relays.
/// {@endtemplate}
class Nostr implements NostrServiceBase {
  static final Nostr _instance = Nostr._();

  /// {@macro nostr_service}
  static Nostr get instance => _instance;

  /// This is the controller which will receive all events from all relays.
  final _streamController = StreamController<NostrEvent>.broadcast();

  /// This is the stream which will have all events from all relays.
  Stream<NostrEvent> get stream => _streamController.stream;

  /// {@macro nostr_service}
  Nostr._();

  @override
  String generateKeys() {
    final nostrKeyPairs = NostrKeyPairs.generate();
    NostrClientUtils.log(
      "generated key pairs, whis it's public keyis: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs.private;
  }

  Future<void> init({
    required List<String> relaysUrl,
  }) async {
    for (String relay in relaysUrl) {
      NostrRegistry.registerRelayWebSocket(
        relayUrl: relay,
        webSocket: await WebSocket.connect(relay),
      );
      NostrClientUtils.log("websocket for relay with $relay is registered");
      NostrRegistry.getRelayWebSocket(relayUrl: relay)!.listen((d) {
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
      }, onError: (e) {
        NostrClientUtils.log(
            "web socket of relay with $relay had an error: $e");
      }, onDone: () {
        // NostrRegistry.getRelayWebSocket(relayUrl: relay)!.close();
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

    for (WebSocket relayWebSocket in NostrRegistry.allRelayWebSockets()) {
      relayWebSocket.add(serialized);
      NostrClientUtils.log(
          "event with id: ${event.id} is sent to registered relays.");
    }
  }

  @override
  Stream<NostrEvent> subscribeToEvents({
    required NostrRequest request,
  }) {
    final serialized = request.serialized();
    for (WebSocket relayWebSocket in NostrRegistry.allRelayWebSockets()) {
      relayWebSocket.add(serialized);
    }

    return stream.where((event) {
      return event.subscriptionId == request.subscriptionId;
    });
  }

  void unsubscribeFromEvents(String subscriptionId) {
    final close = NostrRequestClose(subscriptionId: subscriptionId);
    final serialized = close.serialized();

    for (WebSocket relayWebSocket in NostrRegistry.allRelayWebSockets()) {
      relayWebSocket.add(serialized);
    }
  }
}
