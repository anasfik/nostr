---
sidebar_position: 3
description: Learn how to get a key pair from an existent private key.
---


# Get a key pair from an existent private key

If you have only a [private key](./generate-private-key-directly), and you want to get its associated key pair, you can use the `generateKeyPairFromExistingPrivateKey()` method of the `Nostr.instance.keysService`, This method will return a `NostrKeyPairs` object that represents that key pair, Example:

```dart
// The private key, maybe the one you generated separately.
final privateKey = "THE_PRIVATE_KEY_HEX_STRING";

// Generate a new key pair from the private key.
NostrKeyPairs keyPair = Nostr.instance.keysService.generateKeyPairFromExistingPrivateKey(privateKey);

// Now you can use it as you want.
print(keyPair.private); // ...
print(keyPair.public); // ...

print(keyPair.private == privateKey) // true
```

## What's Next ?

Learn how you can generate a public key directly from a private one, click [here](./get-a-public-key-from-private-key).
