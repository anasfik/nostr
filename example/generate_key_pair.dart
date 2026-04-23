import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

void main() {
  final nostr = exampleNostr();

  print(divider('key generation'));

  final keyPair = nostr.keys.generateKeyPair();
  print('public : ${keyPair.public.substring(0, 32)}...');
  print('private: ${keyPair.private.substring(0, 32)}...');

  final isValid = NostrKeyPairs.isValidPrivateKey(keyPair.private);
  print('valid  : $isValid');

  final reconstructed = nostr.keys.generateKeyPairFromExistingPrivateKey(
    keyPair.private,
  );
  print('reconstructed matches: ${reconstructed == keyPair}');

  final publicKey = nostr.keys.derivePublicKey(privateKey: keyPair.private);
  print('derived public matches: ${publicKey == keyPair.public}');
}
