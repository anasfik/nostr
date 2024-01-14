import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  final relays = [
    'wss://nos.lol',
  ];

  await Nostr.instance.relaysService.init(relaysUrl: relays);

  final newKeyPair = Nostr.instance.keysService.generateKeyPair();

  final event = NostrEvent.fromPartialData(
      content: newKeyPair.public,
      kind: 1,
      keyPairs: newKeyPair,
      tags: [
        ['t', newKeyPair.public],
      ],);

  Nostr.instance.relaysService.sendEventToRelays(event, onOk: (ok) {
    print('event sent, ${ok.eventId}');
  },);

  await Future.delayed(const Duration(seconds: 5));

// ...

  final filter = NostrFilter(
    kinds: const [1],
    t: [newKeyPair.public],
  );

  final req = NostrRequest(filters: [filter]);

  final sub = Nostr.instance.relaysService.startEventsSubscription(
    request: req,
    onEose: (eose) {
      Nostr.instance.relaysService.closeEventsSubscription(eose.subscriptionId);
    },
  );

  sub.stream.listen((event) {
    print(event.content);
  });

  await Future.delayed(const Duration(seconds: 5));

  for (var index = 0; index < 50; index++) {
    Nostr.instance.relaysService.startEventsSubscription(
      request: req,
    );
  }

  await Future.delayed(const Duration(seconds: 5));

  Nostr.instance.relaysService.startEventsSubscription(
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

  Nostr.instance.relaysService.sendEventToRelays(anotherEvent, onOk: (ok) {
    print('event sent, ${ok.eventId}');
  },);
}
