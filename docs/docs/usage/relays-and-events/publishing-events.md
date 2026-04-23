---
sidebar_position: 3
description: Publish signed Nostr events to connected relays and handle relay responses.
---

# Publishing Events

## Publish a single event

```dart
final result = await nostr.publish(event);

result.fold(
  (ok) {
    print('event id  : ${ok.eventId}');
    print('accepted  : ${ok.isEventAccepted}');
    print('message   : ${ok.message}');
  },
  (failure) {
    print('error     : ${failure.message}');
    print('code      : ${failure.code}');
    print('retryable : ${failure.isRetryable}');
  },
);
```

The `ok` value is a `NostrEventOkCommand` with:
- `eventId` — the event id that was submitted
- `isEventAccepted` — whether the relay accepted it
- `message` — relay's response message (may include rejection reason)

## Asynchronous publish (fire-and-forget)

If you do not need the relay response, use the low-level relays service:

```dart
nostr.relays.sendEventToRelays(event);
```

This sends the event and does not block for a response.

## Publish with a timeout

Configure via `NostrClientOptions` on the instance:

```dart
final nostr = Nostr(
  clientOptions: NostrClientOptions(
    requestTimeout: const Duration(seconds: 10),
  ),
);
```

## Handling rejections

A relay may accept the WebSocket send but still reject the event (e.g., rate limiting, PoW requirements, content policy). Always check `ok.isEventAccepted` when it matters:

```dart
result.fold(
  (ok) {
    if (!ok.isEventAccepted) {
      print('relay rejected: ${ok.message}');
    }
  },
  (failure) => print('transport error: ${failure.message}'),
);
```
