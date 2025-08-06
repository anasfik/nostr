import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // // I did disabled logs here so we can see the output of the example exclusively.
  Nostr.instance.disableLogs();

  // We initialize the Nostr Relays Service with relays.
  await Nostr.instance.services.relays.init(
    relaysUrl: <String>[
      'wss://relay.nostr.band/all',
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
        limit: 100,
      ),
    ],
  );

  // Now we create the stream of that request.
  // ignore: unused_local_variable
  final requestStream =
      Nostr.instance.services.relays.startEventsSubscriptionWithoutAutoHandling(
    request: request,
    includeRequestEntity: true,
  );

  // We listen to the stream and print the events.
  requestStream.stream.listen((data) {
    print(
      data.substring(
        0,
        data.indexOf(request.subscriptionId!) + request.subscriptionId!.length,
      ),
    );
  });
}
