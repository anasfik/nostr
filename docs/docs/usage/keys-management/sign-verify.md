---
sidebar_position: 4
description: Sign messages and event ids with BIP-340, and verify the result.
---

# Sign and verify

Signing in dart_nostr is BIP-340 over a 32-byte message. There are two entry points, and they differ in one important way: the keys service hashes your text first, while `NostrKeyPairs.sign` signs the bytes you give it. Event signatures use the second form.

| Task | Call | Hashes input |
|---|---|---|
| Sign a text message | `nostr.keys.sign(privateKey:, message:)` | Yes, SHA-256 |
| Verify a text message | `nostr.keys.verify(publicKey:, message:, signature:)` | Yes, SHA-256 |
| Sign an event id | `keyPairs.sign(eventId)` | No, signs the 32-byte id |
| Verify an event id | `NostrKeyPairs.verify(pubkey, eventId, signature)` | No |

## Sign and verify a message

`sign` and `verify` take a UTF-8 string, SHA-256 hash it, and sign or verify the digest. The signature is 64 bytes, hex encoded.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();

  final signature = nostr.keys.sign(
    privateKey: keyPairs.private,
    message: 'hello nostr',
  );
  print(signature); // 128-character hex signature

  final valid = nostr.keys.verify(
    publicKey: keyPairs.public,
    message: 'hello nostr',
    signature: signature,
  );
  print(valid); // true

  final wrongMessage = nostr.keys.verify(
    publicKey: keyPairs.public,
    message: 'different message',
    signature: signature,
  );
  print(wrongMessage); // false

  final wrongKey = nostr.keys.verify(
    publicKey: nostr.keys.generateKeyPair().public,
    message: 'hello nostr',
    signature: signature,
  );
  print(wrongKey); // false
}
```

## Sign an event id

An event id is itself a SHA-256 digest of the serialised event. `NostrEvent.fromPartialData` computes that id and calls `keyPairs.sign(id)`, so the signature covers the id directly. `NostrEvent.isVerified()` checks the same pair.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final keyPairs = NostrKeyPairs.generate();

  final note = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: keyPairs,
  );

  final signature = keyPairs.sign(note.id!);
  print(NostrKeyPairs.verify(keyPairs.public, note.id!, signature)); // true
  print(note.isVerified()); // true
}
```

Because BIP-340 uses a random auxiliary value, two signatures over the same id are both valid but not byte-identical. Compare verification results, not signature strings, when you check your own work.

## Do not hash an event id twice

`keys.sign` always hashes its `message` argument. Passing an event id to it signs `SHA-256(id)`, which is not the message the event's `sig` field must cover. The signature verifies against the hash, but relays and other clients reject it for the event.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();
  final note = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: keyPairs,
  );

  final doubleHashed = nostr.keys.sign(
    privateKey: keyPairs.private,
    message: note.id!,
  );

  print(NostrKeyPairs.verify(keyPairs.public, note.id!, doubleHashed)); // false
  print(note.isVerified()); // true, the event still carries the correct signature
}
```

Rule of thumb: sign text with `nostr.keys.sign`, sign an event with `keyPairs.sign(event.id!)` or let the event builders do it.

## Next

- [Create events](../relays-and-events/creating-events.md) shows the builders that sign for you
- [Publish events](../relays-and-events/publishing-events.md) covers relay acceptance
- [Error handling](../advanced/error-handling.md) covers what a rejected publish looks like
