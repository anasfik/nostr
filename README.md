# dart_nostr

dart_nostr is a Dart and Flutter SDK for building Nostr applications. It handles relay connections, event signing and publishing, typed subscription management, key tooling, and NIP utilities — so you can focus on your product instead of the protocol.

## Documentation

Full API guides, per-feature references, and advanced configuration are in the documentation site:

- [Introduction and overview](https://anasfik.github.io/nostr/)
- [Installation](https://anasfik.github.io/nostr/installation)
- [Quick start](https://anasfik.github.io/nostr/quick-start)
- [Keys](https://anasfik.github.io/nostr/usage/keys-management/)
- [Relays and events](https://anasfik.github.io/nostr/usage/relays-and-events/connecting-to-relays)
- [Identity (NIP-05, NIP-19)](https://anasfik.github.io/nostr/usage/identity/nip05)
- [Error handling](https://anasfik.github.io/nostr/usage/advanced/error-handling)
- [Advanced configuration](https://anasfik.github.io/nostr/usage/advanced/client-options)

Source documentation is also available on [pub.dev](https://pub.dev/documentation/dart_nostr/latest/).

## Getting Started

### Install

```yaml
dependencies:
  dart_nostr: ^10.0.0
```

```bash
dart pub add dart_nostr
# or
flutter pub add dart_nostr
```

### Import

```dart
import 'package:dart_nostr/dart_nostr.dart';
```

### Connect, publish, and subscribe

```dart
Future<void> main() async {
  final nostr = Nostr.instance;

  // Connect to relays
  final connectResult = await nostr.connect([
    'wss://relay.damus.io',
    'wss://nos.lol',
  ]);

  if (connectResult.isFailure) {
    print(connectResult.failureOrNull);
    return;
  }

  // Generate a key pair
  final keyPair = nostr.keys.generateKeyPair();

  // Publish a note
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello from dart_nostr',
    keyPairs: keyPair,
  );

  final publishResult = await nostr.publish(event);
  publishResult.fold(
    (ok) => print('published: ${ok.isEventAccepted}'),
    (failure) => print('failed: ${failure.message}'),
  );

  // Subscribe to recent notes
  final subResult = nostr.subscribeRequest(
    NostrRequest(
      filters: [
        NostrFilter(
          kinds: [1],
          limit: 20,
          since: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    ),
  );

  subResult.fold(
    (stream) {
      stream.stream.listen((event) => print(event.content));
    },
    (failure) => print('subscribe failed: ${failure.message}'),
  );
}
```

### Error handling pattern

Every operation that can fail returns `NostrResult<T>`:

```dart
result.fold(
  (value) { /* success */ },
  (failure) {
    print(failure.message);
    print(failure.code);
    print(failure.isRetryable);
  },
);
```

### Key operations

```dart
final keyPair = nostr.keys.generateKeyPair();
print(keyPair.public);   // hex pubkey
print(keyPair.private);  // hex privkey

// Reconstruct from private key
final same = nostr.keys.generateKeyPairFromExistingPrivateKey(keyPair.private);

// NIP-19 bech32 encoding
final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPair.private);

// Sign and verify
final sig = nostr.keys.sign(privateKey: keyPair.private, message: 'hello');
final ok  = nostr.keys.verify(publicKey: keyPair.public, message: 'hello', signature: sig);
```

### NIP-05 identity verification

```dart
final pubKey = await nostr.utils.pubKeyFromIdentifierNip05(
  internetIdentifier: 'user@domain.com',
);

final verified = await nostr.utils.verifyNip05(
  internetIdentifier: 'user@domain.com',
  pubKey: pubKey ?? '',
);
```

## What the package provides

- `Nostr.instance` — singleton; `Nostr()` — isolated instance with independent relay pool
- `nostr.connect()` / `nostr.disconnect()` — connection lifecycle with typed results
- `nostr.publish()` — signed event submission with relay OK response
- `nostr.subscribeRequest()` / `nostr.subscribeFilters()` — typed stream subscriptions
- `nostr.count()` — NIP-45 event count requests
- `nostr.keys` — key generation, derivation, signing, verification
- `nostr.bech32` — NIP-19 encode/decode (npub, nsec, nprofile, nevent)
- `nostr.utils` — NIP-05 resolution and verification
- `nostr.relays` — low-level relay pool for protocol work
- `NostrResult<T>` / `NostrFailure` — typed error model throughout
- `NostrClientOptions` / `NostrRetryPolicy` — configurable timeouts and retry

## API surfaces

| Surface | Use when |
|---|---|
| Top-level facade (`nostr.connect`, `nostr.publish`, ...) | Building app features, need typed results and lifecycle management |
| `nostr.relays` | Raw relay operations, protocol research, custom orchestration |
| `nostr.services` | Direct access to internal components, building abstractions |

## Example files

The [example](example/) directory contains runnable samples:

- [main.dart](example/main.dart) — end-to-end workflow covering all major features
- [generate_key_pair.dart](example/generate_key_pair.dart) — key generation and validation
- [sending_event_to_relays.dart](example/sending_event_to_relays.dart) — publish metadata and notes
- [listening_to_events.dart](example/listening_to_events.dart) — subscriptions and filters
- [signing_and_verfiying_messages.dart](example/signing_and_verfiying_messages.dart) — sign and verify
- [verify_nip05.dart](example/verify_nip05.dart) — NIP-05 verification
- [relay_document_nip_11.dart](example/relay_document_nip_11.dart) — relay info fetch

## Tests

```bash
dart test
```

## Contributing

Fork the [repository](https://github.com/anasfik/nostr), make changes, and open a pull request. Include tests where appropriate.

## License

MIT. See [LICENSE](LICENSE).

## Links

- [pub.dev package](https://pub.dev/packages/dart_nostr)
- [Documentation](https://anasfik.github.io/nostr/)
- [API reference](https://pub.dev/documentation/dart_nostr/latest/)
- [GitHub repository](https://github.com/anasfik/nostr)
- [Nostr protocol](https://nostr.com/)
- [NIPs specification](https://github.com/nostr-protocol/nips)
