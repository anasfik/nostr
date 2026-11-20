---
sidebar_position: 1
description: Handle typed failures with NostrResult and NostrFailure.
---

# Error handling

The facade methods `connect`, `addRelays`, `disconnect`, `publish`, `count`, and `subscribe` return `NostrResult<T>` instead of throwing. A result is either a success holding `T` or a failure holding a `NostrFailure`.

## `NostrResult<T>`

`NostrResult` is a sealed class with the concrete subclasses `NostrSuccess<T>` and `NostrFailureResult<T>`. You rarely name the subclasses; the accessors below cover most code.

| Member | Returns | Notes |
|---|---|---|
| `isSuccess` | `bool` | |
| `isFailure` | `bool` | |
| `valueOrNull` | `T?` | `null` on failure |
| `failureOrNull` | `NostrFailure?` | `null` on success |
| `fold(onSuccess, onFailure)` | `R` | Both callbacks must return the same type |
| `map(mapper)` | `NostrResult<R>` | Transforms a success, passes a failure through |
| `flatMap(mapper)` | `NostrResult<R>` | Chains another result-returning call |

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final result = await nostr.connect(const ['wss://relay.damus.io']);

  final description = result.fold(
    (_) => 'connected',
    (failure) => '${failure.code.name}: ${failure.message}',
  );
  print(description);

  final failure = result.failureOrNull;
  if (failure != null) {
    if (failure.isRetryable) {
      print('retryable, context: ${failure.context}');
    } else {
      print('not retryable: ${failure.context}');
    }
  }

  final connected = result.isSuccess;
  print(connected);
}
```

## `NostrFailure`

| Field | Type | Meaning |
|---|---|---|
| `code` | `NostrFailureCode` | Enum value, not a string; use `.name` for the identifier |
| `message` | `String` | Human-readable description |
| `cause` | `Object?` | Original exception when one exists |
| `stackTrace` | `StackTrace?` | Original stack trace |
| `context` | `Map<String, Object?>` | Structured data; the client adds `operation` and `relays` |
| `isRetryable` | `bool` | Whether another attempt can plausibly succeed |

`NostrFailure` also has `copyWith`. The factory constructors are `NostrFailure.invalidArgument`, `.connection`, `.invalidState`, `.timeout`, `.protocol`, `.serialization`, and `.unknown`. There is no factory for `permissionDenied` or `unavailable`; construct those with the main constructor if your own code needs them.

## Failure codes

| Code | Raised when |
|---|---|
| `invalidArgument` | Caller input is wrong: empty relay list, URL without `ws://`/`wss://`, empty event id, empty filter |
| `invalidState` | The client is not connected, or the operation is not valid in the current state |
| `connection` | Socket, DNS, or TLS failure while connecting or sending |
| `timeout` | The operation exceeded `requestTimeout` or a relay-level timeout |
| `protocol` | A relay or transport reported a protocol-level failure |
| `serialization` | A `FormatException` occurred while decoding relay data |
| `permissionDenied` | Authorization refused |
| `unavailable` | A required dependency or transport is unavailable |
| `unknown` | An error that did not map to another code |

The client itself emits `invalidArgument`, `invalidState`, `connection`, `timeout`, `serialization`, and `unknown`. `protocol` is emitted only when a custom transport throws `NostrException`, and `permissionDenied` and `unavailable` are not emitted by the bundled transport at all. A relay rejecting your event is also not a failure: see below.

## A rejected event is a success result

`publish` returns the first `OK` received from any relay. A relay that answers `OK:false` still produces `NostrSuccess<NostrEventOkCommand>`, with `isEventAccepted == false` and the relay's reason in `message`. Check the flag, not only `isSuccess`.

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

  final result = await nostr.publish(note);

  result.fold(
    (ok) {
      if (ok.isEventAccepted ?? false) {
        print('accepted by a relay');
      } else {
        print('rejected: ${ok.message}');
      }
    },
    (failure) => print('${failure.code.name}: ${failure.message}'),
  );
}
```

`publish` does not aggregate per-relay answers. If you need every relay's `OK`, use `nostr.relays.sendEventToRelays` with its `onOk` callback, covered in [Low-level API](./low-level-api.md).

## Retries

`connect`, `publish`, and `count` are retried according to `NostrClientOptions.retryPolicy`; the other facade calls are single-attempt. The default policy makes three total attempts. See [Client options](./client-options.md) for the policies and for `failFast`.

## Exceptions you still have to handle

Not every surface returns a result:

- `NostrKeyPairs(private:)` and `generateKeyPairFromExistingPrivateKey` throw `ArgumentError` for a malformed private key.
- `nostr.nips.*` getters that need a signer throw `StateError` until `connect` or `addRelays` binds one, or until you call `nostr.nips.bindSigner(signer)`.
- Social and NIP builders throw `ArgumentError` for invalid combinations, for example a comment with no target or two root families.
- `nostr.utils.pubKeyFromIdentifierNip05` and `verifyNip05` throw on a failed HTTP lookup.

## Related

- [Client options](./client-options.md) for timeouts, retry policies, and `failFast`
- [Low-level API](./low-level-api.md) for the relay methods behind the facade
- [Sign and verify](../keys-management/sign-verify.md) for the `ArgumentError` cases around keys
