import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/core/exceptions.dart';
import 'package:dart_nostr/nostr/core/utils.dart';

import 'package:http/http.dart' as http;

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
    final emailRegEx =
        RegExp(r'^[a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]+$');

    return emailRegEx.hasMatch(identifier);
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

  String random64HexChars() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));

    return hex.encode(randomBytes);
  }

  /// Generates a random 64 length hexadecimal string that is consistent with the given [input].

  String consistent64HexChars(String input) {
    final randomBytes = utf8.encode(input);
    final hashed = sha256.convert(randomBytes);

    return hex.encode(hashed.bytes);
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
  }) async {
    assert(
      pubKey.length == 64 || !pubKey.startsWith('npub'),
      'pub key is invalid, it must be in hex format and not a npub(nip19) key!',
    );
    assert(
      internetIdentifier.contains('@') &&
          internetIdentifier.split('@').length == 2,
      'invalid internet identifier',
    );

    try {
      final pubKeyFromResponse = await pubKeyFromIdentifierNip05(
        internetIdentifier: internetIdentifier,
      );

      return pubKey == pubKeyFromResponse;
    } catch (e) {
      logger.log(
        'error while verifying nip05 for internet identifier: $internetIdentifier',
        e,
      );
      rethrow;
    }
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
  }) async {
    try {
      final localPart = internetIdentifier.split('@')[0];
      final domainPart = internetIdentifier.split('@')[1];

      logger.log(
        'Attempt to fetch pubkey for $internetIdentifier from $domainPart',
      );

      final res = await http.get(
        Uri.parse('https://$domainPart/.well-known/nostr.json?name=$localPart'),
      );

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (decoded
          case {
            'names': final names as Map<String, dynamic>,
          }) {
        logger.log(
          'Pubkey for $localPart is ${names[localPart] ?? 'not found'} '
          'at $domainPart',
        );

        return names[localPart] as String?;
      }

      return null;
    } on Exception catch (e) {
      logger.log(
        'error while verifying nip05 for internet identifier: '
        '$internetIdentifier',
        e,
      );

      throw Nip05VerificationException(parent: e);
    }
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
    final idChars = hexString.split('');

    // encode to bits.
    var idCharsBinary = idChars.map((char) {
      final charCode = int.parse(char, radix: 16);
      final charBinary = charCode.toRadixString(2);
      return charBinary;
    }).toList();

    idCharsBinary = idCharsBinary.map((charBinary) {
      final charBinaryLength = charBinary.length;
      final charBinaryLengthDiff = 4 - charBinaryLength;
      final charBinaryPadded =
          charBinary.padLeft(charBinaryLength + charBinaryLengthDiff, '0');
      return charBinaryPadded;
    }).toList();

    return idCharsBinary.join().split('1').first.length;
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
