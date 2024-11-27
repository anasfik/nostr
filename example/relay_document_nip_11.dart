import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  final relayDocument =
      await Nostr.instance.services.relays.relayInformationsDocumentNip11(
    relayUrl: 'wss://relay.damus.io',
  );

  print(relayDocument?.name);
}
