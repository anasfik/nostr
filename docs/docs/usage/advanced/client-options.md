---
sidebar_position: 2
description: Configure timeouts, retry policies, and other client options.
---

# Client Options

`NostrClientOptions` controls connection behaviour. Pass it when constructing a `Nostr` instance:

```dart
final nostr = Nostr(
  clientOptions: NostrClientOptions(
    connectionTimeout: const Duration(seconds: 10),
    requestTimeout: const Duration(seconds: 15),
    retryPolicy: NostrRetryPolicy.exponential(
      maxAttempts: 3,
      initialDelayMs: 200,
      maxDelayMs: 5000,
    ),
  ),
);
```

## Available options

| Option | Type | Default | Description |
|---|---|---|---|
| `connectionTimeout` | `Duration` | 10s | Per-relay WebSocket connect timeout |
| `requestTimeout` | `Duration` | 15s | Timeout for publish and count responses |
| `retryPolicy` | `NostrRetryPolicy` | `none` | Retry strategy for failed operations |

## Using `Nostr.instance` with options

`Nostr.instance` is a singleton. To apply custom options, create an isolated instance instead:

```dart
// Isolated instance — separate connection pool, independent lifecycle
final nostr = Nostr(
  clientOptions: NostrClientOptions(...),
);
```

Both the singleton and isolated instances expose the same public API.
