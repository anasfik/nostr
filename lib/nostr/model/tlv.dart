import 'dart:typed_data';

class TLV {
  final int type;
  final int length;
  final Uint8List value;

  TLV({
    required this.type,
    required this.length,
    required this.value,
  });
}
