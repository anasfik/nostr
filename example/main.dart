import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = await connectedExampleNostr(enableLogs: true);
  final keyPair = nostr.keys.generateKeyPair();

  final currentDateInMsAsString =
      DateTime.now().millisecondsSinceEpoch.toString();

  // create an event
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'content',
    keyPairs: keyPair,
    tags: [
      ['t', currentDateInMsAsString],
      ['title', 'ps5'],
    ],
  );

  final asMap = event.toMap();
  print(asMap);

  final publishResult = await nostr.publish(event);
  publishResult.fold(
    (ok) => print('publish accepted: ${ok.isEventAccepted}'),
    (failure) => print('publish failed: $failure'),
  );

  await Future<void>.delayed(const Duration(seconds: 5));

  final request = NostrRequest(
    filters: [
      NostrFilter(
        kinds: const [1],
        t: [currentDateInMsAsString],
        authors: [keyPair.public],
      ),
    ],
  );

  final subscribeResult = nostr.subscribeRequest(request);
  final sub = subscribeResult.valueOrNull;

  final StreamSubscription<NostrEvent>? subscription = sub?.stream.listen(
    (receivedEvent) => print('received event: ${receivedEvent.content}'),
  );

  await Future<void>.delayed(const Duration(seconds: 5));

  await subscription?.cancel();
  sub?.close();

  await Future<void>.delayed(const Duration(seconds: 5));

  final event2 = NostrEvent.fromPartialData(
    kind: 1,
    content: 'example content',
    keyPairs: keyPair,
    tags: [
      ['t', currentDateInMsAsString],
    ],
  );

  await nostr.publish(event2);
}
