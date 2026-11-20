---
title: NIP coverage
sidebar_label: NIP coverage
sidebar_position: 1
---

This table records what the package implements, measured against the 100 NIPs in
`nostr-protocol/nips` at commit `bec0fc8`. A NIP is **supported** when a module
exists and builds or parses that NIP's event kinds and tags, or when a shared
layer covers it (the event and filter models, the relay transport, or
`NostrSocialBuilder`). **Partial** means the shared behaviour exists but the
general-purpose API for the NIP does not; the concrete gap is named in the notes.
**Missing** means there is no code. Of the 100 canonical NIPs, 87 are supported,
4 are partial and 9 are missing. Paths are relative to `lib/nostr/`.

The tests run offline against unit vectors and an in-process fake relay. Passing
tests do not prove interoperability with every relay implementation: relays differ
in which NIPs and edge cases they enforce, so validate against the relays you
deploy on.

| NIP | Title | Status | Module path | Kinds/notes |
| --- | --- | --- | --- | --- |
| NIP-01 | Basic protocol flow description | supported | `nips/nip01/nip01.dart` | 0; REQ/EVENT/EOSE/CLOSE/OK/NOTICE |
| NIP-02 | Follow List | supported | `nips/social/social_builder.dart` | 3 |
| NIP-03 | OpenTimestamps Attestations for Events | supported | `model/event/event.dart` | 1040 (ots passthrough) |
| NIP-04 | Encrypted Direct Message | supported | `nips/nip04/nip04.dart` | 4 |
| NIP-05 | Mapping Nostr keys to DNS-based internet identifiers | supported | `nips/nip05/nip05.dart` | — |
| NIP-06 | Basic key derivation from mnemonic seed phrase | supported | `nips/nip06/nip06.dart` | — |
| NIP-07 | `window.nostr` capability for web browsers | supported | `nips/nip07/nip07.dart` | any (window.nostr bridge) |
| NIP-08 | Handling Mentions | missing | `—` | no code; unrecommended upstream (superseded by 27) |
| NIP-09 | Event Deletion Request | supported | `nips/social/social_builder.dart` | 5 |
| NIP-10 | Text Notes and Threads | supported | `nips/social/social_builder.dart` | 1 (thread tags) |
| NIP-11 | Relay Information Document | supported | `nips/nip11/nip11.dart` | — |
| NIP-12 | Generic Tag Queries | partial | `model/request/filter.dart` | `#e`/`#p`/`#t`/`#a` typed; gap: no typed API for arbitrary `#<tag>` filters (raw keys via `additionalFilters`) |
| NIP-13 | Proof of Work | supported | `nips/nip13/nip13.dart` | any (PoW) |
| NIP-14 | Subject tag in Text events | supported | `nips/social/social_builder.dart` | 1 (subject tag) |
| NIP-15 | Nostr Marketplace | missing | `—` | no code; unrecommended upstream (superseded by 99) |
| NIP-16 | Event Treatment | missing | `—` | no code; folded into NIP-01 upstream, only `NostrEventAddress.isAddressableKind` classification exists |
| NIP-17 | Private Direct Messages | supported | `nips/nip17/nip17.dart` | 14, 15 |
| NIP-18 | Reposts | supported | `nips/social/social_builder.dart` | 6 |
| NIP-19 | bech32-encoded entities | supported | `nips/nip19/nip19.dart` | — |
| NIP-20 | Command Results | partial | `model/ok.dart` | OK receipts only (`NostrEventOkCommand`); gap: no NIP-20-specific API (folded into NIP-01) |
| NIP-21 | `nostr:` URI scheme | supported | `nips/nip21/nip21.dart` | — |
| NIP-22 | Comment | supported | `nips/social/social_builder.dart` | 1111 |
| NIP-23 | Long-form Content | supported | `nips/social/social_builder.dart` | 30023 |
| NIP-24 | Extra metadata fields and tags | supported | `nips/nip24/nip24.dart` | 0 (extra fields), `r`/`i`/`title`/`t` tags |
| NIP-25 | Reactions | supported | `nips/social/social_builder.dart` | 7 |
| NIP-26 | Delegated Event Signing | missing | `—` | no code; unrecommended upstream |
| NIP-27 | Text Note References | supported | `nips/nip27/nip27.dart` | 1 (nostr: refs) |
| NIP-28 | Public Chat | supported | `nips/nip28/nip28.dart` | 40–44 |
| NIP-29 | Relay-based Groups | supported | `nips/nip29/nip29.dart` | 39000–39002, 9000–9002/9005/9007–9009 |
| NIP-30 | Custom Emoji | supported | `nips/nip30/nip30.dart` | 30030 (+ emoji tags) |
| NIP-31 | Dealing with unknown event kinds | missing | `—` | no code; unrecommended upstream |
| NIP-32 | Labeling | supported | `nips/nip32/nip32.dart` | 1985 |
| NIP-33 | Parameterized Replaceable Events | partial | `nips/social/social_builder.dart` | `d`/`a` coordinates, `createListEvent`; gap: no replacement/deletion helper |
| NIP-34 | `git` stuff | supported | `nips/nip34/nip34.dart` | 30617, 30618, 1617–1619, 1621, 1630–1633, 10317 |
| NIP-35 | Torrents | supported | `nips/nip35/nip35.dart` | 2003 (+ 2004 comment detection) |
| NIP-36 | Sensitive Content / Content Warning | supported | `nips/nip36/nip36.dart` | — (`content-warning` tag) |
| NIP-37 | Draft Wraps | supported | `nips/nip37/nip37.dart` | 31234, 1234, 10013 |
| NIP-38 | User Statuses | supported | `nips/nip38/nip38.dart` | 30315 |
| NIP-39 | Linking Profiles to Other Platforms | supported | `nips/nip39/nip39.dart` | 10011 |
| NIP-40 | Expiration Timestamp | partial | `nips/nip37/nip37.dart` | `expiration` written/read by 37/38/60/69/96/B7, A4 tags, Blossom auth; gap: no general expiration builder or filter helper |
| NIP-42 | Authentication of clients to relays | supported | `nips/nip42/nip42.dart` | 22242 |
| NIP-43 | Relay Access Metadata and Requests | supported | `nips/nip43/nip43.dart` | 33534, 13534, 8000, 8001, 28934, 28936 |
| NIP-44 | Encrypted Payloads (Versioned) | supported | `nips/nip44/nip44.dart` | — (payload encryption) |
| NIP-45 | Event Counts | supported | `nips/nip45/nip45.dart` | — (COUNT) |
| NIP-46 | Nostr Remote Signing | supported | `nips/nip46/nip46.dart` | 24133 |
| NIP-47 | Nostr Wallet Connect (NWC) | supported | `nips/nip47/nip47.dart` | 13194, 23194–23195 (+ legacy 23196 notification) |
| NIP-48 | Bridged events | supported | `nips/nip48/nip48.dart` | any (`proxy` tag) |
| NIP-49 | Private Key Encryption (`ncryptsec`) | supported | `nips/nip49/nip49.dart` | — |
| NIP-50 | Search Capability | supported | `model/request/filter.dart` | — (`search`) |
| NIP-51 | Lists | supported | `nips/social/social_builder.dart` | 10000–10003, 30000+ (generic) |
| NIP-52 | Calendar Events | supported | `nips/nip52/nip52.dart` | 31922–31925 |
| NIP-53 | Live Streaming and Spaces | supported | `nips/nip53/nip53.dart` | 30311, 1311, 30312, 30313, 10312 |
| NIP-54 | Wiki | supported | `nips/nip54/nip54.dart` | 30818, 30819, 818, 9802 |
| NIP-55 | Android Signer Application | supported | `nips/nip55/nip55.dart` | any (intent URIs) |
| NIP-56 | Reporting | supported | `nips/nip56/nip56.dart` | 1984 |
| NIP-57 | Lightning Zaps | supported | `nips/nip57/nip57.dart` | 9734, 9735 |
| NIP-58 | Badges | supported | `nips/nip58/nip58.dart` | 8, 30009, 10008, 30008 |
| NIP-59 | Gift Wrap | supported | `nips/nip59/nip59.dart` | 13, 1059 |
| NIP-5A | Static Websites (nsites) | supported | `nips/nip5a/nip5a.dart` | 15128, 35128, 5128 |
| NIP-60 | Cashu Wallets | supported | `nips/nip60/nip60.dart` | 17375, 7375, 7376, 7374 |
| NIP-61 | Nutzaps | supported | `nips/nip61/nip61.dart` | 10019, 9321 |
| NIP-62 | Request to Vanish | supported | `nips/nip62/nip62.dart` | 62 |
| NIP-64 | Chess (Portable Game Notation) | supported | `nips/nip64/nip64.dart` | 64 |
| NIP-65 | Relay List Metadata | supported | `nips/social/social_builder.dart` | 10002 |
| NIP-66 | Relay Liveness Monitoring | supported | `nips/nip66/nip66.dart` | 30166, 10166 |
| NIP-67 | EOSE Completeness Hint | supported | `model/request/eose.dart` | — (`finish`/`more`/`auth` hints) |
| NIP-68 | Picture-first feeds | supported | `nips/nip68/nip68.dart` | 20 (+ `imeta`, `annotate-user`) |
| NIP-69 | Peer-to-peer Order events | supported | `nips/nip69/nip69.dart` | 38383 |
| NIP-70 | Protected Events | supported | `nips/nip70/nip70.dart` | — (`['-']` tag) |
| NIP-71 | Video Events | supported | `nips/nip71/nip71.dart` | 21, 22, 34235, 34236 |
| NIP-72 | Moderated Communities (Reddit Style) | missing | `—` | no code; unrecommended upstream (superseded by 29) |
| NIP-73 | External Content IDs | supported | `nips/nip73/nip73.dart` | — (`i`/`k` tags) |
| NIP-75 | Zap Goals | supported | `nips/nip75/nip75.dart` | 9041 |
| NIP-77 | Negentropy Syncing | supported | `nips/nip77/nip77.dart` | — (negentropy) |
| NIP-78 | Arbitrary custom app data | supported | `nips/nip78/nip78.dart` | 78, 30078 |
| NIP-7D | Forum Threads | supported | `nips/nip7d/nip7d.dart` | 11 (+ 1111 replies) |
| NIP-84 | Highlights | supported | `nips/nip54/nip54.dart` | 9802 |
| NIP-85 | Trusted Assertions | supported | `nips/nip85/nip85.dart` | 30382–30385, 10040 |
| NIP-86 | Relay Management API | supported | `nips/nip86/nip86.dart` | — (JSON-RPC, NIP-98 auth) |
| NIP-87 | Cashu and Fedimint Discoverability | supported | `nips/nip87/nip87.dart` | 38000, 38172, 38173 |
| NIP-88 | Polls | supported | `nips/nip88/nip88.dart` | 1068, 1018 |
| NIP-89 | Recommended Application Handlers | supported | `nips/nip89/nip89.dart` | 31989, 31990 |
| NIP-90 | Data Vending Machine | missing | `—` | no code; unrecommended upstream |
| NIP-92 | Media Attachments Metadata (`imeta`) | supported | `nips/nip92/nip92.dart` | — (`imeta` tag) |
| NIP-94 | File Metadata | supported | `nips/nip94/nip94.dart` | 1063 |
| NIP-96 | HTTP File Storage Integration | supported | `nips/nip96/nip96.dart` | 1063 (upload result) |
| NIP-98 | HTTP Auth | supported | `nips/nip98/nip98.dart` | 27235 |
| NIP-99 | Classified Listings | supported | `nips/nip99/nip99.dart` | 30402, 30403 |
| NIP-A0 | Voice Messages | supported | `nips/nipa0/nipa0.dart` | 1222, 1244 |
| NIP-A3 | payto: Payment Targets | supported | `nips/nipa3/nipa3.dart` | 10133 |
| NIP-A4 | Public Messages | supported | `nips/nipa4/nipa4.dart` | 24 |
| NIP-B0 | Web Bookmarking | supported | `nips/nipb0/nipb0.dart` | 39701 |
| NIP-B7 | Blossom media | supported | `nips/nipb7/nipb7.dart` | 24242 |
| NIP-BE | Nostr BLE Communications Protocol | missing | `—` | no code; unrecommended upstream |
| NIP-C0 | Code Snippets | supported | `nips/nipc0/nipc0.dart` | 1337 |
| NIP-C7 | Chats | supported | `nips/nipc7/nipc7.dart` | 9 |
| NIP-CC | Geocaching Events | supported | `nips/nipcc/nipcc.dart` | 37516, 37517, 7516, 7517, 1111 |
| NIP-CD | Slash Commands | supported | `nips/nipcd/nipcd.dart` | 31992, 10992 |
| NIP-EE | E2EE Messaging using the Messaging Layer Security (MLS) Protocol | missing | `—` | no code; unrecommended upstream |
| NIP-F4 | Podcasts | supported | `nips/nipf4/nipf4.dart` | 10154, 10064, 54 |

## Extras

Implemented, but outside the 100 NIPs at the measured commit.

| NIP | Title | Status | Module path | Kinds/notes |
| --- | --- | --- | --- | --- |
| NIP-AD | Web Address Pointers | supported | `nips/nipad/nipad.dart` | — (`.well-known/nostr.json` lookup) |
| BUD-01/02 | Blossom blob storage | supported | `nips/blossom/blossom.dart` | blob upload/download/head; 24242 auth shared with NIP-B7 |

## What is not covered

- No NIP-61 DLEQ proof verification. Nutzap validation checks structure and keys;
  the proof itself is out of scope (`nips/nip61/nip61.dart`).
- No wallet, Lightning or mint HTTP client. NIP-47 and NIP-57 build and parse the
  events and payloads; paying invoices and talking to a mint are left to the
  application.
- No execution of relay management against a live relay. NIP-86 is an HTTP
  JSON-RPC client that takes an injected `http.Client`; it does not manage a relay
  over its websocket connection.
