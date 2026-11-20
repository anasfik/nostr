---
sidebar_label: Core concepts
sidebar_position: 3
description: How instances, services, signers, results, relay connections, and NIP modules fit together in dart_nostr.
---

# Core concepts

Six things explain most of the API: how instances are created, where services live, what a signer is, how results carry failures, how relay connections are tracked, and which NIP helpers need a signer. Each section below covers one.

## Instances

`Nostr()` creates an instance with its own client, relay transport, subscription manager, and pending connections. `Nostr.instance` returns a shared instance that is created the first time you touch it. Use the constructor when you want to own the lifecycle.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final isolated = Nostr();
  final shared = Nostr.instance;

  print(identical(isolated, shared)); // false
}
```

One resource is not per instance. The key-pair cache is `static`, shared by every instance and capped at 32 entries with FIFO eviction. Two instances that derive the same private key share the cached `NostrKeyPairs`. Use the constructor for connection isolation, not for key isolation.

## Services

Every capability hangs off a getter. The facade methods are thin wrappers over `nostr.client`.

| Getter | Type | Covers |
|---|---|---|
| `nostr.keys` | `NostrKeys` | Generate, derive, validate, sign, verify |
| `nostr.utils` | `NostrUtils` | NIP-05 lookups, proof-of-work difficulty, random hex |
| `nostr.bech32` | `NostrBech32` | NIP-19 encode and decode |
| `nostr.relays` | `NostrRelays` | Raw relay pool, low-level subscriptions, NIP-11 |
| `nostr.subscriptions` | `SubscriptionManager` | Subscription tracking and statistics |
| `nostr.client` | `NostrClient` | The typed facade behind `connect` and `publish` |
| `nostr.nips` | `NostrNips` | Per-NIP helpers |

`nostr.connect`, `nostr.addRelays`, `nostr.removeRelay`, `nostr.disconnect`, `nostr.publish`, `nostr.count`, `nostr.subscribe`, `nostr.subscribeFilters`, and `nostr.subscribeRequest` all delegate to `nostr.client`. The relay pool underneath is the same one `nostr.relays` drives.

## Signers

A signer is anything that implements `NostrEventSigner`. The package ships `NostrLocalKeySigner`, which wraps a `NostrKeyPairs`. Implement the interface yourself to delegate to a NIP-07 extension, a NIP-46 bunker, or a NIP-55 Android app, so the library never sees the private key.

```dart
abstract interface class NostrEventSigner {
  String get publicKey;
  Future<NostrEvent> sign(NostrEvent event);
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey);
  Future<String> nip44Decrypt(String payload, String senderPublicKey);
}
```

`sign` returns a fully signed event: it computes the id when missing and sets `id` and `sig`. The two NIP-44 methods are what gift-wrap and encrypted-DM helpers use.

Access to the signer is a binding, not a constructor argument on `NostrNips`. `connect(signer: ...)` and `addRelays(signer: ...)` bind it for you. `bindSigner` rebuilds every signer-bound helper, so a helper you stored before rebinding belongs to the old signer. Binding happens before the connection attempt, so a failed `connect` can still leave a signer bound.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final keys = nostr.keys.generateKeyPair();
  final signer = NostrLocalKeySigner(keys);

  nostr.nips.bindSigner(signer);

  final note = await nostr.nips.social.createTextNote('signed locally');
  print(note.id);
  print(signer.publicKey == note.pubkey); // true

  nostr.nips.bindSigner(null);
}
```

`disconnect()` clears connections only. The signer stays bound so it can be reused after reconnecting. Call `bindSigner(null)` when the identity should stop signing.

## Results

`NostrResult<T>` is sealed with two cases, `NostrSuccess<T>` and `NostrFailureResult<T>`. It exposes `isSuccess`, `isFailure`, `valueOrNull`, `failureOrNull`, `fold`, `map`, and `flatMap`.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();

  // Not connected yet: this returns a failure, it does not throw.
  final result = nostr.subscribe(const NostrFilter(kinds: [1], limit: 20));

  print(result.isSuccess); // false
  print(result.valueOrNull); // null
  print(result.failureOrNull?.code); // NostrFailureCode.invalidState

  result.fold(
    (stream) => print('subscribed: ${stream.subscriptionId}'),
    (failure) => print('${failure.code}: ${failure.message}'),
  );
}
```

`NostrFailure` carries:

| Field | Type | Meaning |
|---|---|---|
| `code` | `NostrFailureCode` | Category, not a string |
| `message` | `String` | Human-readable description |
| `context` | `Map<String, Object?>` | Structured detail, for example the relay or the operation |
| `cause` | `Object?` | Underlying error, when there is one |
| `stackTrace` | `StackTrace?` | Original trace, when captured |
| `isRetryable` | `bool` | Whether a retry can plausibly succeed |

`NostrFailureCode` has nine values: `invalidArgument`, `invalidState`, `connection`, `timeout`, `protocol`, `serialization`, `permissionDenied`, `unavailable`, `unknown`. Factories exist for all but `permissionDenied` and `unavailable`; construct those with the main `NostrFailure` constructor if you need them.

## Relay connections

There are two entry points, and they are not equivalent.

`nostr.connect(relayUrls, signer: ...)` is the facade. It applies `NostrClientOptions` timeouts and retry policy, binds the signer for NIP-42 authentication, verifies that at least one relay actually connected, and only then marks the client connected. It returns `NostrResult<void>`.

`nostr.relays.init(relaysUrl: [...])` is the raw pool. It opens the sockets, installs callbacks, and returns `Future<void>`. It ignores connection exceptions by default, so it resolves even when relays are down. It does not set the client's connection state, and it accepts a signer for NIP-42 challenges.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  await nostr.relays.init(relaysUrl: ['wss://relay.damus.io']);

  print(nostr.relays.connectedRelayUrls);
  print(nostr.isConnected); // false: the facade client has not connected

  await nostr.relays.disconnectFromRelays();
}
```

Connection state is reported per layer:

- `nostr.isConnected` and `nostr.connectedRelays` describe the facade client.
- `nostr.liveRelayUrls` is the client's current view of live relays.
- `nostr.relays.connectedRelayUrls` is what the raw pool believes is connected.
- `nostr.activeSubscriptions` and `nostr.subscriptionStatistics` describe tracked subscriptions.

Pick one entry point per session. `connect` already calls `init` on the same pool with registry clearing enabled, so calling both re-initializes the sockets.

## NIP modules

All NIP helpers live under `nostr.nips`. They split into two kinds.

**Stateless helpers** hold no per-caller state and are constructed once: `nip05`, `nip06`, `nip07`, `nip11`, `nip19`, `nip21`, `nip24`, `nip27`, `nip29`, `nip30`, `nip35`, `nip36`, `nip42`, `nip43`, `nip45`, `nip48`, `nip55`, `nip66`, `nip70`, `nip73`, `nip77`, `nip92`, `nip5a`, `nip7d`, `nipa3`, `nipc0`, `nipc7`, `nipAD`.

**Signer-bound helpers** are built on first access from the bound signer and discarded when you rebind: `nip04`, `nip17`, `nip28`, `nip32`, `nip34`, `nip37`, `nip38`, `nip39`, `nip46`, `nip47`, `nip52`, `nip53`, `nip54`, `nip56`, `nip57`, `nip58`, `nip60`, `nip61`, `nip62`, `nip64`, `nip68`, `nip69`, `nip71`, `nip75`, `nip78`, `nip85`, `nip86`, `nip87`, `nip88`, `nip89`, `nip94`, `nip96`, `nip98`, `nip99`, `nipa0`, `nipa4`, `nipB0`, `nipB7`, `nipCC`, `nipcd`, `nipf4`, `blossom`, `social`.

Some NIPs are not on `nips` at all because they need no module: NIP-01 lives in the event and request models, NIP-03 is the `NostrEvent.ots` field, NIP-13 is `NostrProofOfWork`, NIP-44 is the static `Nip44` class, NIP-49 is `NostrNip49`, NIP-50 is `NostrFilter.search`, NIP-59 is the static `Nip59` class, and NIP-67 hints travel on `NostrRequestEoseCommand.hints`.

## What throws where

| Surface | Behavior |
|---|---|
| `NostrKeyPairs(private: ...)`, `nostr.keys.generateKeyPairFromExistingPrivateKey` | `ArgumentError` when the key is not 64 hex characters |
| Signer-bound getters such as `nostr.nips.social` or `nostr.nips.nip17` | `StateError` when no signer is bound |
| `nostr.utils.verifyNip05` | `Nip05VerificationException` when the lookup fails; asserts on a malformed identifier in debug builds |
| Social and NIP builders with invalid arguments | `ArgumentError`, for example empty comment content or conflicting root scopes |
| `connect`, `connectDefaults`, `addRelays`, `disconnect`, `publish`, `count`, `subscribe`, `subscribeFilters`, `subscribeRequest` | A failure result; they do not throw on invalid input or network errors |
| `nostr.relays.init(relaysUrl: [])` | An `assert` in debug builds; asserts are stripped in release, so validate the list yourself |

Everything else returns plain values. The low-level `nostr.relays` methods are the exception: some signal failure by throwing rather than returning a result. `relays.sendEventToRelays`, for example, throws when the event has no id.
