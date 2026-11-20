# Changelog

## 11.2.0

**NIP coverage: 87 of the 100 canonical NIPs**

### Added

- **Shared NIP helpers** (`nips/common/tags.dart`): `NostrTags` (read/add/remove tags immutably), `NostrEventAddress` (`a`-coordinate parse/build, addressable-kind check) and `NostrValidators` (hex64, integer/time coercion, lowercase and geohash checks).
- **NIP-24 extra metadata** (`NostrNip24`, `nips/nip24/nip24.dart`): kind-0 extras (`display_name`, `website`, `banner`, `bot`, `birthday`), deprecated-field cleanup, and `r`/`i`/`title`/`t` tag helpers with lowercase hashtag validation.
- **NIP-32 labeling** (`NostrNip32`, `nips/nip32/nip32.dart`): builds and signs kind-1985 labels for `e`, `p`, `a`, `r` and `t` targets with optional relay hints.
- **NIP-34 git** (`NostrNip34`, `nips/nip34/nip34.dart`): repository announcements (30617), repo state (30618), patches (1617), pull requests (1618/1619), issues (1621), statuses (1630–1633), grasp lists (10317), clone-URI parsing and trusted status resolution.
- **NIP-35 torrents** (`NostrNip35`, `nips/nip35/nip35.dart`): kind-2003 indexes with `file`/`tracker`/`i` tags, plus kind-2004 comment detection.
- **NIP-36 content warnings** (`NostrNip36`, `nips/nip36/nip36.dart`): distinguishes a bare `content-warning` tag from a reasoned one and preserves an explicitly empty reason.
- **NIP-37 draft wraps** (`NostrNip37`, `nips/nip37/nip37.dart`): kind-31234 encrypted drafts, kind-1234 checkpoints and kind-10013 encrypted relay lists, including draft deletion (empty content).
- **NIP-38 user statuses** (`NostrNip38`, `nips/nip38/nip38.dart`): kind-30315 statuses with `r`/`p`/`e`/`a` references, an optional `expiration`, and empty content as the clear signal.
- **NIP-43 relay access** (`NostrNip43`, `nips/nip43/nip43.dart`): role definitions (33534), membership lists (13534), add/remove events (8000/8001) and join/leave requests (28934/28936); templates carry exactly one NIP-70 marker.
- **NIP-48 bridged events** (`NostrNip48`, `nips/nip48/nip48.dart`): `proxy` tag parse/build for any event kind.
- **NIP-52 calendars** (`NostrNip52`, `nips/nip52/nip52.dart`): date-based events (31922), time-based events (31923), calendars (31924) and RSVPs (31925).
- **NIP-53 live** (`NostrNip53`, `nips/nip53/nip53.dart`): streams (30311), chat (1311), rooms (30312), meetings (30313), presence (10312), participant roles and NIP-53 activity proofs.
- **NIP-56 reporting** (`NostrNip56`, `nips/nip56/nip56.dart`): kind-1984 reports with typed report types and NIP-32 label interop.
- **NIP-5A static sites** (`NostrNip5a`, `nips/nip5a/nip5a.dart`): root manifests (15128), named manifests (35128) and snapshot manifests (5128).
- **NIP-60 cashu** (`NostrNip60`, `nips/nip60/nip60.dart`): wallet state (17375), token events (7375), spending history (7376), mint quotes (7374), spend planning and NIP-09 token deletion.
- **NIP-61 nutzaps** (`NostrNip61`, `nips/nip61/nip61.dart`): mint recommendations (10019), P2PK-locked nutzaps (9321) and structural nutzap verification.
- **NIP-62 request to vanish** (`NostrNip62`, `nips/nip62/nip62.dart`): kind-62 requests, per-relay or `ALL_RELAYS`.
- **NIP-64 chess** (`NostrNip64`, `nips/nip64/nip64.dart`): PGN tag parsing and 80-column movetext serialization for kind 64.
- **NIP-66 liveness** (`NostrNip66`, `nips/nip66/nip66.dart`): monitor announcements (10166), relay discovery events (30166), timeouts and check lists; read-only, never gates connections.
- **NIP-67 EOSE hints** (`NostrNip67`, `nips/nip67/nip67.dart`): parses `finish`/`more`/`auth` hints from a three-element `EOSE` and surfaces them on `NostrEOSE.hints` and `NostrRequestEoseCommand.hints`.
- **NIP-68 pictures** (`NostrNip68`, `nips/nip68/nip68.dart`): kind-20 picture-first events with `imeta` and `annotate-user` annotations.
- **NIP-69 P2P orders** (`NostrNip69`, `nips/nip69/nip69.dart`): kind-38383 orders with fiat ranges, payment methods, ratings and platform/source tags.
- **NIP-70 protected events** (`NostrNip70`, `nips/nip70/nip70.dart`): detects the `['-']` protection tag, returns a copy carrying exactly one such tag (id/sig cleared for re-signing), and reports whether a protected event may be embedded in a repost.
- **NIP-71 video** (`NostrNip71`, `nips/nip71/nip71.dart`): regular (21/22) and addressable (34235/34236) video events with `imeta` text tracks.
- **NIP-73 external content ids** (`NostrNip73`, `nips/nip73/nip73.dart`): `i`/`k` parsing, kind derivation, tags and filters.
- **NIP-7D forum threads** (`NostrNip7d`, `nips/nip7d/nip7d.dart`): kind-11 thread templates and parsing; replies are NIP-22 kind-1111 comments.
- **NIP-78 custom app data** (`NostrNip78`, `nips/nip78/nip78.dart`): builds and signs kinds 78 and 30078, validates the `d` tag required by the addressable kind, and parses either back into `NostrAppData`.
- **NIP-85 trusted assertions** (`NostrNip85`, `nips/nip85/nip85.dart`): user (30382), event (30383), address (30384) and identifier (30385) assertions plus provider recommendations (10040).
- **NIP-86 relay management** (`NostrNip86`, `nips/nip86/nip86.dart`): JSON-RPC client for relay management, authorized with NIP-98.
- **NIP-87 ecash discovery** (`NostrNip87`, `nips/nip87/nip87.dart`): kind-38000 recommendations, cashu mint info (38172) and fedimint info (38173).
- **NIP-88 polls** (`NostrNip88`, `nips/nip88/nip88.dart`): builds/signs kind-1068 polls and kind-1018 responses, parses polls and computes tallies from kind-1018 responses.
- **NIP-89 app handlers** (`NostrNip89`, `nips/nip89/nip89.dart`): kind-31989 recommendations and kind-31990 handler information, with platform URL tags.
- **NIP-92 media attachments** (`NostrNip92`, `nips/nip92/nip92.dart`): parses and re-serializes `imeta` tags, including per-field metadata and profile picture/banner lookups.
- **NIP-A0 voice messages** (`NostrNipA0`, `nips/nipa0/nipa0.dart`): kind-1222 messages and kind-1244 replies with waveform and duration.
- **NIP-A3 payment targets** (`NostrNipA3`, `nips/nipa3/nipa3.dart`): kind-10133 `payto` targets.
- **NIP-A4 public messages** (`NostrNipA4`, `nips/nipa4/nipa4.dart`): kind-24 messages with receiver tags.
- **NIP-B0 bookmarks** (`NostrNipB0`, `nips/nipb0/nipb0.dart`): kind-39701 web bookmarks with URL coordinates, topics and titles.
- **NIP-C0 code snippets** (`NostrNipC0`, `nips/nipc0/nipc0.dart`): kind-1337 snippets with language, repo, dependencies and SPDX license tags.
- **NIP-C7 chats** (`NostrNipC7`, `nips/nipc7/nipc7.dart`): kind-9 chat messages, four-slot `q` replies and chat filters.
- **NIP-CC geocaching** (`NostrNipCC`, `nips/nipcc/nipcc.dart`): kind-37516 listings, kind-37517 curation lists, kind-7516 found logs, kind-7517 verification proofs and kind-1111 log comments.
- **NIP-CD slash commands** (`NostrNipCD`, `nips/nipcd/nipcd.dart`): kind-31992 command definitions, kind-10992 installed lists and invocation parsing with typed arguments and scopes.
- **NIP-F4 podcasts** (`NostrNipF4`, `nips/nipf4/nipf4.dart`): kind-10154 metadata, kind-10064 authored lists and kind-54 episodes.
- **`NostrNips` accessors** for every new module: `nip24`, `nip32`, `nip34`, `nip35`, `nip36`, `nip37`, `nip38`, `nip43`, `nip48`, `nip52`, `nip53`, `nip5a`, `nip56`, `nip60`, `nip61`, `nip62`, `nip64`, `nip66`, `nip68`, `nip69`, `nip70`, `nip71`, `nip73`, `nip78`, `nip7d`, `nip85`, `nip86`, `nip87`, `nip88`, `nip89`, `nip92`, `nipc0`, `nipc7`, `nipCC`, `nipcd`, `nipa0`, `nipa3`, `nipa4`, `nipB0`, `nipf4`. Stateless helpers are cached const instances; signer-bound helpers rebuild on `bindSigner`.
- **`createComment` scopes**: `NostrSocialBuilder.createComment` accepts address (`rootAddress`/`parentAddress`) and external (`rootExternalId`/`parentExternalId`/`externalKind`) scopes in addition to event ids, per `22.md:44-198`.

### Changed

- **NIP-22 comments are kind 1111** (breaking behavior): `createComment` no longer emits `kind: 22`, which NIP-71 reserves for short video. Root scope uses uppercase `K`/`E`/`A`/`I` tags, the direct parent uses lowercase `k`/`e`/`a`/`i` tags. `targetEventId` and `targetAuthorPubkey` became optional (required for event scope only); mixing root scope families throws `ArgumentError`. Existing calls still compile, but the emitted kind and tags change.
- **NIP-53 rooms require `roomName`**: `generateRoomTemplate` rejects a blank room name, matching `53.md:142`; a kind-30312 room without one is invalid.
- **NIP-53 unknown status is typed null**: live events, rooms and meetings expose `status` as `null` for values outside `planned`/`live`/`ended` (and for an absent tag), with the raw tag value kept in `rawStatus`.
- **NIP-37 and NIP-60 need self-addressed NIP-44**: the bound signer must be able to encrypt and decrypt to its own public key. Remote signers that cannot will fail at runtime, which is documented on the accessors.
- **NIP-67 EOSE parsing**: `NostrEOSE.fromRelayMessage` reads the subscription id from slot 1 instead of the last element, so a three-element `EOSE` no longer fails a cast and the hint array is never mistaken for the subscription id; hints are exposed separately on both EOSE models.

### Fixed

- **NIP-60 cashu payloads**: malformed NIP-44 ciphertext in wallet, token, history and quote events now surfaces as `FormatException` with the underlying reason instead of an uncaught crypto error.
- **NIP-61 nutzap proofs**: every proof must carry a NUT-11 P2PK secret locked to the advertised `02`-prefixed key; missing or differently locked proofs are rejected rather than accepted.
- **NIP-CC verification**: only found logs whose embedded kind-7517 proof is authored by the cache verification key, references the cache `naddr`, names the finder and matches the log `a` address count as verified finds, so forged or foreign proofs cannot win.
- **NIP-34 status resolution**: only the root author and listed maintainers can set a patch/PR/issue status; the most recent trusted status wins.
- **NIP-7D / NIP-C7 templates**: `extraTags` can no longer inject a second `title` on a thread, and replies reject a blank `q` target instead of emitting an unusable tag.

### Documentation

- README coverage table now reports 87 supported, 4 partial (12/20/33/40) and 9 missing canonical NIPs against `nostr-protocol/nips` @ `bec0fc8`, with Dart paths and handled kinds per NIP; the accessor table lists every `NostrNips` getter; the roadmap is reduced to the 9 remaining NIPs and the testing section reports 992 tests.
- `pubspec.yaml`: version 11.2.0 and a description matching the measured coverage.

## 11.1.0

**NIP layout consolidation + new NIP coverage**

### Added

- **New NIP modules**: NIP-04 encrypted DMs, NIP-07 browser-extension bridge, NIP-27 mentions, NIP-28 public chat, NIP-29 relay groups, NIP-30 custom emoji, NIP-39 identity claims, NIP-46 Nostr Connect (bunker RPC), NIP-47 Nostr Wallet Connect, NIP-54 wiki/articles, NIP-55 Android signer, NIP-58 badges, NIP-75 zap goals, NIP-77 negentropy, NIP-98 HTTP auth, NIP-99 classified listings, NIP-AD web address pointers, NIP-B7 Blossom authorization.
- **`NostrNips` accessor** for every implementation: `Nostr.instance.nips` now exposes one cached entry point per NIP (stateless helpers, signer-bound helpers rebuilt by `bindSigner`, plus `social`, `blossom`, `nip42` and `nip45`).
- **NIP-42 auth builder**: `NostrNip42.createAuthEvent` builds kind-22242 events; `NostrRelays` answers relay challenges through it.
- **NIP-45 helpers**: `NostrNip45` builds COUNT requests and parses COUNT responses.

### Changed

- All NIP implementations live under `lib/nostr/nips/<nip>/` and are exported from the `nips.dart` barrel. NIP-01 primitives and NIP-45 COUNT models re-export from their canonical home; NIPs implemented by the social builder (02/09/10/18/22/23/25/51/65) and NIP-84 highlights (in `nip54`) are indexed there.
- Old import paths (`builders/social_builder.dart`, `instance/bech32/bech32.dart`, `instance/tlv/tlv_utils.dart`, `model/relay_informations.dart`, `model/count.dart`, `nips/nip13/pow.dart`, `nips/nip57/zaps.dart`) remain as compatibility shims.

### Fixed

- **NIP-99** price tags accept decimal amounts (`10.50`) instead of integer-only values.
- **NIP-AD** encodes the `path` query parameter (reserved characters no longer break the lookup), supports a request timeout, and exposes `close()`.
- **NIP-58** API docs show the real `definitionAddress` parameter for badge awards.
- **NIP-54** docs spell out fork-tag support and the merge/defer boundary.

## 11.0.1

**Security and reliability patch**

### Security

- **NIP-17/NIP-59 sender spoofing fixed**: gift wraps and seals are now signature-verified, the seal must be kind 13, and the seal author must match the rumor author. A malicious sender can no longer seal a rumor that claims someone else's pubkey.
- **NIP-17 file messages** now reject the sender being listed as a recipient, matching the existing chat-message guard.

### Reliability

- **Reconnects replay active subscriptions**: after a relay reconnects, every active REQ that targets it is sent again, so streams no longer go silent.
- **Disconnects cancel pending reconnects**: a shutdown/generation check prevents a scheduled backoff reconnect from reopening a socket after `disconnectFromRelays()`.
- **NIP-42 AUTH relay tag** now carries the relay's websocket URL (`ws://`/`wss://`) instead of an HTTP URL, as the spec requires.
- **Subscription auto-close now reaches the relay**: `SubscriptionManager` invokes an `onAutoClose` hook, wired to `closeEventsSubscription`, before removing expired subscriptions.

### Filters

- `NostrFilter.fromJson` now preserves unknown keys in `additionalFilters`.
- `NostrFilter.toMap` lets core filter keys win over `additionalFilters`.
- `NostrFilter.validate()` rejects negative kinds, invalid id/author hex, and limits above 10,000.

### Tooling

- Added a CI workflow that runs `dart analyze` and the default test suite.
- Removed stray root files `handling` and `todo.extensionThatDoNotExist`.
- No public API removals in this patch.

## 11.0.0

**Major Release — Full Client-Feature NIP Coverage**

### New Features

- **NIP-44 v2 encryption** (`Nip44`): secp256k1 ECDH → HKDF → ChaCha20 + HMAC-SHA256, verified against all official paulmillr/nip44 vectors including extended-length prefixes and invalid-payload cases
- **NIP-59 gift wrap pipeline** (`Nip59`): rumor → seal (kind 13) → gift wrap (kind 1059) with ephemeral keys and randomized timestamps
- **NIP-17 private direct messages** (`NostrNip17`): kind-14 chat rumors, kind-15 file messages, group-chat wrapping per member
- **NIP-42 relay authentication**: automatic AUTH challenge answering when a signer is provided to `init()`; `CLOSED` messages are now surfaced on a typed stream instead of being discarded
- **Pluggable signers** (`NostrEventSigner`): local key signer included; interface ready for NIP-07 / NIP-46 / NIP-55 implementations
- **Social event builders** (`NostrSocialBuilder`): text notes with NIP-10 threading & NIP-27 mentions, profiles, follows (NIP-02), deletions (NIP-09), reposts (NIP-18), reactions (NIP-25), comments (NIP-22), relay lists (NIP-65), long-form articles (NIP-23/30023), generic lists (NIP-51)
- **NIP-57 zaps** (`NostrZaps`): zap request building, LNURL-pay resolution, invoice requesting, zap receipt parsing
- **NIP-49 encrypted keys** (`NostrNip49`): scrypt + XChaCha20-Poly1305 `ncryptsec`, verified against the spec vector
- **Blossom media client** (BUD-01/02) + NIP-96 uploader + NIP-94 file metadata
- **NIP-19 `naddr`** encode/decode; **NIP-21** `nostr:` URI parsing/building (`NostrNip21`)
- **NIP-13 proof-of-work**: difficulty counting, target checks, event miner

### Fixes

- Explicit disconnect and resource teardown invalidate pending handshakes and reconnect attempts, preventing closed sessions from reconnecting later.
- Package archive excludes the documentation site, Flutter playground, deployment files and generated web assets.
- Runtime relay management added: `addRelays()`, `removeRelay()`, `liveRelayUrls` on instances — adding a relay no longer drops existing connections
- `NostrFailure.unknown` messages now include the underlying error type and text instead of hiding the cause
- `nostr.nip21` convenience accessor for URI parsing; `NostrBech32` logger is now optional
- Real-network suite hardened: runtime-relay selection, cross-relay publish fallbacks, scoped retry config (`test/real/dart_test.yaml`)
- Cross-client interoperability validated against content written by Damus, Primal, Amethyst and reader apps: every sampled real event re-derives its id correctly through our serialization, nostr: mentions resolve through NIP-21 parsing, wild articles/profiles round-trip field-complete through our builders
- Profile builder now supports Lightning Address fields (`lud16`/`lud06`) so zap buttons light up across clients; article builder supports `r` reference tags as readers expect

- NIP-06 derivation no longer drops leading zero bytes (produced invalid keys for ~1/256 mnemonics; silent in release builds)
- Publishing to a set of relays where none is connected now fails fast instead of hanging forever
- Subscription streams honor explicitly-set subscription IDs (previously overwritten by random IDs, breaking stream filtering)
- Cancellable timeouts in async publish/count/subscribe — timers no longer linger until expiry
- Reconnect uses exponential backoff with jitter instead of hot-looping against a down relay; reconnects preserve the original init callbacks/options
- One-shot OK/count callbacks are removed after dispatch and EOSE callbacks on subscription close (unbounded memory growth fixed)
- Received-event registry is FIFO-bounded (5000) — long-running clients no longer leak memory
- Key-pair cache is capped at 32 entries (private keys no longer accumulate indefinitely)
- `init()` honors `ensureToClearRegistriesBeforeStarting` (previously documented but never implemented — stale sockets leaked across sessions)
- WebSocket is closed on connection timeout instead of leaking a half-open socket
- Input validation now throws `ArgumentError`/returns failures in release/AOT builds (asserts were silently stripped)
- `RelayInformations` never crashes on missing NIP-11 fields and parses the full document (`limitation`, `fees`, `retention`, …)
- Flutter Web/WASM compatible: `dart:io` removed from the transport layer; platform-independent WebSocket factory
- `connect()` now reports real connectivity: fails fast with a clear message when none of the provided relays are reachable, instead of returning success over dead sockets (found during live-relay testing)

### Testing

- 400+ unit and fake-relay integration tests, including an in-process relay harness driving real websocket flows (publish/OK, subscriptions, AUTH handshakes)
- Opt-in real-network suite (`RUN_REAL_NETWORK_TESTS=1 dart test test/real`) validated against live public relays: publishes as fresh identities, exchanges gift-wrapped DMs between two users over the wire, verifies deletion propagation, parses real zap receipts from feeds, answers NIP-42 challenges on auth-gated relays, and soaks concurrent subscriptions

## 10.0.0

**Major Release — Complete API Modernization**

### Breaking Changes

- Introduce `NostrResult<T>` sealed type — all operations now return typed success/failure instead of throwing exceptions
- Rename services API: `nostr.services.keys` → `nostr.keys`, `nostr.services.relays` → `nostr.relays`
- Top-level facade methods now return `NostrResult<T>`: `connect()`, `publish()`, `count()`, `subscribeRequest()`, etc.
- `NostrFailure` replaces ad-hoc exception strings with structured `message`, `code`, and `isRetryable` fields
- Replace `NostrRetryPolicy.none` with `NostrRetryPolicy()` (default no retries)
- `NostrClientOptions` replaces scattered timeout parameters; new `requestTimeout` and `retryPolicy` fields
- Remove old `services.*` namespace — use `nostr.keys`, `nostr.relays`, `nostr.utils` directly

### New Features

- `NostrClient` facade for typed, error-aware app development
- Subscription lifecycle tracking via `SubscriptionManager` — inspect active subscriptions and event counts
- Low-level relay API via `NostrRelayTransport` for custom transport implementations
- `NostrCryptoUtils` — centralized cryptographic operations
- Configurable connection and request timeouts per instance
- Exponential backoff retry policy: `NostrRetryPolicy.exponential(maxAttempts, initialDelayMs, maxDelayMs)`
- Fixed-interval retry policy: `NostrRetryPolicy.fixed(attempts, delayMs)`

### Documentation

- Complete rewrite of all documentation pages with current API and working examples
- Restructured docs into Keys, Relays & Events, Identity, and Advanced sections
- New guides: Quick Start, Error Handling, Client Options, Low-Level API
- README now leads with Documentation link and Getting Started section
- All example files cleaned up — removed emojis and AI-style comments, natural human-written style

### Internal Improvements

- Refactor core abstractions: `NostrResult<T>`, `NostrFailure`, `NostrClient`, `NostrCryptoUtils`
- Improve relay pool management and WebSocket lifecycle
- Better error recovery and logging
- Comprehensive test coverage for result types and client options

### Migration Path

See docs/usage/advanced/low-level-api.md for migration guidance from old services API to new surfaces.

## 9.2.5

- Improved README documentation with better structure and more natural language
- Made NIPs list inline for easier reading
- Added quick start example and better code samples

## 9.2.4

- Fixed issue #5: Message signing and verification now properly hashes messages with SHA256 before signing, matching the behavior of event signing
- Added `sha256Hash` utility method for consistent message hashing

## 9.2.3

- Fixed dependency constraints and sorted dependencies alphabetically
- Updated SDK requirement to >=3.0.0 <4.0.0 for broader compatibility across Dart 3.x versions

## 9.2.1

- support implementation of broadcasting all kind of entities froma relay(s) connection(s) without the internal package types/model handling.

## 9.1.1

- Provide new nip 05 functions that are nullable based on their success/fasilure instead of having ones that throw exception which may cause unwanted behavior if not been awared of and handled.

## 9.1.0

- Fixed errors caused by strict assumption of content event non-nullability.
- Fixed problem caused by possible received new data type from the relays's `OK` event.

## 9.0.0

- Major structure changes for different services of the package.

## 8.2.1

- Remove the Registering of null/empty onEose callback which lead to a bug in the relays service.

## 8.1.1

- exposed a field in the `NostrFilter` class to allow using more filters.

## 8.1.2

- Made all event fields nullable, exposing the toMap() method publicly for NIP cases where an uncompleted events is required (Gift wraps, Remote signing).
- Minor edits

## 8.1.0

- Making use of the `web_socket_channel` for cross platform compatibility.

## 8.0.3

- Support to sending close commands to specific relays, instead of closing all relays at once.

## 8.0.2

- Fixed issue of async method to get events from relays.

## 8.0.1

- Support for #a tag filter.

## 8.0.0

- Support for identification of relays commands by their name/url, in order to be able to customize behavior based on the relay and the action instead of the action only.
- Minor edits and fixes.

## 7.0.1

- Support for NIP 50 search filter with example.

## 7.0.0

- Breaking changes in most package services.
- Implementations for more asyncronous methods.
- New Mniimal Documentation for the package in readme.md file.
- Minor dev edits, fixes and improvements.

## 6.1.0

- Implmenttaion of free resources method for the relays service of an instance that clears and closes all events registeries and streams.
- Implementation of a new asynchronous methods for sending and receiving events, to ensure actions before and after the event is sent or received.
- More Doc comments for members.
- Minor bug fixes.

## 6.0.1

- Fixed the Stack overflow issue in the event model .

## 6.0.0

- Added ability to create standalone instances of the package services, useful if you want to target Flutter web so you can use only one service for routes and not all of them...
- Break changes in events types, in favor of possible collisions when working with replacable events.

## 5.0.1

- Added documentation config to pubspec.yaml

## 5.0.0

- Fully Breaking changes.
- Adidtion of callbacks triggeres for events, notices...
- Adidtion of more features.

## 4.0.0

- Breaking changes
- Exposed more APIs to the package interface.
- Offered more control over the events sending/receiving.

## 3.3.1

- Bug fixes.
- Added more docs
- More optimizations for the use of the keypair class for quickeer constructions after the first time (caching).

## 3.0.0

- Added new utils methods to the utils service.
- Exposed and modifed some implmentation source service class.
- Minor modifications for better maintainence of code.
- Commented out more APIs of the package.

## 2.1.1

- Changes the dart_bip32_bip44 with bip32_bip44 so it works with dart packages and projects and not Flutter ones sonce it breaks pana scoring system.

## 2.1.0

- Added nprofile & tlv services

## 2.0.1

- Minor changes in the docs.
- Added more docs to memebers that miss it.

## 2.0.0

- Exposed new APIs with new documentation for more developer experience use of this package.
- Addition of utils service.
- Addition of more nostr NIPs in the package.
- Added more examples.

## 1.5.1

- Exported the `NostrEventsStream` model class

## 1.5.0

- Added implementation of bech32 encoder in general.
- Added implementation of npub & nsec encoder.
- Added example for generating npub & nsec keys.
- Added more documentation and documenttaion-example for some memebers that miss it in the keys service.

## 1.4.0

- Added the reconnecting option when a relay sent's a notice message.

## 1.3.3

- refactored the optional memebers to requests in the internal library packages.
- ( experiental ) Implementation of a work around over the relays subscrition limits.

## 1.3.2

- Added a main example.

## 1.3.0

- Add more helper methods.
- Minor fixes.

## 1.2.0

- Added example of litening to events.
- Fixing the subscription id that turns null when not se

## 1.1.0

- Fixed signing and verifying hexadiciaml encoding issue.
- added more example in example/ folder.

## 1.0.6

- Added more helper methods with docs and examples.

## 1.0.5

- Added more docs with examples to more methods.

## 1.0.4

- Highlighted support for more nips in the docs.

## 1.0.3

- Added support for more nips.
- Exposed them in the docs.

## 1.0.2

- Added implementation of nip 11 and its docs

## 1.0.1

- Added docs for nip-05 verification.

## 1.0.0

- Implementation of nip 05 for internet identity verification.
- Adding more docs and examples.

## 1.0.2-dev

- Added more functionalities and parameters to the `relays` service.

## 1.0.1-dev

- organized the main package to services (keys, relays).
- exposed more helper methods.
- added and edited docs

## 1.0.0-dev

- Initial under-development version.
