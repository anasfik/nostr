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
```

#### Sending events to relay(s):

When you have an event that is ready to be sent to your relay(s) as exmaple the [previous event](#creating-and-signing-nostr-events) that we did created, you can call the `sendEventToRelays()` method with it and send it to relays:

```dart
Nostr.instance.relaysService.sendEventToRelays(event);
```

The event will be sent now to all the connected relays now, and if you're already openeing a subsciption to your relays, you will start receiving it in your stream.

<br>
