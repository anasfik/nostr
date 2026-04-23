---
sidebar_position: 5
description: Count matching events using NIP-45 count requests.
---

# Count Events (NIP-45)

Some relays support NIP-45, which lets you ask how many events match a filter without retrieving them all. Use this for follower counts, feed sizes, and similar metrics.

## Basic count

```dart
final result = await nostr.count(
  NostrCountEvent.fromPartialData(
    eventsFilter: NostrFilter(
      kinds: [1],
      authors: [pubkey],
    ),
  ),
);

result.fold(
  (r) => print('count: ${r.count}'),
  (failure) => print('count failed: ${failure.message}'),
);
```

## Count with multiple filters

```dart
final result = await nostr.count(
  NostrCountEvent.fromPartialData(
    eventsFilter: NostrFilter(
      kinds: [3],          // contact lists referencing this pubkey
      tags: {'p': [pubkey]},
    ),
  ),
);
```

Note: relay support for NIP-45 varies. If a relay does not support it, the result will be a failure with an appropriate message.
