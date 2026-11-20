---
sidebar_position: 3
description: Send signed events to relays, read OK receipts, and choose between fire-and-forget and awaited publishing.
---

# Publishing events

`publish` sends one signed event and returns a `NostrResult<NostrEventOkCommand>`.
The success value is a relay `OK` receipt, not a copy of the event.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();
  await nostr.connect(const ['wss://relay.damus.io']);

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: keyPairs,
  );

  final result = await nostr.publish(event);

  result.fold(
    (ok) {
      print('id      : ${ok.eventId}');
      print('accepted: ${ok.isEventAccepted}');
      print('message : ${ok.message}');
    },
    (failure) => print('${failure.code}: ${failure.message}'),
  );
}
```

## Preconditions

`publish` checks two things before it touches a socket:

| Check | Failure |
| --- | --- |
| The client is connected | `NostrFailure.invalidState` |
| `event.id` is non-null and non-empty | `NostrFailure.invalidArgument` |

An event returned by `NostrEvent.fromPartialData` or a signer already satisfies
the id check. An empty or absent id means the event was never hashed or signed;
sign it first.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  // Nothing is connected yet.
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: nostr.keys.generateKeyPair(),
  );

  final result = await nostr.publish(event);
  print(result.failureOrNull?.code); // NostrFailureCode.invalidState
}
```

## Read the OK receipt

| Field | Type | Meaning |
| --- | --- | --- |
| `eventId` | `String` | Id of the submitted event |
| `isEventAccepted` | `bool?` | `true` accepted, `false` rejected, `null` when the relay sent no flag |
| `message` | `String?` | Relay text, usually the rejection reason |

A relay can accept the WebSocket frame and still reject the event: wrong
signature, missing proof of work, rate limit, blocked content, or a write policy.
`isEventAccepted` is the only reliable signal.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: nostr.keys.generateKeyPair(),
  );

  final result = await nostr.publish(event);

  final ok = result.valueOrNull;
  if (ok != null && ok.isEventAccepted != true) {
    print('relay rejected: ${ok.message}');
  }
}
```

`publish` completes on the first `OK` received from any target relay. It reports
that relay's verdict; it does not wait for the others and does not aggregate
their answers. If you need per-relay results, use the low-level API below with
an `onOk` callback.

## Target specific relays

Pass `relays` to publish to a subset. Relays that are not connected yet are
registered first.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io', 'wss://nos.lol']);

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: nostr.keys.generateKeyPair(),
  );

  final result = await nostr.publish(
    event,
    relays: const ['wss://nos.lol'],
  );

  print(result.isSuccess);
}
```

## Fire-and-forget with per-relay callbacks

`nostr.relays.sendEventToRelays` writes the event to every matching relay and
returns once the frames are queued. It does not wait for `OK` and does not retry.
It throws when the event has no id, and silently sends nothing when no connected
relay matches.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: nostr.keys.generateKeyPair(),
  );

  await nostr.relays.sendEventToRelays(
    event,
    onOk: (relay, ok) {
      print('$relay accepted=${ok.isEventAccepted} ${ok.message ?? ''}');
    },
  );
}
```

The `onOk` callback fires once per relay that answers, which makes this the
option to use when you want every relay's verdict rather than the first.

## Await one receipt at the low level

`sendEventToRelaysAsync` returns the first `OK` command and throws
`TimeoutException` when none arrives inside `timeout`. It throws `StateError`
when no connected relay matches.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: nostr.keys.generateKeyPair(),
  );

  final ok = await nostr.relays.sendEventToRelaysAsync(
    event,
    timeout: const Duration(seconds: 10),
  );

  print('${ok.eventId} accepted=${ok.isEventAccepted}');
}
```

## Which entry point to use

| Call | Returns | Waits for `OK` | On timeout or rejection |
| --- | --- | --- | --- |
| `nostr.publish(event)` | `Future<NostrResult<NostrEventOkCommand>>` | First relay | Failure with a `NostrFailureCode` |
| `nostr.relays.sendEventToRelaysAsync(event, timeout:)` | `Future<NostrEventOkCommand>` | First relay | Throws `TimeoutException` |
| `nostr.relays.sendEventToRelays(event, onOk:)` | `Future<void>` | No | Nothing thrown for a rejection; inspect `onOk` |

Related: [Creating events](./creating-events.md),
[Subscribing to events](./subscribing-to-events.md), and
[Error handling](../advanced/error-handling.md).
