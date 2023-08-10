---
sidebar_position: 2
---

# Installation

Wether you already have a Flutter/Dart project, or you will create a new one. You will definitly have a `pubspec.yaml` file, which manage your project dependencies, assets, SDKs..

1. Open your terminal at the path of your project

2. Run those command:

```dart
flutter pub add dart_nostr
flutter pub get
```

if you are not on a Flutter project, run this instead:

```dart
dart pub add dart_nostr
dart pub get
```

3. This will import the package to your project, check your `pubspec.yaml` file, you should find it under the `dependencies` section.

4. After you did installed the package, you can use it by importing it in your `.dart` files.

```dart
import 'package:dart_nostr/dart_nostr.dart';

// ... 
```

Cool, you can pass to next sections in this documentation.
