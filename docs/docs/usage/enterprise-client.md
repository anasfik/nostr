# Enterprise client

The package now exposes a production-oriented facade through `Nostr.client`.

## Why use it

Use the enterprise client when you need:

- typed success/failure results
- centralized timeout and retry configuration
- dependency injection for fake transports and tests
- active subscription tracking
- predictable disconnect and cleanup behavior

## Example

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
    ),
  );

  final connectResult = await nostr.client.connect([
    'wss://relay.damus.io',
    'wss://nos.lol',
  ]);

  if (connectResult.isFailure) {
    print(connectResult.failureOrNull);
    return;
  }

  final keyPair = nostr.services.keys.generateKeyPair();
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'GM from dart_nostr enterprise client',
    keyPairs: keyPair,
  );

  final publishResult = await nostr.client.publish(event);
  publishResult.fold(
    (ok) => print('Relay accepted event: ${ok.message}'),
    (failure) => print('Publish failed: $failure'),
  );
}
```

## Subscription lifecycle

`NostrClient.subscribe()` automatically registers subscriptions in the shared `SubscriptionManager`.

```dart
final subscriptionResult = nostr.client.subscribe(
  NostrRequest(
    filters: [
      NostrFilter(kinds: [1], limit: 50),
    ],
  ),
);

subscriptionResult.fold(
  (stream) {
    final active = nostr.client.getActiveSubscriptions();
    final stats = nostr.client.getSubscriptionStatistics();

    print('Active subscriptions: ${active.length}');
    print('Total tracked events: ${stats.totalEventCount}');

    stream.stream.listen(print);
    stream.close();
  },
  (failure) => print(failure),
);
```

## Migration guidance

Existing low-level APIs remain available under `Nostr.services.*`.

Preferred usage:

- use `Nostr.client.connect()` instead of directly calling relay initialization for standard app flows
- use `Nostr.client.publish()` and `Nostr.client.count()` for typed failures
- use `Nostr.client.subscribe()` when you want lifecycle tracking and simpler cleanup
- keep `Nostr.services.relays` for low-level protocol orchestration and advanced relay behavior
