import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr(enableLogs: true);

  await nostr.relays.init(
    relaysUrl: exampleRelays,
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
    onRelayListening: (relayUrl, _, __) => print('listening: $relayUrl'),
    onRelayConnectionDone: (relayUrl, _) => print('done: $relayUrl'),
    onRelayConnectionError: (relayUrl, error, _) {
      print('error from $relayUrl: $error');
    },
  );

  print('connected relays: ${nostr.relays.relaysList}');

  await nostr.relays.reconnectToRelays(
    connectionTimeout: const Duration(seconds: 5),
    ignoreConnectionException: true,
    lazyListeningToRelays: false,
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
    onRelayListening: (relayUrl, _, __) => print('re-listening: $relayUrl'),
    onRelayConnectionDone: (relayUrl, _) => print('re-done: $relayUrl'),
    onRelayConnectionError: (relayUrl, error, _) {
      print('reconnect error from $relayUrl: $error');
    },
  );

  await nostr.relays.disconnectFromRelays(
    closeCode: (_) => 1000,
    closeReason: (_) => 'Example complete',
    onRelayDisconnect: (relayUrl, _, returnedMessage) {
      print('disconnected from $relayUrl -> $returnedMessage');
    },
  );
}
