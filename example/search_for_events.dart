import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final instance = Nostr();

  // init relays
  await instance.relaysService.init(
    relaysUrl: [
      'wss://relay.noswhere.com',
    ],
  );

  final req = NostrRequest(
    filters: const [
      NostrFilter(
        kinds: [1],
        limit: 10,
        search: 'football',
      )
    ],
  );

  final events = await instance.relaysService.startEventsSubscriptionAsync(
    request: req,
    timeout: const Duration(seconds: 10),
  );

  print(events.map((e) => e.content));

  final isClosed = await instance.relaysService.freeAllResources();
  print('isClosed: $isClosed');
}
