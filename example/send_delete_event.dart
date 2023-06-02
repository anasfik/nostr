import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // Create a new user key pair
  final newKeyPair = Nostr.instance.keysService.generateKeyPair();

  // set our relays list.
  final relays = <String>["wss://relay.damus.io"];

  // init relays service with our relays list.
  await Nostr.instance.relaysService.init(relaysUrl: relays);

  // create a delete event
  final deleteEvent = NostrEvent.deleteEvent(
    reasonOfDeletion:
        "As example, the user decided to delete his created note events.",
    keyPairs: newKeyPair,
    eventIdsToBeDeleted: [
      // this is just an example event id.
      Nostr.instance.utilsService.random64HexChars(),
    ],
  );

  // send the delete event
  Nostr.instance.relaysService.sendEventToRelays(deleteEvent);
}
