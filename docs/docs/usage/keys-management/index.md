---
sidebar_position: 1
sidebar_label: Keys
title: Nostr key management in Dart
description: Generate and derive Nostr key pairs in Dart, choose public-key encodings, sign messages and verify signatures with dart_nostr key utilities.
---

# Keys

`nostr.keys` provides all key operations: generation, derivation, validation, signing, and verification.

Key pairs in dart_nostr are represented as `NostrKeyPairs`, which holds both `public` and `private` as hex strings.

Use `Nostr.instance.keys` for the shared instance or `Nostr().keys` on an isolated client.

## Choose a key workflow

- [Generate or derive a key pair](./generate-key-pair.md) when creating an identity or restoring a private key your app already owns.
- [Sign and verify messages](./sign-verify.md) when working with signatures directly. For protocol events, use the [event creation guide](../relays-and-events/creating-events.md).
- [Encode keys with NIP-19](./bech32-encoding.md) for display and sharing. The [identifier guide](../identity/nip19.md) explains which public formats fit profiles and events.

Private keys and `nsec` strings grant control of an identity. Keep them out of logs, public events, analytics and issue reports. A display encoding is not encryption or secure storage.
