import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';

void main() async {
  // This method will enable the logs of the library.
  Nostr.instance.enableLogs();

  // initialize the relays service.
  await Nostr.instance.relaysService.init(
    relaysUrl: <String>["wss://relay.damus.io"],
  );

  // generate a key pair.
  final keyPair = Nostr.instance.keysService.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 0,
    content: "test ",
    keyPairs: keyPair,
  );

  Nostr.instance.relaysService.sendEventToRelays(
    event,
    onOk: (ok) {
      print(ok.eventId);
      print(ok.isEventAccepted);
      print(ok.message);
    },
  );

// ! check logs and run this code.
}
