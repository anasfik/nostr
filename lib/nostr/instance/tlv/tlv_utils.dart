import 'dart:typed_data';

import 'package:dart_nostr/nostr/instance/tlv/base/base.dart';
import 'package:dart_nostr/nostr/model/tlv.dart';

/// {@template nostr_tlv}
/// This class is responsible for handling the tlv.
/// {@endtemplate}
class NostrTLV implements TLVBase {
  /// Decode list bytes to list tlv model
  @override
  List<TLV> decode(Uint8List data) {
    final tlvList = <TLV>[];
    var offset = 0;
    while (offset < data.length) {
      final type = data[offset++];
      final length = _decodeLength(data, offset);
      offset += _getLengthBytes(length);
      final value = data.sublist(offset, offset + length);
      offset += length;
      tlvList.add(TLV(type: type, length: length, value: value));
    }
    return tlvList;
  }

  /// Decode length from list bytes
  int _decodeLength(Uint8List buffer, int offset) {
    var length = buffer[offset] & 255;
    if ((length & 128) == 128) {
      final numberOfBytes = length & 127;
      if (numberOfBytes > 3) {
        throw Exception('Invalid length');
      }
      length = 0;
      for (var i = offset + 1; i < offset + 1 + numberOfBytes; ++i) {
        length = length * 256 + (buffer[i] & 255);
      }
    }
    return length;
  }

  int _getLengthBytes(int length) {
    return (length & 128) == 128 ? 1 + (length & 127) : 1;
  }

  /// Encode list tlv to list bytes
  @override
  Uint8List encode(List<TLV> tlvList) {
    final byteLists = <Uint8List>[];
    for (final tlv in tlvList) {
      final typeBytes = Uint8List.fromList([tlv.type]);
      final lengthBytes = _encodeLength(tlv.value.length);
      byteLists.addAll([typeBytes, lengthBytes, tlv.value]);
    }
    return _concatenateUint8List(byteLists);
  }

  /// Encode length to list bytes
  Uint8List _encodeLength(int length) {
    if (length < 128) {
      return Uint8List.fromList([length]);
    }
    final lengthBytesList = <int>[0x82 | (length >> 8), length & 0xFF];
    return Uint8List.fromList(lengthBytesList);
  }

  /// concatenate/chain list bytes
  Uint8List _concatenateUint8List(List<Uint8List> lists) {
    final totalLength =
        lists.map((list) => list.length).reduce((a, b) => a + b);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final list in lists) {
      result.setRange(offset, offset + list.length, list);
      offset += list.length;
    }
    return result;
  }
}
