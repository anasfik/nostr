import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr(enableLogs: true);

  await nostr.relays.init(
    relaysUrl: exampleRelays,
    retryOnClose: true,
    retryOnError: true,
    shouldReconnectToRelayOnNotice: true,
  );

  for (var i = 0; i < 5; i++) {
    final request = NostrRequest(
      filters: <NostrFilter>[
        NostrFilter(
          t: const ['nostr'],
          kinds: const [1],
          limit: 10,
          since: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    );

    final stream = nostr.relays.startEventsSubscription(request: request);
    print('Started subscription #$i -> ${stream.subscriptionId}');
  }
}
