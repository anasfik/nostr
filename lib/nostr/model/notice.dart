// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:equatable/equatable.dart';

class NostrNotice extends Equatable {
  final String message;

  const NostrNotice({
    required this.message,
  });

  @override
  List<Object?> get props => [message];

  static bool canBeDeserialized(String dataFromRelay) {
    final decoded = jsonDecode(dataFromRelay) as List;

    return decoded.first == NostrConstants.notice;
  }

  static NostrNotice fromRelayMessage(String data) {
    assert(canBeDeserialized(data));

    final decoded = jsonDecode(data) as List;
    assert(decoded.first == NostrConstants.notice);
    final message = decoded[1] as String;

    return NostrNotice(message: message);
  }
}
