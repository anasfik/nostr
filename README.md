# Nostr Dart Client for Nostr protocol.

<p align="center">
<img src="https://imgur.com/KqnGsN2.png" width="70%" placeholder="Nostr protocol" />
</p>


# Usage:

<br>

## Keys Service:

This service is responsible for handling anything that is related to the nostr keys including generating and deriving private & public keys, signing and verifying messages, etc.





## Relays Service:

The relays service is responsible for anything related to the actual interaction with relays such connecting to them, sending events to them, listening to events from them, etc.

#### Creating and signing Nostr events:

You can get the final events that you will send to your relays by either creating a raw `NostrEvent` object and then you will need to generate and set literally all its properties by yourself using the Nostr protocol specifications which you will need to have a basic [understanding of it](https://github.com/nostr-protocol/nips/blob/master/01.md) :

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

As it is explained, this will require you to set every single value of the event properties manually, including the `id` and `sig` values.

Well, we al lve easy things right? This package offers the option to handle all this internally and covers you in this part with the  `NostrEvent.fromPartialData(...)` which requires you to only set the direct necessary fields and the rest will be handled internally so you don't need to worry about it:

```dart
final pair = Nostr.instance.keysService.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 0,
    keyPairs: pair,
    content: 'This is a test event content',
    tags: [],
    createdAt: DateTime.parse('...'),,
  );
```

The only required fields here are `kind`, `keyPairs` and `content`.

- if `tags` is ignored, it will be set to an empty list `[]`.

- if `createdAt` is ignored, it will be set to the current date `DateTime.now()` .

- other fields like `id`, `sign` and pubkey is what you don't need to worry about, they will be generated and set internally.


`NostrEvent.fromPartialData` requires the `keyPairs` because it needs to get the private key to sign the event and assign to the `sign` field, and it needs to get the public key to use it as the `pubkey` of the event.



#### Connecting to relay(s):

As I already said, this package exposes only one main instance, which is `Nostr.instance`, you will need to initialize/connect to your relay(s) only one time in your Dart/Flutter app with:

```dart
Nostr.instance.relaysService.init(
  
  relaysUrl: ['wss://relay.damus.io'],
  
  onRelayListening: (String relayUrl, receivedData) {}, // will be called once a relay is connected and listening to events.
  
  onRelayError: (String relayUrl, Object? error) {}, // will be called once a relay is disconnected or an error occurred.
  
  onRelayDone: (String relayUrl) {}, // will be called once a relay is disconnected, finished.
  
  lazyListeningToRelays: false, // if true, the relays will not start listening to events until you call `Nostr.instance.relaysService.startListeningToRelays()`, if false, the relays will start listening to events as soon as they are connected.

  retryOnError: false, // Weither to ro retry connecting to relay(s) if an error occurred to them .
  
  retryOnClose: false, // Weither to ro retry connecting to relay(s) if they are closed.
  
  bool ensureToClearRegistriesBeforeStarting = true, // Weither to clear the registries of the relays before starting to listen to them, this is useful if you want to implmenta  reconnecting feature, so that you will totally clear previous connections and start a new one.

  bool ignoreConnectionException: true, // Weither to ignore any exception that occurs while connecting to relay(s) or not (if false, the exception will be thrown and you will have to catch it).

  bool shouldReconnectToRelayOnNotice = false, // Weither to reconnect to relay(s) if they sent a [NOTICE, ...] message.
  
  Duration connectionTimeout = const Duration(seconds: 5), // The timeout of the connection to relay(s).
  
);
```

The only required field here is `relaysUrl`, which accepts a `List<String>` that contains the URLs of your relays web sockets, you can pass as many relays as you want.

I personally recommend initializing the relays service in the `main()` function of your app, so that it will be initialized as soon as the app starts, and then it will be available to be used anywhere and anytime in your app.

```dart
void main() {
Nostr.instance.relaysService.init(...);

// if it is a flutter app: runApp(MyApp());
//...
 }
```

#### Listening to events from relay(s):

For listening to events from relay(s), you will need to create a `NostrRequest` first with the specify your request type and filters = that you wanna apply as example:

```dart
// creating the request.
final req = NostrRequest(
 filters: [
   NostrFilter(
     kind: 1,
     tags: ["p", "..."],
     authors: ["..."],
   ),
 ],
);

// creating a stream of events.
NostrEventsStream nostrEventsStream = Nostr.instance.relaysService.startEventsSubscription(req);

// listening to the stream.
nostrEventsStream.stream.listen((event) {
  print(event);
});

// closing the nostr nostr events stream after 10 seconds (and yes this will close it for all relays that you're listening to)
Future.delayed(Duration(seconds: 10)).then((value) {  
  nostrEventsStream.close();
});
```

#### Sending events to relay(s):

When you have an event that is ready to be sent to your relay(s) as exmaple the [previous event](#creating-and-signing-nostr-events) that we did created, you can call the `sendEventToRelays()` method with it and send it to relays:

```dart
Nostr.instance.relaysService.sendEventToRelays(event);
```

The event will be sent now to all the connected relays now, and if you're already openeing a subsciption to your relays, you will start receiving it in your stream.

<br>

#### nip-05 identifier verification:

in order to verify a user pubkey with his internet identifier, you will need to call the `verifyNip05()` function with the user's pubkey and internet identifier as the only parameters:

```dart
bool isVerified = await Nostr.instance.relaysService.verifyNip05(
  internetIdentifier: '<THE-INTERNET-IDENTIFIER-OF-THE-USER>',
  pubkey: '<THE-PUBKEY-OF-THE-USER>',
);

print(isVerified); // ...
```

if the user is verified, the function will return `true`.

#### Relay Information Document:

You can get the relay information document (NIP 11) by calling the `getRelayInformationDocument()` function with the relay's URL as the only parameter:

```dart

  RelayInformations relayInformationDocument = await Nostr.instance.relaysService.getRelayInformationDocument(
    relayUrl: 'wss://relay.damus.io',
  );
  print(relayInformationDocument.supportedNips); // ...
```
