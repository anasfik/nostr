---
sidebar_position: 4
---

# Sending Events

When you have an event that is ready to be sent to your relay(s), as explained in [creating events](./sending-events), you can call the `sendEventToRelays()` method to send it to the connected relays.

```dart
// Create an example event
final event = NostrEvent.fromPartialData(
  kind: 1,
  content: 'event content example', 
  keyPair: userKeyPair,
);

// Send the event to the connected relays
// TODO: Add code
```

The event will be sent now to all the connected relays, and if you're already opening a subscription with a request that matches this event, you will receive it in your stream.
