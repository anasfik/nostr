import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:equatable/equatable.dart';

/// {@template nostr_request_close}
/// A request to close a subscription with a given subscription id.
/// {@endtemplate}
class NostrRequestClose extends Equatable {
  /// {@macro nostr_request_close}
  const NostrRequestClose({
    required this.subscriptionId,
  });

  /// The subscription id.
  final String subscriptionId;

  /// Serializes the request to a json string.
  String serialized() {
    return jsonEncode([NostrConstants.close, subscriptionId]);
  }

  @override
  List<Object?> get props => [subscriptionId];
}
