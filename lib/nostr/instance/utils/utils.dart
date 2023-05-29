import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

import 'package:convert/convert.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../dart_nostr.dart';
import '../../model/tlv.dart';
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

  /// This method will verify the [internetIdentifier] with a [pubKey] using the NIP05 implementation, and simply will return a [Future] with a [bool] that indicates if the verification was successful or not.
  ///
  /// example:
  /// ```dart
  /// final verified = await Nostr.instance.relays.verifyNip05(
  ///  internetIdentifier: "localPart@domainPart",
  ///  pubKey: "pub key in hex format",
  /// );
  /// ```
  @override
  Future<bool> verifyNip05({
    required String internetIdentifier,
    required String pubKey,
  }) async {
    assert(
      pubKey.length == 64 || !pubKey.startsWith("npub"),
      "pub key is invalid, it must be in hex format and not a npub(nip19) key!",
    );
    assert(
      internetIdentifier.contains("@") &&
          internetIdentifier.split("@").length == 2,
      "invalid internet identifier",
    );

    try {
      final localPart = internetIdentifier.split("@")[0];
      final domainPart = internetIdentifier.split("@")[1];
      final res = await http.get(
        Uri.parse("https://$domainPart/.well-known/nostr.json?name=$localPart"),
      );

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      assert(decoded["names"] != null, "invalid nip05 response, no names key!");
      final pubKeyFromResponse = decoded["names"][localPart];
      assert(pubKeyFromResponse != null, "invalid nip05 response, no pub key!");

      return pubKey == pubKeyFromResponse;
    } catch (e) {
      NostrClientUtils.log(
        "error while verifying nip05 for internet identifier: $internetIdentifier",
        e,
      );
      rethrow;
    }
  }

  @override
  Future<String> pubKeyFromIdentifierNip05({
    required String internetIdentifier,
  }) async {
    try {
      final localPart = internetIdentifier.split("@")[0];
      final domainPart = internetIdentifier.split("@")[1];
      final res = await http.get(
        Uri.parse("https://$domainPart/.well-known/nostr.json?name=$localPart"),
      );

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      assert(decoded["names"] != null, "invalid nip05 response, no names key!");
      final pubKeyFromResponse = decoded["names"][localPart];

      return pubKeyFromResponse;
    } catch (e) {
      NostrClientUtils.log(
        "error while verifying nip05 for internet identifier: $internetIdentifier",
        e,
      );
      rethrow;
    }
  }

  /// [pubkey] is the users pubkey
  /// [userRelays] is a list of relay urls to include in the nprofile
  /// finds relays and [returns] a bech32 encoded nprofile with relay hints
  String encodePubKeyToNProfile({
    required String pubkey,
    List<String> userRelays = const [],
  }) {
    final map = <String, dynamic>{"pubkey": pubkey, "relays": userRelays};

    return _nProfileMapToBech32(map);
  }

  /// [returns] a map with pubkey and relays
  @override
  Map<String, dynamic> decodeNprofileToMap(String bech32) {
    final List<String> decodedBech32 =
        Nostr.instance.keysService.decodeBech32(bech32);

    final String dataString = decodedBech32[0];
    final List<int> data = HEX.decode(dataString);

    final List<TLV> tlvList =
        Nostr.instance.tlvService.decode(Uint8List.fromList(data));
    final Map<String, dynamic> resultMap = _parseTlvList(tlvList);

    if (resultMap["pubkey"].length != 64) {
      throw Exception("Invalid pubkey length");
    }

    return resultMap;
  }

  /// [returns] a short version nprofile1:sdf54e:ewfd54
  String _convertBech32toHr(String bech32, {int cutLength = 15}) {
    final int length = bech32.length;
    final String first = bech32.substring(0, cutLength);
    final String last = bech32.substring(length - cutLength, length);
    return "$first:$last";
  }

  /// [returns] a short version nprofile1:sdf54e:ewfd54
  String _nProfileMapToBech32Hr(Map<String, dynamic> map) {
    return _convertBech32toHr(_nProfileMapToBech32(map));
  }

  /// expects a map with pubkey and relays and [returns] a bech32 encoded nprofile
  String _nProfileMapToBech32(Map<String, dynamic> map) {
    final String pubkey = map["pubkey"];

    final List<String> relays = List<String>.from(map['relays']);

    final List<TLV> tlvList = _generateTlvList(pubkey, relays);

    final Uint8List bytes = Nostr.instance.tlvService.encode(tlvList);

    final String dataString = HEX.encode(bytes);

    return Nostr.instance.keysService.encodeBech32(
      dataString,
      NostrConstants.nProfile,
    );
  }

  Map<String, dynamic> _parseTlvList(List<TLV> tlvList) {
    String pubkey = "";
    List<String> relays = [];
    for (TLV tlv in tlvList) {
      if (tlv.type == 0) {
        pubkey = HEX.encode(tlv.value);
      } else if (tlv.type == 1) {
        relays.add(ascii.decode(tlv.value));
      }
    }
    return {"pubkey": pubkey, "relays": relays};
  }

  List<TLV> _generateTlvList(String pubkey, List<String> relays) {
    final Uint8List pubkeyBytes = _hexDecodeToUint8List(pubkey);
    List<TLV> tlvList = [TLV(type: 0, length: 32, value: pubkeyBytes)];

    for (String relay in relays) {
      final Uint8List relayBytes = _asciiEncodeToUint8List(relay);
      tlvList.add(TLV(type: 1, length: relayBytes.length, value: relayBytes));
    }

    return tlvList;
  }

  Uint8List _hexDecodeToUint8List(String hexString) {
    return Uint8List.fromList(HEX.decode(hexString));
  }

  Uint8List _asciiEncodeToUint8List(String asciiString) {
    return Uint8List.fromList(ascii.encode(asciiString));
  }
}
