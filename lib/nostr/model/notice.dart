// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../core/constants.dart';

class NostrNotice extends Equatable {
  final String message;

  NostrNotice({
    required this.message,
  });

  @override
  List<Object?> get props => [message];

  static bool canBeDeserializedNotice(String dataFromRelay) {
    final decoded = jsonDecode(dataFromRelay) as List;

    return decoded.first == NostrConstants.notice;
  }

  factory NostrNotice.fromRelayMessage(String data) {
    assert(canBeDeserializedNotice(data));
    final decoded = jsonDecode(data) as List;
    assert(decoded.first == NostrConstants.notice);
    final message = decoded[1] as String;

    return NostrNotice(message: message);
  }
}
