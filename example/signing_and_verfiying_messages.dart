import '_example_shared.dart';

/// Sign and verify messages using Nostr keys.
/// Demonstrates message signing and verification with cryptographic proof.
void main() {
  print(divider('🔐 Message Signing & Verification Example'));

  final nostr = exampleNostr();

  // Generate a key pair
  final keyPair = nostr.keys.generateKeyPair();
  print('✅ Generated key pair for signing');

  // Define the message to sign
  const message = 'Hello Nostr! This is a signed message.';
  print('\n📝 Message: "$message"');

  // Sign the message with the private key
  final signature = nostr.keys.sign(
    privateKey: keyPair.private,
    message: message,
  );
  print('\n✍️ Signature: ${signature.substring(0, 32)}...');

  // Verify the signature with the public key
  final isVerified = nostr.keys.verify(
    publicKey: keyPair.public,
    message: message,
    signature: signature,
  );
  print('✅ Verification result: $isVerified');

  // Try to verify with wrong message (should fail)
  final isVerifiedWrong = nostr.keys.verify(
    publicKey: keyPair.public,
    message: 'Different message',
    signature: signature,
  );
  print('❌ Verification with wrong message: $isVerifiedWrong');

  print('\n${divider()}');
  print('✅ Message signing example completed!');
}
