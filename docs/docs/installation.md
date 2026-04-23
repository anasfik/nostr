---
sidebar_position: 2
description: Install dart_nostr in a Dart or Flutter project.
---

# Installation

## Flutter

```bash
flutter pub add dart_nostr
```

## Dart

```bash
dart pub add dart_nostr
```

## Manual

Add to `pubspec.yaml`:

```yaml
dependencies:
  dart_nostr: ^9.2.5
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
