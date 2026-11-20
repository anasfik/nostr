---
sidebar_position: 2
description: Generate a new key pair, rebuild one from a stored private key, derive a public key, or validate a key.
---

# Generate key pairs

A key pair is a `NostrKeyPairs` value with hex `public` and `private` fields. Generation uses 32 random bytes, so a fresh key is returned on every call.

## Generate a new key pair

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();

  print(keyPairs.public); // 64-character hex public key
  print(keyPairs.private); // 64-character hex private key
}
```

Store `private` yourself. The library does not persist keys; the only copy it keeps is the in-memory cache described in [Keys](./index.md).

## Generate only a private key

Use `generatePrivateKey()` when the private key is written somewhere before the pair is needed. The value is the same kind of hex string that `generateKeyPair().private` returns.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();

  final privateKey = nostr.keys.generatePrivateKey();
  print(privateKey);

  // Later, rebuild the full pair from the stored key.
  final keyPairs = nostr.keys.generateKeyPairFromExistingPrivateKey(privateKey);
  print(keyPairs.public);
}
```

`generateKeyPairFromExistingPrivateKey` accepts 64 hex characters in either case and normalises them to lowercase. Anything else throws `ArgumentError`; guard untrusted input with `isValidPrivateKey` first.

## Derive a public key from a private key

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final privateKey = nostr.keys.generatePrivateKey();

  final publicKey = nostr.keys.derivePublicKey(privateKey: privateKey);

  print(publicKey);
  print(publicKey == nostr.keys.generateKeyPairFromExistingPrivateKey(privateKey).public); // true
}
```

## Validate a private key

`isValidPrivateKey` returns `false` instead of throwing, so it is safe on user input. It is available on an instance and as a static method on `NostrKeyPairs`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();

  print(nostr.keys.isValidPrivateKey(keyPairs.private)); // true
  print(NostrKeyPairs.isValidPrivateKey(keyPairs.private)); // true

  print(nostr.keys.isValidPrivateKey('not a key')); // false
  print(NostrKeyPairs.isValidPrivateKey('')); // false
}
```

## Derive a key from a BIP-39 mnemonic

NIP-06 derivation uses the path `m/44'/1237'/0'/0/0`. `nostr.nips.nip06` validates the mnemonic and returns the private key; the resulting key is a normal 64-character hex string that can be turned into a pair.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  const mnemonic =
      'leader monkey parrot ring guide accident before fence cannon height naive bean';

  final nostr = Nostr();
  final nip06 = nostr.nips.nip06;

  if (!nip06.isMnemonicValid(mnemonic)) {
    print('invalid mnemonic');
    return;
  }

  final privateKey = nip06.privateKeyFromMnemonic(mnemonic);
  final keyPairs = nostr.keys.generateKeyPairFromExistingPrivateKey(privateKey);

  print(keyPairs.public);
}
```

The same two operations are wrapped as `NostrKeys.isMnemonicValid` and `NostrKeys.getPrivateKeyFromMnemonic`. Those wrappers are static on a class that the package root does not export, which is why the example uses the NIP-06 accessor.

## Next

- [Sign and verify](./sign-verify.md) with the generated keys
- [NIP-19 bech32 encoding](./bech32-encoding.md) to share `npub` and `nsec` forms
- [NIP-05 identifiers](../identity/nip05.md) to attach a name to a public key
