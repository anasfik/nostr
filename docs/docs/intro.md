---
sidebar_position: 1
sidebar_label: Overview
slug: /
description: dart_nostr is a Dart and Flutter SDK for the Nostr protocol. It covers relay connections, signing, publishing, subscriptions, and 87 of the 100 canonical NIPs.
---

# dart_nostr

`dart_nostr` is a Dart and Flutter SDK for the Nostr protocol. It connects to relays, signs and publishes events, manages subscriptions, handles keys, and implements most NIPs.

## Install

```yaml
dependencies:
  dart_nostr: ^11.2.0
```

Then run `dart pub get` or `flutter pub get`.

## What it covers

| Area | What you get |
|---|---|
| Keys | Generate, derive, validate, sign, verify, mnemonic derivation |
| NIP-19 | `npub`, `nsec`, `nprofile`, `nevent`, `naddr` |
| Relays | Connect, add, remove, disconnect, retry, NIP-11 documents, NIP-42 auth |
| Events | Build, sign, publish, delete, verify, NIP-13 proof of work |
| Subscriptions | Typed filters, event streams, subscription tracking, EOSE |
| Counting | NIP-45 count requests |
| Encryption | NIP-44, NIP-04, NIP-17 gift-wrapped DMs |
| Signers | Local keys, plus the `NostrEventSigner` interface for NIP-07, NIP-46, and NIP-55 |
| Identity | NIP-05 resolution and verification |

The API has two tiers. The facade (`nostr.connect`, `nostr.publish`, `nostr.subscribe`, `nostr.nips.<nip>`) is what application code should use. The `nostr.relays` and `nostr.services` surfaces expose raw relay operations for protocol work.

## Protocol coverage

Coverage is measured against the canonical NIPs repository at commit `bec0fc8`, which contains 100 NIPs.

| Status | Count |
|---|---|
| Supported | 87 |
| Partial | 4 — 12, 20, 33, 40 |
| Missing | 9 — 08, 15, 16, 26, 31, 72, 90, BE, EE |

The partial NIPs have a specific gap each. NIP-12 has typed `e`/`p`/`t`/`a` filters but no generic tag API. NIP-20 surfaces relay `OK` receipts through the event model rather than a dedicated API. NIP-33 builds addressable events with `d` and `a` tags but ships no replacement or deletion helper. NIP-40 expiration tags are written and read by several NIP helpers, but there is no general expiration builder.

Eight of the nine missing NIPs are marked unrecommended upstream, so they are built only on demand. NIP-16 is the exception: it is still mandatory, and relay-side replaceable/ephemeral semantics are not modelled by a general classifier. If you need one of these, open an issue rather than assuming a helper exists.

## What it is not

- It gives no guarantee that a relay is live, reachable, or storing anything. Relays can drop, reject, or time out, and the API reports what happened rather than hiding it.
- NIP-61 support checks nutzap structure and P2PK locks. It does not compute Cashu DLEQ proofs and does not talk to a mint.
- There is no wallet or Lightning implementation. The package builds and parses events; moving sats is your application's job.

## Errors: what throws and what returns

Network operations return `NostrResult<T>`, a sealed success/failure type. They do not throw on relay or transport problems.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final result = await nostr.connect(['wss://relay.damus.io']);

  result.fold(
    (_) => print('connected'),
    (failure) => print('${failure.code}: ${failure.message}'),
  );
}
```

Not everything returns a result. Three surfaces throw deliberately:

- Constructors and builders throw `ArgumentError` on invalid input, for example a malformed private key or an invalid builder argument.
- Signer-bound NIP accessors throw `StateError` when no signer is bound, for example `nostr.nips.social` before `bindSigner` or `connect(signer: ...)`.
- `nostr.utils.verifyNip05` throws `Nip05VerificationException` when the lookup fails.

## Where to go next

- [Installation](./installation) — add the package to a project
- [Core concepts](./must-know) — instance model, signers, results, relay state
- [Quick start](./quick-start) — a complete first-run program
