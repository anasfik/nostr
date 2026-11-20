---
sidebar_position: 5
description: Ask relays how many events match a filter with NIP-45, and read the typed count response.
---

# Count events (NIP-45)

NIP-45 lets you ask a relay how many events match a filter without transferring
the events. Relay support varies; a relay that does not implement it never
answers, and the request times out.

## Count through the client

`nostr.count` takes a `NostrCountEvent` and returns
`NostrResult<NostrCountResponse>`. The response's `count` field is an `int`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();
  await nostr.connect(const ['wss://relay.damus.io']);

  final result = await nostr.count(
    NostrCountEvent.fromPartialData(
      eventsFilter: NostrFilter(
        kinds: const [1],
        authors: [keyPairs.public],
      ),
    ),
  );

  result.fold(
    (response) => print('count: ${response.count}'),
    (failure) => print('${failure.code}: ${failure.message}'),
  );
}
```

`NostrCountEvent.fromPartialData` derives a deterministic subscription id from
the filter. It takes exactly one parameter:

| Parameter | Type | Meaning |
| --- | --- | --- |
| `eventsFilter` | `NostrFilter` | The filter to count |

`NostrCountResponse` has `subscriptionId` and `count`. The client answers with
the first `COUNT` received from a relay, so with several relays the number is
one relay's view of its own database, not a network-wide total.

## Count by tag

Counts use the same typed filter fields as subscriptions. There is no `tags`
map; use `t`, `p`, `e`, or `a`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final result = await nostr.count(
    NostrCountEvent.fromPartialData(
      eventsFilter: const NostrFilter(
        kinds: [1],
        t: ['nostr'],
      ),
    ),
  );

  print(result.valueOrNull?.count);
}
```

## Count at the low level

`sendCountEventToRelaysAsync` skips the result wrapper. It returns the first
response or throws `TimeoutException`; it also throws `StateError` when no
connected relay matches.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final countEvent = NostrCountEvent.fromPartialData(
    eventsFilter: const NostrFilter(kinds: [1], limit: 100),
  );

  final response = await nostr.relays.sendCountEventToRelaysAsync(
    countEvent,
    timeout: const Duration(seconds: 10),
  );

  print('${response.subscriptionId}: ${response.count}');
}
```

## Build and parse manually

`nostr.nips.nip45` is stateless and needs no signer. It builds requests and
parses raw `["COUNT", <subscription_id>, {"count": <n>}]` payloads.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nip45 = Nostr.instance.nips.nip45;

  final request = nip45.countEventFor(
    const NostrFilter(kinds: [1]),
  );
  print(request.serialized());

  final response = nip45.parseResponse(
    '["COUNT","sub-id",{"count":42}]',
  );
  print(response.count);
}
```

Related: [Subscribing to events](./subscribing-to-events) and
[NIP coverage](../../reference/nip-coverage).
