---
sidebar_position: 1
description: Handle typed failures with NostrResult<T> and NostrFailure.
---

# Error Handling

High-level relay operations return `NostrResult<T>` with success (`T`) and failure (`NostrFailure`) states. Local parsing and cryptographic helpers can throw; validate input and handle exceptions at those boundaries.

## `NostrResult<T>` API

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
failure.code        // NostrFailureCode — machine-readable enum
failure.isRetryable // bool — whether retrying makes sense
failure.context     // Map<String, Object?> — structured diagnostic data
```

## Common error codes

| Code | Meaning |
|---|---|
| `connection` | Could not establish WebSocket connection |
| `timeout` | Operation exceeded the configured timeout |
| `protocol` | A relay response violates the expected protocol |
| `invalidArgument` | Input validation failed, such as an invalid relay URL or empty filters |
| `invalidState` | The operation cannot run in the current client state |

Use `NostrFailureCode.connection` (and the other enum members) in comparisons. A successful publish result still needs `receipt.isEventAccepted` checked: a relay's rejection is not necessarily a transport failure.

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
- `NostrRetryPolicy.linear(maxAttempts: 3, delayMs: 1000)` — constant interval retries
- `NostrRetryPolicy.exponential(maxAttempts: 3, initialDelayMs: 100, maxDelayMs: 5000)` — exponential backoff
