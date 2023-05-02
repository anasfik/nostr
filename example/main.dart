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

  // creating a request for listening to events.
  NostrRequest request = NostrRequest(
    filters: [
      NostrFilter(
        kinds: [1],
        t: [currentDateInMsAsString],
        authors: [keyPair.public],
      ),
    ],
  );

// listen to events
  final sub =
      Nostr.instance.relaysService.startEventsSubscription(request: request);
  StreamSubscription sub2 = Stream.empty().listen((event) {
    print(event);
  });
}
