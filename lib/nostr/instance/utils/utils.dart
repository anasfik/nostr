import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:dart_nostr/nostr/core/crypto_utils.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/nips/nip05/nip05.dart';
import 'package:dart_nostr/nostr/nips/nip13/nip13.dart';

/// {@template nostr_utils}
/// This class is responsible for handling some of the helper utils of the library.
/// {@endtemplate}
class NostrUtils {
  /// {@macro nostr_utils}
  NostrUtils({
    required this.logger,
  });

  /// {@macro nostr_client_utils}
  final NostrLogger logger;

  /// NIP-05 implementation used by the compatibility methods below.
  late final NostrNip05 _nip05 = NostrNip05(logger: logger);

  /// Wether the given [identifier] has a valid format.
  ///
  ///
  /// Example:
  ///
  /// ```dart
  /// final isIdentifierValid = Nostr.instance.utilsService.isValidNip05Identifier("example");
  /// print(isIdentifierValid) // false
  /// ```

  bool isValidNip05Identifier(String identifier) {
    return _nip05.isValidNip05Identifier(identifier);
  }

  /// Encodes the given [input] to hex format
  ///
  ///
  /// Example:
  ///
  /// ```dart
  /// final hexDecodedString = Nostr.instance.utilsService.hexEncodeString("example");
  /// print(hexDecodedString); // ...
  /// ```

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

  String random64HexChars([int length = 32]) {
    return NostrCryptoUtils.randomHex(length);
  }

  /// Generates a random 64 length hexadecimal string that is consistent with the given [input].

  String consistent64HexChars(String input) {
    return NostrCryptoUtils.deterministicHash(input);
  }

  /// Generates a SHA256 hash of the given [input] and returns it as a hex-encoded string.
  ///
  /// Example:
  ///
  /// ```dart
  /// final hash = Nostr.instance.utilsService.sha256Hash("message");
  /// print(hash); // hex-encoded SHA256 hash
  /// ```
  String sha256Hash(String input) {
    return NostrCryptoUtils.sha256Hash(input);
  }

  /// This method will verify the [internetIdentifier] with a [pubKey] using the NIP05 implementation, and simply will return a [Future] with a [bool] that indicates if the verification was successful or not.
  ///
  /// example:
  /// ```dart
  /// final verified = await Nostr.instance.relays.verifyNip05(
  ///  internetIdentifier: "localPart@domainPart",
  ///  pubKey: "pub key in hex format",
  /// );
  /// ```

  Future<bool> verifyNip05({
    required String internetIdentifier,
    required String pubKey,
  }) {
    return _nip05.verifyNip05(
      internetIdentifier: internetIdentifier,
      pubKey: pubKey,
    );
  }

  /// Return the public key found by the NIP05 implementation via the given for the given [internetIdentifier]
  ///
  ///
  /// Example:
  /// ```dart
  ///  final pubKey = await Nostr.instance.relays.pubKeyFromIdentifierNip05(
  ///   internetIdentifier: "localPart@domainPart",
  /// );
  ///
  /// print(pubKey); // ...
  /// ```

  Future<String?> pubKeyFromIdentifierNip05({
    required String internetIdentifier,
  }) {
    return _nip05.pubKeyFromIdentifierNip05(
      internetIdentifier: internetIdentifier,
    );
  }

  /// Counts the difficulty of the given [hexString], this wis intebded t be used in the NIP 13 with this package.
  ///
  /// Example:
  /// ```dart
  /// final difficulty = Nostr.instance.utilsService.countDifficultyOfHex("002f");
  /// print(difficulty); // 36
  /// ```
  ///

  int countDifficultyOfHex(String hexString) {
    return NostrProofOfWork.getDifficulty(hexString);
  }

  // String _convertBech32toHr(String bech32, {int cutLength = 15}) {
  //   final int length = bech32.length;
  //   final String first = bech32.substring(0, cutLength);
  //   final String last = bech32.substring(length - cutLength, length);
  //   return "$first:$last";
  // }

  /// [returns] a short version nprofile1:sdf54e:ewfd54
  // String _nProfileMapToBech32Hr(Map<String, dynamic> map) {
  //   return _convertBech32toHr(_nProfileMapToBech32(map));
  // }
}
