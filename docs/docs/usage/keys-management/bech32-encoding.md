---
sidebar_position: 3
description: Encode and decode npub, nsec, nprofile, nevent, and naddr with NIP-19.
---

# NIP-19 bech32 encoding

`nostr.bech32` (type `NostrBech32`, also aliased as `NostrNip19`) converts between hex keys or event coordinates and their bech32 forms. The TLV decoders return `Map<String, dynamic>`; there are no typed entity classes.

| Entity | Encode | Decode | Decoded keys |
|---|---|---|---|
| `npub` | `encodePublicKeyToNpub(pubkey)` | `decodeNpubKeyToPublicKey(npub)` | hex string |
| `nsec` | `encodePrivateKeyToNsec(privkey)` | `decodeNsecKeyToPrivateKey(nsec)` | hex string |
| `nprofile` | `encodeNProfile(pubkey:, userRelays:)` | `decodeNprofileToMap(nprofile)` | `pubkey`, `relays` |
| `nevent` | `encodeNevent(eventId:, pubkey:, userRelays:)` | `decodeNeventToMap(nevent)` | `eventId`, `pubkey`, `relays` |
| `naddr` | `encodeNAddr(kind:, authorPubkey:, identifier:, userRelays:)` | `decodeNaddrToMap(naddr)` | `kind`, `pubkey`, `identifier`, `relays` |

`userRelays` is optional on all encoders and defaults to an empty list. On `naddr`, `identifier` is the event's `d` tag value and also defaults to an empty string.

## npub and nsec

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();

  final npub = nostr.bech32.encodePublicKeyToNpub(keyPairs.public);
  final nsec = nostr.bech32.encodePrivateKeyToNsec(keyPairs.private);

  print(npub); // npub1...
  print(nsec); // nsec1...

  final publicKey = nostr.bech32.decodeNpubKeyToPublicKey(npub);
  final privateKey = nostr.bech32.decodeNsecKeyToPrivateKey(nsec);

  print(publicKey == keyPairs.public); // true
  print(privateKey == keyPairs.private); // true
}
```

The `npub` and `nsec` decoders assert on the prefix in debug builds only. In release builds a mismatched entity decodes to hex without that check, so validate the prefix yourself if the input is untrusted.

## nprofile

`nprofile` carries a public key plus relay hints. The decoded value is a map whose `relays` entry is a list of strings.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();

  final nprofile = nostr.bech32.encodeNProfile(
    pubkey: keyPairs.public,
    userRelays: const ['wss://relay.damus.io'],
  );
  print(nprofile); // nprofile1...

  final decoded = nostr.bech32.decodeNprofileToMap(nprofile);

  print(decoded['pubkey']); // hex public key
  print(decoded['relays']); // [wss://relay.damus.io]
}
```

## nevent

`nevent` references an event by id, optionally with the author's public key and relay hints. Create the event first to have an id to encode.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();
  final note = NostrEvent.fromPartialData(
    kind: 1,
    content: 'hello nostr',
    keyPairs: keyPairs,
  );

  final nevent = nostr.bech32.encodeNevent(
    eventId: note.id!,
    pubkey: keyPairs.public,
    userRelays: const ['wss://relay.damus.io'],
  );
  print(nevent); // nevent1...

  final decoded = nostr.bech32.decodeNeventToMap(nevent);

  print(decoded['eventId']); // 64-character hex event id
  print(decoded['pubkey']); // author public key
  print(decoded['relays']); // [wss://relay.damus.io]
}
```

## naddr

`naddr` addresses a parameterised replaceable event by kind, author, and `d` tag. The relay hints are encoded as TLV type 3.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final nostr = Nostr();
  final keyPairs = nostr.keys.generateKeyPair();

  final naddr = nostr.bech32.encodeNAddr(
    kind: 30023,
    authorPubkey: keyPairs.public,
    identifier: 'hello-nostr',
    userRelays: const ['wss://relay.damus.io'],
  );
  print(naddr); // naddr1...

  final decoded = nostr.bech32.decodeNaddrToMap(naddr);

  print(decoded['kind']); // 30023
  print(decoded['pubkey']); // author public key
  print(decoded['identifier']); // hello-nostr
  print(decoded['relays']); // [wss://relay.damus.io]
}
```

`encodeNAddr` rejects a kind outside the unsigned 32-bit range with `ArgumentError`, and `decodeNaddrToMap` rejects an entity whose prefix is not `naddr`.

## Share the same key with a name

`nprofile` and `npub` both identify a public key. To attach a human-readable identifier to the same key, see [NIP-05](../identity/nip05).
