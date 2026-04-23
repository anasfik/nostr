// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:equatable/equatable.dart';

class NostrNotice extends Equatable {
  final String message;

  /// The URL of the relay that sent this notice.
  /// Populated when the notice is received from a relay connection.
  final String? relayUrl;

  const NostrNotice({
    required this.message,
    this.relayUrl,
  });

  @override
  List<Object?> get props => [message, relayUrl];

  NostrNotice copyWith({
    String? message,
    String? relayUrl,
  }) {
    return NostrNotice(
      message: message ?? this.message,
      relayUrl: relayUrl ?? this.relayUrl,
    );
  }

  /// Creates a [NostrNotice] from an already-decoded relay message list.
  /// Attach the relay source via [copyWith] after construction.
  factory NostrNotice.fromDecodedMessage(List<dynamic> decoded) {
    return NostrNotice(message: decoded[1] as String);
  }

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

  @override
  String toString() => 'NostrNotice(relay: $relayUrl, message: $message)';
}
