---
sidebar_position: 4
description: Subscribe to Nostr events using filters, listen to streams, and handle EOSE.
---

# Subscribing to Events

## Basic subscription

```dart
final result = nostr.subscribeRequest(
  NostrRequest(
    filters: [
      NostrFilter(
        kinds: [1],
        limit: 20,
        since: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ],
  ),
);

result.fold(
  (stream) {
    print('subscription id: ${stream.subscriptionId}');

    stream.stream.listen((event) {
      print('${event.pubkey.substring(0, 8)} — ${event.content}');
    });
  },
  (failure) => print('subscribe failed: ${failure.message}'),
);
```

## NostrFilter fields

```dart
NostrFilter(
  ids: ['event_id_1'],          // specific event ids
  authors: ['pubkey_hex'],      // filter by author pubkey
  kinds: [1, 6, 7],            // event kinds
  tags: {'t': ['nostr']},       // tag filters
  since: DateTime(...),         // events after this time
  until: DateTime(...),         // events before this time
  limit: 50,                    // max events to return
  search: 'keyword',            // NIP-50 search (if relay supports it)
)
```

## Multiple filters

A single `NostrRequest` can carry multiple filters. The relay returns events matching any filter:

```dart
nostr.subscribeRequest(
  NostrRequest(
    filters: [
      NostrFilter(kinds: [0], authors: [pubkey]),   // profile
      NostrFilter(kinds: [1], authors: [pubkey], limit: 30),  // notes
      NostrFilter(kinds: [3], authors: [pubkey]),   // contacts
    ],
  ),
);
```

## Subscribe with EOSE handling

```dart
result.fold(
  (stream) {
    stream.stream.listen(
      (event) => print(event.content),
      onDone: () => print('stream closed'),
    );

    // Close after EOSE via a timeout or explicit call
    Future.delayed(const Duration(seconds: 3), stream.close);
  },
  (failure) => print(failure.message),
);
```

## Close a specific subscription

```dart
stream.close();
```

Or close by subscription id:

```dart
nostr.relays.closeEventsSubscription(subscriptionId);
```

## Close all subscriptions

```dart
nostr.closeAllSubscriptions();
```

## Subscription statistics

```dart
final active = nostr.activeSubscriptions;
final stats = nostr.subscriptionStatistics;

print('active     : ${active.length}');
print('total events tracked: ${stats.totalEventCount}');
```

## Subscribe with filters shorthand

```dart
final result = nostr.subscribeFilters([
  NostrFilter(kinds: [1], limit: 10),
]);
```

## Async subscription (await until EOSE)

```dart
final events = await nostr.subscribe(
  NostrRequest(
    filters: [NostrFilter(kinds: [1], limit: 20)],
  ),
);
// events is List<NostrEvent> received before EOSE
```
