---
sidebar_position: 5
---

# Count Event

You can get the events count for a specific query (filters) which mentioned in [nip45](https://github.com/nostr-protocol/nips/blob/master/45.md) instead of retrieving all their data, this is handy when you want to show numerical count to the user such as follwers, a feed notes number...

For this, you can use the `sendCountEventToRelays` method, passing a `NostrCountEvent` that represents the count query:

```dart

// Filter to target all notes (kind 1)  events with the "nostr" tag.
  NostrFilter filter = NostrFilter(
    kinds: [1],
    t: ["nostr"],
  );

// create the count event.
final countEvent = NostrCountEvent.fromPartialData(
  eventsFilter: filter,
);

Nostr.instance.relaysService.sendCountEventToRelays(
  countEvent,
  onCountResponse: (countRes) {
    print("your filter matches ${countRes.count} events");
  },
);
```

when the response is got by the relays, the `onCountResponse` callback will be called, you can use it.

