---
sidebar_position: 2
description: Configure connection and request timeouts, retry policy, and fail-fast behaviour.
---

# Client options

`NostrClientOptions` is passed to the `Nostr` constructor. It is immutable for the lifetime of the instance, and there is no setter: `Nostr.instance` is built with `const NostrClientOptions()`, so a customised client needs its own instance.

| Option | Type | Default | Used by |
|---|---|---|---|
| `connectionTimeout` | `Duration` | 10 seconds | Per-relay WebSocket connect, and `addRelays` |
| `requestTimeout` | `Duration` | 15 seconds | `publish` and `count` responses |
| `retryPolicy` | `NostrRetryPolicy` | `const NostrRetryPolicy()` | `connect`, `publish`, `count` |
| `failFast` | `bool` | `false` | Returns the first failure without retrying |

The default retry policy is not "no retries". `const NostrRetryPolicy()` means `maxAttempts: 3`, `initialDelayMs: 100`, `maxDelayMs: 5000`, `backoffMultiplier: 2.0`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr(
    clientOptions: NostrClientOptions(
      connectionTimeout: const Duration(seconds: 10),
      requestTimeout: const Duration(seconds: 15),
      retryPolicy: NostrRetryPolicy.exponential(
        maxAttempts: 4,
        initialDelayMs: 150,
        maxDelayMs: 3000,
      ),
      failFast: false,
    ),
  );

  final result = await nostr.connect(const ['wss://relay.damus.io']);
  print(result.isSuccess);

  await nostr.disconnect();
}
```

## Retry policies

| Factory | Parameters | Delay between attempts |
|---|---|---|
| `NostrRetryPolicy()` | `maxAttempts: 3`, `initialDelayMs: 100`, `maxDelayMs: 5000`, `backoffMultiplier: 2.0` | Exponential by default |
| `NostrRetryPolicy.linear()` | `maxAttempts: 3`, `delayMs: 1000` | Constant `delayMs` |
| `NostrRetryPolicy.exponential()` | `maxAttempts: 3`, `initialDelayMs: 100`, `maxDelayMs: 5000` | Doubles each attempt |
| `NostrRetryPolicy.none()` | none | Single attempt (`maxAttempts: 1`) |

`maxAttempts` counts total attempts, including the first one. `maxAttempts: 3` therefore means one initial call plus at most two retries. Delays are clamped to `maxDelayMs`, so a large attempt number cannot sleep longer than that.

Because the factories are not `const`, `NostrClientOptions` cannot be constructed as `const` once you pass `NostrRetryPolicy.exponential(...)` or `.linear(...)`.

## Which operations are retried

| Operation | Retried | Why |
|---|---|---|
| `connect` | Yes | Transport and socket failures are retryable |
| `publish` | Yes | Relay timeout or socket failure |
| `count` | Yes | Relay timeout or socket failure |
| `subscribe` / `subscribeRequest` / `subscribeFilters` | No | Returns synchronously; the stream carries later errors |
| `addRelays` | No | One attempt |
| `removeRelay` | No | One attempt |
| `disconnect` | No | One attempt |

Retrying only wraps failures that are thrown by the transport. Two cases skip the loop entirely: argument validation (an empty relay list or a URL without `ws://`/`wss://`) returns `NostrFailure.invalidArgument` on the first call, and calling `publish`, `count`, or `subscribe` before `connect` returns `NostrFailure.invalidState`. A relay answering `OK:false` is not an exception either; it is a successful `NostrResult` whose `isEventAccepted` is `false`.

## Fail fast

`failFast: true` returns the first failure without sleeping or trying again, while keeping the policy unchanged for diagnostics. It is a per-instance switch, not a per-call one, so use a separate instance if only some paths should stop early.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr(
    clientOptions: NostrClientOptions(
      retryPolicy: NostrRetryPolicy.linear(maxAttempts: 5, delayMs: 500),
      failFast: true,
    ),
  );

  final result = await nostr.connect(const ['wss://relay.damus.io']);
  print(result.failureOrNull?.message);
}
```

## Related

- [Error handling](./error-handling.md) for `NostrResult` and `NostrFailure`
- [Low-level API](./low-level-api.md) for direct relay control
- [Connecting to relays](../relays-and-events/connecting-to-relays.md) for the connection lifecycle
