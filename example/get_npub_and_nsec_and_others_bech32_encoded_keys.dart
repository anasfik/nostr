import '_example_shared.dart';

/// Get Bech32-encoded keys (Npub, Nsec).
/// Demonstrates Bech32 encoding/decoding with verification.
void main() {
  print(divider('🔐 Bech32 Encoded Keys Example'));

  final nostr = exampleNostr();
  
  // Generate a key pair
  final keyPair = nostr.keys.generateKeyPair();
  print('✅ Generated key pair');

  // Encode to Bech32 format
  final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
  final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPair.private);

  print('\n📍 Bech32 Encoded:');
  print('   Npub: $npub');
  print('   Nsec: $nsec');

  // Decode and verify round-trip
  final decodedPublicKey = nostr.bech32.decodeNpubKeyToPublicKey(npub);
  final decodedPrivateKey = nostr.bech32.decodeNsecKeyToPrivateKey(nsec);

  print('\n✅ Round-trip Verification:');
  print('   Public key matches: ${decodedPublicKey == keyPair.public}');
  print('   Private key matches: ${decodedPrivateKey == keyPair.private}');

  print('\n${divider()}');
  print('✅ Bech32 encoding example completed!');
}
