---
sidebar_position: 3
description: Drive the relay pool directly and inject a custom transport for tests.
---

# Low-level API

The facade (`nostr.connect`, `nostr.publish`, `nostr.subscribe`) is the normal entry point. `nostr.relays` and `nostr.services` expose the layer beneath it when the facade does not fit.

## When to use it

- You need every relay's `OK` instead of the first one.
- You want a subscription that is not tracked by the facade's subscription manager.
- You need relay information documents, or per-relay connect and disconnect.
- You are building another abstraction on top of the package.

The low-level relay methods operate on the pool that `nostr.connect(...)` starts. Call connect first: without it there is no registered socket, and calls that do not pass an explicit `relays` list hit the pool's null check.

## `nostr.relays`

| Method | Returns | Notes |
|---|---|---|
| `sendEventToRelays(event, {relays, onOk})` | `Future<void>` | Fire and forget; `onOk` fires per relay |
| `sendEventToRelaysAsync(event, {required timeout, relays})` | `Future<NostrEventOkCommand>` | Resolves with the first `OK` |
| `startEventsSubscription({required request, onEose, relays})` | `NostrEventsStream` | Untracked by `nostr.subscribe` |
| `startEventsSubscriptionAsync({required request, required timeout, onEose, relays})` | `Future<List<NostrEvent>>` | Collects until the first EOSE or the timeout |
| `closeEventsSubscription(subscriptionId, [relay])` | `void` | Pass a relay to close on one relay only |
| `relayInformationsDocumentNip11({required relayUrl})` | `Future<RelayInformations?>` | NIP-11 document |
| `connectAdditionalRelays(relays, {required connectionTimeout, signer})` | `Future<void>` | Keeps existing connections |
| `disconnectFromRelay(relayUrl)` | `Future<bool>` | `true` when the relay was connected |
| `disconnectFromRelays()` | `Future<bool>` | Closes the pool |

`sendEventToRelays` throws if the event has no id or if no connected relay matches the optional `relays` list. It returns as soon as the frames are written, so use `sendEventToRelaysAsync` when you need one `OK` before continuing.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final keys = nostr.keys.generateKeyPair();

  final connected = await nostr.connect(const ['wss://relay.damus.io']);
  if (connected.isFailure) {
    print(connected.failureOrNull!.message);
    return;
  }

  final note = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: keys,
  );

  await nostr.relays.sendEventToRelays(
    note,
    onOk: (relay, ok) {
      print('$relay accepted=${ok.isEventAccepted} ${ok.message}');
    },
  );

  final result = await nostr.relays.sendEventToRelaysAsync(
    note,
    timeout: const Duration(seconds: 10),
  );
  print(result.isEventAccepted);
}
```

## Raw subscriptions and EOSE

`startEventsSubscription` returns a `NostrEventsStream` with a `stream`, a `subscriptionId`, the originating `request`, and a `close()` method. EOSE arrives through the `onEose` callback, which receives the relay URL and a `NostrRequestEoseCommand`. That command carries `subscriptionId` and NIP-67 `hints`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final subscription = nostr.relays.startEventsSubscription(
    request: NostrRequest(
      filters: [const NostrFilter(kinds: [1], limit: 10)],
    ),
    onEose: (relay, eose) {
      print('EOSE from $relay for ${eose.subscriptionId}, hints=${eose.hints}');
      nostr.relays.closeEventsSubscription(eose.subscriptionId);
    },
  );

  final listener = subscription.stream.listen((event) {
    print(event.content);
  });

  await Future<void>.delayed(const Duration(seconds: 5));
  await listener.cancel();
  subscription.close();

  await nostr.disconnect();
}
```

The facade does not expose EOSE at all: the stream returned by `nostr.subscribe` never reports it. If you need to wait for a result set, use `startEventsSubscriptionAsync`, which returns the events collected up to the first EOSE from any relay, or up to the timeout. `shouldThrowErrorOnTimeoutWithoutEose` defaults to `true`, so a relay that never sends EOSE surfaces as a `TimeoutException`. The helper cancels its own stream listener but does not close the relay-side subscription; call `closeEventsSubscription` if you need the relay to stop sending.

## `nostr.services`

`nostr.services` is the container the instance was built from:

| Field | Type | Role |
|---|---|---|
| `client` | `NostrClient` | The typed facade behind `nostr.connect`, `publish`, `count`, `subscribe` |
| `keys` | `NostrKeys` | Same object as `nostr.keys` |
| `relays` | `NostrRelays` | Same object as `nostr.relays` |
| `utils` | `NostrUtils` | Same object as `nostr.utils` |
| `bech32` | `NostrBech32` | Same object as `nostr.bech32` |
| `nips` | `NostrNips` | Same object as `nostr.nips` |
| `relayPool` | `RelayPoolManager` | Relay bookkeeping |
| `subscriptionManager` | `SubscriptionManager` | Facade subscription tracking |
| `connectionPool` | `ConnectionPoolManager` | Reconnect bookkeeping |
| `errorRecovery` | `ErrorRecoveryManager` | Retry and recovery state |
| `clientOptions` | `NostrClientOptions` | The options the client uses |
| `logger` | `NostrLogger` | Shared logger |
| `relayTransport` | `NostrRelayTransport?` | The injected transport, or `null` when the default is used |

## Custom transport

The transport is an interface, `NostrRelayTransport`, with eight methods: `connect`, `publish`, `count`, `subscribe`, `closeSubscription`, `addRelays`, `removeRelay`, and `disconnect`. Implement it and pass the instance as `NostrServices.relayTransport`; `Nostr` has no `transport` parameter.

`NostrServices` requires a logger. `NostrDebugOptions`, which `NostrLogger` needs, is not exported from the package root, so the shortest valid wiring reuses the logger already on an instance.

```dart
import 'package:dart_nostr/dart_nostr.dart';

class InMemoryTransport implements NostrRelayTransport {
  @override
  Future<void> connect({
    required List<String> relays,
    required Duration connectionTimeout,
    NostrEventSigner? signer,
  }) async {}

  @override
  Future<NostrEventOkCommand> publish(
    NostrEvent event, {
    required Duration timeout,
    List<String>? relays,
  }) async {
    return NostrEventOkCommand(
      eventId: event.id ?? '',
      isEventAccepted: true,
      message: 'stored locally',
    );
  }

  @override
  Future<NostrCountResponse> count(
    NostrCountEvent countEvent, {
    required Duration timeout,
    List<String>? relays,
  }) async {
    return NostrCountResponse(
      subscriptionId: countEvent.subscriptionId,
      count: 0,
    );
  }

  @override
  NostrEventsStream subscribe({
    required NostrRequest request,
    List<String>? relays,
  }) {
    return NostrEventsStream(
      stream: const Stream<NostrEvent>.empty(),
      subscriptionId: request.subscriptionId ?? 'local',
      request: request,
    );
  }

  @override
  void closeSubscription(String subscriptionId, [String? relay]) {}

  @override
  Future<void> addRelays({
    required List<String> relays,
    required Duration connectionTimeout,
    NostrEventSigner? signer,
  }) async {}

  @override
  Future<bool> removeRelay(String relayUrl) async => false;

  @override
  Future<bool> disconnect() async => true;
}

Future<void> main() async {
  final nostr = Nostr(
    services: NostrServices(
      logger: Nostr.instance.services.logger,
      relayTransport: InMemoryTransport(),
    ),
  );

  await nostr.connect(const ['wss://relay.invalid']);

  final note = NostrEvent.fromPartialData(
    kind: 1,
    content: 'local only',
    keyPairs: nostr.keys.generateKeyPair(),
  );

  final result = await nostr.publish(note);
  print(result.valueOrNull?.message); // stored locally
}
```

`NostrLocalKeySigner` and any other signer you implement go through the same facade, so a transport swap does not change signing behaviour.

## Isolated instances

Each `Nostr()` call builds its own services, transport, subscription manager, and signer binding. Two instances do not share connections or subscriptions, and disconnecting one leaves the other connected.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final accountA = Nostr();
  final accountB = Nostr();

  await accountA.connect(const ['wss://relay.damus.io']);
  await accountB.connect(const ['wss://nos.lol']);

  print(accountA.connectedRelays);
  print(accountB.connectedRelays);

  await accountA.disconnect();
  print(accountB.isConnected); // true
}
```

Two things are process-wide rather than per instance:

- The key-pair cache is `static`, so instances that use the same private key share a `NostrKeyPairs` object. Clear it with `await nostr.keys.freeAllResources()`.
- Custom transports are only as isolated as the object you inject; passing one transport to two instances shares it.

There is no `dispose` method on `Nostr` in 11.2.0. To release an instance, call `await nostr.disconnect()`, or `await nostr.relays.freeAllResources()` to close the pool and clear its registry, then clear the key cache if the keys are no longer needed.

## Related

- [Client options](./client-options.md) for timeouts and retries
- [Error handling](./error-handling.md) for `NostrResult` and `NostrFailure`
- [Subscribing to events](../relays-and-events/subscribing-to-events.md) for the facade subscription API
