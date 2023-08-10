# Nostr Dart Client for Nostr protocol.

<p align="center">
<img src="https://imgur.com/KqnGsN2.png" width="70%" placeholder="Nostr protocol" />
</p>


# Usage:

<br>

## Keys Service:


## Relays Service:

The relays service is responsible for anything related to the actual interaction with relays such connecting to them, sending events to them, listening to events from them, etc.

#### Creating and signing Nostr events:


#### Connecting to relay(s):

As I already said, this package exposes only one main instance, which is `Nostr.instance`, 
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
