# dart_nostr

A Dart/Flutter library for building Nostr clients. Built with simplicity in mind, dart_nostr handles the complexity of the Nostr protocol so you can focus on creating great user experiences.

## What is Nostr?

[Nostr](https://nostr.com/) (Notes and Other Stuff Transmitted by Relays) is a simple, open protocol for global, decentralized, and censorship-resistant social media. This library gives you everything you need to build Nostr clients in Dart or Flutter.

## Features

- Complete key management (generation, derivation, encoding/decoding)
- Event creation, signing, and verification
- WebSocket relay connections with automatic reconnection
- Event subscriptions with stream and future-based APIs
- Support for 40+ NIPs out of the box
- NIP-05 verification
- NIP-19 entity encoding (nevent, nprofile, etc.)
- Proof of work support (NIP-13)
- And much more

## Supported NIPs

Currently implements: [01](https://github.com/nostr-protocol/nips/blob/master/01.md), [02](https://github.com/nostr-protocol/nips/blob/master/02.md), [03](https://github.com/nostr-protocol/nips/blob/master/03.md), [04](https://github.com/nostr-protocol/nips/blob/master/04.md), [05](https://github.com/nostr-protocol/nips/blob/master/05.md), [06](https://github.com/nostr-protocol/nips/blob/master/06.md), [08](https://github.com/nostr-protocol/nips/blob/master/08.md), [09](https://github.com/nostr-protocol/nips/blob/master/09.md), [10](https://github.com/nostr-protocol/nips/blob/master/10.md), [11](https://github.com/nostr-protocol/nips/blob/master/11.md), [13](https://github.com/nostr-protocol/nips/blob/master/13.md), [14](https://github.com/nostr-protocol/nips/blob/master/14.md), [15](https://github.com/nostr-protocol/nips/blob/master/15.md), [18](https://github.com/nostr-protocol/nips/blob/master/18.md), [19](https://github.com/nostr-protocol/nips/blob/master/19.md), [21](https://github.com/nostr-protocol/nips/blob/master/21.md), [23](https://github.com/nostr-protocol/nips/blob/master/23.md), [24](https://github.com/nostr-protocol/nips/blob/master/24.md), [25](https://github.com/nostr-protocol/nips/blob/master/25.md), [27](https://github.com/nostr-protocol/nips/blob/master/27.md), [28](https://github.com/nostr-protocol/nips/blob/master/28.md), [30](https://github.com/nostr-protocol/nips/blob/master/30.md), [31](https://github.com/nostr-protocol/nips/blob/master/31.md), [32](https://github.com/nostr-protocol/nips/blob/master/32.md), [36](https://github.com/nostr-protocol/nips/blob/master/36.md), [38](https://github.com/nostr-protocol/nips/blob/master/38.md), [39](https://github.com/nostr-protocol/nips/blob/master/39.md), [40](https://github.com/nostr-protocol/nips/blob/master/40.md), [45](https://github.com/nostr-protocol/nips/blob/master/45.md), [47](https://github.com/nostr-protocol/nips/blob/master/47.md), [48](https://github.com/nostr-protocol/nips/blob/master/48.md), [50](https://github.com/nostr-protocol/nips/blob/master/50.md), [51](https://github.com/nostr-protocol/nips/blob/master/51.md), [52](https://github.com/nostr-protocol/nips/blob/master/52.md), [53](https://github.com/nostr-protocol/nips/blob/master/53.md), [56](https://github.com/nostr-protocol/nips/blob/master/56.md), [57](https://github.com/nostr-protocol/nips/blob/master/57.md), [58](https://github.com/nostr-protocol/nips/blob/master/58.md), [72](https://github.com/nostr-protocol/nips/blob/master/72.md), [75](https://github.com/nostr-protocol/nips/blob/master/75.md), [78](https://github.com/nostr-protocol/nips/blob/master/78.md), [84](https://github.com/nostr-protocol/nips/blob/master/84.md), [89](https://github.com/nostr-protocol/nips/blob/master/89.md), [94](https://github.com/nostr-protocol/nips/blob/master/94.md), [98](https://github.com/nostr-protocol/nips/blob/master/98.md), [99](https://github.com/nostr-protocol/nips/blob/master/99.md).

Note: NIP-42 and NIP-44 are planned for future releases. Platform-specific NIPs like [NIP-07](https://github.com/nostr-protocol/nips/blob/master/07.md) (web browser extensions) aren't directly applicable to this library.

## Getting Started

Add dart_nostr to your pubspec.yaml:

```yaml
dependencies:
  dart_nostr: ^9.2.4
```

Or use the command line:

```bash
flutter pub add dart_nostr  # Flutter
dart pub add dart_nostr     # Dart
```

## Quick Example

Here's a simple example to get you started:

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // Initialize
  final nostr = Nostr.instance;

  // Generate keys
  final keyPair = nostr.keysService.generateKeyPair();
  print('Public key: ${keyPair.public}');

  // Connect to relays
  await nostr.relaysService.init(
    relaysUrl: ['wss://relay.damus.io', 'wss://nos.lol'],
  );

  // Create and publish an event
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello Nostr!',
    keyPairs: keyPair,
  );

  nostr.relaysService.sendEventToRelays(event);

  // Subscribe to events
  final stream = nostr.relaysService.startEventsSubscription(
    request: NostrRequest(filters: [
      NostrFilter(kinds: [1], limit: 10),
    ]),
  );

  stream.stream.listen((event) {
    print('Received: ${event.content}');
  });
}
```

## Usage Guide

### Working with Instances

You can use dart_nostr in two ways depending on your needs:

```dart
// Singleton - shared state across your app
final nostr = Nostr.instance;
```

```dart
// Multiple instances - isolated state
final nostr1 = Nostr();
final nostr2 = Nostr(); // Completely independent
```

Most apps work well with the singleton. Use multiple instances if you need to connect to different relay sets simultaneously or want to isolate different parts of your app.

### Keys

#### Generate New Keys

```dart
final keyPair = nostr.keysService.generateKeyPair();
print(keyPair.public);  // Your public key
print(keyPair.private); // Keep this secret!
```

#### Work with Existing Keys

```dart
// If you already have a private key
final keyPair = nostr.keysService
    .generateKeyPairFromExistingPrivateKey(myPrivateKey);
```

#### Sign and Verify Messages

```dart
final signature = nostr.keysService.sign(
  privateKey: keyPair.private,
  message: "GM",
);

final isValid = nostr.keysService.verify(
  publicKey: keyPair.public,
  message: "GM",
  signature: signature,
);
```

#### Bech32 Encoding (nsec/npub)

```dart
// Encode to human-friendly formats
final nsec = nostr.keysService.encodePrivateKeyToNsec(privateKey);
final npub = nostr.keysService.encodePublicKeyToNpub(publicKey);

// Decode back
final privateKey = nostr.keysService.decodeNsecKeyToPrivateKey(nsec);
final publicKey = nostr.keysService.decodeNpubKeyToPublicKey(npub);
```

### Events

#### Create and Sign Events

The easiest way:

```dart
final event = NostrEvent.fromPartialData(
  kind: 1,  // Text note
  content: 'Hello Nostr!',
  keyPairs: keyPair,
  tags: [
    ['p', 'pubkey_to_mention'],
    ['e', 'event_id_to_reference'],
  ],
);

// Event is already signed and has an ID
print(event.id);
print(event.sig);
```

### Relays

#### Connect to Relays

```dart
await nostr.relaysService.init(
  relaysUrl: [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.nostr.band',
  ],
);
```

#### Subscribe to Events

Real-time streaming:

```dart
final stream = nostr.relaysService.startEventsSubscription(
  request: NostrRequest(filters: [
    NostrFilter(
      kinds: [1],
      authors: [keyPair.public],
      limit: 50,
    ),
  ]),
);

stream.stream.listen((event) {
  print(event.content);
});

// Don't forget to close when done
stream.close();
```

One-time fetch (waits for EOSE):

```dart
final events = await nostr.relaysService.startEventsSubscriptionAsync(
  request: NostrRequest(filters: [
    NostrFilter(kinds: [1], limit: 20),
  ]),
);

print('Got ${events.length} events');
```

#### Publish Events

```dart
nostr.relaysService.sendEventToRelays(event);

// Or wait for confirmation
final ok = await nostr.relaysService.sendEventToRelaysAsync(event);
print(ok.message);
```

### More Features

#### NIP-05 Verification

```dart
final verified = await nostr.utilsService.verifyNip05(
  internetIdentifier: "user@domain.com",
  pubKey: publicKey,
);
```

#### NIP-19 Entities

```dart
// Create shareable event links
final nevent = nostr.utilsService.encodeNevent(
  eventId: event.id,
  pubkey: keyPair.public,
  userRelays: ['wss://relay.damus.io'],
);

// Create profile links
final nprofile = nostr.utilsService.encodeNProfile(
  pubkey: keyPair.public,
  userRelays: ['wss://relay.damus.io'],
);
```

#### Event Counting

```dart
final countEvent = NostrCountEvent.fromPartialData(
  eventsFilter: NostrFilter(kinds: [1], authors: [keyPair.public]),
);

final count = await nostr.relaysService.sendCountEventToRelaysAsync(countEvent);
print('User has ${count.count} text notes');
```

#### Relay Information

```dart
final info = await nostr.relaysService.relayInformationsDocumentNip11(
  relayUrl: "wss://relay.damus.io",
);

print(info?.name);
print(info?.supportedNips);
```

## Examples

The [example](example/) directory contains runnable examples showing:

- Basic key management
- Creating and publishing events
- Subscribing to event streams
- Working with different event kinds
- NIP-05 verification flows
- And more real-world scenarios

## API Documentation

Full API documentation is available at [pub.dev](https://pub.dev/documentation/dart_nostr/latest/).

## Contributing

Found a bug? Have a feature idea? Contributions are welcome!

1. Check existing issues or create a new one
2. Fork the repository
3. Create your feature branch
4. Make your changes
5. Submit a pull request

Please ensure your code follows the existing style and includes tests where appropriate.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- [Nostr Protocol](https://nostr.com/)
- [NIPs Repository](https://github.com/nostr-protocol/nips)
- [pub.dev Package](https://pub.dev/packages/dart_nostr)
- [GitHub Repository](https://github.com/anasfik/nostr)

## Questions?

- Open an [issue](https://github.com/anasfik/nostr/issues)
- Start a [discussion](https://github.com/anasfik/nostr/discussions)
