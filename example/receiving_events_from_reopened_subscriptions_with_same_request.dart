import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  final relays = [
    'wss://nos.lol',
  ];

  await Nostr.instance.services.relays.init(relaysUrl: relays);

  final newKeyPair = Nostr.instance.services.keys.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    content: newKeyPair.public,
    kind: 1,
    keyPairs: newKeyPair,
    tags: [
      ['t', newKeyPair.public],
    ],
  );

  Nostr.instance.services.relays.sendEventToRelays(
    event,
    onOk: (relay, ok) {
      print('from relay: $relay');
      print('event sent, ${ok.eventId}');
    },
  );

  await Future.delayed(const Duration(seconds: 5));

  // ...

  final filter = NostrFilter(
    kinds: const [1],
    t: [newKeyPair.public],
  );

  final req = NostrRequest(filters: [filter]);

  final sub = Nostr.instance.services.relays.startEventsSubscription(
    request: req,
    onEose: (relay, eose) {
      Nostr.instance.services.relays
          .closeEventsSubscription(eose.subscriptionId);
    },
  );

  sub.stream.listen((event) {
    print(event.content);
  });

  await Future.delayed(const Duration(seconds: 5));

  for (var index = 0; index < 50; index++) {
    Nostr.instance.services.relays.startEventsSubscription(
      request: req,
    );
  }

  await Future.delayed(const Duration(seconds: 5));

  Nostr.instance.services.relays.startEventsSubscription(
    request: req,
  );

  await Future.delayed(const Duration(seconds: 5));

  final anotherEvent = NostrEvent.fromPartialData(
    kind: 1,
    content: 'another event with different content, but matches same filter',
    keyPairs: newKeyPair,
    tags: [
      ['t', newKeyPair.public],
    ],
  );

  Nostr.instance.services.relays.sendEventToRelays(
    anotherEvent,
    onOk: (relay, ok) {
      print('event sent, ${ok.eventId}');
    },
  );
}
