import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();
  final keyPair = nostr.keys.generateKeyPair();
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Enterprise-grade Nostr event example',
    keyPairs: keyPair,
  );

  final encoded = nostr.bech32.encodeNevent(
    eventId: event.id!,
    pubkey: keyPair.public,
    userRelays: exampleRelays,
  );

  print(divider('nevent'));
  print('event id : ${event.id}');
  print('encoded  : $encoded');
  print('decoded  : ${nostr.bech32.decodeNeventToMap(encoded)}');
}
