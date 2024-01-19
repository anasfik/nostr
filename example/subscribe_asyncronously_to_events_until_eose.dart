import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

void main(List<String> args) async {
  Nostr.instance.disableLogs();

  await Nostr.instance.relaysService.init(
    relaysUrl: [
      'wss://relay.damus.io',
    ],
  );
  final keyPair = Nostr.instance.keysService.generateKeyPair();

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
    final countEvent = NostrCountEvent.fromPartialData(
      eventsFilter: NostrFilter(
        kinds: const [0],
        authors: [keyPair.public],
      ),
    );

    final okCommand = await Nostr.instance.relaysService.sendEventToRelaysAsync(
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

    final events =
        await Nostr.instance.relaysService.startEventsSubscriptionAsync(
      request: request,
      timeout: const Duration(seconds: 10),
    );

    for (final element in events) {
      // should our event content here
      print('${element.content}\n\n');
    }

    final isFree = await Nostr.instance.relaysService.freeAllResources();
    print('isFree: $isFree');
  } catch (e) {
    print(e);
  }
}
