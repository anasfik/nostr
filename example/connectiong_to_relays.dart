import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  await Nostr.instance.relaysService.init(
    relaysUrl: [
      /// your relays ...
    ],
    ensureToClearRegistriesBeforeStarting: true,
    connectionTimeout: Duration(seconds: 5),
    ignoreConnectionException: true,
    lazyListeningToRelays: false,
    onRelayConnectionDone: (relayUrl, relayWebSocket) {
      print("Connected to relay: $relayUrl");
    },
    onRelayListening: (relayUrl, receivedEvent, relayWebSocket) {
      print("Listening to relay: $relayUrl");
    },
    onRelayConnectionError: (relayUrl, error, relayWebSocket) {},
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
  );

  await Nostr.instance.relaysService.reconnectToRelays(
    connectionTimeout: Duration(seconds: 5),
    ignoreConnectionException: true,
    lazyListeningToRelays: false,
    onRelayConnectionDone: (relayUrl, relayWebSocket) {
      print("Connected to relay: $relayUrl");
    },
    onRelayListening: (relayUrl, receivedEvent, relayWebSocket) {
      print("Listening to relay: $relayUrl");
    },
    onRelayConnectionError: (relayUrl, error, relayWebSocket) {},
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
  );
}
