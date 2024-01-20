# Dart Nostr

This is a Dart/Flutter toolkit for developing [Nostr](https://nostr.com/) client apps faster and easier.

## Table of Contents

- [Supported NIPs](#supported-nips)
- [Installation](#installation)
- [Usage](#usage)
  - [Singleton instance vs. multiple instances](#singleton-instance-vs-multiple-instances)
  - [Keys](#keys)
    - [Generate private and public keys](#generate-private-and-public-keys)
    - [Generate a key pair from a private key](#generate-a-key-pair-from-a-private-key)
    - [Sign & verify with a private key](#sign--verify-with-a-private-key)
    - [More functionalities](#more-functionalities)
  - [Events & Relays](#events--relays)
    - [Create an event](#create-an-event)
    - [Connect to relays](#connect-to-relays)
    - [Listen to events](#listen-to-events)
      - [As a stream](#as-a-stream)
      - [As a future (resolves on EOSE)](#as-a-future-resolves-on-eose)
    - [Reconnect & disconnect](#reconnect--disconnect)
    - [Send an event](#send-an-event)
    - [Send NIP45 COUNT](#send-nip45-count)
    - [Relay Metadata NIP11](#relay-metadata-nip11)
    - [More functionalities](#more-functionalities-1)
  - [More utils](#more-utils)

## Supported NIPs

if you are working on a Nostr client, app... you will be able to apply and use all the following NIPs (Updated 2024-01-18):

- [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [NIP-02](https://github.com/nostr-protocol/nips/blob/master/02.md)
- [NIP-03](https://github.com/nostr-protocol/nips/blob/master/03.md)
- [NIP-04](https://github.com/nostr-protocol/nips/blob/master/04.md)
- [NIP-05](https://github.com/nostr-protocol/nips/blob/master/05.md)
- [NIP-06](https://github.com/nostr-protocol/nips/blob/master/06.md) 
- [NIP-08](https://github.com/nostr-protocol/nips/blob/master/08.md)
- [NIP-09](https://github.com/nostr-protocol/nips/blob/master/09.md)
- [NIP-10](https://github.com/nostr-protocol/nips/blob/master/10.md)
- [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md)
- [NIP-13](https://github.com/nostr-protocol/nips/blob/master/13.md)
- [NIP-14](https://github.com/nostr-protocol/nips/blob/master/14.md)
- [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md)
- [NIP-18](https://github.com/nostr-protocol/nips/blob/master/18.md)
- [NIP-19](https://github.com/nostr-protocol/nips/blob/master/19.md)
- [NIP-21](https://github.com/nostr-protocol/nips/blob/master/21.md)
- [NIP-23](https://github.com/nostr-protocol/nips/blob/master/23.md)
- [NIP-24](https://github.com/nostr-protocol/nips/blob/master/24.md)
- [NIP-25](https://github.com/nostr-protocol/nips/blob/master/25.md)
- [NIP-27](https://github.com/nostr-protocol/nips/blob/master/27.md)
- [NIP-28](https://github.com/nostr-protocol/nips/blob/master/28.md)
- [NIP-30](https://github.com/nostr-protocol/nips/blob/master/30.md)
- [NIP-31](https://github.com/nostr-protocol/nips/blob/master/31.md)
- [NIP-32](https://github.com/nostr-protocol/nips/blob/master/32.md)
- [NIP-36](https://github.com/nostr-protocol/nips/blob/master/36.md)
- [NIP-38](https://github.com/nostr-protocol/nips/blob/master/38.md)
- [NIP-39](https://github.com/nostr-protocol/nips/blob/master/39.md)
- [NIP-40](https://github.com/nostr-protocol/nips/blob/master/40.md)
- NIP-42 (not yet implemented)
- NIP-44 (not yet implemented)
- [NIP-45](https://github.com/nostr-protocol/nips/blob/master/45.md)
- [NIP-47](https://github.com/nostr-protocol/nips/blob/master/47.md)
- [NIP-48](https://github.com/nostr-protocol/nips/blob/master/48.md)
- [NIP-50](https://github.com/nostr-protocol/nips/blob/master/50.md)
- [NIP-51](https://github.com/nostr-protocol/nips/blob/master/51.md)
- [NIP-52](https://github.com/nostr-protocol/nips/blob/master/52.md)
- [NIP-53](https://github.com/nostr-protocol/nips/blob/master/53.md)
- [NIP-56](https://github.com/nostr-protocol/nips/blob/master/56.md)
- [NIP-57: Lightning Zaps](57.md)
- [NIP-58](https://github.com/nostr-protocol/nips/blob/master/58.md)
<!-- - [NIP-65](https://github.com/nostr-protocol/nips/blob/master/65.md) -->
- [NIP-72](https://github.com/nostr-protocol/nips/blob/master/72.md)
- [NIP-75](https://github.com/nostr-protocol/nips/blob/master/75.md)
- [NIP-78](https://github.com/nostr-protocol/nips/blob/master/78.md)
- [NIP-84](https://github.com/nostr-protocol/nips/blob/master/84.md)
- [NIP-89](https://github.com/nostr-protocol/nips/blob/master/89.md)
- [NIP-94](https://github.com/nostr-protocol/nips/blob/master/94.md)
- [NIP-98](https://github.com/nostr-protocol/nips/blob/master/98.md)
- [NIP-99](https://github.com/nostr-protocol/nips/blob/master/99.md)

NIPs marked as "not yet implemented" are not supported yet.

Some existant NIPs are platform specific or can't just be supported directly like [NIP 07](https://github.com/nostr-protocol/nips/blob/master/07.md) which is only web-specific, or [NIP 90](https://github.com/nostr-protocol/nips/blob/master/90.md) which is related to Data Vending machines.

## Installation

Install the package by adding the following to your `pubspec.yaml` file:

```yaml
dependencies:
  dart_nostr: any
```

Otherwise you can install it from the command line:

```bash
# Flutter project
flutter pub add dart_nostr

# Dart project
dart pub add dart_nostr
```

## Usage

### Singleton instance vs. multiple instances

The base and only class you need to remember is `Nostr`, all methods and utilities are available through it.

The `Nostr` class is accessible through two ways, a singleton instance which you can access by calling `Nostr.instance` and a constructor which you can use to create multiple instances of `Nostr`.

Each instance (including the singleton instance) is independent from each other, so everything you do with one instance will be accessible only through that instance including relays, events, caches, callbacks, etc.

Use the singleton instance if you want to use the same instance across your app, so as example once you do connect to a set of relays, you can access and use them (send and receive events) from anywhere in your app.

Use the constructor if you want to create multiple instances of `Nostr`, as example if you want to connect to different relays in different parts of your app, or if you have extensive Nostr relays usage (requests) and you want to separate them into different instances so you avoid relays limits.

```dart
/// Singleton instance
final instance = Nostr.instance;

/// Constructor
final instance = Nostr();
```

### Keys

#### Generate private and public keys

```dart
final newKeyPair = instance.keysService.generateKeyPair();

print(newKeyPair.public); // Public key
print(newKeyPair.private); // Private key
```

#### Generate a key pair from a private key

```dart
final somePrivateKey = "HERE IS MY PRIVATE KEY";

final newKeyPair = instance.keysService
      .generateKeyPairFromExistingPrivateKey(somePrivateKey);

print(somePrivateKey == newKeyPair.private); // true
print(newKeyPair.public); // Public key
```

#### Sign & verify with a private key

```dart

/// sign a message with a private key
final signature = instance.keysService.sign(
  privateKey: keyPair.private,
  message: "hello world",
);

print(signature);

/// verify a message with a public key
final verified = instance.keysService.verify(
  publicKey: keyPair.public,
  message: "hello world",
  signature: signature,
);

print(verified); // true
```

Note: `dart_nostr` provides even more easier way to create, sign and verify Nostr events, see the relays and events sections below.

#### More functionalities

The package exposes more useful methods, like:
  
```dart
// work with nsec keys
instance.keysService.encodePrivateKeyToNsec(privateKey);
instance.keysService.decodeNsecKeyToPrivateKey(privateKey);

// work with npub keys
instance.keysService.encodePublicKeyToNpub(privateKey);
instance.keysService.decodeNpubKeyToPublicKey(privateKey);

// more keys derivations and validations methods
instance.keysService.derivePublicKey(privateKey);
instance.keysService.generatePrivateKey(privateKey);
instance.keysService.isValidPrivateKey(privateKey);

// general utilities that related to keys
instance.utilsService.decodeBech32(bech32String);
instance.utilsService.encodeBech32(bech32String);
instance.utilsService.pubKeyFromIdentifierNip05(bech32String);
```

### Events & Relays

#### Create an event

Quickest way to create an event is by using the `NostrEvent.fromPartialData` constructor, it does all the heavy lifting for you, like signing the event with the provided private key, generating the event id, etc.

```dart
final event = NostrEvent.fromPartialData(
  kind: 1,
  content: 'example content',
  keyPairs: keyPair, // will be used to sign the event
  tags: [
    ['t', currentDateInMsAsString],
  ],
);

print(event.id); // event id
print(event.sig); // event signature

print(event.serialized()); // event as serialized JSON
```

Note: you can also create an event from scratch with the `NostrEvent` constructor, but you will need to do the heavy lifting yourself, like signing the event, generating the event id, etc.

#### Connect to relays
for a single `Nostr` instance, you can connect and reconnect to multiple relays once or multiple times, so you will be able to send and receive events later.

```dart
try {
 
 final relays = ['wss://relay.damus.io'];
 
 await instance.relaysService.init(
  relaysUrl: relays,
 );

print("connected successfully")
} catch (e) {
  print(e);
}
```

if anything goes wrong, you will get an exception with the error message.
Note: the `init` method is highly configurable, so you can control the behavior of the connection, like the number of retries, the timeout, wether to throw an exception or not, register callbacks for connections or events...

#### Listen to events

##### As a stream 

```dart
```dart
// Creating a request to be sent to the relays. (as example this request will get all events with kind 1 of the provided public key)
final request = NostrRequest(
  filters: [
    NostrFilter(
      kinds: const [1],
      authors: [keyPair.public],
    ),
  ],
);


// Starting the subscription and listening to events
final nostrStream = Nostr.instance.relaysService.startEventsSubscription(
  request: request,
  onEose: (ease) => print(ease),
);

print(nostrStream.subscriptionId); // The subscription id

// Listening to events
nostrStream.stream.listen((NostrEvent event) {
  print(event.content);
});

// close the subscription later
nostrStream.close();
```

##### As a future (resolves on EOSE)

```dart
// Creating a request to be sent to the relays. (as example this request will get all events with kind 1 of the provided public key)
final request = NostrRequest(
  filters: [
    NostrFilter(
      kinds: const [1],
      authors: [keyPair.public],
    ),
  ],
);

// Call the async method and wait for the result
final events =
    await Nostr.instance.relaysService.startEventsSubscriptionAsync(
  request: request,
);

// print the events
print(events.map((e) => e.content));
```

Note: `startEventsSubscriptionAsync` will be resolve with an `List<NostrEvent>` as soon as a relay sends an EOSE command.

#### Reconnect & disconnect

```dart
// reconnect
await Nostr.instance.relaysService.reconnectToRelays(
       onRelayListening: onRelayListening,
       onRelayConnectionError: onRelayConnectionError,
       onRelayConnectionDone: onRelayConnectionDone,
       retryOnError: retryOnError,
       retryOnClose: retryOnClose,
       shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
       connectionTimeout: connectionTimeout,
       ignoreConnectionException: ignoreConnectionException,
       lazyListeningToRelays: lazyListeningToRelays,
     );
    
// disconnect
await Nostr.instance.relaysService.disconnectFromRelays();
```

#### Send an event

```dart
// sending synchronously
Nostr.instance.relaysService.sendEventToRelays(
  event,
  onOk: (ok) => print(ok),
);

// sending synchronously with a custom timeout
final okCommand = await Nostr.instance.relaysService.sendEventToRelaysAsync(
  event,
  timeout: const Duration(seconds: 3),
);

print(okCommand);
```

Note: `sendEventToRelaysAsync` will be resolve with an `OkCommand` as soon as one relay accepts the event.

#### Send NIP45 COUNT

```dart
// create a count event
final countEvent = NostrCountEvent.fromPartialData(
  eventsFilter: NostrFilter(
    kinds: const [0],
    authors: [keyPair.public],
  ),
);

// Send the count event synchronously
Nostr.instance.relaysService.sendCountEventToRelays(
  countEvent,
  onCountResponse: (countRes) {
    print('count: $countRes');
  },
);

// Send the count event asynchronously
final countRes = await Nostr.instance.relaysService.sendCountEventToRelaysAsync(
  countEvent,
  timeout: const Duration(seconds: 3),
);

print("found ${countRes.count} events");
```

#### Relay Metadata NIP11

```dart
final relayDoc = await Nostr.instance.relaysService.relayInformationsDocumentNip11(
  relayUrl: "wss://relay.damus.io",
);

print(relayDoc?.name);
print(relayDoc?.description);
print(relayDoc?.contact);
print(relayDoc?.pubkey);
print(relayDoc?.software);
print(relayDoc?.supportedNips);
print(relayDoc?.version);
```

#### More functionalities

The package exposes more useful methods, like:

```dart
// work with nevent and nevent
final nevent = Nostr.instance.utilsService.encodeNevent(
  eventId: event.id,
  pubkey: pubkey,
  userRelays: [],
);
  
print(nevent);

final map = Nostr.instance.utilsService.decodeNeventToMap(nevent);
print(map);


// work with nprofile
final nprofile = Nostr.instance.utilsService.encodeNProfile(
  pubkey: pubkey,
  userRelays: [],
);

print(nprofile);

final map = Nostr.instance.utilsService.decodeNprofileToMap(nprofile);
print(map);

```

### More utils

#### Generate random 64 hex

```dart
final random = Nostr.instance.utilsService.random64HexChars();
final randomButBasedOnInput = Nostr.instance.utilsService.consistent64HexChars("input");

print(random);
print(randomButBasedOnInput);
```

#### NIP05 related

```dart
/// verify a nip05 identifier
final verified = await Nostr.instance.utilsService.verifyNip05(
  internetIdentifier: "something@domain.com",
  pubKey: pubKey,
);

print(verified); // true

  
/// Validate a nip05 identifier format
final isValid = Nostr.instance.utilsService.isValidNip05Identifier("work@gwhyyy.com");
print(isValid); // true

/// Get the pubKey from a nip05 identifier
final pubKey = await Nostr.instance.utilsService.pubKeyFromIdentifierNip05(
  internetIdentifier: "something@somain.c",
);
  
print(pubKey);
```

### NIP13 hex difficulty

```dart
Nostr.instance.utilsService.countDifficultyOfHex("002f");
```
