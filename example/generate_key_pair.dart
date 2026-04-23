import 'package:dart_nostr/dart_nostr.dart';

import '_example_shared.dart';

/// Generate and validate Nostr key pairs.
/// Demonstrates key generation, validation, and reconstruction.
void main() {
  print(divider('🔑 Key Generation Example'));

  final nostr = exampleNostr();

  // Generate a new key pair
  final keyPair = nostr.keys.generateKeyPair();
  print('✅ Generated new key pair:');
  print('   Public Key:  ${keyPair.public.substring(0, 32)}...');
  print('   Private Key: ${keyPair.private.substring(0, 32)}...');

  // Validate the private key
  final isValid = NostrKeyPairs.isValidPrivateKey(keyPair.private);
  print('\n✅ Private key is valid: $isValid');

  // Reconstruct key pair from private key
  final reconstructed = nostr.keys.generateKeyPairFromExistingPrivateKey(
    keyPair.private,
  );
  print('✅ Reconstructed key pair matches: ${reconstructed == keyPair}');

  // Derive public key from private key
  final publicKey = nostr.keys.derivePublicKey(privateKey: keyPair.private);
  print('✅ Derived public key matches: ${publicKey == keyPair.public}');

  print('\n${divider()}');
  print('✅ Key generation example completed!');
}
