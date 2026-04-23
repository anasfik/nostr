import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = await connectedExampleNostr();
  final keyPair = nostr.keys.generateKeyPair();

  final deleteEvent = NostrEvent.deleteEvent(
    keyPairs: keyPair,
    reasonOfDeletion: 'Example deletion request',
    eventIdsToBeDeleted: [NostrCryptoUtils.randomHex()],
  );

  final result = await nostr.publish(deleteEvent);
  result.fold(
    (ok) => print('delete event accepted: ${ok.isEventAccepted}'),
    (failure) => print('delete event failed: $failure'),
  );
}
