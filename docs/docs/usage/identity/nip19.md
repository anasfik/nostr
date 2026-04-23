---
sidebar_position: 2
description: Encode and decode NIP-19 bech32 entities — npub, nsec, nprofile, nevent, naddr.
---

# NIP-19 Encoding

See [Keys — NIP-19 Bech32 Encoding](../keys-management/bech32-encoding) for the full reference.

Quick summary:

| Entity | Method |
|---|---|
| `npub` | `nostr.bech32.encodePublicKeyToNpub(pubkey)` |
| `nsec` | `nostr.bech32.encodePrivateKeyToNsec(privkey)` |
| `nprofile` | `nostr.bech32.encodeNProfile(pubkey: ..., userRelays: [...])` |
| `nevent` | `nostr.bech32.encodeNEvent(eventId: ..., relays: [...], pubkey: ...)` |

Decoding follows the same pattern — call the corresponding `decode*` method and check the returned object's fields.
