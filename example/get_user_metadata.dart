import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  await Nostr.instance.services.relays.init(
    relaysUrl: ['wss://relay.damus.io'],
  );

  final request = NostrRequest(
    filters: const <NostrFilter>[
      NostrFilter(
        kinds: [0],
        limit: 10,
        search: 'something Idk',
      ),
    ],
  );

  final requestStream = Nostr.instance.services.relays.startEventsSubscription(
    request: request,
    relays: ['wss://relay.nostr.band/all'],
    onEose: (relay, ease) {
      print('ease received for subscription id: ${ease.subscriptionId}');

      Nostr.instance.services.relays.closeEventsSubscription(
        ease.subscriptionId,
      );
    },
  );

  requestStream.stream.listen((event) {
    print(event);
  });
}
