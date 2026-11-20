---
sidebar_position: 2
description: Build signed Nostr events with fromPartialData, or assemble one field by field when you need full control.
---

# Creating events

## Build and sign in one call

`NostrEvent.fromPartialData` computes the canonical event id, signs it with the
supplied key pair, and sets `pubkey` from that key pair. No relay connection or
bound signer is involved:

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPairs = NostrKeyPairs.generate();

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: keyPairs,
  );

  print(event.id);
  print(event.pubkey);
  print(event.isVerified());
}
```

| Parameter | Required | Meaning |
| --- | --- | --- |
| `kind` | yes | Event kind |
| `content` | yes | Event content; may be empty |
| `keyPairs` | yes | Local key pair used for `pubkey`, `id`, and `sig` |
| `tags` | no | `List<List<String>>`; defaults to an empty list |
| `createdAt` | no | Defaults to `DateTime.now()` |
| `ots` | no | Optional NIP-03 OpenTimestamps attestation |

All fields are on the returned `NostrEvent` as nullable values (`id`, `kind`,
`content`, `sig`, `createdAt`, `tags`), because the same model also represents
partially populated relay messages. For an event built with `fromPartialData`
they are set.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPairs = NostrKeyPairs.generate();

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'tagged note',
    keyPairs: keyPairs,
    tags: [
      ['t', 'nostr'],
      ['t', 'dart'],
    ],
    createdAt: DateTime.now(),
  );

  print(event.tags);
}
```

Tags are written exactly as relay JSON expects them: a tag name followed by its
values. The library does not validate tag names.

## Common kinds

| Kind | Description |
| --- | --- |
| `0` | User metadata, JSON-encoded in `content` |
| `1` | Short text note |
| `3` | Contact list |
| `4` | Legacy NIP-04 encrypted direct message |
| `5` | Deletion request |
| `7` | Reaction |
| `1059` | NIP-59 gift wrap, produced by the NIP-17 helpers |
| `10002` | Relay list metadata |

The full set of builders, including social events and long-form articles, lives
on `nostr.nips.social`; see [NIP accessors](../../reference/accessors).

## Metadata event (kind 0)

Kind 0 stores profile fields as a JSON object in `content`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPairs = NostrKeyPairs.generate();

  final metadata = NostrEvent.fromPartialData(
    kind: 0,
    content: '{"name":"alice","about":"building on nostr",'
        '"picture":"https://example.com/avatar.jpg"}',
    keyPairs: keyPairs,
  );

  print(metadata.content);
}
```

## Deletion request (kind 5)

`NostrEvent.deleteEvent` builds a kind-5 event whose `content` is the reason and
whose tags reference the events to delete. Deleting an addressable event also
needs its `a` coordinate, which this helper does not add; build the event with
`fromPartialData` if you need one.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPairs = NostrKeyPairs.generate();

  final deletion = NostrEvent.deleteEvent(
    keyPairs: keyPairs,
    reasonOfDeletion: 'posted by mistake',
    eventIdsToBeDeleted: ['event_id_1', 'event_id_2'],
  );

  print(deletion.kind); // 5
  print(deletion.tags);
}
```

## Compute an id, then sign

`NostrEvent.getEventId` hashes the canonical serialization
`[0, pubkey, created_at, kind, tags, content]`. `NostrKeyPairs.sign` signs the
32-byte id. This is what `fromPartialData` does internally.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPairs = NostrKeyPairs.generate();
  final createdAt = DateTime.now();
  const tags = <List<String>>[];

  final id = NostrEvent.getEventId(
    kind: 1,
    content: 'hello nostr',
    createdAt: createdAt,
    tags: tags,
    pubkey: keyPairs.public,
  );

  final event = NostrEvent(
    id: id,
    kind: 1,
    content: 'hello nostr',
    sig: keyPairs.sign(id),
    pubkey: keyPairs.public,
    createdAt: createdAt,
    tags: tags,
  );

  print(event.isVerified());
}
```

Note that `NostrKeyPairs.sign` expects an event id here. If you want to sign an
arbitrary message, use `nostr.keys.sign`, which hashes the message first; see
[Sign and verify](../keys-management/sign-verify).

## Verify and serialize

| Method | Returns | Use |
| --- | --- | --- |
| `isVerified()` | `bool` | Checks the Schnorr signature over `id` with `pubkey`; `false` when `id` or `sig` is null |
| `toMap()` | `Map<String, dynamic>` | Event object with `created_at` in seconds; omits null fields |
| `serialized()` | `String` | Relay message `["EVENT", {...}]` |
| `uniqueKey()` | `NostrEventKey` | Identity for an event received from a relay; throws for locally built events |

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: NostrKeyPairs.generate(),
  );

  print(event.isVerified());
  print(event.toMap());
  print(event.serialized());
}
```

`serialized()` wraps the event in `["EVENT", {...}]`, the form used on a relay
socket. A single event sent this way is missing the subscription id that a relay
`EVENT` message normally carries; use `toMap()` when you need just the object.

## Raw constructor

The default constructor requires all seven fields. Use it to reconstruct an
event that already has a valid id and signature, for example from your own
storage.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final event = NostrEvent(
    id: 'hex_event_id',
    kind: 1,
    content: 'raw event',
    sig: 'hex_signature',
    pubkey: 'hex_pubkey',
    createdAt: DateTime.now(),
    tags: const [],
  );

  print(event.isVerified());
}
```

`NostrEvent.deserialized` parses a relay `["EVENT", <subscription_id>, {...}]`
message instead. Passing a prefix other than `EVENT`, or a message with fewer
than three elements, throws `FormatException`.

Related: [Publishing events](./publishing-events) and
[Signers](../../features/signers).
