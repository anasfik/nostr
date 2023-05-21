import 'dart:typed_data';
import 'package:dart_nostr/nostr/model/tlv.dart';

abstract class TLVBase {
  List<TLV> decode(Uint8List data);
  Uint8List encode(List<TLV> tlvList);
}
