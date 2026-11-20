---
sidebar_position: 2
sidebar_label: Installation
title: Install dart_nostr for Dart and Flutter
description: Add dart_nostr to a Dart or Flutter project. The published package is 11.1.0, the version these guides and the playground use.
---

# Installation

## Flutter

The commands below install the published **11.1.0** release (published 2026-11-19).
These guides and the playground use that same version, so there is no source
preview to pin. Short snippets omit application setup; start with
the [quick start](./quick-start.md) for the client lifecycle.

```bash
flutter pub add dart_nostr
```

## Dart

```bash
dart pub add dart_nostr
```

## Pinning a version

`pubspec.yaml` accepts the caret range these guides assume:

```yaml
dependencies:
  dart_nostr: ^11.1.0
```

Pin an exact version (`11.1.0`) or a Git ref only when you need to test unreleased
work; the published release is what the guides document.

## NIPs moved under one accessor

Version 11.1.0 consolidated the NIP implementations under
`lib/nostr/nips/` and exposes them through `NostrNips` on the client. Older
guides that imported per-NIP files directly should use the accessor instead.

## Import

```dart
import 'package:dart_nostr/dart_nostr.dart';
```

This single import exposes all public types: `Nostr`, `NostrEvent`, `NostrFilter`, `NostrRequest`, `NostrKeyPairs`, `NostrResult`, `NostrFailure`, and the rest.
