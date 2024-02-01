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
          kinds: [30402], limit: 100, t: ['tribly_exclusive'], search: 'gu',),
    ],
  );

  final sub = instance.relaysService.startEventsSubscription(
    request: req,
  );

  sub.stream.listen((event) {
    print(event.content);
  });
}
