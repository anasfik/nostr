---
sidebar_position: 2
description: Generate a new key pair or derive one from an existing private key.
---

# Generate Key Pairs

## Generate a new key pair

```dart
final nostr = Nostr.instance;
final keyPair = nostr.keys.generateKeyPair();

print(keyPair.public);   // hex public key
print(keyPair.private);  // hex private key
```

## Generate only a private key

If you want to store the private key before creating the full key pair:

```dart
final privateKey = nostr.keys.generatePrivateKey();
// store privateKey ...

// later:
final keyPair = nostr.keys.generateKeyPairFromExistingPrivateKey(privateKey);
```

## Reconstruct a key pair from a private key

```dart
final keyPair = nostr.keys.generateKeyPairFromExistingPrivateKey(
  'your_hex_private_key',
);
print(keyPair.public);
```

## Derive a public key from a private key

```dart
final publicKey = nostr.keys.derivePublicKey(
  privateKey: 'your_hex_private_key',
);
```

## Validate a private key

```dart
final isValid = NostrKeyPairs.isValidPrivateKey('your_hex_private_key');
print(isValid); // true / false
```

`isValidPrivateKey` is a static method — it does not require an instance.
