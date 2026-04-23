import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = await connectedExampleNostr(enableLogs: true);

  final request = NostrRequest(
    filters: const <NostrFilter>[
      NostrFilter(
        kinds: [1],
        t: ['nostr'],
        limit: 2,
      ),
    ],
  );

  final result = nostr.subscribeRequest(request);

  result.fold(
    (stream) {
      stream.stream.listen((event) {
        print(jsonEncode(event.toMap()));
      });
    },
    (failure) => print('subscription failed: $failure'),
  );
}
