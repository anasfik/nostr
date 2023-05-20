import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';

import 'base/base.dart';

/// {@template nostr_utils}
/// This class is responsible for handling some of the helper utils of the library.
/// {@endtemplate}
class NostrUtils implements NostrUtilsBase {
  /// Wether the given [identifier] has a valid format.
  ///
  ///
  /// Example:
  ///
  /// ```dart
  /// final isIdentifierValid = Nostr.instance.utilsService.isValidNip05Identifier("example");
  /// print(isIdentifierValid) // false
  /// ```
  @override
  bool isValidNip05Identifier(String identifier) {
    final emailRegEx =
        RegExp(r'^[a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]+$');

    return emailRegEx.hasMatch(identifier);
  }

  /// Encodes the given [input] to hex format
  ///
  ///
  /// Exmaple:
  ///
  /// ```dart
  /// final hexDecodedString = Nostr.instance.utilsService.hexEncodeString("example");
  /// print(hexDecodedString); // ...
  /// ```
  @override
  String hexEncodeString(String input) {
    return hex.encode(utf8.encode(input));
  }

  /// Generates a randwom 64-length hexadecimal string.
  ///
  ///
  /// Example:
  ///
  /// ```dart
  /// final randomGeneratedHex = Nostr.instance.utilsService.random64HexChars();
  /// print(randomGeneratedHex); // ...
  /// ```
  @override
  String random64HexChars() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));

    return hex.encode(randomBytes);
  }
}
