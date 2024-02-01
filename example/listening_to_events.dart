import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // // I did disabled logs here so we can see the output of the example exclusively.
  Nostr.instance.disableLogs();

  // We initialize the Nostr Relays Service with relays.
  await Nostr.instance.relaysService.init(
    relaysUrl: <String>[
      'wss://relay.damus.io',
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
        kinds: [1],
        limit: 20,
      ),
    ],
  );

  // Now we create the stream of that request.
  // ignore: unused_local_variable
  final requestStream = Nostr.instance.relaysService.startEventsSubscription(
    request: request,
    onEose: (relay, ease) {
      print('ease received for subscription id: ${ease.subscriptionId}');

      Nostr.instance.relaysService.closeEventsSubscription(
        ease.subscriptionId,
      );
    },
  );

  // We listen to the stream and print the events.
  requestStream.stream.listen((event) {
    print('-------------------');
    print(event.content);
  });
}
