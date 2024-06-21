import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // This method will enable the logs of the library.
  Nostr.instance.enableLogs();
  final relaysList = [
    'wss://relay.nostr.band/all',
  ];

  // initialize the relays service.
  await Nostr.instance.relaysService.init(
    relaysUrl: relaysList,
    onRelayConnectionError: (relay, err, websocket) {
      print('relay connection error: $err');
    },
  );

  // generate a key pair.
  final keyPair = Nostr.instance.keysService.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 0,
    content: 'test ',
    keyPairs: keyPair,
  );

  Nostr.instance.relaysService.sendEventToRelays(
    event,
    relays: [
      ...relaysList,
      'wss://relay.damus.io',
    ],
    onOk: (relay, ok) {
      print(relay);
      print(ok.eventId);
      print(ok.isEventAccepted);
      print(ok.message);
      print('\n');
    },
  );

  Nostr.instance.relaysService.sendEventToRelays(
    event,
    relays: [
      ...relaysList,
    ],
    onOk: (relay, ok) {
      print("second only");
    },
  );

// ! check logs and run this code.
}
