---
sidebar_position: 1
description: Generate, derive, validate, and sign with nostr.keys.
---

# Keys

`nostr.keys` is the key surface of a `Nostr` instance. It creates secp256k1 key pairs, derives public keys, validates private keys, and signs or verifies messages.

Key material is held by `NostrKeyPairs` (`lib/nostr/core/key_pairs.dart`). Both `private` and `public` are 64-character lowercase hex strings, and `public` is derived from `private` when the object is constructed. A private key that is not 64 hex characters throws `ArgumentError`.

## Methods

| Method | Returns | Notes |
|---|---|---|
| `generateKeyPair()` | `NostrKeyPairs` | New random key pair |
| `generatePrivateKey()` | `String` | New random private key only |
| `generateKeyPairFromExistingPrivateKey(String)` | `NostrKeyPairs` | Rebuilds a pair from a stored private key |
| `derivePublicKey({required String privateKey})` | `String` | Public key for a private key |
| `isValidPrivateKey(String)` | `bool` | Instance method; `NostrKeyPairs.isValidPrivateKey` is the static equivalent |
| `sign({required String privateKey, required String message})` | `String` | SHA-256 hashes the message before signing; see [Sign and verify](./sign-verify.md) |
| `verify({required String publicKey, required String message, required String signature})` | `bool` | Hashes the message the same way |

NIP-06 mnemonic helpers live on `nostr.nips.nip06` (`isMnemonicValid`, `privateKeyFromMnemonic`). Static wrappers with the same behaviour exist on the keys service as `NostrKeys.isMnemonicValid` and `NostrKeys.getPrivateKeyFromMnemonic`, but `NostrKeys` is not exported from the package root, so use the NIP-06 accessor unless you import the instance implementation directly.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  final keyPairs = nostr.keys.generateKeyPair();

  print(keyPairs.public);
  print(keyPairs.private);

  final derived = nostr.keys.derivePublicKey(privateKey: keyPairs.private);
  print(derived == keyPairs.public); // true

  print(nostr.keys.isValidPrivateKey(keyPairs.private)); // true
  print(nostr.keys.isValidPrivateKey('not a key')); // false

  await nostr.keys.freeAllResources();
}
```

## The key-pair cache is process-wide

`NostrKeys` caches pairs by private key in a `static` map capped at 32 entries, with FIFO eviction (`lib/nostr/instance/keys/keys.dart`). The cache is not owned by an instance: two `Nostr` instances that derive the same private key get the same cached `NostrKeyPairs` object, and neither instance's `disconnect()` empties it.

Treat the cache as key material held in memory. Clear it with `nostr.keys.freeAllResources()` once a set of keys is no longer needed.

## Next

- [Generate key pairs](./generate-key-pair.md)
- [Sign and verify](./sign-verify.md)
- [NIP-19 bech32 encoding](./bech32-encoding.md)
- [NIP-05 identifiers](../identity/nip05.md)
- [Core concepts](../../must-know.md)
