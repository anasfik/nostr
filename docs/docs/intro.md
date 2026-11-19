---
sidebar_position: 1
sidebar_label: Overview
slug: /
title: Dart and Flutter Nostr SDK documentation
description: Learn dart_nostr with installation steps, a Dart quick start, and guides to relay connections, signed events, subscriptions, keys and typed failures.
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

- **Typed relay results.** High-level relay operations return `NostrResult<T>` with a success value or a structured `NostrFailure`. Local parsing and cryptographic helpers can throw; validate external input and handle those errors in your app.
- **Single entry point.** `Nostr.instance` is the singleton accessor. All services are reachable from it.
- **Two API tiers.** The top-level facade (`nostr.connect`, `nostr.publish`, `nostr.subscribeRequest`) is optimized for app development. The `nostr.relays` and `nostr.services` surfaces give raw protocol access when needed.
- **Testable.** Instances are isolated and support injected transports, making unit testing straightforward.

## Quick orientation

```dart
import 'package:dart_nostr/dart_nostr.dart';

final nostr = Nostr.instance;     // singleton
final nostr2 = Nostr();           // isolated instance, separate connection pool
```

For example, publishing returns a typed result. A successful operation still requires checking whether the relay accepted the event:

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
