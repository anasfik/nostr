---
sidebar_position: 1
description: Handle typed failures with NostrResult<T> and NostrFailure.
---

# Error Handling

All SDK operations that can fail return `NostrResult<T>` — a sealed type with two states: success (`T`) and failure (`NostrFailure`).

## NostrResult<T> API

```dart
// Check state
result.isSuccess   // bool
result.isFailure   // bool

// Extract values (null if wrong state)
result.valueOrNull    // T?
result.failureOrNull  // NostrFailure?

// Pattern match
result.fold(
  (value) { /* success */ },
  (failure) { /* failure */ },
);
```

## NostrFailure fields

```dart
failure.message     // String — human-readable description
failure.code        // String — machine-readable error code
failure.isRetryable // bool — whether retrying makes sense
failure.details     // Map<String, dynamic>? — optional structured data
```

## Common error codes

| Code | Meaning |
|---|---|
| `connection_failed` | Could not establish WebSocket connection |
| `timeout` | Operation exceeded the configured timeout |
| `relay_rejected` | Relay returned an OK:false response |
| `invalid_relay_url` | Relay URL is not a valid WebSocket URL |
| `empty_filter` | A subscription request contained no filters |
| `not_connected` | Operation requires an active connection |

## Retry policy

Configure retry behavior on `NostrClientOptions`:

```dart
final nostr = Nostr(
  clientOptions: NostrClientOptions(
    retryPolicy: NostrRetryPolicy.exponential(
      maxAttempts: 4,
      initialDelayMs: 150,
      maxDelayMs: 3000,
    ),
  ),
);
```

Available policies:
- `NostrRetryPolicy.none()` — no retries
- `NostrRetryPolicy.fixed(attempts, delayMs)` — fixed interval retries
- `NostrRetryPolicy.exponential(maxAttempts, initialDelayMs, maxDelayMs)` — exponential backoff
