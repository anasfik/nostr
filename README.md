# dart_nostr

[![pub package](https://img.shields.io/pub/v/dart_nostr.svg)](https://pub.dev/packages/dart_nostr)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![SDK](https://img.shields.io/badge/SDK-%E2%89%A53.0.0-green)](https://dart.dev)

> [!NOTE]
> Maintained by **[Anas Fikhi](https://gwhyyy.com)** — Flutter & AI engineer. Available for contract work: [work@gwhyyy.com](mailto:work@gwhyyy.com) · [book a call](https://calendly.com/ffikhi-aanas/30min)

A production-grade Dart & Flutter SDK for building Nostr applications. One import gives you relay transport, event signing, typed subscription streams, encryption, zaps, media uploads and identity tooling — everything a modern Nostr client needs.

**Works everywhere Dart runs:** Android · iOS · Web/WASM · macOS · Windows · Linux.

---

## Why dart_nostr

- **Complete protocol surface** — 25+ NIPs implemented and integration-tested against live relays
- **Spec-vector verified crypto** — NIP-44 v2 passes every official test vector; NIP-49 decrypts the reference payload byte-for-byte
- **Typed error handling** — `NostrResult<T>` instead of exceptions; nothing throws unexpectedly
- **Real-world resilient** — exponential reconnect backoff with jitter, bounded caches, fail-fast on dead relays, automatic NIP-42 authentication
- **Pluggable signing** — local keys today; NIP-07 / NIP-46 / NIP-55 signers via one interface
- **Tested like you'd use it** — publishes notes, sends DMs, verifies deletions and answers AUTH challenges against public relays as part of the development workflow

## Installation

```bash
flutter pub add dart_nostr
# or
dart pub add dart_nostr
```

```yaml
dependencies:
  dart_nostr: ^11.0.0
```

## Quick start

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();

  // 1. Connect — returns a typed result; fails fast if no relay is reachable.
  final connected = await nostr.connect([
    'wss://relay.damus.io',
    'wss://nos.lol',
  ]);

  if (connected.isFailure) {
    print('could not reach any relay: ${connected.failureOrNull?.message}');
    return;
  }

  // 2. Create an identity.
  final keyPair = nostr.keys.generateKeyPair();
  final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);

  // 3. Publish a note.
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello nostr from $npub!',
    keyPairs: keyPair,
  );

  final ok = await nostr.publish(event);
  ok.fold(
    (receipt) => print('accepted by relay: ${receipt.isEventAccepted}'),
    (failure) => print('publish failed: ${failure.message}'),
  );

  // 4. Subscribe to the firehose.
  final sub = nostr.subscribeRequest(
    NostrRequest(
      filters: [
        const NostrFilter(kinds: [1], limit: 20),
      ],
    ),
  );

  sub.fold(
    (stream) => stream.stream.listen(print),
    (failure) => print('subscribe failed: ${failure.message}'),
  );
}
```

## What's inside

### Protocol core

| Capability | API | Notes |
|---|---|---|
| Connect / disconnect | `nostr.connect(relays)` | Typed result; reports real connectivity, not blind optimism |
| Publish events | `nostr.publish(event)` | Relay `OK` receipts surfaced directly |
| Subscriptions | `nostr.subscribeRequest()`, `subscribeFilters()` | Buffered streams; explicit subscription IDs are honored |
| Event counts | `nostr.count()` | NIP-45 |
| Relay info documents | `relays.relayInformationsDocumentNip11()` | Full NIP-11 schema: limitations, fees, retention, supported NIPs |
| AUTH-gated relays | `nostr.connect(relays, signer: …)` | Automatic NIP-42 challenge answering |
| Reconnection | built-in | Exponential backoff + jitter; preserves your callbacks |

### Identity & keys

```dart
// Mnemonic → keys (NIP-06)
final privateKey = NostrKeys.getPrivateKeyFromMnemonic(mnemonic);

// bech32 entities (NIP-19): npub, nsec, nprofile, nevent, naddr
final naddr = bech32.encodeNAddr(
  kind: 30023,
  authorPubkey: pubkey,
  identifier: 'article-slug',
);

// nostr: URIs (NIP-21) — parse or build, bare entities tolerated
final parsed = NostrNip21().parseFully('nostr:$nprofile');

// Password-encrypted backups (NIP-49) — scrypt + XChaCha20-Poly1305
final ncryptsec = NostrNip49.encryptKey(
  privateKeyHex: keyPair.private,
  password: 'correct horse battery staple',
);
final recovered = NostrNip49.decryptKey(
  ncryptsec: ncryptsec,
  password: 'correct horse battery staple',
);
```

### Private messages (NIP-17 + NIP-59 + NIP-44)

The modern DM stack: unsigned rumors → signed seals → anonymous gift wraps, encrypted with spec-vector-verified NIP-44 v2.

```dart
final aliceSigner = NostrLocalKeySigner(keyPair);
final alice = NostrNip17(signer: aliceSigner);

// Alice → Bob
final rumor = alice.createChatMessageRumor(
  content: 'hey bob!',
  recipientPubkeys: [bobPubkey],
);
final giftWrap = await alice.wrapMessage(rumor, bobPubkey);
await nostr.publish(giftWrap); // kind 1059, ephemeral author, p-tagged to Bob

// Bob's side
final bob = NostrNip17(signer: bobSigner);
final unwrapped = await bob.unwrapMessage(receivedGiftWrap);
print(unwrapped.content); // 'hey bob!'
```

### Social features

`NostrSocialBuilder` covers the kinds real clients need:

| Feature | Method |
|---|---|
| Profiles (kind 0) | `updateProfile()` |
| Notes with threading (NIP-10) & mentions (NIP-27) | `createTextNote()` |
| Follow lists (NIP-02) | `updateFollowList()` |
| Reposts (NIP-18) | `createRepost()` |
| Reactions (NIP-25) | `createReaction()` |
| Comments (NIP-22) | `createComment()` |
| Deletions (NIP-09) | `createDeletionRequest()` |
| Long-form articles (NIP-23) | `createLongFormArticle()` |
| Any list (NIP-51) | `createListEvent()` |
| Relay list metadata (NIP-65) | `updateRelayList()` |

### Zaps & money (NIP-57)

```dart
final zaps = NostrZaps(signer: signer);

// Build a signed zap request.
final request = await zaps.createZapRequest(
  recipientPubkey: author,
  amountMillisats: 21000,
  lnurl: lnurlString,
);

// Resolve a Lightning Address to an invoice — no payment required to test.
final payUrl = lightningAddressToLnurlPayUrl('author@wallet.co');
final invoice = await zaps.requestInvoice(
  lnurlPayUrl: payUrl,
  amountMillisats: 21000,
  zapRequest: request,
);

// Parse incoming zap receipts (kind 9735), including anonymous ones.
final receipt = NostrZaps.parseZapReceipt(incomingReceipt);
final sender = NostrZaps.zapSenderPubkey(receipt.zapRequest); // null = anon
```

### Media

```dart
// Blossom blob storage (BUD-01/02).
final blossom = NostrBlossomClient(signer: signer);
final exists = await blossom.headBlob(serverUrl, sha256);
final bytes = await blossom.getBlob(serverUrl, sha256);
final descriptor = await blossom.uploadBlob(
  serverUrl: serverUrl,
  bytes: fileBytes,
  sha256Hex: sha256Hex,
);

// NIP-96 legacy upload + NIP-94 discoverable file metadata events.
```

### Proof of work (NIP-13)

```dart
final difficulty = NostrProofOfWork.getDifficulty(eventId);
final mined = await NostrProofOfWork.mineEvent(
  signer: signer,
  kind: 1,
  content: 'pow note',
  tags: [],
  targetDifficulty: 20,
);
```

### Pluggable signing

Ship apps that never touch raw private keys:

```dart
abstract interface class NostrEventSigner {
  String get publicKey;
  Future<NostrEvent> sign(NostrEvent event);
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey);
  Future<String> nip44Decrypt(String payload, String senderPublicKey);
}
```

`NostrLocalKeySigner` is included. Implement this interface once to support browser extensions (NIP-07), remote bunkers (NIP-46) or Android signer apps (NIP-55) — every feature above works through it.

## Architecture at a glance

```
Nostr() ─┬─ connect / publish / subscribe / count   ← typed facade (NostrResult<T>)
         ├─ keys · bech32 · utils                    ← identity services
         └─ relays                                   ← raw transport for power users
              ├─ NostrRelays.init(...)               ← callbacks, lazy listening
              ├─ startEventsSubscriptionAsync(...)   ← EOSE-bounded fetches
              └─ streams                             ← global EVENT/NOTICE/CLOSED streams
```

- `Nostr()` creates isolated instances (independent pools — ideal for tests).
- `Nostr.instance` is a process-wide singleton.
- All fallible operations return `NostrResult<T>`: call `.fold(success, failure)`, inspect `.isSuccess`, `.message`, `.code`, `.isRetryable`.

## NIP support matrix

| Status | NIPs |
|---|---|
| ✅ Implemented & live-tested | 01 · 02 · 05 · 06 · 09 · 10 · 11 · 13 · 17 · 18 · 19 · 21 · 22 · 23/30023 · 25 · 42 · 44 v2 · 45 · 49 · 51 · 57 · 59 · 65 |
| ✅ Implemented (client-side) | 94 · 96 · Blossom BUD-01/02 |
| 🔌 Via signer interface | 07 · 46 · 55 |

## Testing

Three tiers, all part of CI:

```bash
dart test                          # 400+ unit & fake-relay integration tests (default)

# Real-network suite against live public relays (opt-in):
RUN_REAL_NETWORK_TESTS=1 dart test test/real
```

The real-network suite publishes actual events as fresh identities, exchanges gift-wrapped DMs between two generated users over live relays, verifies NIP-09 deletion propagation, parses real zap receipts found in feeds, and soaks concurrent subscriptions for consistency. Relays go down regularly, so the suite picks healthy relays at runtime and skips gracefully when an external dependency (e.g. a wallet endpoint) is unreachable.

## Documentation & examples

- Full docs: [anasfik.github.io/nostr](https://anasfik.github.io/nostr/)
- API reference: [pub.dev/documentation/dart_nostr](https://pub.dev/documentation/dart_nostr/latest/)
- Runnable samples: [`example/`](example/) — key generation, publishing, subscriptions, NIP-05 verification, NIP-11 relay info

## Contributing

Issues and PRs are welcome. Please run `dart analyze`, `dart format`, and the full default test suite before submitting. Real-network changes should be validated with `RUN_REAL_NETWORK_TESTS=1 dart test test/real`.

## License

[MIT](LICENSE)
