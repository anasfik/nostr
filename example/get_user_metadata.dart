import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = await connectedExampleNostr();
  const publicKey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  final result = nostr.subscribeRequest(
    NostrRequest(
      filters: const <NostrFilter>[
        NostrFilter(
          kinds: [0],
          authors: [publicKey],
          limit: 3,
        ),
      ],
    ),
  );

  result.fold(
    (stream) {
      stream.stream.listen((event) {
        print('metadata event: ${event.content}');
      });
    },
    (failure) => print('metadata lookup failed: $failure'),
  );
}
