import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  await Nostr.instance.relaysService.init(
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

  final requestStream = Nostr.instance.relaysService.startEventsSubscription(
    request: request,
    relays: ['wss://relay.nostr.band/all'],
    onEose: (relay, ease) {
      print('ease received for subscription id: ${ease.subscriptionId}');

      Nostr.instance.relaysService.closeEventsSubscription(
        ease.subscriptionId,
      );
    },
  );

  requestStream.stream.listen((event) {
    print(event);
  });
}
