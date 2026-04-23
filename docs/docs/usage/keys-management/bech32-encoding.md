---
sidebar_position: 3
description: Encode and decode npub, nsec, nprofile, nevent, and naddr using NIP-19.
---

# NIP-19 Bech32 Encoding

`nostr.bech32` handles all NIP-19 entity encoding and decoding.

## npub / nsec

```dart
final nostr = Nostr.instance;
final keyPair = nostr.keys.generateKeyPair();

// encode
final npub = nostr.bech32.encodePublicKeyToNpub(keyPair.public);
final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPair.private);

print(npub);  // npub1...
print(nsec);  // nsec1...

// decode
final pubKey = nostr.bech32.decodeNpubKeyToPublicKey(npub);
final privKey = nostr.bech32.decodeNsecKeyToPrivateKey(nsec);

print(pubKey == keyPair.public);    // true
print(privKey == keyPair.private);  // true
```

## nprofile

`nprofile` encodes a public key with optional relay hints.

```dart
final nprofile = nostr.bech32.encodeNProfile(
  pubkey: keyPair.public,
  userRelays: ['wss://relay.damus.io'],
);
print(nprofile);  // nprofile1...

final decoded = nostr.bech32.decodeNProfile(nprofile);
print(decoded.pubkey);
print(decoded.relays);
```

## nevent

`nevent` encodes an event reference with optional relay and author hints.

```dart
final nevent = nostr.bech32.encodeNEvent(
  eventId: event.id!,
  relays: ['wss://relay.damus.io'],
  pubkey: keyPair.public,
);
print(nevent);  // nevent1...

final decoded = nostr.bech32.decodeNEvent(nevent);
print(decoded.eventId);
```
