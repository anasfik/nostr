---
sidebar_position: 2
description: Learn how to generate a new private key directly, and use it later to generate a key pair.
---


# Generate A Private Key Directly

Well, since you know that you can get a whole [key pair](./generate-key-pair) to use with only it's private key, you may want to only generate it. Then creating a key pair from it later, this will be useful if you want to store the private key somewhere and use it later to generate a key pair and so avoiding the instantly derivation of the key pair from the private key.

For this, you can use the `generatePrivateKey()` method of the `Nostr.instance.services.keys`, this method returns a `String` that represents the private key, Example:

```dart
// Generate a new private key.
String privateKey = Nostr.instance.services.keys.generatePrivateKey();

// Now you can use it as you want.
print(privateKey); // ...

// ... 

// later, after one hour as example, you can generate a keypair from it.
NostrKeyPairs keyPair = Nostr.instance.services.keys.generateKeyPairFromExistingPrivateKey(privateKey);

// Now you can use it as you want.
print(keyPair.private); // ...
print(keyPair.public); // ...

print(keyPair.private == privateKey) // true
```

## What's Next

Learn how you can create a key pair from a key pair, [click here](./get-a-key-pair-from-private-key).
