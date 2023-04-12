# Nostr Dart Client for Nostr protocol.

<p align="center">
<img src="https://imgur.com/KqnGsN2.png" width="70%" placeholder="Nostr protocol" />
</p>

**help this gets discovered and noticed by other developers with a star ⭐**

This package is a client for the [Nostr protocol](https://github.com/nostr-protocol/). It is a wrapper that lets you interact with the Nostr protocol in an easier, faster and more organized way.

## TODO:

(talking to me) please, when you have time, here is a thing to do in addition to maintaining the package.

- [ ] Add tests for every single member.
- [ ] Add more documentation.
- [ ] add more examples.
- [ ] ...

# Usage:

the main and only the instance that you need to use to access all other memebers in this package is:

```dart
Nostr.instance;
```

`Nostr.instance` offers access to the services of this package which they-self offer many other functionalities to get your things done.

```dart
Nostr.instance.keysService; // access to the keys service, which will provide methods to handle user key pairs, private keys, public keys, etc.

Nostr.instance.relaysService; // access to the relays service, which will provide methods to interact with your own relays such as sending events, listening to events, etc.
```

## Keys Service:

#### Generate a new key pair:

```dart
NostrKeyPairs keyPair = await Nostr.instance.keysService.generateKeyPair();

print(keyPair.private); // ...
print(keyPair.public); // ...
```

#### Get a key pair from an existent private key:

```dart
NostrKeyPairs keyPair = await Nostr.instance.keysService.generateKeyPairFromExistingPrivateKey(privateKey);
```

#### generate and get a new private key directly:

```dart
String privateKey = await Nostr.instance.keysService.generatePrivateKey();
```

#### Derive a public key from a private key directly:

```dart
String publicKey = await Nostr.instance.keysService.derivePublicKey(privateKey);
```

#### Sign and verify a message:

```dart
final privateKey = ...;
final message = ...;
String signature = await Nostr.instance.keysService.sign(
  privateKey: privateKey,
  message: message,
);
print(signature); // ...

bool isVerified = await Nostr.instance.keysService.verify(
  publicKey: publicKey,
  message: message,
  signature: signature,
);
print(isMessageVerified); // ...
```
