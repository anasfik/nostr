import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';

import 'base/base.dart';

/// {@template nostr_utils}
/// This class is responsible for handling some of the helper utils of the library.
/// {@endtemplate}
class NostrUtils implements NostrUtilsBase {
  @override
  bool isValidNip05Identifier(String identifier) {
    final emailRegEx =
        RegExp(r'^[a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]+$');

    return emailRegEx.hasMatch(identifier);
  }

  @override
  String hexEncodeString(String input) {
    return hex.encode(utf8.encode(input));
  }

  @override
  String random64HexChars() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));

    return hex.encode(randomBytes);
  }
}
