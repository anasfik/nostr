---
sidebar_position: 5
description: Learn how to encode & decode a key pair keys to the npub & nsec formats.
---

# Create npub & nsec keys

Nostr is about hex keys, these are what you will use to sign & verify data, or in other, you will create direct events with them. However, Nostr [NIP 19](https://github.com/nostr-protocol/nips/blob/master/19.md) exposes bech32-encoded entities, Please check it first to understand what is npub & nsec keys.

Let's say we have this key pair:

```dart
final keyPair = Nostr.instance.keysService.generateKeyPair();

print(keyPair.public); // ...
print(keyPair.private); // ...
```

## Npub keys (public keys)

Let's learn how to encode & decode npub keys, in the following sections.

### Encode a public key to npub format

Let's say we want to create the convenable npub key for the public key above, we can use the `encodePublicKeyToNpub()` method of the `Nostr.instance.keysService`, Example:

```dart
final npubKey = Nostr.instance.keysService.encodePublicKeyToNpub(keyPair.public);

print(npubKey); // npub...
```

we can now use it, maybe show it to users...

### Decodes a npub key to a public key

Now let's say we want to turn back our npub to our public key, we can use the `decodeNpubKeyToPublicKey()` method of the `Nostr.instance.keysService`, Example:

```dart
final decodedPublicKey = Nostr.instance.keysService.decodeNpubKeyToPublicKey(npubKey);

print(decodedPublicKey); // ...

print(decodedPublicKey == keyPair.public); // true
```

See, we got our public key back.

## Nsec keys (private keys)

Let's learn how to encode & decode nsec keys, in the following sections.

### Encode a private key to nsec format

Let's say we want to create the convenable nsec key for the private key above, we can use the `encodePrivateKeyToNsec()` method of the `Nostr.instance.keysService`, Example:

```dart

final nsecKey = Nostr.instance.keysService.encodePrivateKeyToNsec(keyPair.private);

print(nsecKey); // nsec...
```

We can now use it, maybe show it in the key's owner profile...

### Decodes a nsec key to a private key

Now let's say we want to turn back our nsec to our private key, we can use the `decodeNsecKeyToPrivateKey()` method of the `Nostr.instance.keysService`, Example:

```dart
final decodedPrivateKey = Nostr.instance.keysService.decodeNsecKeyToPrivateKey(nsecKey);

print(decodedPrivateKey); // ...

print(decodedPrivateKey == keyPair.private); // true
```

See, in the same way we got our private key back.

## What's next ?

Learn how to [sign & verify data](./signing-and-verifying-data).
