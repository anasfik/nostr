import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = await connectedExampleNostr(relays: const ['wss://nos.lol']);
  final keyPair = nostr.keys.generateKeyPair();

  final request = NostrRequest(
    filters: [
      NostrFilter(
        kinds: const [1],
        t: [keyPair.public],
      ),
    ],
  );

  final first = nostr.relays.startEventsSubscription(
    request: request,
    onEose: (_, eose) =>
        nostr.relays.closeEventsSubscription(eose.subscriptionId),
  );

  first.stream.listen((event) => print('first subscription: ${event.content}'));
  await Future<void>.delayed(const Duration(seconds: 2));
  first.close();

  final reopened = nostr.relays.startEventsSubscription(
    request: request,
    useConsistentSubscriptionIdBasedOnRequestData: true,
  );

  reopened.stream.listen((event) {
    print('reopened subscription: ${event.content}');
  });

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'event received by reopened request',
    keyPairs: keyPair,
    tags: [
      ['t', keyPair.public],
    ],
  );

  await nostr.publish(event);
}
