import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = await connectedExampleNostr();

  final filter = NostrFilter(
    kinds: [0],
    since: DateTime.now().subtract(Duration(days: 2)),
  );

  final result = await nostr.count(
    NostrCountEvent.fromPartialData(eventsFilter: filter),
  );

  result.fold(
    (countResponse) =>
        print('new users in past 2 days: ${countResponse.count}'),
    (failure) => print('count failed: $failure'),
  );
}
