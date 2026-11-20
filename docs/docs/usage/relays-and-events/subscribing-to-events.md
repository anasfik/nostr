---
sidebar_position: 4
description: Request events with filters, consume the live stream, close subscriptions, and detect end of stored events.
---

# Subscribing to events

`nostr.subscribe` starts a subscription and returns
`NostrResult<NostrEventsStream>` synchronously. It does not await the relay and
it does not return a `List` of events.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final result = nostr.subscribe(
    const NostrFilter(kinds: [1], limit: 20),
  );

  final events = result.valueOrNull;
  if (events == null) {
    print(result.failureOrNull?.message);
    return;
  }

  final listener = events.stream.listen((event) {
    print('${event.pubkey.substring(0, 8)}: ${event.content}');
  });

  await Future<void>.delayed(const Duration(seconds: 5));
  await listener.cancel();
  events.close();
}
```

Subscribing requires an open connection, at least one filter, and at least one
filter with a criterion. Otherwise the call returns a failure with
`NostrFailureCode.invalidState` or `NostrFailureCode.invalidArgument`.

## Filter fields

`NostrFilter` is a const class with typed fields. There is no `tags` map.

| Field | Type | Filter key | Notes |
| --- | --- | --- | --- |
| `ids` | `List<String>?` | `ids` | Lowercase hex, up to 64 characters |
| `authors` | `List<String>?` | `authors` | Lowercase hex, up to 64 characters |
| `kinds` | `List<int>?` | `kinds` | Negative kinds are rejected |
| `e` | `List<String>?` | `#e` | Referenced event ids |
| `p` | `List<String>?` | `#p` | Referenced pubkeys |
| `t` | `List<String>?` | `#t` | Hashtags |
| `a` | `List<String>?` | `#a` | Addressable event coordinates |
| `since` | `DateTime?` | `since` | Inclusive lower bound, sent in seconds |
| `until` | `DateTime?` | `until` | Upper bound, sent in seconds |
| `limit` | `int?` | `limit` | Must be greater than 0 and at most 10000 |
| `search` | `String?` | `search` | NIP-50, only where the relay supports it |
| `additionalFilters` | `Map<String, dynamic>?` | verbatim | Escape hatch for other tag keys |

`validate()` returns a list of human-readable errors. The facade calls it before
subscribing, so an invalid filter fails fast instead of being sent.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final filter = NostrFilter(
    kinds: const [1],
    authors: const [
      '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
    ],
    t: const ['nostr', 'dart'],
    since: DateTime.now().subtract(const Duration(hours: 6)),
    limit: 50,
  );

  print(filter.validate()); // [] when valid
  print(filter.toMap());
}
```

Tag keys in `additionalFilters` are sent as written, so include the leading `#`:

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  const filter = NostrFilter(
    kinds: [30023],
    additionalFilters: {'#d': ['my-article']},
  );

  print(filter.toMap()); // {'kinds': [30023], '#d': ['my-article']}
}
```

## Several filters

`subscribeFilters` and `subscribeRequest` accept more than one filter in a single
subscription. A relay returns events matching any of them and sends one EOSE for
the whole subscription.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final result = nostr.subscribeFilters(const [
    NostrFilter(kinds: [0], authors: ['3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d']),
    NostrFilter(kinds: [1], authors: ['3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d'], limit: 30),
    NostrFilter(kinds: [3], authors: ['3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d']),
  ]);

  print(result.isSuccess);
}
```

Use `subscribeRequest(NostrRequest(filters: [...], subscriptionId: ...))` when
you need to choose the subscription id yourself. Otherwise the id is derived.

## The stream object

| Member | Type | Meaning |
| --- | --- | --- |
| `stream` | `Stream<NostrEvent>` | Broadcast stream of matching events |
| `subscriptionId` | `String` | Id used on the relay socket |
| `request` | `NostrRequest` | Request that produced the stream |
| `onClose` | `void Function()?` | Callback invoked by `close()` |
| `close()` | `void` | Closes the subscription and sends `CLOSE` |

The facade stream is a broadcast stream, so it supports several listeners but
does not replay earlier events to a listener that joins late. `close()` returns
`void`, not a `Future`; call it after you finish listening rather than awaiting
it. Cancelling a listener also closes the subscription on the relay side.

## End of stored events (EOSE)

The facade stream carries events only. It does not surface EOSE, and it stays
open after the relay has sent all stored events, which is what you want for live
updates.

EOSE is available on the low-level relay service. `onEose` fires per relay and
carries the subscription id plus any NIP-67 hints.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final stream = nostr.relays.startEventsSubscription(
    request: NostrRequest(
      filters: const [NostrFilter(kinds: [1], limit: 50)],
    ),
    onEose: (relay, eose) {
      print('$relay finished ${eose.subscriptionId} hints=${eose.hints}');
    },
  );

  stream.stream.listen((event) => print(event.content));
}
```

To wait until stored events are done, use `startEventsSubscriptionAsync`. It
returns the events collected up to the first relay's EOSE, and throws
`TimeoutException` if no EOSE arrives within `timeout`. Pass
`shouldThrowErrorOnTimeoutWithoutEose: false` to get the partial list instead.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final events = await nostr.relays.startEventsSubscriptionAsync(
    request: NostrRequest(
      filters: const [NostrFilter(kinds: [1], limit: 50)],
    ),
    timeout: const Duration(seconds: 15),
  );

  print('received ${events.length} events before EOSE');
}
```

Because the future completes on the first EOSE, a multi-relay subscription may
return before slower relays have answered.

## Close subscriptions

| Call | Effect |
| --- | --- |
| `events.close()` | Sends `CLOSE` and stops tracking the facade subscription |
| `listener.cancel()` | Cancels your listener and closes the subscription |
| `nostr.closeAllSubscriptions()` | Closes every facade-tracked subscription |
| `nostr.relays.closeEventsSubscription(id)` | Sends `CLOSE` for a low-level subscription id |
| `nostr.subscriptions.closeSubscription(id)` | Drops tracking metadata only; sends nothing to relays |

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final result = nostr.subscribe(const NostrFilter(kinds: [1], limit: 5));
  final events = result.valueOrNull;
  if (events == null) {
    return;
  }

  events.stream.listen((event) => print(event.content));
  await Future<void>.delayed(const Duration(seconds: 2));

  nostr.relays.closeEventsSubscription(events.subscriptionId);
}
```

## Tracking

`activeSubscriptions` maps subscription id to `SubscriptionMetadata`.
`subscriptionStatistics` aggregates the same records.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr.instance;

  print(nostr.activeSubscriptions.length);

  final stats = nostr.subscriptionStatistics;
  print(stats.totalSubscriptions);
  print(stats.totalEventCount);
  print(stats.averageEventsPerSubscription);
}
```

Related: [Publishing events](./publishing-events.md),
[Count events](./count-events.md), and
[Low-level API](../advanced/low-level-api.md).
