---
position: 3
---


# Generate and get a new private key directly

Well, since you know that you can get a whole keypair to use with only it's private key, you may want to only generate it, then creating a keypair from it later, this will be useful if you want to store the private key somewhere and use it later to generate a keypair and so avoiding the instantly derivation of the keypair from the private key.

For this, you can use the `generatePrivateKey()` method of the `Nostr.instance.keysService`, this method will return a `String` that represents the private key, Example:

```dart
// Generate a new private key.
String privateKey = Nostr.instance.keysService.generatePrivateKey();

// Now you can use it as you want.
print(privateKey); // ...

// ... 

// later, after one hour as example, you can generate a keypair from it.
NostrKeyPairs keyPair = Nostr.instance.keysService.generateKeyPairFromExistingPrivateKey(privateKey);

// Now you can use it as you want.
print(keyPair.private); // ...
print(keyPair.public); // ...
```
