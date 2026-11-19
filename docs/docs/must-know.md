---
sidebar_position: 4
description: Understand Nostr events, instance ownership, public data and cleanup before using dart_nostr.
---

# Before You Build

Nostr clients sign events locally and exchange them through relays. Read the [Nostr protocol specifications](https://github.com/nostr-protocol/nips/) for event formats and supported extensions.

## Own the client lifecycle

`Nostr()` creates an isolated instance. `Nostr.instance` returns a shared singleton. Choose one owner for each instance's connections and subscriptions; disconnecting a singleton affects everyone using it.

```dart
final nostr = Nostr();
final keys = nostr.keys;
final bech32 = nostr.bech32;
final utils = nostr.utils;
```

Prefer `connect`, `publish`, `subscribeRequest`, and `disconnect` for relay operations. Their typed results make failures explicit. `nostr.relays` exposes legacy lower-level operations for advanced use; it is not a second connection pool to mix into a facade workflow.

## Treat published data as public

Publishing sends a signed event to external relays. Relays may retain or redistribute it. Keep private keys out of logs, source control, URLs and analytics. Use disposable keys for experiments rather than importing your identity into a demo.

## Close resources

Close subscriptions when their owner no longer needs them. Disconnect an isolated client when its lifecycle ends:

```dart
nostr.closeAllSubscriptions();
await nostr.disconnect();
```

See the [quick start](./quick-start.md) for a complete connection, publish and subscription example with failure handling.
