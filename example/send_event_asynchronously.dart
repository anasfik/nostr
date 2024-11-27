import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';

Future<void> main(List<String> args) async {
  await Nostr.instance.services.relays.init(
    relaysUrl: [
      'wss://relay.damus.io',
    ],
  );

  final keyPair = Nostr.instance.services.keys.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello World! from dart_nostr package',
    keyPairs: keyPair,
  );

  try {
    final okCOmmand =
        await Nostr.instance.services.relays.sendEventToRelaysAsync(
      event,
      timeout: const Duration(seconds: 10),
    );

    print(okCOmmand.isEventAccepted);
  } on TimeoutException {
    print('Timeout');
  } catch (e) {
    print(e);
  }
}
