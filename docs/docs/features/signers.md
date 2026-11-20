---
sidebar_position: 1
description: How dart_nostr delegates signing, which signers ship with the package, and how binding a signer changes the NIP helpers.
---

# Signers

A signer is anything that can produce a signed event and perform NIP-44
encryption on behalf of one public key. The package never requires your private
key on the signing path: the `NostrEventSigner` interface is the seam where local
keys, browser extensions, or remote bunkers plug in.

## The interface

`NostrEventSigner` is an `abstract interface class` with four members. Implement
all four; there is no default encryption implementation.

| Member | Contract |
| --- | --- |
| `publicKey` | 64-character hex pubkey that signed events are attributed to |
| `sign(event)` | Computes `id` when missing, signs it, returns a new event with `sig` and `pubkey` set |
| `nip44Encrypt(plaintext, recipientPublicKey)` | NIP-44 v2 ciphertext |
| `nip44Decrypt(payload, senderPublicKey)` | Plaintext for a NIP-44 payload |

`sign` receives a template event and returns a new object; `NostrLocalKeySigner`
does not mutate the template. Implementations should keep `publicKey`
synchronous and stable.

## Local key signer

`NostrLocalKeySigner` wraps a `NostrKeyPairs` and implements all four members.
Use it in trusted environments only.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final keyPairs = NostrKeyPairs.generate();
  final signer = NostrLocalKeySigner(keyPairs);

  final template = NostrEvent(
    id: null,
    kind: 1,
    content: 'hello nostr',
    sig: null,
    pubkey: signer.publicKey,
    createdAt: DateTime.now(),
    tags: const [],
  );

  final signed = await signer.sign(template);
  print(signed.isVerified());
}
```

The package also ships `NostrNip07Signer`, which adapts a browser extension
provider to the same interface.

## Binding a signer

The NIP helpers under `nostr.nips` that need keys are built from one bound
signer. Binding happens in three places:

| Call | Effect |
| --- | --- |
| `connect(relays, signer: signer)` | Binds the signer, then connects |
| `addRelays(relays, signer: signer)` | Connects the new relays and binds the signer |
| `nostr.nips.bindSigner(signer)` | Binds without connecting; use this for offline signing |

`connect` binds the signer before it validates or dials relays. A failed connect,
including an empty or malformed relay list, therefore leaves the signer bound.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();

  nostr.nips.bindSigner(NostrLocalKeySigner(keyPairs));

  final note = await nostr.nips.social.createTextNote('written offline');
  print(note.id);

  nostr.nips.bindSigner(null);

  try {
    await nostr.nips.social.createTextNote('after unbind');
  } on StateError catch (error) {
    print(error.message);
  }
}
```

## Unbinding and rebinding

`disconnect()` clears connections and tracked subscriptions. It does not clear
the signer, so a later reconnect can reuse it. To revoke it explicitly, call
`nostr.nips.bindSigner(null)`.

`bindSigner` drops every cached signer-bound helper and rebuilds them from the
new signer on the next access. That has two consequences:

- Any helper object you captured earlier (for example `final social =
  nostr.nips.social;`) stays on the old signer. Re-read the getter after
  rebinding.
- Reading a signer-bound getter with no signer bound throws `StateError`. It does
  not fall back to an empty or anonymous identity.

The signer-bound accessors are listed in [NIP accessors](../reference/accessors).
Stateless helpers such as `nip19`, `nip05`, `nip11`, and `nip45` work without a
signer.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  print(nostr.nips.signer); // null

  nostr.nips.bindSigner(NostrLocalKeySigner(NostrKeyPairs.generate()));
  print(nostr.nips.signer?.publicKey);

  nostr.nips.bindSigner(null);
  print(nostr.nips.signer); // null
}
```

## Remote signers (NIP-46)

NIP-46 moves signing to a bunker over kind-24133 events. The pieces are the
`NostrNip46` helper, which encrypts and decrypts the request/response payloads,
and `NostrNip46Client`, which tracks pending calls and matches responses.

| Member | Purpose |
| --- | --- |
| `NostrNip46.kind` | `24133`, the only event kind used for requests and responses |
| `NostrNip46.parseBunkerUrl(url)` | Reads `pubkey`, `relay`, and `secret` from a `bunker://` URL |
| `NostrNip46Client({nip46, remotePubkey, publish, secret, timeout})` | Wires the client to a transport and a bunker |
| `connect({metadata})` | Approves the client; sends the connect secret |
| `getPublicKey()` | Returns and caches the remote user's pubkey |
| `signEvent(event)` | Sends an event template and verifies the returned signature |
| `send(method, params)` | Raw JSON-RPC call for other methods |
| `handleEvent(event)` | Feeds a received kind-24133 event to a pending call |
| `close()` | Rejects pending calls and clears cached state |

`NostrNip46Client` is not itself a `NostrEventSigner`. To use a bunker as the
signer for `nostr.nips`, implement the four members by delegating to it:

```dart
import 'package:dart_nostr/dart_nostr.dart';

class Nip46Signer implements NostrEventSigner {
  Nip46Signer(this.client, this.publicKey);

  final NostrNip46Client client;

  @override
  final String publicKey;

  @override
  Future<NostrEvent> sign(NostrEvent event) => client.signEvent(event);

  @override
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey) {
    return client.send(
      Nip46Method.nip44Encrypt,
      [recipientPublicKey, plaintext],
    );
  }

  @override
  Future<String> nip44Decrypt(String payload, String senderPublicKey) {
    return client.send(
      Nip46Method.nip44Decrypt,
      [senderPublicKey, payload],
    );
  }
}
```

Wiring the client requires a local key for the kind-24133 request events, plus a
subscription to the responses addressed to that local pubkey:

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  const bunkerUrl =
      'bunker://0000000000000000000000000000000000000000000000000000000000000000'
      '?relay=wss%3A%2F%2Frelay.damus.io';

  final pointer = NostrNip46.parseBunkerUrl(bunkerUrl);
  final nostr = Nostr();
  final clientKeys = nostr.keys.generateKeyPair();
  final clientSigner = NostrLocalKeySigner(clientKeys);

  await nostr.connect(pointer.relays, signer: clientSigner);

  final client = NostrNip46Client(
    nip46: nostr.nips.nip46,
    remotePubkey: pointer.pubkey,
    secret: pointer.secret,
    publish: (event) async {
      await nostr.publish(event);
    },
  );

  nostr.subscribe(
    NostrFilter(kinds: const [NostrNip46.kind], p: [clientKeys.public]),
  ).valueOrNull?.stream.listen(client.handleEvent);

  await client.connect();
  final remotePublicKey = await client.getPublicKey();

  print(remotePublicKey);
}
```

Wrap the connected client in the adapter shown above and bind it with
`nostr.nips.bindSigner(Nip46Signer(client, remotePublicKey))` to use the bunker
for the signer-bound NIP helpers.

The placeholder bunker pubkey above is syntactically valid but not a real
signer; replace it with the one from your bunker.

A remote signer must expose `nip44_encrypt` and `nip44_decrypt`, including for
payloads addressed to its own pubkey. NIP-37 and NIP-60 depend on that; see
[Encryption and DMs](./encryption-and-dms).

Related: [Keys management](../usage/keys-management/),
[NIP accessors](../reference/accessors), and
[Encryption and DMs](./encryption-and-dms).
