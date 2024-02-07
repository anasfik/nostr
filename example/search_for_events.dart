import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final instance = Nostr()..disableLogs();

  // init relays
  await instance.relaysService.init(
    relaysUrl: [
      'wss://relay.nostr.band/all',
    ],
  );

  final req = NostrRequest(
    filters: const [
      NostrFilter(
        limit: 500,
        kinds: [10004],
      ),
      NostrFilter(
        kinds: [3],
        limit: 100,
      ),
    ],
  );

  final sub = instance.relaysService.startEventsSubscription(
    request: req,
  );

  sub.stream.listen((event) {
    print(event.tags);
  });
}
