---
sidebar_position: 2
sidebar_label: Identifiers
title: "Nostr identifiers: npub, nsec and relay hints"
description: Choose a Nostr identifier for a public key, private key, profile or event. Learn when to use npub, nsec, nprofile and nevent in a Dart app.
---

# Choose a Nostr identifier

NIP-19 adds recognizable prefixes to identifiers that people copy, share or scan. It does not replace the hex keys and event IDs used in Nostr protocol events and filters.

## Which format should an app display?

| Format | Contains | Typical use |
|---|---|---|
| `npub` | Public key | Display or share an account identifier |
| `nsec` | Private key | Secret key import or export, never a public profile field |
| `nprofile` | Public key and optional relay hints | Share a profile with clues about where it may be found |
| `nevent` | Event ID and optional relay/author hints | Share a reference to an existing event |
| `naddr` | Author, kind and identifier coordinate | Refer to an addressable event |

## Sharing is not storage or verification

An `nsec` string is still a private key. Encoding it does not encrypt it. Never include it in a public event, a screenshot, telemetry or a bug report.

Relay hints help another client locate a profile or event; they do not prove availability, ownership or trust. Decoding an identifier does not fetch an event or verify its signature. Treat decoded values as external input before using them in your app.

Use the [Dart NIP-19 encoding examples](../keys-management/bech32-encoding.md) for method names and round trips. For the wire-format rules and prefix definitions, read the [NIP-19 specification](https://github.com/nostr-protocol/nips/blob/master/19.md).
