---
title: NIP accessors
sidebar_label: Accessors
sidebar_position: 2
---

Every `Nostr` instance exposes its NIP helpers through `nostr.nips`
(`NostrNips`). There are two kinds:

- **Stateless** helpers are created once and hold no key. They are safe to call
  on any instance, with or without a connection.
- **Signer-bound** helpers read from the currently bound `NostrEventSigner` and
  throw `StateError` until one is bound. Bind it with
  `connect(relays, signer: ...)`, `addRelays(..., signer: ...)`, or
  `nostr.nips.bindSigner(signer)`.

## Accessors

| Accessor | Kind | What it covers |
| --- | --- | --- |
| `nip19` | stateless | bech32 entity encoding/decoding: `npub`, `nsec`, `nprofile`, `nevent`, `naddr` |
| `nip21` | stateless | `nostr:` URI parsing and building |
| `nip27` | stateless | text-note reference and mention parsing |
| `nip05` | stateless | internet identifier validation and resolution |
| `nip06` | stateless | mnemonic to key derivation |
| `nip11` | stateless | relay information document fetching |
| `nip29` | stateless | relay-group templates, parsing and validation; templates are unsigned |
| `nip30` | stateless | custom emoji parsing/matching and emoji-set helpers; the builder takes the signer as an argument |
| `nip07` | stateless | browser `window.nostr` bridge helpers; pass your bridge to the methods, or connect `NostrNip07Signer` and bind the result |
| `nip55` | stateless | Android signer URI helpers; intent execution is the application's job |
| `nip42` | stateless | relay auth event builder; `NostrRelays` answers AUTH challenges for the connection signer |
| `nip45` | stateless | COUNT request and response payload helpers |
| `nip77` | stateless | negentropy reconciliation helpers; pass the storage vector in |
| `nip24` | stateless | kind-0 extra metadata fields and tags |
| `nip35` | stateless | kind 2003 torrent indexes and kind 2004 comments; templates are unsigned |
| `nip36` | stateless | `content-warning` tag helpers |
| `nip43` | stateless | relay access metadata and join/leave request builders; the builder takes the signer per call |
| `nip70` | stateless | protected-event `['-']` tagging |
| `nip73` | stateless | external content `i`/`k` id tag helpers and filters |
| `nip92` | stateless | `imeta` media attachment metadata |
| `nip66` | stateless | relay liveness monitoring; read-only and never gates connections |
| `nipAD` | stateless | web address pointer resolution |
| `nip48` | stateless | `proxy` tags on bridged events |
| `nip5a` | stateless | static website manifests and snapshots; the publisher takes the signer per call |
| `nip7d` | stateless | kind-11 forum thread templates; unsigned |
| `nipc7` | stateless | kind-9 chat message templates and filters; unsigned |
| `nipa3` | stateless | kind-10133 `payto` payment target templates; unsigned |
| `nipc0` | stateless | kind-1337 code snippet templates; unsigned |
| `nip37` | signer-bound | draft wraps, checkpoints and private relay lists; needs a signer that can NIP-44 to its own public key |
| `nip38` | signer-bound | kind-30315 user statuses |
| `nip04` | signer-bound | legacy encrypted DMs; needs a `NostrLocalKeySigner` for the ECDH input |
| `nip17` | signer-bound | private direct messages (kinds 14/15, rumor/seal/gift-wrap stack) |
| `nip28` | signer-bound | kinds 40–44 public chat channels |
| `nip32` | signer-bound | kind-1985 label events |
| `nip39` | signer-bound | kind-10011 external identity claims; parsing is static, publishing and verification need the signer |
| `nip46` | signer-bound | Nostr Connect (bunker) RPC over kind 24133 |
| `nip47` | signer-bound | Nostr Wallet Connect request/response helpers; use `NostrNip47.forConnection` to bind a per-connection secret |
| `nip98` | signer-bound | kind-27235 HTTP authentication tokens |
| `nip52` | signer-bound | kinds 31922–31925 calendar events, calendars and RSVPs |
| `nip53` | signer-bound | live streams, chat, rooms, meetings and presence |
| `nip54` | signer-bound | wiki articles, merges, redirects, and kind-9802 highlights (NIP-84) |
| `nip56` | signer-bound | kind-1984 reports |
| `nip58` | signer-bound | badge definitions, awards, profile badges and badge sets |
| `nip60` | signer-bound | cashu wallet, token, history and quote events; needs self-addressed NIP-44 |
| `nip61` | signer-bound | mint recommendations and nutzaps |
| `nip62` | signer-bound | kind-62 requests to vanish |
| `nip64` | signer-bound | kind-64 chess games as PGN |
| `nip68` | signer-bound | kind-20 picture-first feeds, including `imeta` and `annotate-user` |
| `nip69` | signer-bound | kind-38383 peer-to-peer orders |
| `nip71` | signer-bound | kinds 21/22/34235/34236 video events |
| `nip75` | signer-bound | kind-9041 zap goals |
| `nip78` | signer-bound | kinds 78/30078 custom app data |
| `nipB0` | signer-bound | kind-39701 web bookmarks |
| `nipCC` | signer-bound | geocache listings, logs, verification and curation |
| `nip34` | signer-bound | git repositories, patches, pull requests, issues and statuses |
| `nip86` | signer-bound | relay management JSON-RPC; every request is authorized with NIP-98 |
| `nipa0` | signer-bound | kinds 1222/1244 voice messages and replies |
| `nipcd` | signer-bound | slash command definitions, lists and invocations |
| `nipf4` | signer-bound | podcast metadata, authored lists and episodes |
| `nipa4` | signer-bound | kind-24 public messages |
| `nip85` | signer-bound | trusted assertions and provider recommendations |
| `nip87` | signer-bound | cashu and fedimint discoverability |
| `nip88` | signer-bound | kinds 1068/1018 polls and responses |
| `nip89` | signer-bound | kinds 31989/31990 recommended application handlers |
| `nip99` | signer-bound | kinds 30402/30403 classified listings |
| `nipB7` | signer-bound | Blossom authorization events and `blossom:` URI helpers |
| `nip57` | signer-bound | Lightning zap requests, invoice resolution and receipts |
| `nip94` | signer-bound | kind-1063 file metadata events |
| `nip96` | signer-bound | NIP-96 file uploads |
| `blossom` | signer-bound | Blossom media server client: blob upload, download and head |
| `social` | signer-bound | signed builders for kinds 1, 3, 5, 6, 7, 1111, 30023, 10000–10003, 10002 and generic addressable lists (NIP-02, 09, 10, 14, 18, 22, 23, 25, 33, 51, 65) |

`logger` and `signer` are plain members, not NIP accessors; `signer` reports the
currently bound instance and `bindSigner` sets it.

## NIPs reached through other entry points

Some NIPs are implemented on the classes that own them instead of a `nips`
getter:

| NIP | Entry point | What it covers |
| --- | --- | --- |
| 01 | `model/event`, `model/request`, relay message models (re-exported by `nips/nip01`) | events, filters, REQ/EVENT/EOSE/CLOSE/OK/NOTICE |
| 03 | `NostrEvent.ots` | OpenTimestamps attestation field passthrough |
| 13 | `NostrProofOfWork` | proof-of-work mining and validation |
| 44 | `Nip44` | v2 payload encryption and decryption |
| 49 | `NostrNip49` | `ncryptsec` encryption and decryption |
| 50 | `NostrFilter.search` | relay search filter field |
| 59 | `Nip59` | gift wrap and seal |
| 67 | `NostrEOSE.hints`, `NostrRequestEoseCommand.hints` | EOSE completeness hints |

## Binding and rebinding a signer

```dart
final nostr = Nostr.instance;
final signer = NostrLocalKeySigner(nostr.keys.generateKeyPair());
final otherSigner = NostrLocalKeySigner(nostr.keys.generateKeyPair());

// connect() binds the signer on the NIP surface as well as the transport.
await nostr.connect(['wss://relay.damus.io'], signer: signer);
await nostr.nips.social.createTextNote('hello');

// Binding a different signer drops every cached signer-bound helper.
// The next accessor read builds it against the new signer.
nostr.nips.bindSigner(otherSigner);
await nostr.nips.social.createTextNote('hello from the other key');

// disconnect() clears connection state only; the signer stays bound.
await nostr.disconnect();
await nostr.nips.social.createTextNote('still bound');

// Clear it explicitly.
nostr.nips.bindSigner(null);
// nostr.nips.social -> StateError: NostrNips.social requires a signer.
```

`bindSigner` returns early when passed the same signer instance, so nothing is
rebuilt. `connect` and `addRelays` bind only when you pass a non-null signer;
passing `null` leaves the existing binding alone. Only `bindSigner(null)` revokes
it.
