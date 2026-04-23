import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

Future<void> main() async {
  final nostr = exampleNostr();
  await nostr.relays.init(relaysUrl: exampleRelays);
  final keyPair = nostr.keys.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 0,
    content: jsonEncode(
      {
        'name': 'Gwhyyy (dart_nostr)',
      },
    ),
    keyPairs: keyPair,
  );

  try {
    final okCommand = await nostr.relays.sendEventToRelaysAsync(
      event,
      timeout: const Duration(seconds: 3),
    );

    if (!(okCommand.isEventAccepted ?? true)) {
      print('not accepted');
      return;
    }

    final request = NostrRequest(
      filters: [
        NostrFilter(
          limit: 10,
          kinds: const [0],
          authors: [keyPair.public],
        ),
      ],
    );

    final events = await nostr.relays.startEventsSubscriptionAsync(
      request: request,
      timeout: const Duration(seconds: 10),
    );

    for (final element in events) {
      print('${element.content}\n\n');
    }

    await nostr.relays.freeAllResources();
  } catch (error) {
    print(error);
  }
}
