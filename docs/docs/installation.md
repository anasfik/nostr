---
sidebar_position: 2
description: Install dart_nostr in a Dart or Flutter project.
---

# Installation

## Flutter

The commands below install the published **10.0.1** release (checked 2026-11-11).
These guides and the playground target the **11.0.0 source preview**. Use the
pinned Git dependency below to follow the preview APIs. Version 11.0.0 has not
been published to pub.dev. Short snippets omit application setup; start with
the [quick start](./quick-start.md) for the client lifecycle.

```bash
flutter pub add dart_nostr
```

## Dart

```bash
dart pub add dart_nostr
```

## Source preview used by these guides

Add to `pubspec.yaml`:

```yaml
dependencies:
  dart_nostr:
    git:
      url: https://github.com/anasfik/nostr.git
      ref: d61258e
```

Then run:

```bash
dart pub get
```

## Import

```dart
import 'package:dart_nostr/dart_nostr.dart';
```

This single import exposes all public types: `Nostr`, `NostrEvent`, `NostrFilter`, `NostrRequest`, `NostrKeyPairs`, `NostrResult`, `NostrFailure`, and the rest.
