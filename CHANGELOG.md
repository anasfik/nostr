# Changelog

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
