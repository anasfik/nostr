# Dart_Nostr - Quick Reference Guide

## Package Overview

**dart_nostr** is a mature, feature-rich Dart/Flutter library for building Nostr clients. It implements 40+ NIPs (Nostr Implementation Possibilities) and provides a comprehensive API for key management, event handling, relay communication, and subscription management.

---

## Current Architecture

```
dart_nostr v9.2.5
│
├── Core Layer
│   ├── Key Pairs (BIP340, BIP39 support)
│   ├── Cryptography (SHA256, signing/verification)
│   └── Utilities (encoding, hashing, random generation)
│
├── Instance Layer (Singleton Services)
│   ├── NostrKeys - Key generation & derivation
│   ├── NostrRelays - Relay connections & subscriptions
│   ├── NostrUtils - Hashing, NIP05 verification, Bech32
│   └── NostrBech32 - Bech32 encoding/decoding
│
├── Model Layer (Data Structures)
│   ├── NostrEvent - Event representation
│   ├── NostrRequest - Subscription requests
│   ├── NostrFilter - Event filtering
│   ├── NostrRequestClose - Subscription closure
│   ├── NostrKeyPairs - Cryptographic keys
│   └── Other entities (Notice, OK, RelayInformations, etc.)
│
└── Service Layer
    └── NostrServices - Service aggregation & management
```

---

## Test Suite Summary

**Total: 118 Tests (All Passing ✅)**

| Component | Tests | Coverage |
|-----------|-------|----------|
| Key Pairs (Cryptography) | 8 | Binary operations, signing, verification |
| Keys Service | 11 | Key generation, derivation, caching |
| Relay Tests (NEW) | 46 | Connection, subscriptions, filtering, parameters |
| Utils Service | 15 | Hashing, NIP05, Bech32, random generation |
| Events | 12 | Deserialization, field parsing, tags |
| Filters | 12 | Filter creation, composition, mapping |
| Requests | 14 | Request serialization, subscription management |

### Relay Tests (46 tests, NEW)
- **Relay Registration** (3): Init methods, async behavior
- **Subscription Generation** (21): Stream creation, filtering, tag handling
- **Subscription Closure** (4): Close requests, multiple subscriptions
- **Stream Operations** (6): ID generation, unique streams, immutability
- **Models** (7): Filter toMap, type preservation, equality
- **Connection Parameters** (6): Timeout, retry, clearing registries

---

## Key Components

### 1. Nostr Singleton (Main Entry Point)

```dart
// Access main service
Nostr.instance.services.keys     // NostrKeys service
Nostr.instance.services.relays   // NostrRelays service
Nostr.instance.services.utils    // NostrUtils service
```

### 2. Key Management

```dart
// Generate new key pair
final keyPair = await Nostr.instance.services.keys.generateKeyPair();

// Derive public key from private
final publicKey = await Nostr.instance.services.keys.derivePublicKey('privateKey');

// Sign message
final signature = await Nostr.instance.services.keys.signMessage(
  privateKey: 'key',
  message: 'message',
);
```

### 3. Relay Management

```dart
// Initialize relays
await Nostr.instance.services.relays.init(
  relaysUrl: [
    'wss://relay.damus.io',
    'wss://relay.nostr.band',
    'wss://nos.lol',
  ],
);

// Subscribe to events
final stream = Nostr.instance.services.relays.startEventsSubscription(
  request: NostrRequest(
    filters: [
      NostrFilter(
        kinds: [1],        // Text notes
        authors: ['author1'],
        limit: 50,
      ),
    ],
  ),
);

// Listen for events
stream.stream.listen((event) {
  print('Event: ${event.content}');
});
```

### 4. Event Filtering

```dart
// Simple filter
final filter = NostrFilter(kinds: [1], limit: 10);

// Complex filter
final complexFilter = NostrFilter(
  kinds: [0, 1, 7],           // Multiple kinds
  authors: ['author1', 'author2'],
  e: ['eventId1'],             // Referenced events
  p: ['pubkey1'],              // Referenced pubkeys
  since: DateTime.now().subtract(Duration(days: 7)),
  until: DateTime.now(),
  limit: 100,
);
```

### 5. Event Operations

```dart
// Create event
final event = NostrEvent(
  content: 'Hello, Nostr!',
  kind: 1,
  pubKey: 'publicKey',
  createdAt: DateTime.now(),
  tags: [
    ['e', 'replyToEventId'],
    ['p', 'replyToAuthorId'],
  ],
);

// Sign event (BIP340)
final signedEvent = event.copyWith(sig: signature);

// Publish to relay
// (handled internally via relay websocket)
```

---

## Supported NIPs (40+)

Core Protocol:
- NIP-01: Event generation & signing
- NIP-02: Contact list
- NIP-03: OpenTimestamps
- NIP-05: Mapping nostr keys to DNS
- NIP-06: Basic key derivation

Event Types:
- NIP-08: Mentioning users
- NIP-09: Event deletion
- NIP-10: Relationships
- NIP-13: Proof of work
- NIP-14: Subject tag
- NIP-15: Nostr marketplace
- NIP-18: Reposts

Relay Protocol:
- NIP-11: Relay information document

Encryption/Auth:
- NIP-04: Encrypted direct messages
- NIP-42: Authentication

Other:
- NIP-19: Bech32-encoded entities (nprofile, nevent, etc.)
- NIP-25: Reactions
- NIP-28: Public chat channels
- NIP-39: External identities
- NIP-47: Wallet connect
- NIP-50: Keywords filter
- NIP-51: Lists
- NIP-57: Zaps
- And 20+ more...

---

## Recent Improvements

### Commit: [tests] add relay and subscription coverage
- **Date:** Feb 10, 2026
- **Files Modified:** 7
- **Changes:** +1620 lines, -150 lines
- **New Test Files:** 5
  - `test/nostr/core/key_pairs_test.dart` (8 tests)
  - `test/nostr/instance/keys/keys_test.dart` (11 tests)
  - `test/nostr/instance/relays/relays_test.dart` (46 tests)
  - `test/nostr/model/request/filter_test.dart` (12 tests)
  - `test/nostr/model/request/request_test.dart` (14 tests)

---

## Strategic Roadmap (2026)

### Phase 1: Stability (Q1 2026)
- Expand test suite from 118 → 500+ tests
- Integration tests
- Error handling improvements
- Documentation enhancements

### Phase 2: Features (Q2 2026)
- Storage adapter implementation
- Advanced relay management
- Batch event operations
- NIP-42 & NIP-44 implementation

### Phase 3: Performance (Q3 2026)
- Caching layer
- Serialization optimization
- Connection pooling
- Performance benchmarks

### Phase 4: Developer Experience (Q4 2026)
- CLI tools
- Code generators
- Example applications
- Community features

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Test Count | 118 | 500+ |
| Code Coverage | ~70% | 85%+ |
| Monthly Downloads | ~2k | 10k+ |
| GitHub Stars | ~400 | 500+ |
| Build Time | <30s | <30s |
| Package Size | <500KB | <500KB |

---

## Dependencies

```yaml
# Core
bip340: ^0.3.0           # Schnorr signatures
bip32_bip44: ^1.0.0      # Key derivation
bip39: ^1.0.6            # Mnemonic seeds
crypto: ^3.0.2           # SHA256, HMAC
hex: ^0.2.0              # Hex encoding

# Communication
web_socket_channel: ^3.0.3  # WebSocket relay

# Utilities
bech32: ^0.2.2           # Bech32 encoding
http: ^1.1.0             # HTTP client

# Code Quality
equatable: ^2.0.5        # Equality comparison
async: ^2.13.0           # Async utilities

# Development
test:                    # Unit testing
very_good_analysis:      # Linting
```

---

## Quick Start

### 1. Installation

```bash
flutter pub add dart_nostr  # Flutter
dart pub add dart_nostr     # Dart
```

### 2. Basic Setup

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() async {
  // Initialize relays
  await Nostr.instance.services.relays.init(
    relaysUrl: ['wss://relay.damus.io'],
  );
  
  // Subscribe to events
  final stream = Nostr.instance.services.relays
    .startEventsSubscription(
      request: NostrRequest(
        filters: [NostrFilter(kinds: [1], limit: 10)],
      ),
    );
  
  // Listen for events
  stream.stream.listen((event) {
    print('${event.pubKey}: ${event.content}');
  });
}
```

### 3. Generate Keys

```dart
final keyPair = await Nostr.instance.services.keys
  .generateKeyPair();

print('Private: ${keyPair.privateKey}');
print('Public: ${keyPair.publicKey}');
```

### 4. Create & Sign Events

```dart
final event = NostrEvent(
  content: 'Hello, Nostr!',
  kind: 1,
  pubKey: keyPair.publicKey,
  createdAt: DateTime.now(),
);

// Sign (BIP340)
final sig = await Nostr.instance.services.keys.signMessage(
  privateKey: keyPair.privateKey,
  message: event.toJson(),
);

final signedEvent = event.copyWith(sig: sig);
```

---

## File Structure

```
lib/
├── dart_nostr.dart          # Main export
├── nostr/
│   ├── core/                # Cryptography & utilities
│   │   ├── key_pairs.dart
│   │   ├── utils.dart
│   │   ├── extensions.dart
│   │   ├── constants.dart
│   │   └── exceptions.dart
│   ├── instance/            # Services
│   │   ├── keys/
│   │   ├── relays/
│   │   ├── utils/
│   │   ├── bech32/
│   │   ├── tlv/
│   │   └── registry.dart
│   ├── model/               # Data structures
│   │   ├── event/
│   │   ├── request/
│   │   ├── base.dart
│   │   └── export.dart
│   └── service/             # Service aggregation
│       └── services.dart
```

---

## Performance Characteristics

| Operation | Typical Time | Notes |
|-----------|--------------|-------|
| Key generation | <100ms | BIP39 + BIP32 |
| Message signing | <10ms | BIP340 |
| Event serialization | <5ms | JSON |
| Relay connection | 100-500ms | Network dependent |
| Event subscription | <20ms | Filter processing |
| NIP-05 verification | 100-2000ms | HTTP request |

---

## Common Patterns

### Pattern 1: Complete Client Flow

```dart
void main() async {
  // 1. Generate keys
  final keyPair = await Nostr.instance.services.keys
    .generateKeyPair();
  
  // 2. Connect to relays
  await Nostr.instance.services.relays.init(
    relaysUrl: ['wss://relay.damus.io'],
  );
  
  // 3. Create event
  final event = NostrEvent(
    content: 'Hello!',
    kind: 1,
    pubKey: keyPair.publicKey,
    createdAt: DateTime.now(),
  );
  
  // 4. Sign event
  final sig = await Nostr.instance.services.keys
    .signMessage(
      privateKey: keyPair.privateKey,
      message: event.toJson(),
    );
  
  final signedEvent = event.copyWith(sig: sig);
  
  // 5. Subscribe to events
  final stream = Nostr.instance.services.relays
    .startEventsSubscription(
      request: NostrRequest(
        filters: [NostrFilter(kinds: [1])],
      ),
    );
  
  // 6. Listen
  stream.stream.listen(print);
}
```

### Pattern 2: Filter Composition

```dart
// Build complex filter
final filter = NostrFilter(
  kinds: [1, 7],                           // Text & reactions
  authors: authorsList,
  e: referencedEventIds,
  since: DateTime.now().subtract(Duration(days: 7)),
  until: DateTime.now(),
  limit: 100,
);

final request = NostrRequest(filters: [filter]);
final stream = Nostr.instance.services.relays
  .startEventsSubscription(request: request);
```

### Pattern 3: Multiple Filters

```dart
final request = NostrRequest(
  filters: [
    NostrFilter(kinds: [0]),        // User metadata
    NostrFilter(kinds: [1]),        // Text notes
    NostrFilter(kinds: [7]),        // Reactions
  ],
);
```

---

## Next Steps

1. **Review** the full `IMPROVEMENT_IDEAS.md` for strategic guidance
2. **Implement** Phase 1 improvements (stability & testing)
3. **Contribute** to the package development
4. **Build** your Nostr client with dart_nostr

---

## Resources

- **GitHub:** https://github.com/anasfik/nostr
- **Pub.dev:** https://pub.dev/packages/dart_nostr
- **Nostr Protocol:** https://nostr.com/
- **Nostr NIPs:** https://github.com/nostr-protocol/nips

