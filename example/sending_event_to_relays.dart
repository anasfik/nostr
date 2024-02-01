import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // This method will enable the logs of the library.
  Nostr.instance.enableLogs();

  // initialize the relays service.
  await Nostr.instance.relaysService.init(
    relaysUrl: <String>[
      'wss://relay.damus.io',
      'wss://relay.nostrss.re',
    ],
    onRelayConnectionError: (relay, err, websocket) {
      print('relay connection error: $err');
    },
    ignoreConnectionException: true,
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
    onOk: (relay, ok) {
      print(relay);
      print(ok.eventId);
      print(ok.isEventAccepted);
      print(ok.message);
      print("\n");
    },
  );

// ! check logs and run this code.
}
