---
sidebar_position: 4
description: A complete first-run program covering keys, connection, publishing, subscribing, and shutdown.
---

# Quick start

This program creates an identity, connects to two relays, publishes a text note, listens for notes, and shuts down cleanly.

## The program

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  final keys = nostr.keys.generateKeyPair();
  final signer = NostrLocalKeySigner(keys);

  final connection = await nostr.connect(
    ['wss://relay.damus.io', 'wss://nos.lol'],
    signer: signer,
  );

  final connectFailure = connection.failureOrNull;
  if (connectFailure != null) {
    print('${connectFailure.code}: ${connectFailure.message}');
    return;
  }

  final event = await nostr.nips.social.createTextNote('Hello Nostr');

  final result = await nostr.publish(event);
  result.fold(
    (receipt) => print('accepted: ${receipt.isEventAccepted}'),
    (failure) => print('publish failed: ${failure.message}'),
  );

  final stream = nostr
      .subscribe(const NostrFilter(kinds: [1], limit: 20))
      .valueOrNull;
  stream?.stream.listen((event) => print(event.content));

  await Future<void>.delayed(const Duration(seconds: 5));

  stream?.close();
  nostr.closeAllSubscriptions();
  await nostr.disconnect();
  nostr.nips.bindSigner(null);
}
```

## What each step does

### Create an instance

`Nostr()` returns a new instance with its own client, relay transport, and subscription manager. `Nostr.instance` returns a lazily created shared instance. Use the constructor when you want explicit ownership; the two differ in scope, not in capabilities.

### Create keys and a signer

`nostr.keys.generateKeyPair()` returns a `NostrKeyPairs` with hex-encoded `public` and `private` fields. `NostrLocalKeySigner` wraps it in the `NostrEventSigner` interface, which is what the signer-bound NIP helpers require. Store the private key yourself; nothing is persisted for you.

### Connect

`connect` takes the relay list and an optional signer. Passing the signer does two things: it enables NIP-42 authentication when a relay sends an AUTH challenge, and it binds the signer to `nostr.nips`. If every relay fails, you get a failure with `code` and `message`; check `failureOrNull` before continuing.

### Publish

`nostr.nips.social.createTextNote` builds and signs a kind-1 event through the bound signer. `nostr.publish` sends it to the connected relays and resolves with a `NostrResult<NostrEventOkCommand>`. `isEventAccepted` is the relay's boolean answer, and `message` carries its reason when the answer is false. A null `isEventAccepted` means the relay sent an OK without a status.

### Subscribe

`nostr.subscribe` is synchronous: on success it registers the filter and returns `NostrResult<NostrEventsStream>` without waiting for the first event. `valueOrNull` is the stream holder, or null when the subscription could not start, which happens when the client is not connected or the filter is empty. The facade stream is a broadcast stream, so you can attach more than one listener. Events arrive until you close the subscription.

### Shut down

`stream.close()` closes that one subscription. `nostr.closeAllSubscriptions()` closes everything the client tracks. `nostr.disconnect()` closes tracked subscriptions, closes relay connections, and clears connection state.

`nostr.nips.bindSigner(null)` is required because `disconnect` does not clear the signer. The signer stays bound so you can reconnect and keep using the same identity. That is convenient during a session and wrong at shutdown: the signer-bound helpers would still hold your key pair. Clear it explicitly when the identity should no longer be usable.

For an application that is shutting down for good, call `await nostr.dispose()` instead of, or after, `disconnect()`. It clears the shared key cache and frees the relay pool; calling it twice is safe.

## Next steps

- [Core concepts](./must-know.md) — instance model, signer contract, results, relay state
- [Key management](./usage/keys-management/index.md) — derive, validate, sign, and encode keys
- [Connecting to relays](./usage/relays-and-events/connecting-to-relays.md) — options, timeouts, retries
- [Publishing events](./usage/relays-and-events/publishing-events.md) — event kinds and OK handling
- [Subscribing to events](./usage/relays-and-events/subscribing-to-events.md) — filters, streams, EOSE
