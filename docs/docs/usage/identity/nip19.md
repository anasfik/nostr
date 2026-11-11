---
sidebar_position: 2
description: Encode and decode NIP-19 bech32 entities — npub, nsec, nprofile, nevent, naddr.
---

# NIP-19 Encoding

See [Keys — NIP-19 Bech32 Encoding](../keys-management/bech32-encoding.md) for the full reference.

Quick summary:

| Entity | Method |
|---|---|
| `npub` | `nostr.bech32.encodePublicKeyToNpub(pubkey)` |
| `nsec` | `nostr.bech32.encodePrivateKeyToNsec(privkey)` |
| `nprofile` | `nostr.bech32.encodeNProfile(pubkey: ..., userRelays: [...])` |
| `nevent` | `nostr.bech32.encodeNevent(eventId: ..., userRelays: [...], pubkey: ...)` |

Use `decodeNprofileToMap` and `decodeNeventToMap` for profile and event references. They return maps with `pubkey`/`relays` and `eventId` fields, respectively. `decodeNpubKeyToPublicKey` and `decodeNsecKeyToPrivateKey` return hex strings. Never log secret keys.
