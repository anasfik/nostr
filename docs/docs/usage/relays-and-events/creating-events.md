---
sidebar_position: 2
description: Create signed Nostr events using fromPartialData or the raw constructor.
---

# Creating Events

## Recommended: fromPartialData

`NostrEvent.fromPartialData` computes the event `id`, signs it with the provided key pair, and sets `pubkey` automatically.

```dart
final keyPair = nostr.keys.generateKeyPair();

final event = NostrEvent.fromPartialData(
  kind: 1,
  content: 'hello nostr',
  keyPairs: keyPair,
);
```

All fields except `kind`, `content`, and `keyPairs` are optional:

```dart
final event = NostrEvent.fromPartialData(
  kind: 1,
  content: 'tagged note',
  keyPairs: keyPair,
  tags: [
    ['t', 'nostr'],
    ['t', 'dart'],
  ],
  createdAt: DateTime.now(),
);
```

### Common event kinds

| Kind | Description |
|---|---|
| `0` | User metadata (JSON-encoded profile) |
| `1` | Short text note |
| `3` | Contact list |
| `4` | Encrypted direct message |
| `5` | Deletion request |
| `7` | Reaction |
| `10002` | Relay list metadata |

## Metadata event (kind 0)

```dart
import 'dart:convert';

final metadata = NostrEvent.fromPartialData(
  kind: 0,
  content: jsonEncode({
    'name': 'alice',
    'about': 'building on nostr',
    'picture': 'https://example.com/avatar.jpg',
  }),
  keyPairs: keyPair,
);
```

## Delete event (kind 5)

```dart
final deletion = NostrEvent.deleteEvent(
  keyPairs: keyPair,
  reasonOfDeletion: 'posted by mistake',
  eventIdsToBeDeleted: ['event_id_1', 'event_id_2'],
);
```

## Raw event constructor

Use the raw constructor when you need full control over all fields (e.g., when reconstructing an event received from a relay):

```dart
final event = NostrEvent(
  pubkey: 'hex_pubkey',
  kind: 1,
  content: 'raw event',
  createdAt: DateTime.now(),
  id: 'hex_event_id',
  tags: [],
  sig: 'hex_signature',
);
```

You are responsible for computing `id` and `sig` correctly when using the raw constructor.
