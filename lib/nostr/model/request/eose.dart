import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/nips/nip67/nip67.dart';
import 'package:equatable/equatable.dart';

class NostrEOSE extends Equatable {
  const NostrEOSE({
    required this.subscriptionId,
    this.hints = const [],
  });

  final String subscriptionId;

  /// NIP-67 completeness hints, e.g. `["finish"]`; empty when absent.
  final List<String> hints;

  @override
  List<Object?> get props => [subscriptionId, hints];

  bool canBeDeserialized(String message) {
    final decoded = jsonDecode(message) as List;

    return decoded.isNotEmpty && decoded.first == NostrConstants.eose;
  }

  NostrEOSE fromRelayMessage(String message) {
    final decoded = jsonDecode(message) as List;

    // The subscription id is always at index 1; a NIP-67 relay appends hints
    // at index 2, so `decoded.last` is not the subscription id.
    return NostrEOSE(
      subscriptionId: decoded.length > 1 ? '${decoded[1]}' : '',
      hints: NostrNip67.hintsOf(decoded),
    );
  }
}
