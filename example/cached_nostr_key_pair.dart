import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPair = Nostr.instance.keysService.generateKeyPair();

  final existentKeyPair = Nostr.instance.keysService
      .generateKeyPairFromExistingPrivateKey(keyPair.private);

  print(existentKeyPair.private);
}
