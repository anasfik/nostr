# dart_nostr

[![pub package](https://img.shields.io/pub/v/dart_nostr.svg)](https://pub.dev/packages/dart_nostr)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![SDK](https://img.shields.io/badge/SDK-%E2%89%A53.0.0-green)](https://dart.dev)

> [!NOTE]
> Maintained by **[Anas Fikhi](https://gwhyyy.com)** — Flutter & AI engineer. Available for contract work: [work@gwhyyy.com](mailto:work@gwhyyy.com) · [book a call](https://calendly.com/ffikhi-aanas/30min)

A production-grade Dart & Flutter SDK for Nostr: relay transport, event signing, typed subscription streams, encryption, DMs, zaps, media uploads and identity tooling behind one import.

**NIP coverage is documented, not implied:** 87 of the 100 canonical NIPs have code in this package, 4 are partial, and the remaining 9 are listed in the [coverage table](#nip-coverage) with a [roadmap](#missing-nips-roadmap). Coverage was measured against [`nostr-protocol/nips` @ `bec0fc8`](https://github.com/nostr-protocol/nips/tree/bec0fc8).

**Works everywhere Dart runs:** Android · iOS · Web/WASM · macOS · Windows · Linux.

---

## Why dart_nostr

- **Explicit NIP coverage** — every canonical NIP is marked supported, partial or missing, with the Dart entry point and handled kinds. No "25+ NIPs" hand-waving.
- **Spec-vector verified crypto** — NIP-44 v2 passes every official test vector; NIP-49 decrypts the reference payload byte-for-byte; NIP-13 PoW mining is verified on real event ids.
- **Typed error handling** — `NostrResult<T>` instead of exceptions; nothing throws unexpectedly.
- **Resilient transport** — exponential reconnect backoff with jitter, replay of active subscriptions after reconnect, bounded caches, fail-fast on dead relays, automatic NIP-42 authentication.
- **Pluggable signing** — local keys plus NIP-07 browser, NIP-46 bunker and NIP-55 Android bridges behind one `NostrEventSigner` interface.
- **Per-NIP accessors** — `Nostr.instance.nips.<nip>` for stateless helpers and `social`, `blossom`, `nip42`, `nip45` for the rest.
- **Tested as used** — 992 default tests (unit + in-process fake relay) run in CI; a live-relay suite is opt-in.

## Installation

```bash
flutter pub add dart_nostr
# or
dart pub add dart_nostr
```

```yaml
dependencies:
  dart_nostr: ^11.2.0
```

## Quick start

Every NIP helper hangs off the shared instance:

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr.instance;
  final nips = nostr.nips;

  // 1. Identity (NIP-19 for encoding, NIP-06 for mnemonic derivation).
  final keyPair = nostr.keys.generateKeyPair();
  final signer = NostrLocalKeySigner(keyPair);
  final npub = nips.nip19.encodePublicKeyToNpub(keyPair.public);

  // 2. Connect. The signer also answers NIP-42 AUTH challenges.
  final connected = await nostr.connect([
    'wss://relay.damus.io',
    'wss://nos.lol',
  ], signer: signer);

  if (connected.isFailure) {
    print('could not reach any relay: ${connected.failureOrNull?.message}');
    return;
  }

  // 3. Build a signed note through the NIP-01/10/27 social builder,
  //    then publish it and inspect relay OK receipts.
  final note = await nips.social.createTextNote(
    'Hello nostr from $npub!',
    mentionedPubkeys: const [],
  );
  final ok = await nostr.publish(note);
  ok.fold(
    (receipt) => print('accepted: ${receipt.isEventAccepted}'),
    (failure) => print('publish failed: ${failure.message}'),
  );

  // 4. Subscribe: stored events arrive first, live events continue after EOSE.
  final sub = nostr.subscribe(
    const NostrFilter(kinds: [1], limit: 20),
  );
  sub.fold(
    (stream) => stream.stream.listen((event) => print(event.content)),
    (failure) => print('subscribe failed: ${failure.message}'),
  );

  // 5. NIP-44 v2 payload encryption with the bound identity.
  final payload = Nip44.encryptMessage(
    plaintext: 'secret',
    senderPrivateKeyHex: keyPair.private,
    recipientPublicKeyHex: keyPair.public,
  );
  print(Nip44.decryptMessage(
    payload: payload,
    recipientPrivateKeyHex: keyPair.private,
    senderPublicKeyHex: keyPair.public,
  ));
}
```

## Per-NIP accessor surface

`Nostr.instance.nips` (also `nostr.nips`) exposes one entry point per NIP. Signer-bound helpers are created lazily and rebuilt by `bindSigner`; stateless helpers are shared.

| Accessor | NIPs | Notes |
|---|---|---|
| `nips.nip04` | 04 | Legacy encrypted DMs; needs a local-key signer |
| `nips.nip05` | 05 | Identifier validation and resolution |
| `nips.nip06` | 06 | Mnemonic → key derivation |
| `nips.nip07` | 07 | Adapts a supplied `window.nostr` bridge to `NostrEventSigner` |
| `nips.nip11` | 11 | Relay information documents |
| `nips.nip17` | 17 | Rumor → seal → gift wrap DM stack |
| `nips.nip19` | 19 | npub/nsec/nprofile/nevent/naddr |
| `nips.nip21` | 21 | `nostr:` URI parse/build |
| `nips.nip24` | 24 | Kind-0 extras, deprecated-field cleanup, `r`/`i`/`title`/`t` helpers |
| `nips.nip27` | 27 | Mention/reference parsing |
| `nips.nip28` | 28 | Public chat channel events |
| `nips.nip29` | 29 | Relay group templates and parsing |
| `nips.nip30` | 30 | Custom emoji and emoji sets |
| `nips.nip32` | 32 | Kind-1985 labels, signer-bound |
| `nips.nip34` | 34 | Git repos, patches, PRs, issues, statuses, signer-bound |
| `nips.nip35` | 35 | Torrent indexes and comments; templates are unsigned |
| `nips.nip36` | 36 | `content-warning` tag helpers |
| `nips.nip37` | 37 | Draft wraps, checkpoints, private relay lists; needs self-addressed NIP-44 |
| `nips.nip38` | 38 | Kind-30315 user statuses, signer-bound |
| `nips.nip39` | 39 | External identity claims |
| `nips.nip42` | 42 | Auth event builder (transport answers AUTH) |
| `nips.nip43` | 43 | Relay roles and membership; join/leave builders take a signer per call |
| `nips.nip45` | 45 | COUNT request/response |
| `nips.nip46` | 46 | Nostr Connect RPC (bunker) |
| `nips.nip47` | 47 | Nostr Wallet Connect |
| `nips.nip48` | 48 | `proxy` tags on bridged events |
| `nips.nip52` | 52 | Calendar events, calendars and RSVPs |
| `nips.nip53` | 53 | Live streams, chat, rooms, meetings, presence |
| `nips.nip54` | 54 | Wiki articles, merges, redirects, highlights (84) |
| `nips.nip55` | 55 | Android signer URI helpers |
| `nips.nip56` | 56 | Kind-1984 reports |
| `nips.nip57` | 57 | Zap requests, invoice resolution, receipts |
| `nips.nip58` | 58 | Badges and profile badges |
| `nips.nip5a` | 5A | Static site manifests and snapshots |
| `nips.nip60` | 60 | Cashu wallet, tokens, history, quotes; needs self-addressed NIP-44 |
| `nips.nip61` | 61 | Mint recommendations and P2PK nutzaps |
| `nips.nip62` | 62 | Requests to vanish |
| `nips.nip64` | 64 | Chess games as PGN notes |
| `nips.nip66` | 66 | Relay liveness monitoring (read-only) |
| `nips.nip68` | 68 | Picture-first feeds |
| `nips.nip69` | 69 | Peer-to-peer order events |
| `nips.nip70` | 70 | Protected-event `['-']` tagging |
| `nips.nip71` | 71 | Video events |
| `nips.nip73` | 73 | External content `i`/`k` ids and filters |
| `nips.nip75` | 75 | Zap goals |
| `nips.nip77` | 77 | Negentropy reconciliation |
| `nips.nip78` | 78 | Custom app data (kinds 78/30078) |
| `nips.nip7d` | 7D | Forum thread templates |
| `nips.nip85` | 85 | Trusted assertions and provider lists |
| `nips.nip86` | 86 | Relay management JSON-RPC over NIP-98 |
| `nips.nip87` | 87 | Cashu and Fedimint discoverability |
| `nips.nip88` | 88 | Polls (1068) and responses (1018) |
| `nips.nip89` | 89 | App handler recommendations and handler info |
| `nips.nip92` | 92 | `imeta` media attachment parsing |
| `nips.nip94` | 94 | File metadata events |
| `nips.nip96` | 96 | NIP-96 uploads |
| `nips.nip98` | 98 | HTTP auth tokens |
| `nips.nip99` | 99 | Classified listings |
| `nips.nipa0` | A0 | Voice messages and voice replies |
| `nips.nipa3` | A3 | `payto` payment targets |
| `nips.nipa4` | A4 | Public messages |
| `nips.nipB0` | B0 | Web bookmarks |
| `nips.nipB7` | B7 | Blossom auth events and `blossom:` URIs |
| `nips.nipc0` | C0 | Code snippets |
| `nips.nipc7` | C7 | Chat messages and chat filters |
| `nips.nipCC` | CC | Geocache listings, logs, proofs, curation |
| `nips.nipcd` | CD | Slash command definitions, lists, invocations |
| `nips.nipf4` | F4 | Podcast metadata, lists and episodes |
| `nips.nipAD` | AD (extra) | Web address pointers |
| `nips.blossom` | BUD-01/02 (extra) | Blob upload/download/head |
| `nips.social` | 02, 09, 10, 14, 18, 22, 23, 25, 33, 51, 65 | Signed social builders |

Static-only APIs stay on their classes: `NostrProofOfWork` (13), `Nip44` (44), `NostrNip49` (49), `Nip59` (59). NIP-67 hints surface on `NostrEOSE.hints` and `NostrRequestEoseCommand.hints`; the `NostrNip67` helpers import from `nostr/nips/nip67/nip67.dart`.

## NIP coverage

Measured against the canonical NIPs repository at `bec0fc8` (100 NIPs). **87 supported · 4 partial · 9 missing.** Paths are relative to `lib/nostr/`. "Kinds" lists the kinds the package builds/parses for that NIP; `—` means the NIP has no event kinds (encryption, transport, encoding or API surface).

Legend: ✅ supported · ◐ partial · ✗ missing

| NIP | Title | Status | Dart path | Kinds |
|---|---|---|---|---|
| NIP-01 | Basic protocol flow description | ✅ supported | `nips/nip01/nip01.dart` | 0; REQ/EVENT/EOSE/CLOSE/OK/NOTICE |
| NIP-02 | Follow List | ✅ supported | `nips/social/social_builder.dart` | 3 |
| NIP-03 | OpenTimestamps Attestations for Events | ✅ supported | `model/event/event.dart` | 1040 (ots passthrough) |
| NIP-04 | Encrypted Direct Message | ✅ supported | `nips/nip04/nip04.dart` | 4 |
| NIP-05 | Mapping Nostr keys to DNS-based internet identifiers | ✅ supported | `nips/nip05/nip05.dart` | — |
| NIP-06 | Basic key derivation from mnemonic seed phrase | ✅ supported | `nips/nip06/nip06.dart` | — |
| NIP-07 | `window.nostr` capability for web browsers | ✅ supported | `nips/nip07/nip07.dart` | any (window.nostr bridge) |
| NIP-08 | Handling Mentions | ✗ missing | `—` | — |
| NIP-09 | Event Deletion Request | ✅ supported | `nips/social/social_builder.dart` | 5 |
| NIP-10 | Text Notes and Threads | ✅ supported | `nips/social/social_builder.dart` | 1 (thread tags) |
| NIP-11 | Relay Information Document | ✅ supported | `nips/nip11/nip11.dart` | — |
| NIP-12 | Generic Tag Queries | ◐ partial | `model/request/filter.dart` | #e/#p/#t/#a + raw extra keys |
| NIP-13 | Proof of Work | ✅ supported | `nips/nip13/nip13.dart` | any (PoW) |
| NIP-14 | Subject tag in Text events | ✅ supported | `nips/social/social_builder.dart` | 1 (subject tag) |
| NIP-15 | Nostr Marketplace | ✗ missing | `—` | — |
| NIP-16 | Event Treatment | ✗ missing | `—` | — |
| NIP-17 | Private Direct Messages | ✅ supported | `nips/nip17/nip17.dart` | 14, 15 |
| NIP-18 | Reposts | ✅ supported | `nips/social/social_builder.dart` | 6 |
| NIP-19 | bech32-encoded entities | ✅ supported | `nips/nip19/nip19.dart` | — |
| NIP-20 | Command Results | ◐ partial | `model/ok.dart` | OK receipts only |
| NIP-21 | `nostr:` URI scheme | ✅ supported | `nips/nip21/nip21.dart` | — |
| NIP-22 | Comment | ✅ supported | `nips/social/social_builder.dart` | 1111 |
| NIP-23 | Long-form Content | ✅ supported | `nips/social/social_builder.dart` | 30023 |
| NIP-24 | Extra metadata fields and tags | ✅ supported | `nips/nip24/nip24.dart` | 0 (extra fields), `r`/`i`/`title`/`t` tags |
| NIP-25 | Reactions | ✅ supported | `nips/social/social_builder.dart` | 7 |
| NIP-26 | Delegated Event Signing | ✗ missing | `—` | — |
| NIP-27 | Text Note References | ✅ supported | `nips/nip27/nip27.dart` | 1 (nostr: refs) |
| NIP-28 | Public Chat | ✅ supported | `nips/nip28/nip28.dart` | 40–44 |
| NIP-29 | Relay-based Groups | ✅ supported | `nips/nip29/nip29.dart` | 39000–39002, 9000–9002/9005/9007–9009 |
| NIP-30 | Custom Emoji | ✅ supported | `nips/nip30/nip30.dart` | 30030 (+ emoji tags) |
| NIP-31 | Dealing with unknown event kinds | ✗ missing | `—` | — |
| NIP-32 | Labeling | ✅ supported | `nips/nip32/nip32.dart` | 1985 |
| NIP-33 | Parameterized Replaceable Events | ◐ partial | `nips/social/social_builder.dart` | `d`/`a` coordinates, `createListEvent` generic addressable builder; no replacement/deletion helper |
| NIP-34 | `git` stuff | ✅ supported | `nips/nip34/nip34.dart` | 30617, 30618, 1617–1619, 1621, 1630–1633, 10317 |
| NIP-35 | Torrents | ✅ supported | `nips/nip35/nip35.dart` | 2003 (+ 2004 comment detection) |
| NIP-36 | Sensitive Content / Content Warning | ✅ supported | `nips/nip36/nip36.dart` | — (`content-warning` tag) |
| NIP-37 | Draft Wraps | ✅ supported | `nips/nip37/nip37.dart` | 31234, 1234, 10013 |
| NIP-38 | User Statuses | ✅ supported | `nips/nip38/nip38.dart` | 30315 |
| NIP-39 | Linking Profiles to Other Platforms | ✅ supported | `nips/nip39/nip39.dart` | 10011 |
| NIP-40 | Expiration Timestamp | ◐ partial | `nips/nip37/nip37.dart` | `expiration` in 37/38/60/69/96/B7 helpers, A4 tags, Blossom auth |
| NIP-42 | Authentication of clients to relays | ✅ supported | `nips/nip42/nip42.dart` | 22242 |
| NIP-43 | Relay Access Metadata and Requests | ✅ supported | `nips/nip43/nip43.dart` | 33534, 13534, 8000, 8001, 28934, 28936 |
| NIP-44 | Encrypted Payloads (Versioned) | ✅ supported | `nips/nip44/nip44.dart` | — (payload encryption) |
| NIP-45 | Event Counts | ✅ supported | `nips/nip45/nip45.dart` | — (COUNT) |
| NIP-46 | Nostr Remote Signing | ✅ supported | `nips/nip46/nip46.dart` | 24133 |
| NIP-47 | Nostr Wallet Connect (NWC) | ✅ supported | `nips/nip47/nip47.dart` | 13194, 23194–23195 (+ legacy 23196 notification) |
| NIP-48 | Bridged events | ✅ supported | `nips/nip48/nip48.dart` | any (`proxy` tag) |
| NIP-49 | Private Key Encryption (`ncryptsec`) | ✅ supported | `nips/nip49/nip49.dart` | — |
| NIP-50 | Search Capability | ✅ supported | `model/request/filter.dart` | — (`search`) |
| NIP-51 | Lists | ✅ supported | `nips/social/social_builder.dart` | 10000–10003, 30000+ (generic) |
| NIP-52 | Calendar Events | ✅ supported | `nips/nip52/nip52.dart` | 31922–31925 |
| NIP-53 | Live Streaming and Spaces | ✅ supported | `nips/nip53/nip53.dart` | 30311, 1311, 30312, 30313, 10312 |
| NIP-54 | Wiki | ✅ supported | `nips/nip54/nip54.dart` | 30818, 30819, 818, 9802 |
| NIP-55 | Android Signer Application | ✅ supported | `nips/nip55/nip55.dart` | any (intent URIs) |
| NIP-56 | Reporting | ✅ supported | `nips/nip56/nip56.dart` | 1984 |
| NIP-57 | Lightning Zaps | ✅ supported | `nips/nip57/nip57.dart` | 9734, 9735 |
| NIP-58 | Badges | ✅ supported | `nips/nip58/nip58.dart` | 8, 30009, 10008, 30008 |
| NIP-59 | Gift Wrap | ✅ supported | `nips/nip59/nip59.dart` | 13, 1059 |
| NIP-5A | Static Websites (nsites) | ✅ supported | `nips/nip5a/nip5a.dart` | 15128, 35128, 5128 |
| NIP-60 | Cashu Wallets | ✅ supported | `nips/nip60/nip60.dart` | 17375, 7375, 7376, 7374 |
| NIP-61 | Nutzaps | ✅ supported | `nips/nip61/nip61.dart` | 10019, 9321 |
| NIP-62 | Request to Vanish | ✅ supported | `nips/nip62/nip62.dart` | 62 |
| NIP-64 | Chess (Portable Game Notation) | ✅ supported | `nips/nip64/nip64.dart` | 64 |
| NIP-65 | Relay List Metadata | ✅ supported | `nips/social/social_builder.dart` | 10002 |
| NIP-66 | Relay Liveness Monitoring | ✅ supported | `nips/nip66/nip66.dart` | 30166, 10166 |
| NIP-67 | EOSE Completeness Hint | ✅ supported | `model/request/eose.dart` | — (`finish`/`more`/`auth` hints) |
| NIP-68 | Picture-first feeds | ✅ supported | `nips/nip68/nip68.dart` | 20 (+ `imeta`, `annotate-user`) |
| NIP-69 | Peer-to-peer Order events | ✅ supported | `nips/nip69/nip69.dart` | 38383 |
| NIP-70 | Protected Events | ✅ supported | `nips/nip70/nip70.dart` | — (`['-']` tag) |
| NIP-71 | Video Events | ✅ supported | `nips/nip71/nip71.dart` | 21, 22, 34235, 34236 |
| NIP-72 | Moderated Communities (Reddit Style) | ✗ missing | `—` | — |
| NIP-73 | External Content IDs | ✅ supported | `nips/nip73/nip73.dart` | — (`i`/`k` tags) |
| NIP-75 | Zap Goals | ✅ supported | `nips/nip75/nip75.dart` | 9041 |
| NIP-77 | Negentropy Syncing | ✅ supported | `nips/nip77/nip77.dart` | — (negentropy) |
| NIP-78 | Arbitrary custom app data | ✅ supported | `nips/nip78/nip78.dart` | 78, 30078 |
| NIP-7D | Forum Threads | ✅ supported | `nips/nip7d/nip7d.dart` | 11 (+ 1111 replies) |
| NIP-84 | Highlights | ✅ supported | `nips/nip54/nip54.dart` | 9802 |
| NIP-85 | Trusted Assertions | ✅ supported | `nips/nip85/nip85.dart` | 30382–30385, 10040 |
| NIP-86 | Relay Management API | ✅ supported | `nips/nip86/nip86.dart` | — (JSON-RPC, NIP-98 auth) |
| NIP-87 | Cashu and Fedimint Discoverability | ✅ supported | `nips/nip87/nip87.dart` | 38000, 38172, 38173 |
| NIP-88 | Polls | ✅ supported | `nips/nip88/nip88.dart` | 1068, 1018 |
| NIP-89 | Recommended Application Handlers | ✅ supported | `nips/nip89/nip89.dart` | 31989, 31990 |
| NIP-90 | Data Vending Machine | ✗ missing | `—` | — |
| NIP-92 | Media Attachments Metadata (`imeta`) | ✅ supported | `nips/nip92/nip92.dart` | — (`imeta` tag) |
| NIP-94 | File Metadata | ✅ supported | `nips/nip94/nip94.dart` | 1063 |
| NIP-96 | HTTP File Storage Integration | ✅ supported | `nips/nip96/nip96.dart` | 1063 (upload result) |
| NIP-98 | HTTP Auth | ✅ supported | `nips/nip98/nip98.dart` | 27235 |
| NIP-99 | Classified Listings | ✅ supported | `nips/nip99/nip99.dart` | 30402, 30403 |
| NIP-A0 | Voice Messages | ✅ supported | `nips/nipa0/nipa0.dart` | 1222, 1244 |
| NIP-A3 | payto: Payment Targets | ✅ supported | `nips/nipa3/nipa3.dart` | 10133 |
| NIP-A4 | Public Messages | ✅ supported | `nips/nipa4/nipa4.dart` | 24 |
| NIP-B0 | Web Bookmarking | ✅ supported | `nips/nipb0/nipb0.dart` | 39701 |
| NIP-B7 | Blossom media | ✅ supported | `nips/nipb7/nipb7.dart` | 24242 |
| NIP-BE | Nostr BLE Communications Protocol | ✗ missing | `—` | — |
| NIP-C0 | Code Snippets | ✅ supported | `nips/nipc0/nipc0.dart` | 1337 |
| NIP-C7 | Chats | ✅ supported | `nips/nipc7/nipc7.dart` | 9 |
| NIP-CC | Geocaching Events | ✅ supported | `nips/nipcc/nipcc.dart` | 37516, 37517, 7516, 7517, 1111 |
| NIP-CD | Slash Commands | ✅ supported | `nips/nipcd/nipcd.dart` | 31992, 10992 |
| NIP-EE | E2EE Messaging using the Messaging Layer Security (MLS) Protocol | ✗ missing | `—` | — |
| NIP-F4 | Podcasts | ✅ supported | `nips/nipf4/nipf4.dart` | 10154, 10064, 54 |

### Extras (outside the canonical 100)

| NIP | Title | Status | Dart path | Kinds |
|---|---|---|---|---|
| NIP-AD | Web Address Pointers | ✅ supported | `nips/nipad/nipad.dart` | — (`.well-known/nostr.json` lookup) |
| BUD-01/02 | Blossom blob storage | ✅ supported | `nips/blossom/blossom.dart` | 24242 auth (with B7) |

NIP-AD is counted separately: it is not part of the 100 NIPs at the measured spec commit, so the package advertises 87/100 canonical plus NIP-AD and Blossom as extras.

## Shared-layer and partial notes

Fourteen canonical NIPs have no dedicated implementation folder; they are implemented by the transport, model or social builder:

- **01** — `model/event`, `model/request`, relay messages; re-exported by `nips/nip01`.
- **02, 09, 10, 14, 18, 22, 23, 25, 51, 65** — `NostrSocialBuilder` (follows, deletions, thread tags, subject tag, reposts, comments, articles, reactions, generic lists, relay lists).
- **03** — only the `NostrEvent.ots` pass-through field; there is no kind-1040 builder or OTS proof verification.
- **50** — `NostrFilter.search` plus the filter builder.
- **84** — kind-9802 highlights live in `nips/nip54`.

Partial implementations, with the exact gap:

| NIP | What works | What is missing |
|---|---|---|
| 12 Generic tag queries | Typed `#e`, `#p`, `#t`, `#a` filters; unknown keys round-trip through `additionalFilters` | No typed API for arbitrary `#<tag>` filters |
| 20 Command results | Relay `OK` receipts are parsed and surfaced (`NostrEventOkCommand`); `CLOSED` is handled by the subscription layer | No NIP-20-specific API (the NIP is folded into NIP-01) |
| 33 Parameterized replaceable events | `createListEvent` builds any kind from `entries` with an optional `d` tag; other builders emit `d`/`a` tags and address coordinates | No dedicated replacement/deletion helper |
| 40 Expiration timestamp | `expiration` tags are written/read by NIP-37 draft wraps, NIP-38 statuses, NIP-60 quotes, NIP-69 orders, NIP-B7, NIP-96 and Blossom auth flows; NIP-A4 accepts them via `extraTags` | No general-purpose expiration builder or filter helper |

Other documented limits:

- **NIP-22** `createComment` emits kind 1111. It takes exactly one root scope family: event (`rootEventId`), address (`rootAddress`) or external (`rootExternalId`), with uppercase `K`/`E`/`A`/`I` root tags and lowercase `k`/`e`/`a`/`i` parent tags. Kind 22 is not a comment: NIP-71 reserves it for short video.
- **NIP-29** implements 39000–39002 and 9000/9001/9002/9005/9007/9008/9009. Roles (39003), group lists (39004/39005) and the 9010/9021/9022 variants are not implemented.
- **NIP-34** builds 1617–1633 and 10317; the deprecated kind-1622 reply is not emitted, replies use NIP-22 kind 1111.
- **NIP-53** kind-30312 rooms require a non-empty `roomName` (`53.md:142`). Live events, rooms and meetings keep an unknown `status` in `rawStatus` and leave `status` null.
- **NIP-60 / NIP-37** need a signer that can NIP-44 encrypt and decrypt to its own public key; remote signers must support self-addressed NIP-44 operations.
- **NIP-86** treats the relay as a JSON-RPC endpoint authorized with NIP-98; there is no websocket management surface.
- **NIP-96** upload uses the Blossom-style kind-24242 authorization event; NIP-96 deployments that expect a different auth event should be validated before use.
- **Unrecommended but implemented:** 03, 04, 06, 28 and 96. They work, but the canonical repo marks them unrecommended (see 04 → 17, 06 → single nsec, 28 → 29, 96 → Blossom).

## Missing-NIPs roadmap

Nine canonical NIPs have no code. Eight of them are marked `unrecommended` upstream; NIP-16 is the only one still `final`/`mandatory`.

- **16 Event Treatment** — replaceable, ephemeral and addressable semantics by kind range. Relays enforce them, and the package classifies only addressable kinds (`NostrEventAddress.isAddressableKind`, `NostrVideoKind.isAddressable`, `NostrAppData.isAddressable`), with no replaceable/ephemeral kind classification helper.
- **Not planned (8)** — 08 → 27, 15 → 99, 26, 31, 72 → 29, 90, BE, EE. All are unrecommended upstream, so they are built only on explicit demand.

## Shims and migration

All NIP implementations live under `lib/nostr/nips/<nip>/` and are exported from `lib/nostr/nips/nips.dart`. Old import paths still resolve as compatibility shims:

| Old path | Canonical path |
|---|---|
| `builders/social_builder.dart` | `nips/social/social_builder.dart` |
| `instance/bech32/bech32.dart` | `nips/nip19/nip19.dart` |
| `instance/tlv/tlv_utils.dart` | `nips/nip19/tlv.dart` |
| `model/relay_informations.dart` | `nips/nip11/relay_informations.dart` |
| `model/count.dart` | `nips/nip45/nip45.dart` |
| `nips/nip13/pow.dart` | `nips/nip13/nip13.dart` |
| `nips/nip57/zaps.dart` | `nips/nip57/nip57.dart` |

`NostrNip19` remains as a typedef for `NostrBech32`, and `NostrEvent.ots` is unchanged. No public API was removed in 11.1.0.

## Testing and CI

The default suite is offline: unit tests plus an in-process fake relay. The live-network suite is opt-in.

```bash
dart analyze                # 0 errors, 0 warnings; info-level lint debt remains
dart test -r compact        # 992 tests, offline

# Real-network suite against live public relays (opt-in):
RUN_REAL_NETWORK_TESTS=1 dart test test/real
```

The real-network suite publishes events as fresh identities, exchanges gift-wrapped DMs between generated users, verifies NIP-09 deletion propagation, parses live zap receipts and soaks concurrent subscriptions. Relays fail regularly, so it selects healthy relays at runtime and skips when an external dependency is unreachable.

CI (`.github/workflows/ci.yml`) runs `dart pub get`, `dart analyze` and `dart test -r compact` on every push to `main` and every pull request.

## Documentation & examples

- Full docs: [nostr.gwhyyy.com](https://nostr.gwhyyy.com/)
- API reference: [pub.dev/documentation/dart_nostr](https://pub.dev/documentation/dart_nostr/latest/)
- Runnable samples: [`example/`](example/) — key generation, publishing, subscriptions, NIP-05 verification, NIP-11 relay info

## Contributing

Issues and PRs are welcome. Run `dart analyze`, `dart format`, and the default test suite before submitting. Real-network changes should be validated with `RUN_REAL_NETWORK_TESTS=1 dart test test/real`.

## License

[MIT](LICENSE)
