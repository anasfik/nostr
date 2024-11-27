import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // Waiting first for the connection to be established for all relays.

  await Nostr.instance.services.relays.init(
    relaysUrl: <String>[
      'wss://relay.damus.io',
      'wss://eden.nostr.land',
    ],
    shouldReconnectToRelayOnNotice: true,
  );

  // sending n different requests to the relays.
  for (var i = 0; i < 50; i++) {
    // Creating the request that we will listen with to events.

    final req = NostrRequest(
      filters: <NostrFilter>[
        NostrFilter(
          t: const ['nostr'],
          kinds: const [0],
          since: DateTime.now().subtract(const Duration(days: 10)),
        ),
      ],
    );

    print('Starting subscription $i');
    Nostr.instance.services.relays.startEventsSubscription(request: req);
  }
}
