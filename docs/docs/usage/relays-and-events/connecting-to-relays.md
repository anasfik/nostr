---
sidebar_position: 1
description: Open relay WebSocket connections, tune timeouts and retries, and inspect or change the live relay set.
---

# Connecting to relays

A connection is owned by one `Nostr` instance. `Nostr.connect` opens a WebSocket
to each relay, waits for the handshake, and returns a `NostrResult<void>`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  final result = await nostr.connect(const [
    'wss://relay.damus.io',
    'wss://nos.lol',
  ]);

  result.fold(
    (_) => print('connected to ${nostr.connectedRelays.length} relays'),
    (failure) => print('${failure.code}: ${failure.message}'),
  );
}
```

The relay list is normalized before use: entries are trimmed, empty strings and
duplicates are dropped, and every remaining URL must start with `ws://` or
`wss://`. A list that fails these checks returns a failure with
`NostrFailureCode.invalidArgument`; no socket is opened.

The call succeeds when at least one relay answers. A partly reachable list is
still a success; inspect `liveRelayUrls` when you need to know which relays are
actually live.

## Connect with the default relays

`connectDefaults` connects to `Nostr.defaultRelays`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  final result = await nostr.connectDefaults();
  print(result.isSuccess);
  print(Nostr.defaultRelays);
}
```

## Inspect connection state

| Member | Type | Meaning |
| --- | --- | --- |
| `isConnected` | `bool` | Whether the last `connect` succeeded and `disconnect` has not run |
| `connectedRelays` | `List<String>` | Relays the client believes it connected to |
| `liveRelayUrls` | `List<String>` | Connected relay URLs read from the relay transport |

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connectDefaults();

  print(nostr.isConnected);
  print(nostr.connectedRelays);
  print(nostr.liveRelayUrls);
}
```

`connectedRelays` is an unmodifiable copy of the normalized list from the last
successful `connect`. It is not a health check: a relay that failed the handshake
while another succeeded stays in the list. `liveRelayUrls` reflects the
transport's view and drops relays that disconnected.

## Add and remove relays

`addRelays` connects new relays without disturbing existing ones. `removeRelay`
closes one relay and returns `true` when it was connected.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connect(const ['wss://relay.damus.io']);

  final added = await nostr.addRelays(const ['wss://nos.lol']);
  if (added.isFailure) {
    print(added.failureOrNull!.message);
  }

  final removed = await nostr.removeRelay('wss://nos.lol');
  print('removed: $removed');
}
```

`addRelays` does not retry. A failure means no new relay was reached, or the list
was empty or malformed. Relays that did connect stay connected.

## Authenticate while connecting (NIP-42)

Pass a signer to `connect` or `addRelays` so the transport can answer an `AUTH`
challenge from a relay. The signer is also bound to `nostr.nips`, which enables
the signer-bound NIP helpers.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final signer = NostrLocalKeySigner(nostr.keys.generateKeyPair());

  final result = await nostr.connect(
    const ['wss://relay.damus.io'],
    signer: signer,
  );

  print(result.isSuccess);
}
```

Binding rules, including what happens when `connect` fails, are covered in
[Signers](../../features/signers).

## Timeouts and retries

`NostrClientOptions` is read when the instance is constructed. There is no
setter and no way to change it afterwards, so per-connection tuning means
constructing your own `Nostr` rather than using `Nostr.instance`. The singleton
is built once with `const NostrClientOptions()`.

| Option | Default | Used by |
| --- | --- | --- |
| `connectionTimeout` | 10 seconds | `connect`, `addRelays` |
| `requestTimeout` | 15 seconds | `publish`, `count` |
| `retryPolicy` | `const NostrRetryPolicy()` (3 attempts, 100 ms initial delay, 5000 ms cap, doubling) | `connect`, `publish`, `count` |
| `failFast` | `false` | Try once, return the first failure |

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

  await nostr.connect(const ['wss://relay.damus.io']);
}
```

Retries apply to connecting, publishing, and counting only. `subscribe`,
`addRelays`, `removeRelay`, and `disconnect` attempt once. Set
`retryPolicy: NostrRetryPolicy.none()` or `failFast: true` to disable retrying.

## Disconnect

`disconnect` closes every relay and clears tracked subscriptions.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  await nostr.connectDefaults();

  final result = await nostr.disconnect();
  print(result.isSuccess);

  // The signer passed to connect stays bound after disconnect.
  nostr.nips.bindSigner(null);
}
```

## Relay information (NIP-11)

`relayInformationsDocumentNip11` fetches the relay's JSON description over HTTP:
`ws://` becomes `http://` and `wss://` becomes `https://`. Every field on
`RelayInformations` is nullable because relays omit most of the document. By
default a fetch error is rethrown; pass `throwExceptionIfExists: false` to get
`null` instead.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  final info = await nostr.relays.relayInformationsDocumentNip11(
    relayUrl: 'wss://relay.damus.io',
    throwExceptionIfExists: false,
  );

  if (info != null) {
    print(info.name);
    print(info.software);
    print(info.version);
    print(info.supportedNips);
    print(info.limitation?.maxMessageLength);
  }
}
```

| Field | Type | Notes |
| --- | --- | --- |
| `name`, `description`, `software`, `version` | `String?` | Free-form relay identity |
| `pubkey`, `contact` | `String?` | Operator contact details |
| `supportedNips` | `List<int>?` | NIP numbers the relay claims |
| `limitation` | `RelayLimitation?` | Message size, subscriptions, auth requirements |
| `fees` | `RelayFees?` | Admission and publication fees |
| `retention` | `List<RelayRetention>` | Retention policies, possibly empty |

Related: [Publishing events](./publishing-events),
[Subscribing to events](./subscribing-to-events), and
[Signers](../../features/signers).
