---
position: 2
---


# Get a key pair from an existent private key.

If you have only a private key, and you want to get it's associated key pair,you can use the `generateKeyPairFromExistingPrivateKey()` method of the `Nostr.instance.keysService`, This method will return a `NostrKeyPairs` that represents the key pair, Example:

```dart
// The private key.
final privateKey = "THE_PRIVATE_KEY_HEX_STRING";

// Generate a new key pair from the private key.
NostrKeyPairs keyPair = Nostr.instance.keysService.generateKeyPairFromExistingPrivateKey(privateKey);

// Now you can use it as you want.
print(keyPair.private); // ...
print(keyPair.public); // ...
```
