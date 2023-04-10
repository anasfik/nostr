import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:nostr_client/nostr/core/constants.dart';

class NostrEOSE extends Equatable {
  final String subscriptionId;
  const NostrEOSE({required this.subscriptionId});
  @override
  List<Object?> get props => [subscriptionId];

  static canBeDeserialized(String message) {
    final decoded = jsonDecode(message) as List;

    return decoded.first == NostrConstants.eose;
  }

  factory NostrEOSE.fromRelayMessage(String message) {
    final decoded = jsonDecode(message) as List;

    return NostrEOSE(
      subscriptionId: decoded.last,
    );
  }
}
