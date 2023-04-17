# Nostr Dart Client for Nostr protocol.

<p align="center">
<img src="https://imgur.com/KqnGsN2.png" width="70%" placeholder="Nostr protocol" />
</p>

**help this gets discovered and noticed by other developers with a star ⭐**

This package is a client for the [Nostr protocol](https://github.com/nostr-protocol/). It is a wrapper that lets you interact with the Nostr protocol in an easier, faster and more organized way.

## NIPS that can be implemented with this package:

- NIP-01
- NIP-02
- NIP-03
- NIP-04 (TODO: make the encryption part automated by the package).
- NIP-05
- NIP-09
- NIP-10
- NIP-11
- NIP-12
- NIP-14
- NIP-16
- NIP-18
- ...

## TODO (if you want to contribute, please feel free to implement any of the following NIPS and make a pull request, I will be happy to review it and merge it.)

- NIP-06
- NIP-13

# Usage:

The main and only instance that you need to use to access all other members in this package is:

```dart
Nostr.instance;
```

`Nostr.instance` offers access to separated services of this package which they-self offer many other members/functions to get your things done.

```dart
Nostr.instance.keysService; // access to the keys service, which will provide methods to handle user key pairs, private keys, public keys, etc.

Nostr.instance.relaysService; // access to the relays service, which will provide methods to interact with your own relays such as sending events, listening to events, etc.
```

<br>

## Keys Service:

This service is responsible for handling anything that is related to the user's key pairs, private keys, public keys, signing and verifying messages, etc.

#### Generate a new key pair:

In order to generate a new key pair, you will need to call the `generateKeyPair()` function, which will return a `NostrKeyPairs` object that contains the private key and the public key of the generated key pair.

```dart
NostrKeyPairs keyPair = await Nostr.instance.keysService.generateKeyPair();

print(keyPair.private); // ...
print(keyPair.public); // ...
```

#### Get a key pair from an existent private key:

If you already have a private key, you can get a key pair from it by calling the `generateKeyPairFromExistingPrivateKey()` function, which will return a `NostrKeyPairs` object that contains the private key and the generated public key.

```dart
NostrKeyPairs keyPair = await Nostr.instance.keysService.generateKeyPairFromExistingPrivateKey(privateKey);
```

#### generate and get a new private key directly:

Sometimes, you will need to only generate a private key and not a key pair, in this case, you can call the `generatePrivateKey()` function, which will return a `String` that contains the generated private key directly.

```dart
String privateKey = await Nostr.instance.keysService.generatePrivateKey();
```

#### Derive a public key from a private key directly:

Or, if you already have a private key, you can derive the public key from it by calling the `derivePublicKey()` function, which will return a `String` that contains the derived public key directly.

```dart
String publicKey = await Nostr.instance.keysService.derivePublicKey(privateKey);
```

#### Sign and verify a message:

To sign a message, you will need to call the `sign()` function, which will return a `String` that contains the signature of the message.

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

<br>

## Relays Service:

#### Creating and signing Nostr events:

You can get the final events that you will send to your relays by either creating a raw `NostrEvent` object and then you will need to generate and set it's `id` and `sign` by yourself using the Nostr protocol speceifications which you can check manually from it's official documentation.

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

As it is explained, this will require you to set every single value of the event manually, including the `id` and `sig` values.

This package covers you in thus part and offers a `NostrEvent.fromPartialData(...)` which requires only the direct fields to be set and the rest will be handled automatically so you don't need to worry about it.

```dart
  final event = NostrEvent.fromPartialData(
    kind: 0,
    keyPairs: "<THE-KEYPAIRS-OF-THE-EVENT-CREATOR>",
    content: 'This is a test event content',
    tags: [],
    createdAt: DateTime.parse('...'),,
  );
```

The only required fields here are `kind`, `keyPairs` and `content`.

- if `tags` is ignored, it will be set to `[]`.
- if `createdAt` is ignored, it will be set to `DateTime.now()` automatically.
- other fields like `id` and `sign` will be generated automatically.

`NostrEvent.fromPartialData` requires the `keyPairs` because it needs to get the private key to sign the event and assign to the `sign` field, and it needs to get the public key to use it as the `pubkey` of the event.

To get a `NostrKeyPairs` of your event creator, refer please to the [Keys Service](#keys-service) section.

#### Connecting to relay(s):

as I already said, this package exposes only one main instance, which is `Nostr.instance`, you will need to initialize/connect to your relay(s) only one time in your Dart/Flutter app with:

```dart
Nostr.instance.relaysService.init(
  relaysUrl: ['wss://relay.damus.io'],
 onRelayListening: (String relayUrl, receivedData) {}, // will be called once a relay is connected and listening to events.
 onRelayError: (String relayUrl, Object? error) {}, // will be called once a relay is disconnected or an error occurred.
 onRelayDone: (String relayUrl) {}, // will be called once a relay is disconnected, finished.
 lazyListeningToRelays: false, // if true, the relays will not start listening to events until you call `Nostr.instance.relaysService.startListeningToRelays()`, if false, the relays will start listening to events as soon as they are connected.
);
```

the only required field here is `relaysUrl`, which accepts a `List<String>` that contains the URLs of your relays web sockets, you can pass as many relays as you want.

I personally recommend initializing the relays service in the `main()` function of your app, so that it will be initialized as soon as the app starts, and will be available to be used anywhere else in your app.

```dart
void main() {
Nostr.instance.relaysService.init(...);

//...
 }
```

#### Listening to events from relay(s):

For listening to events from relay(s), you will need to create a `NostrRequest` request with the target filters:

```dart
// creating the request.
NostrRequest req = NostrRequest(
 filters: [
   NostrFilter(
     kind: 1,
     tags: ["p", "..."],
     authors: ["..."],
     ),
 ],
);

// creating a stream of events.
Stream<NostrEvent> stream = Nostr.instance.relaysService.startEventsSubscription(req);

// listening to the stream.
stream.listen((event) {
  print(event);
});
```

you can set manually the `subscriptionId` of the request, or you can let the package generate it for you automatically.

#### Sending events to relay(s):

When you have an event that is ready to be sent to your relay(s), you can call the `sendEventToRelays()` function with the event as the only parameter:

```dart
Nostr.instance.relaysService.sendEventToRelays(event);
```

The event will be sent to all the connected relays now, and if you're already subscribing with a `NostrRequest` to the relays, you will start receiving the event in your stream.

#### nip-05 verification:

in order to verify a user pubkey with his internet identifier, you will need to call the `verifyNip05()` function with the user's pubkey and internet identifier as the only parameters:

```dart
bool isVerified = await Nostr.instance.relaysService.verifyNip05(
  internetIdentifier: '<THE-INTERNET-IDENTIFIER-OF-THE-USER>',
  pubkey: '<THE-PUBKEY-OF-THE-USER>',
);
print(isVerified); // ...
```

if the user is verified, the function will return `true`, otherwise, it will return `false`.

#### nip-11 relay Information Document:

You can get the relay information document by calling the `getRelayInformationDocument()` function with the relay's URL as the only parameter:

```dart

  RelayInformations relayInformationDocument = await Nostr.instance.relaysService.getRelayInformationDocument(
    relayUrl: 'wss://relay.damus.io',
  );
  print(relayInformationDocument.supportedNips); // ...
```
