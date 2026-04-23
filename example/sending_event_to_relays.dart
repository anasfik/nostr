import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr(enableLogs: true);
  await nostr.relays.init(
    relaysUrl: exampleRelays,
    onRelayConnectionError: (relay, error, _) {
      print('relay connection error from $relay: $error');
    },
  );

  final keyPair = nostr.keys.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 0,
    content: 'example metadata payload',
    keyPairs: keyPair,
  );

  await nostr.relays.sendEventToRelays(
    event,
    relays: exampleRelays,
    onOk: (relay, ok) {
      print('relay: $relay');
      print('event id: ${ok.eventId}');
      print('accepted: ${ok.isEventAccepted}');
      print('message: ${ok.message}\n');
    },
  );
}
