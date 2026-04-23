---
sidebar_position: 3
description: Access raw relay operations and protocol internals via nostr.relays and nostr.services.
---

# Low-Level API

The top-level facade (`nostr.connect`, `nostr.publish`, etc.) covers the majority of app development needs. When you need lower-level control, use `nostr.relays` and `nostr.services`.

## When to use the low-level API

- Raw WebSocket send without waiting for a typed OK response
- Custom relay orchestration not covered by the facade
- Protocol research or NIP implementation work
- Building your own higher-level abstraction on top of dart_nostr

## nostr.relays

`nostr.relays` gives direct access to the relay pool:

```dart
// Send event without waiting for OK
nostr.relays.sendEventToRelays(event);

// Close a specific subscription
nostr.relays.closeEventsSubscription(subscriptionId);

// Send a raw request and get a stream
final subscription = nostr.relays.startEventsSubscription(
  request: NostrRequest(filters: [NostrFilter(kinds: [1], limit: 10)]),
  onEose: (eose) {
    print('EOSE for ${eose.subscriptionId}');
    nostr.relays.closeEventsSubscription(eose.subscriptionId);
  },
);

subscription.stream.listen((event) => print(event.content));
```

## nostr.services

`nostr.services` exposes the internal service components:

```dart
nostr.services.keys     // key operations (same as nostr.keys)
nostr.services.relays   // relay service (same as nostr.relays)
nostr.services.utils    // utility methods
```

## Custom transport

Implement `NostrRelayTransport` to replace the default WebSocket transport:

```dart
class FakeTransport implements NostrRelayTransport {
  // implement connect, send, close, stream...
}

final nostr = Nostr(transport: FakeTransport());
```

This is the recommended approach for unit testing relay-dependent code without hitting real relays.

## Multiple isolated instances

Each `Nostr()` constructor call creates a fully isolated instance with its own relay connections, subscriptions, and key state:

```dart
final accountA = Nostr();
final accountB = Nostr();

await accountA.connect(['wss://relay.damus.io']);
await accountB.connect(['wss://nos.lol']);

// Independent connection pools, separate subscription managers
```
