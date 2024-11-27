import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  // This method will enable the logs of the library.
  Nostr.instance.enableLogs();

  // generates a key pair.
  final keyPair = Nostr.instance.services.keys.generateKeyPair();

  // init relays
  await Nostr.instance.services.relays.init(
    relaysUrl: ['wss://relay.damus.io'],
  );

  final currentDateInMsAsString =
      DateTime.now().millisecondsSinceEpoch.toString();

  // create an event
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'content',
    keyPairs: keyPair,
    tags: [
      ['t', currentDateInMsAsString],
      ['title', "ps5"],
    ],
  );

  final asMap = event.toMap();
  print(asMap);

  // send the event
  Nostr.instance.services.relays.sendEventToRelays(event);

  await Future.delayed(const Duration(seconds: 5));

  // create a subscription id.
  final subscriptionId = Nostr.instance.services.utils.random64HexChars();

  // creating a request for listening to events.
  final request = NostrRequest(
    subscriptionId: subscriptionId,
    filters: [
      NostrFilter(
        kinds: const [1],
        t: [currentDateInMsAsString],
        authors: [keyPair.public],
      ),
    ],
  );

// listen to events
  final sub = Nostr.instance.services.relays.startEventsSubscription(
    request: request,
    onEose: (relay, eose) {
      print('eose $eose from $relay');
    },
  );

  final StreamSubscription subscritpion = sub.stream.listen(
    print,
    onDone: () {
      print('done');
    },
  );

  await Future.delayed(const Duration(seconds: 5));

  // cancel the subscription
  await subscritpion.cancel().whenComplete(() {
    Nostr.instance.services.relays.closeEventsSubscription(subscriptionId);
  });

  await Future.delayed(const Duration(seconds: 5));

  // create a new event that will not be received by the subscription because it is closed.
  final event2 = NostrEvent.fromPartialData(
    kind: 1,
    content: 'example content',
    keyPairs: keyPair,
    tags: [
      ['t', currentDateInMsAsString],
    ],
  );

  // send the event 2 that will not be received by the subscription because it is closed.
  Nostr.instance.services.relays.sendEventToRelays(
    event2,
    onOk: (relay, ok) {
      print('ok $ok from $relay');
    },
  );
}
