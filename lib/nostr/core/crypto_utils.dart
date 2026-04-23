import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

final class NostrCryptoUtils {
  const NostrCryptoUtils._();

  static String randomHex([int byteLength = 32]) {
    final random = Random.secure();
    final randomBytes = List<int>.generate(
      byteLength,
      (_) => random.nextInt(256),
    );

    return hex.encode(randomBytes);
  }

  static String deterministicHash(String input) {
    return sha256Hash(input);
  }

  static String sha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return hex.encode(digest.bytes);
  }
}
