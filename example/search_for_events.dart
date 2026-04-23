import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr();

  await nostr.services.relays.init(
    relaysUrl: exampleRelays,
    onNoticeMessageFromRelay: (relay, _, notice) {
      print('[$relay] notice: ${notice.message}');
    },
  );

  final request = NostrRequest(
    filters: const [
      NostrFilter(
        search: 'nostr',
        kinds: [1],
      ),
    ],
  );

  final stream = nostr.services.relays.startEventsSubscription(
    request: request,
  );

  stream.stream.listen((event) => print(event.toString()));
}
