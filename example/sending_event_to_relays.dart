import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr(enableLogs: true);

  print(divider('publish'));

  final connectResult = await nostr.connect(exampleRelays);
  if (connectResult.isFailure) {
    print('connection failed');
    return;
  }

  final keyPair = nostr.keys.generateKeyPair();

  // metadata event (kind 0)
  final metadataEvent = NostrEvent.fromPartialData(
    kind: 0,
    content: jsonEncode({
      'name': 'dart_nostr user',
      'about': 'nostr sdk example',
    }),
    keyPairs: keyPair,
  );

  final metadataResult = await nostr.publish(metadataEvent);
  metadataResult.fold(
    (ok) {
      print('metadata event id: ${ok.eventId}');
      print('metadata accepted: ${ok.isEventAccepted}');
    },
    (failure) => print('metadata failed: ${failure.message}'),
  );

  // text note (kind 1)
  final noteEvent = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello from dart_nostr ${DateTime.now()}',
    keyPairs: keyPair,
    tags: [
      ['t', 'nostr'],
      ['t', 'dart'],
    ],
  );

  final noteResult = await nostr.publish(noteEvent);
  noteResult.fold(
    (ok) {
      print('note event id: ${ok.eventId}');
      print('note accepted: ${ok.isEventAccepted}');
    },
    (failure) => print('note failed: ${failure.message}'),
  );

  await nostr.disconnect();
}
