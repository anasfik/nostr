import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();
  final keyPair = nostr.keys.generateKeyPair();
  final reconstructed = nostr.keys.generateKeyPairFromExistingPrivateKey(
    keyPair.private,
  );
  final publicKey = nostr.keys.derivePublicKey(privateKey: keyPair.private);

  print(divider('generated key pair'));
  print('public : ${keyPair.public}');
  print('private: ${keyPair.private}');
  print('reconstructed matches: ${reconstructed == keyPair}');
  print('derived public matches: ${publicKey == keyPair.public}');
}
