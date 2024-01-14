import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:equatable/equatable.dart';

class NostrEOSE extends Equatable {
  const NostrEOSE({required this.subscriptionId});
  final String subscriptionId;
  @override
  List<Object?> get props => [subscriptionId];

  bool canBeDeserialized(String message) {
    final decoded = jsonDecode(message) as List;

    return decoded.first == NostrConstants.eose;
  }

  NostrEOSE fromRelayMessage(String message) {
    final decoded = jsonDecode(message) as List;

    return NostrEOSE(subscriptionId: decoded.last as String);
  }
}
