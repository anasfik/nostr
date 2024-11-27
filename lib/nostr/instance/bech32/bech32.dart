import 'dart:convert';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/tlv/tlv_utils.dart';
import 'package:dart_nostr/nostr/model/tlv.dart';
import 'package:hex/hex.dart';

class NostrBech32 {
  NostrBech32({
    required this.logger,
  });

  /// {@macro nostr_utils}
  final tlv = NostrTLV();

  final NostrLogger logger;

  /// Generates a nprofile id from the given [pubkey] and [relays], if no [relays] are given, it will be an empty list.
  /// You can decode the generated nprofile id with [decodeNprofileToMap].
  ///
  ///
  /// Example:
  ///
  /// ```dart
  /// final nProfileId = Nostr.instance.utilsService.encodePubKeyToNProfile(
  ///  pubkey: "pubkey in hex format",
  /// userRelays: ["relay1", "relay2"],
  /// );
  ///
  /// print(nProfileId); // ...
  /// ```
  String encodeNProfile({
    required String pubkey,
    List<String> userRelays = const [],
  }) {
    final map = <String, dynamic>{'pubkey': pubkey, 'relays': userRelays};

    return _nProfileMapToBech32(map);
  }

  /// Generates a nprofile id from the given [eventId], [pubkey] and [relays].
  /// You can decode the generated nprofile id with [decodeNeventToMap].
  ///
  /// Example:
  /// ```dart
  /// final nEventId = Nostr.instance.utilsService.encodeNevent(
  /// eventId: "event id in hex format",
  /// pubkey: "pubkey in hex format",
  /// userRelays: ["relay1", "relay2"],
  /// );
  ///
  /// print(nEventId); // ...
  /// ```
  String encodeNevent({
    required String eventId,
    required String pubkey,
    List<String> userRelays = const [],
  }) {
    final map = <String, dynamic>{
      'pubkey': pubkey,
      'relays': userRelays,
      'eventId': eventId,
    };

    return _nEventMapToBech32(map);
  }

  /// Decodes the given [bech32] nprofile id to a map with pubkey and relays.
  /// You can encode a map to a nprofile id with [encodeNProfile].
  ///
  /// Example:
  /// ```dart
  /// final nProfileDecodedMap = Nostr.instance.utilsService.decodeNprofileToMap(
  ///  "nprofile1:..."
  /// );
  ///
  /// print(nProfileDecodedMap); // ...
  /// ```
  Map<String, dynamic> decodeNprofileToMap(String bech32) {
    final decodedBech32 = decodeBech32(bech32);

    final dataString = decodedBech32[0];
    final data = HEX.decode(dataString);

    final tlvList = tlv.decode(Uint8List.fromList(data));
    final resultMap = _parseNprofileTlvList(tlvList);

    if (resultMap['pubkey'].length != 64) {
      throw Exception('Invalid pubkey length');
    }

    return resultMap;
  }

  /// Decodes the given [bech32] nprofile id to a map with pubkey and relays.
  /// You can encode a map to a nprofile id with [encodeNProfile].
  ///
  ///
  /// Example:
  /// ```dart
  /// final nEventDecodedMap = Nostr.instance.utilsService.decodeNeventToMap(
  /// "nevent1:..."
  /// );
  ///
  /// print(nEventDecodedMap); // ...
  /// ```
  Map<String, dynamic> decodeNeventToMap(String bech32) {
    final decodedBech32 = decodeBech32(bech32);

    final dataString = decodedBech32[0];
    final data = HEX.decode(dataString);

    final tlvList = tlv.decode(Uint8List.fromList(data));
    final resultMap = _parseNeventTlvList(tlvList);

    if (resultMap['eventId'].length != 64) {
      throw Exception('Invalid pubkey length');
    }

    return resultMap;
  }

  /// Encodes a Nostr [publicKey] to an npub key (bech32 encoding).
  ///
  /// ```dart
  /// final npubString = Nostr.instance.services.keys.encodePublicKeyToNpub(yourPublicKey);
  /// print(npubString); // ...
  /// ```
  String encodePublicKeyToNpub(String publicKey) {
    return encodeBech32(publicKey, NostrConstants.npub);
  }

  /// Encodes a Nostr [privateKey] to an nsec key (bech32 encoding).
  /// ```dart
  /// final nsecString = Nostr.instance.services.keys.encodePrivateKeyToNsec(yourPrivateKey);
  /// print(nsecString); // ...
  ///
  String encodePrivateKeyToNsec(String privateKey) {
    return encodeBech32(privateKey, NostrConstants.nsec);
  }

  /// Decodes a Nostr [npubKey] to a public key.
  ///
  /// ```dart
  /// final publicKey = Nostr.instance.services.keys.decodeNpubKeyToPublicKey(yourNpubKey);
  /// print(publicKey); // ...
  /// ```
  String decodeNpubKeyToPublicKey(String npubKey) {
    assert(npubKey.startsWith(NostrConstants.npub));

    final decodedKeyComponents = decodeBech32(npubKey);

    return decodedKeyComponents.first;
  }

  /// Decodes a Nostr [nsecKey] to a private key.
  ///
  /// ```dart
  /// final privateKey = Nostr.instance.services.keys.decodeNsecKeyToPrivateKey(yourNsecKey);
  /// print(privateKey); // ...
  /// ```
  String decodeNsecKeyToPrivateKey(String nsecKey) {
    assert(nsecKey.startsWith(NostrConstants.nsec));
    final decodedKeyComponents = decodeBech32(nsecKey);

    return decodedKeyComponents.first;
  }

  /// expects a map with pubkey and relays and [returns] a bech32 encoded nprofile
  String _nProfileMapToBech32(Map<String, dynamic> map) {
    final pubkey = map['pubkey'] as String;

    final relays = List<String>.from(map['relays'] as List);

    final tlvList = _generatenProfileTlvList(pubkey, relays);

    final bytes = tlv.encode(tlvList);

    final dataString = HEX.encode(bytes);

    return encodeBech32(
      dataString,
      NostrConstants.nProfile,
    );
  }

  /// Encodes a [hex] string into a bech32 string with a [hrp] human readable part.
  ///
  /// ```dart
  /// final npubString = Nostr.instance.services.keys.encodeBech32(yourHexString, 'npub');
  /// print(npubString); // ...
  /// ```
  String encodeBech32(String hex, String hrp) {
    final bytes = HEX.decode(hex);
    final fiveBitWords = _convertBits(bytes, 8, 5, true);

    return bech32.encode(Bech32(hrp, fiveBitWords), hex.length + hrp.length);
  }

  /// Decodes a bech32 string into a [hex] string and a [hrp] human readable part.
  ///
  /// ```dart
  /// final decodedHexString = Nostr.instance.services.keys.decodeBech32(npubString);
  /// print(decodedHexString); // ...
  /// ```
  List<String> decodeBech32(String bech32String) {
    const codec = Bech32Codec();
    final bech32 = codec.decode(bech32String, bech32String.length);
    final eightBitWords = _convertBits(bech32.data, 5, 8, false);
    return [HEX.encode(eightBitWords), bech32.hrp];
  }

  String _nEventMapToBech32(Map<String, dynamic> map) {
    final eventId = map['eventId'] as String;
    final authorPubkey = map['pubkey'] as String?;
    final relays = List<String>.from(map['relays'] as List);

    final tlvList = _generatenEventTlvList(
      eventId,
      authorPubkey,
      relays,
    );

    final dataString = HEX.encode(tlv.encode(tlvList));

    return encodeBech32(
      dataString,
      NostrConstants.nEvent,
    );
  }

  Map<String, dynamic> _parseNprofileTlvList(List<TLV> tlvList) {
    var pubkey = '';
    final relays = <String>[];

    for (final tlv in tlvList) {
      if (tlv.type == 0) {
        pubkey = HEX.encode(tlv.value);
      } else if (tlv.type == 1) {
        relays.add(ascii.decode(tlv.value));
      }
    }
    return {'pubkey': pubkey, 'relays': relays};
  }

  Map<String, dynamic> _parseNeventTlvList(List<TLV> tlvList) {
    var pubkey = '';
    final relays = <String>[];
    var eventId = '';
    for (final tlv in tlvList) {
      if (tlv.type == 0) {
        eventId = HEX.encode(tlv.value);
      } else if (tlv.type == 1) {
        relays.add(ascii.decode(tlv.value));
      } else if (tlv.type == 2) {
        pubkey = HEX.encode(tlv.value);
      }
    }

    return {'eventId': eventId, 'pubkey': pubkey, 'relays': relays};
  }

  /// Generates a list of TLV objects
  List<TLV> _generatenEventTlvList(
    String eventId,
    String? authorPubkey,
    List<String> relays,
  ) {
    final tlvList = <TLV>[];
    tlvList.add(_generateEventIdTlv(eventId));

    tlvList.addAll(relays.map(_generateRelayTlv));

    if (authorPubkey != null) {
      tlvList.add(_generateAuthorPubkeyTlv(authorPubkey));
    }

    return tlvList;
  }

  /// TLV type 1
  /// [relay] must be a string
  TLV _generateRelayTlv(String relay) {
    final relayBytes = Uint8List.fromList(ascii.encode(relay));
    return TLV(type: 1, length: relayBytes.length, value: relayBytes);
  }

  /// TLV type 2
  /// [authorPubkey] must be 32 bytes long
  TLV _generateAuthorPubkeyTlv(String authorPubkey) {
    final authorPubkeyBytes = Uint8List.fromList(HEX.decode(authorPubkey));

    return TLV(type: 2, length: 32, value: authorPubkeyBytes);
  }

  /// TLV type 0
  /// [eventId] must be 32 bytes long
  TLV _generateEventIdTlv(String eventId) {
    final eventIdBytes = Uint8List.fromList(HEX.decode(eventId));
    return TLV(type: 0, length: 32, value: eventIdBytes);
  }

  List<TLV> _generatenProfileTlvList(String pubkey, List<String> relays) {
    final pubkeyBytes = _hexDecodeToUint8List(pubkey);
    final tlvList = <TLV>[TLV(type: 0, length: 32, value: pubkeyBytes)];

    for (final relay in relays) {
      final relayBytes = _asciiEncodeToUint8List(relay);
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

  /// Convert bits from one base to another
  /// [data] - the data to convert
  /// [fromBits] - the number of bits per input value
  /// [toBits] - the number of bits per output value
  /// [pad] - whether to pad the output if there are not enough bits
  /// If pad is true, and there are remaining bits after the conversion, then the remaining bits are left-shifted and added to the result
  /// [return] - the converted data
  List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];

    for (final value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;

      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & ((1 << toBits) - 1));
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & ((1 << toBits) - 1));
      }
    } else if (bits >= fromBits || (acc & ((1 << bits) - 1)) != 0) {
      throw Exception('Invalid padding');
    }

    return result;
  }
}
