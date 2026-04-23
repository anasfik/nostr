import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr();

  await nostr.relays.init(
    relaysUrl: exampleRelays,
    onRelayConnectionError: (relay, error, _) {
      print('raw stream error from $relay: $error');
    },
  );

  final request = NostrRequest(
    filters: const <NostrFilter>[
      NostrFilter(kinds: [1], limit: 5),
    ],
  );

  final stream = nostr.relays.startEventsSubscriptionWithoutAutoHandling(
    request: request,
    includeRequestEntity: true,
  );

  stream.stream.listen((data) {
    print('raw entity: $data');
  });
}
