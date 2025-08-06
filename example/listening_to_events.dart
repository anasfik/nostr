import 'dart:convert';
import 'dart:math';

import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // // I did disabled logs here so we can see the output of the example exclusively.
  Nostr.instance.enableLogs();

  // We initialize the Nostr Relays Service with relays.
  await Nostr.instance.services.relays.init(
    relaysUrl: <String>[
      'wss://testing.gathr.gives',
      // 'wss://relay.nostr.band/all',
    ],
    onRelayConnectionError: (relay, error, webSocket) {
      print('Relay error: $error');
    },
    onRelayConnectionDone: (relayUrl, webSocket) =>
        print('Relay done: $relayUrl'),
  );

  final request = NostrRequest(
    filters: const <NostrFilter>[
      NostrFilter(
        kinds: [1985],
        t: ["gathr.organization.project.cancel"],
        limit: 2,
      ),
    ],
  );

  // Now we create the stream of that request.
  // ignore: unused_local_variable
  final requestStream = Nostr.instance.services.relays.startEventsSubscription(
    request: request,
    onEose: (relay, ease) {
      print('ease received for subscription id: ${ease.subscriptionId}');

      Nostr.instance.services.relays.closeEventsSubscription(
        ease.subscriptionId,
      );
    },
  );

  // We listen to the stream and print the events.
  requestStream.stream.listen((event) {
    print(jsonEncode(event.toMap()));

    if (event.tags == null) {
      print('tags are null');

      return;
    }

    if (event.tags?.isEmpty ?? true) {
      print('tags are empty');

      return;
    }

    for (final a in event.tags!) {
      if (a.first == 'a') {
        print(a);
      }
    }
  });
}
