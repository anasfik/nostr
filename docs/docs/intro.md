---
sidebar_position: 1
slug: /
description: dart_nostr — a production-ready Dart and Flutter SDK for building Nostr applications. Typed results, relay management, key tooling, NIP-05/19 support, and clean subscription lifecycle.
---

# dart_nostr

`dart_nostr` is a Dart and Flutter SDK for building Nostr applications. It handles relay connections, event signing and publishing, subscription management, key tooling, and NIP utilities — so you can focus on your product instead of the protocol.

## What it covers

| Area | Details |
|---|---|
| Key management | Generate, derive, validate, sign, verify |
| NIP-19 encoding | `npub`, `nsec`, `nprofile`, `nevent`, `naddr` |
| Relay connections | Connect, disconnect, reconnect, retry |
| Event publishing | Typed `NostrResult<T>` with failure details |
| Subscriptions | Streams with lifecycle tracking and EOSE handling |
| Event counting | NIP-45 count requests |
| Identity | NIP-05 resolve and verify |
| Relay metadata | NIP-11 relay information documents |
| Low-level access | Raw relay operations for protocol work |

## Core design principles

- **Typed results everywhere.** `NostrResult<T>` is a sealed type. Every operation returns either a success value or a structured `NostrFailure`. No unchecked exceptions in the public API.
- **Single entry point.** `Nostr.instance` is the singleton accessor. All services are reachable from it.
- **Two API tiers.** The top-level facade (`nostr.connect`, `nostr.publish`, `nostr.subscribeRequest`) is optimized for app development. The `nostr.relays` and `nostr.services` surfaces give raw protocol access when needed.
- **Testable.** Instances are isolated and support injected transports, making unit testing straightforward.

## Quick orientation

```dart
import 'package:dart_nostr/dart_nostr.dart';

final nostr = Nostr.instance;     // singleton
final nostr2 = Nostr();           // isolated instance, separate connection pool
```

Every operation on the facade returns `NostrResult<T>`:

```dart
final result = await nostr.publish(event);

result.fold(
  (ok) => print('accepted: ${ok.isEventAccepted}'),
  (failure) => print('error: ${failure.message} (${failure.code})'),
);
```

## Navigation

- [Installation](./installation) — add the package to your project
- [Quick Start](./quick-start) — working end-to-end example
- [Usage guides](./usage/keys-management/) — per-feature documentation
