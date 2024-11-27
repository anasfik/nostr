import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPair = Nostr.instance.services.keys.generateKeyPair();

  final existentKeyPair = Nostr.instance.services.keys
      .generateKeyPairFromExistingPrivateKey(keyPair.private);

  print(existentKeyPair.private);
}
