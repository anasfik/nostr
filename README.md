# dart_nostr

dart_nostr is a Dart and Flutter SDK for building Nostr applications with production-ready reliability.

It is designed for developers who need more than a demo client: reliable relay communication, typed failures, strong key tooling, clean subscription management, sensible defaults, and enough low-level access to build custom protocol workflows when needed.

Whether you are building a consumer app, a creator tool, a community platform, a wallet-connected product, or a founder-facing Nostr integration, dart_nostr gives you a practical path from prototype to production.

## Why developers choose dart_nostr

- Typed success and failure results for predictable error handling
- High-level facade for app development and low-level relay APIs for protocol experimentation
- Key generation, signing, verification, encoding, and derivation
- Event publishing, event counting, request subscriptions, and stream lifecycle management
- Retry policies, timeout control, and explicit connection management
- NIP-05 verification and NIP-19 entity encoding support
- Clean testability through dependency-injectable transports and isolated `Nostr` instances
- Works in Dart and Flutter projects without forcing app architecture decisions

## Who this package is for

dart_nostr is a strong fit if you are building:

- Nostr mobile or desktop clients
- Creator publishing tools
- Community and membership products
- Nostr-powered social features inside an existing app
- Relay-aware backend services in Dart
- Internal tooling for protocol research, moderation, search, or automation

## Install

Add the package to your project:

```yaml
dependencies:
  dart_nostr: ^9.2.5
```

Or use the CLI:

```bash
flutter pub add dart_nostr
```

```bash
dart pub add dart_nostr
```

## How to use it

The package has two levels of API:

- **High-level:** `Nostr.instance` and top-level convenience methods for app development
- **Low-level:** `Nostr.services` and `Nostr.relays` for advanced protocol work and custom implementations

## Quick start

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr.instance;

  final connectResult = await nostr.connect([
    'wss://relay.damus.io',
    'wss://nos.lol',
  ]);

  if (connectResult.isFailure) {
    print(connectResult.failureOrNull);
    return;
  }

  final keyPair = nostr.keys.generateKeyPair();

  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello from dart_nostr',
    keyPairs: keyPair,
  );

  final publishResult = await nostr.publish(event);

  publishResult.fold(
    (ok) => print('Published: ${ok.message}'),
    (failure) => print('Publish failed: $failure'),
  );
}
```

## What the package gives you

### Product-facing API

The top-level `Nostr` facade is optimized for app developers.

It provides:

- `connect()`
- `connectDefaults()`
- `disconnect()`
- `publish()`
- `count()`
- `subscribe()`
- `subscribeFilters()`
- `subscribeRequest()`
- subscription statistics and active subscription inspection

This keeps common app flows readable while still exposing the underlying protocol surface when you need it.

### Protocol-facing API

If you need deeper control, use:

- `nostr.relays` for low-level relay operations
- `nostr.services` for direct access to specialized components
- `NostrRelayTransport` for custom transport implementations

This split makes the package suitable both for shipping products and for advanced Nostr engineering.

## Core capabilities

### 1. Key management

Generate, reconstruct, sign, verify, and validate keys.

```dart
final nostr = Nostr.instance;
final keyPair = nostr.keys.generateKeyPair();

final signature = nostr.keys.sign(
  privateKey: keyPair.private,
  message: 'GM',
);

final isVerified = nostr.keys.verify(
  publicKey: keyPair.public,
  message: 'GM',
  signature: signature,
);
```

### 2. Event creation and publishing

Create signed events with a minimal API.

```dart
final event = NostrEvent.fromPartialData(
  kind: 1,
  content: 'Shipping a real Nostr product in Dart',
  keyPairs: keyPair,
  tags: [
    ['t', 'dart'],
    ['t', 'nostr'],
  ],
);

final result = await nostr.publish(event);
```

### 3. Typed subscriptions

Subscribe with explicit request objects and handle success and failure clearly.

```dart
final result = nostr.subscribeRequest(
  NostrRequest(
    filters: const [
      NostrFilter(kinds: [1], limit: 25),
    ],
  ),
);

result.fold(
  (stream) {
    stream.stream.listen((event) {
      print(event.content);
    });
  },
  (failure) => print(failure),
);
```

### 4. Subscription lifecycle tracking

The high-level client integrates with `SubscriptionManager` so applications can inspect active subscriptions and metrics.

```dart
final active = nostr.activeSubscriptions;
final stats = nostr.subscriptionStatistics;

print('Active subscriptions: ${active.length}');
print('Tracked events: ${stats.totalEventCount}');
```

### 5. Event counting

Use NIP-45 style count requests where supported by relays.

```dart
final countResult = await nostr.count(
  NostrCountEvent.fromPartialData(
    eventsFilter: const NostrFilter(kinds: [1], limit: 100),
  ),
);
```

### 6. NIP-05 verification

Resolve or verify internet identifiers.

```dart
final publicKey = await nostr.utils.pubKeyFromIdentifierNip05(
  internetIdentifier: 'jb55@jb55.com',
);
```

```dart
final verified = await nostr.utils.verifyNip05(
  internetIdentifier: 'jb55@jb55.com',
  pubKey: publicKey ?? '',
);
```

### 7. NIP-19 encoding

Create and decode `npub`, `nsec`, `nprofile`, and `nevent` values.

```dart
final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
final nprofile = nostr.bech32.encodeNProfile(
  pubkey: keyPair.public,
  userRelays: ['wss://relay.damus.io'],
);
```

### 8. Relay metadata

Fetch relay information documents via NIP-11.

```dart
final relayInfo = await nostr.relays.relayInformationsDocumentNip11(
  relayUrl: 'wss://relay.damus.io',
);

print(relayInfo?.name);
print(relayInfo?.supportedNips);
```

## Production-ready characteristics

This package is a complete SDK, not just a wrapper.

It includes:

- Typed `NostrResult<T>` for predictable error handling
- Structured `NostrFailure` error mapping
- Configurable retry policies via `NostrRetryPolicy`
- Configurable timeouts via `NostrClientOptions`
- Explicit connection lifecycle management
- Isolated instances for testing or multi-tenant scenarios
- Dependency injection for transport replacement and mocking
- Clean separation of concerns in request, key, and count operations

## Recommended usage pattern

For most applications:

1. Create a `Nostr` instance per app or account scope
2. Connect during startup; disconnect on shutdown
3. Keep event publishing and subscriptions behind your domain layer
4. Use typed failures for logging and error handling
5. Use low-level relay APIs only when you need protocol control

This keeps Nostr concerns isolated without leaking relay details throughout your app.

## API overview

### Top-level facade

Use these directly in most apps:

- `nostr.connect()`
- `nostr.connectDefaults()`
- `nostr.disconnect()`
- `nostr.publish()`
- `nostr.count()`
- `nostr.subscribe()`
- `nostr.subscribeFilters()`
- `nostr.subscribeRequest()`
- `nostr.closeAllSubscriptions()`

### Direct surfaces

- `nostr.keys`
- `nostr.utils`
- `nostr.bech32`
- `nostr.relays`
- `nostr.subscriptions`
- `nostr.services`

## Example directory

The [example](example/) folder includes practical samples for:

- Key generation and validation
- Publishing events
- Asynchronous publish flows
- Relay connection management
- Request subscriptions
- Raw relay entity streams
- NIP-05 verification
- NIP-11 relay documents
- NIP-19 entity encoding
- Request reopening and subscription reuse

Start here to understand the SDK patterns and capabilities.

## Supported protocol areas

dart_nostr covers a broad set of Nostr capabilities across core events, relay communication, key handling, identity, counting, metadata, and entity encoding.

The project historically tracked a large set of NIPs, including major coverage around:

- core protocol and relay messaging
- metadata and text notes
- delete events
- relay information documents
- internet identifiers
- entity encoding and sharing
- counting and other higher-level relay interactions

If you need exact NIP-by-NIP coverage for a production requirement, review the codebase and docs for the specific feature path you plan to ship.

## Choosing between `client`, `relays`, and `services`

Use `client` or top-level `Nostr` methods when:

- you want typed results
- you want retries and timeout handling
- you want managed subscriptions
- you are building application features

Use `relays` when:

- you need lower-level relay behavior
- you need raw request and EOSE handling
- you need protocol experimentation or migration work

Use `services` when:

- you want direct access to specialized internals
- you are composing your own higher-level abstraction

## Running examples and tests

Examples are in [example](example/).

Run tests with:

```bash
dart test
```

## Contributing

Contributions are welcome.

Useful contributions include:

- protocol correctness improvements
- performance work in relay handling and subscriptions
- documentation and examples
- stronger tests around edge cases and relay behavior
- new transport implementations or better observability patterns

Before opening a pull request, make sure your change includes tests when appropriate and keeps the public API clear.

## License

MIT. See [LICENSE](LICENSE).

## Links

- [pub.dev package](https://pub.dev/packages/dart_nostr)
- [API documentation](https://pub.dev/documentation/dart_nostr/latest/)
- [GitHub repository](https://github.com/anasfik/nostr)
- [Nostr protocol](https://nostr.com/)
- [NIPs repository](https://github.com/nostr-protocol/nips)

## Philosophy

dart_nostr is built for developers who want reliability without unnecessary complexity. Whether you're building creator tools, consumer apps, community platforms, or experimenting with Nostr, this SDK provides a solid foundation with sensible defaults and enough flexibility for advanced use cases.
