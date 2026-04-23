---
sidebar_position: 4
description: Sign arbitrary messages and verify signatures using Nostr key pairs.
---

# Sign and Verify

## Sign a message

```dart
final nostr = Nostr.instance;
final keyPair = nostr.keys.generateKeyPair();

final signature = nostr.keys.sign(
  privateKey: keyPair.private,
  message: 'hello nostr',
);
print(signature);  // hex signature
```

## Verify a signature

```dart
final isValid = nostr.keys.verify(
  publicKey: keyPair.public,
  message: 'hello nostr',
  signature: signature,
);
print(isValid);  // true
```

A signature produced by a different private key, or for a different message, will return `false`.

```dart
final isValid = nostr.keys.verify(
  publicKey: keyPair.public,
  message: 'different message',
  signature: signature,
);
print(isValid);  // false
```

This is the same signing primitive that `NostrEvent.fromPartialData` uses internally when producing event signatures.
