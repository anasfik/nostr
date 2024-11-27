---
sidebar_position: 4
description: Learn how to get a public key from a private key.
---

# Get a public key from a private key

If you have only a [private key](./generate-private-key-directly), and you want to get its associated public key, you can use the `derivePublicKey()` method of the `Nostr.instance.services.keys`, This method will return a `String` that represents the public key, Example:

```dart
// Generate a new private key.
String privateKey = Nostr.instance.services.keys.generatePrivateKey();

// Later, after one hour as example, you can get its associated public key.
String publicKey = Nostr.instance.services.keys.derivePublicKey(privateKey);

// Now you can use both.
print(publicKey); // ...
print(privateKey); // ...
```

## What's Next ?

Lear how you can encode & decode a key pair keys to the npub & nsec formats, [click here](./encode-decode-key-pair-keys-to-npub-nsec-formats).
