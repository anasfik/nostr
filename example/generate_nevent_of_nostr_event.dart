import 'package:dart_nostr/nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';

void main() {
  final newKeyPair = Nostr.instance.services.keys.generateKeyPair();

  print('pubKey: ${newKeyPair.public}');

  final relays = ['wss://relay.damus.io'];

  final nostrEvent = NostrEvent.fromPartialData(
    kind: 1,
    content: 'THIS IS EXAMPLE OF NOSTR EVENT CONTENT',
    keyPairs: newKeyPair,
  );

  print('event id: ${nostrEvent.id}');

  if (nostrEvent.id == null) {
    throw Exception('event id cannot be null');
  }

  final encodedNEvent = Nostr.instance.services.bech32.encodeNevent(
    eventId: nostrEvent.id!,
    userRelays: relays,
    pubkey: newKeyPair.public,
  );

  print('encodedNEvent: $encodedNEvent');

  final decodedEvent =
      Nostr.instance.services.bech32.decodeNeventToMap(encodedNEvent);

  print('decodedEvent: $decodedEvent');
}
