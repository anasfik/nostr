import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  // This method will enable the logs of the library.
  Nostr.instance.enableLogs();

  // generates a key pair.
  final keyPair = Nostr.instance.keysService.generateKeyPair();

  // init relays
  await Nostr.instance.relaysService.init(
    relaysUrl: ["wss://relay.damus.io"],
  );

  final currentDateInMsAsString =
      DateTime.now().millisecondsSinceEpoch.toString();

  // create an event
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: "example content",
    keyPairs: keyPair,
    tags: [
      ["t", currentDateInMsAsString],
    ],
  );

  // send the event
  Nostr.instance.relaysService.sendEventToRelays(event);

  await Future.delayed(Duration(seconds: 5));

  // create a subscription id.
  final subscriptionId = Nostr.instance.utilsService.random64HexChars();

  // creating a request for listening to events.
  final request = NostrRequest(
    subscriptionId: subscriptionId,
    filters: [
      NostrFilter(
        kinds: [1],
        t: [currentDateInMsAsString],
        authors: [keyPair.public],
      ),
    ],
  );

// listen to events
  final sub = Nostr.instance.relaysService.startEventsSubscription(
    request: request,
    onEose: (ease) => print(ease),
  );

  StreamSubscription subscritpion = sub.stream.listen(
    (event) {
      print(event);
    },
    onDone: () {
      print("done");
    },
  );

  await Future.delayed(Duration(seconds: 5));

  // cancel the subscription
  subscritpion.cancel().whenComplete(() {
    Nostr.instance.relaysService.closeEventsSubscription(subscriptionId);
  });

  await Future.delayed(Duration(seconds: 5));

  // create a new event that will not be received by the subscription because it is closed.
  final event2 = NostrEvent.fromPartialData(
    kind: 1,
    content: "example content",
    keyPairs: keyPair,
    tags: [
      ["t", currentDateInMsAsString],
    ],
  );

  // send the event 2 that will not be received by the subscription because it is closed.
  Nostr.instance.relaysService.sendEventToRelays(
    event2,
    onOk: (ok) => print(ok),
  );
}
