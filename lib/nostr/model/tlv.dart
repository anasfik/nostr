import 'dart:typed_data';

class TLV {
  TLV({
    required this.type,
    required this.length,
    required this.value,
  });
  final int type;
  final int length;
  final Uint8List value;
}
