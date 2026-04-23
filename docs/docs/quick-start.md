---
sidebar_position: 3
description: Working end-to-end example covering keys, connection, publishing, and subscribing.
---

# Quick Start

This example covers the minimal steps to connect to relays, generate keys, publish a note, and subscribe to events.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr.instance;

  // 1. Connect to relays
  final connectResult = await nostr.connect([
    'wss://relay.damus.io',
    'wss://nos.lol',
  ]);

  if (connectResult.isFailure) {
    print('connect failed: ${connectResult.failureOrNull}');
    return;
  }

  // 2. Generate a key pair
  final keyPair = nostr.keys.generateKeyPair();
  print('pubkey: ${keyPair.public}');

  // 3. Publish an event
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello from dart_nostr',
    keyPairs: keyPair,
    tags: [
      ['t', 'nostr'],
    ],
  );

  final publishResult = await nostr.publish(event);
  publishResult.fold(
    (ok) => print('published: ${ok.isEventAccepted}'),
    (failure) => print('publish failed: ${failure.message}'),
  );

  // 4. Subscribe to recent notes
  final subResult = nostr.subscribeRequest(
    NostrRequest(
      filters: [
        NostrFilter(
          kinds: [1],
          limit: 10,
          since: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    ),
  );

  subResult.fold(
    (stream) {
      stream.stream.listen((event) {
        print('event: ${event.content}');
      });
    },
    (failure) => print('subscribe failed: ${failure.message}'),
  );

  // 5. Disconnect when done
  await Future<void>.delayed(const Duration(seconds: 5));
  nostr.closeAllSubscriptions();
  await nostr.disconnect();
}
```

## What `NostrResult<T>` looks like

Every SDK operation that can fail returns `NostrResult<T>`. It has two states:

```dart
// Check inline
if (result.isSuccess) {
  final value = result.valueOrNull;
}

if (result.isFailure) {
  final failure = result.failureOrNull;
  print(failure?.message);
  print(failure?.code);
  print(failure?.isRetryable);
}

// Or use fold
result.fold(
  (value) { /* success */ },
  (failure) { /* failure */ },
);
```

`NostrFailure` always includes:
- `message` — human-readable description
- `code` — machine-readable error code string
- `isRetryable` — whether retrying the operation makes sense

## Next steps

- [Key management](./usage/keys-management/) — generate, derive, sign, encode
- [Relay connection](./usage/relays-and-events/connecting-to-relays) — connect lifecycle and options
- [Publishing events](./usage/relays-and-events/publishing-events) — event kinds and result handling
- [Subscriptions](./usage/relays-and-events/subscribing-to-events) — streams, filters, EOSE
- [NIP-05 identity](./usage/identity/nip05) — internet identifier resolution
- [NIP-19 encoding](./usage/identity/nip19) — npub, nsec, nprofile, nevent
