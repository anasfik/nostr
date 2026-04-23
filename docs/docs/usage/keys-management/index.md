---
sidebar_position: 1
---

# Keys

`nostr.keys` provides all key operations: generation, derivation, validation, signing, and verification.

Key pairs in dart_nostr are represented as `NostrKeyPairs`, which holds both `public` and `private` as hex strings.

All methods below are on `Nostr.instance.keys` (or any `Nostr` instance).
