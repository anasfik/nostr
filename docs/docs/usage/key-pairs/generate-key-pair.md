--- 
position: 1
---

# Generate A New Key Pair

In order to generate a new key pair of a private and a public keys for a new user, you can achieve it by calling the `generateKeyPair()` method of the `Nostr.instance.keysService`, This method will return a `NostrKeyPairs` that represents the key pair, Example:

```dart
// Generate a new key pair.
NostrKeyPairs keyPair = Nostr.instance.keysService.generateKeyPair();

// Now you can use it as you want.
print(keyPair.private); // ...
print(keyPair.public); // ...
```

You can access and use the private and public keys now in the Nostr operations, such using the public key in events...
