import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  await Nostr.instance.services.relays.init(
    relaysUrl: [
      /// your relays ...
    ],
    onRelayConnectionDone: (relayUrl, relayWebSocket) {
      print('Connected to relay: $relayUrl');
    },
    onRelayListening: (relayUrl, receivedEvent, relayWebSocket) {
      print('Listening to relay: $relayUrl');
    },
    onRelayConnectionError: (relayUrl, error, relayWebSocket) {},
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
  );

  await Future.delayed(const Duration(seconds: 5));

  await Nostr.instance.services.relays.reconnectToRelays(
    connectionTimeout: const Duration(seconds: 5),
    ignoreConnectionException: true,
    lazyListeningToRelays: false,
    onRelayConnectionDone: (relayUrl, relayWebSocket) {
      print('Connected to relay: $relayUrl');
    },
    onRelayListening: (relayUrl, receivedEvent, relayWebSocket) {
      print('Listening to relay: $relayUrl');
    },
    onRelayConnectionError: (relayUrl, error, relayWebSocket) {},
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
  );

  await Future.delayed(const Duration(seconds: 5));

  await Nostr.instance.services.relays.disconnectFromRelays(
    closeCode: (relayUrl) {
      return 1000;
    },
    closeReason: (relayUrl) {
      return 'Bye';
    },
    onRelayDisconnect: (relayUrl, relayWebSocket, returnedMessage) {
      print('Disconnected from relay: $relayUrl, $returnedMessage');
    },
  );
}
