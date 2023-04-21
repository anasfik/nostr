import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  final relayDocument =
      await Nostr.instance.relaysService.relayInformationsDocumentNip11(
    relayUrl: "wss://relay.damus.io",
  );

  print(relayDocument.software);
}
