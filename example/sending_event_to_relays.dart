import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // This method will enable the logs of the library.
  Nostr.instance.enableLogs();

  // initialize the relays service.
  await Nostr.instance.relaysService.init(
    relaysUrl: <String>["wss://relay.damus.io"],
  );

  // generate a key pair.
  final keyPair = Nostr.instance.keysService.generateKeyPair();

  Nostr.instance.relaysService.sendEventToRelays(
    NostrEvent.fromPartialData(
      kind: 0,
      content: "test ",
      keyPairs: keyPair,
    ),
  );

// ! check logs and run this code.
}
