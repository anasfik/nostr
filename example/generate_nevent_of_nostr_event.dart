import 'package:dart_nostr/nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/event.dart';

void main() {
  final newKeyPair = Nostr.instance.keysService.generateKeyPair();

  print("pubKey: ${newKeyPair.public}");

  final relays = ["wss://relay.damus.io"];

  final nostrEvent = NostrEvent.fromPartialData(
    kind: 1,
    content: "THIS IS EXAMPLE OF NOSTR EVENT CONTENT",
    keyPairs: newKeyPair,
  );

  print("event id: ${nostrEvent.id}");

  final encodedNEvent = Nostr.instance.utilsService.encodeNevent(
    eventId: nostrEvent.id,
    userRelays: relays,
    pubkey: newKeyPair.public,
  );

  print("encodedNEvent: $encodedNEvent");

  final decodedEvent =
      Nostr.instance.utilsService.decodeNeventToMap(encodedNEvent);

  print("decodedEvent: $decodedEvent");
}
