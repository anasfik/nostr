--- 
sidebar_position: 1
description: Learn how to generate a new key pair of a private and a public keys for a new user.
---

# Generate A New Key Pair

In order to generate a new key pair of a private and a public keys for a new user as example, you can do it by calling the `generateKeyPair()` method of the `Nostr.instance.services.keys`, This method will return a `NostrKeyPairs` that represents the key pair, like this:

```dart
// Generate a new key pair.
NostrKeyPairs keyPair = Nostr.instance.services.keys.generateKeyPair();

// Now you can use it as you want.
print(keyPair.private); // ...
print(keyPair.public); // ...

// A example, creating new events for that user associated with this key pair.
```

You can access and use the private and public keys now in the Nostr operations, such using the public key in events...

## What's Next

Learn how you can create only a private key for a new user, [click here](./generate-private-key-directly), and create its key pair later.
