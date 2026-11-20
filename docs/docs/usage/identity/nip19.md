---
sidebar_position: 2
description: Encode and decode NIP-19 entities — npub, nsec, nprofile, nevent, naddr.
---

# NIP-19 encoding

NIP-19 covers the bech32 forms used to share keys and event references. In dart_nostr they are methods on `nostr.bech32`; the full method-by-method reference, including the exact decoded map keys, is on [Keys — NIP-19 bech32 encoding](../keys-management/bech32-encoding.md).

| Entity | Method |
|---|---|
| `npub` | `nostr.bech32.encodePublicKeyToNpub(pubkey)` |
| `nsec` | `nostr.bech32.encodePrivateKeyToNsec(privkey)` |
| `nprofile` | `nostr.bech32.encodeNProfile(pubkey:, userRelays:)` |
| `nevent` | `nostr.bech32.encodeNevent(eventId:, pubkey:, userRelays:)` |
| `naddr` | `nostr.bech32.encodeNAddr(kind:, authorPubkey:, identifier:, userRelays:)` |

Decoding is symmetric: `decodeNpubKeyToPublicKey` and `decodeNsecKeyToPrivateKey` return hex strings, while the three TLV decoders return a `Map<String, dynamic>` rather than a typed object.

The type `NostrBech32` is also exported under the alias `NostrNip19`, so either name works in signatures.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keys = nostr.keys.generateKeyPair();
  final note = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: keys,
  );

  final npub = nostr.bech32.encodePublicKeyToNpub(keys.public);
  final nprofile = nostr.bech32.encodeNProfile(
    pubkey: keys.public,
    userRelays: const ['wss://relay.damus.io'],
  );
  final nevent = nostr.bech32.encodeNevent(
    eventId: note.id!,
    pubkey: keys.public,
    userRelays: const ['wss://relay.damus.io'],
  );

  final profile = nostr.bech32.decodeNprofileToMap(nprofile);
  final eventRef = nostr.bech32.decodeNeventToMap(nevent);

  print([npub, profile['pubkey'], eventRef['eventId']]);
}
```

Be aware of two input rules: `encodeNAddr` throws `ArgumentError` for a kind that does not fit in 32 bits, and the `naddr` decoder rejects anything that is not an `naddr` entity. The `npub` and `nsec` decoders only assert their prefix, and assertions are removed in release builds.

## Next

- [NIP-05 identifiers](./nip05.md) for `name@domain` verification
- [Keys](../keys-management/index.md) for generation and signing
- [Reference — accessors](../../reference/accessors.md) for the per-NIP surface
