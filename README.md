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
String message = ...;
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

## Relays Service:

#### Creating, signing Nostr events:

You can get the final events that you will send to your relays by either creating a raw `NostrEvent` object and then you will need to generate it's `id` and `sign` by yourself, example:

```dart

  final event = NostrEvent(
    pubkey: '<THE-PUBKEY-OF-THE-EVENT-CREATOR>',
    kind: 0,
    content: 'This is a test event content',
    createdAt: DateTime.now(),
    id: '<THE-ID-OF-THE-EVENT>', // you will need to generate and set the id of the event manually by hashing other event fields, please refer to the official Nostr protocol documentation to learn how to do it yourself.
    tags: [],
    sig: '<THE-SIGNATURE-OF-THE-EVENT>', // you will need to generate and set the signature of the event manually by signing the event's id, please refer to the official Nostr protocol documentation to learn how to do it yourself.
  );
```

As it is explained, this will require you to set every single value of the event manually, including the `id` and `sig` values, or you can rely on the package for doing the hard part and create a `NostrEvent.fromPartialData(...)` which requires only the direct fields to be set and the rest will be handled automatically.

```dart
  final event = NostrEvent.fromPartialData(
    kind: 0,
    keyPairs: "<THE-KEYPAIRS-OF-THE-EVENT-CREATOR>",
    content: 'This is a test event content',
    tags: [],
    createdAt: DateTime.parse('...'),,
  );
```

The only required fields here are: `kind`, `keyPairs`and `content`. if `tags` os ignored, it will be set to `[]`, and if `createdAt` is ignored, it will be set to `DateTime.now()` automatically.

`NostrEvent.fromPartialData` requires the `keyPairs` because it needs to get the private key to sign the event and assign it the `sign` field, and it needs to get the public key to use it as the `pubkey` of the event.

to get a `NostrKeyPairs` of your event creator, refer please to the [Keys Service](#keys-service) section.

#### Connecting to relay(s):

as we did said that the package exposes only one main instance, which is `Nostr.instance`, you will need to initialize/connect to your relay(s) only one time in your Dart/Flutter app with:

```dart
Nostr.instance.relaysService.init(
  relaysUrl: ['wss://relay.damus.io'],
);
```
