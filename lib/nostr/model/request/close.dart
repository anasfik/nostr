import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../core/constants.dart';

/// {@template nostr_request_close}
/// A request to close a subscription with a given subscription id.
/// {@endtemplate}
class NostrRequestClose extends Equatable {
  /// The subscription id.
  final String subscriptionId;

  /// {@macro nostr_request_close}
  NostrRequestClose({
    required this.subscriptionId,
  });

  /// Serializes the request to a json string.
  String serialized() {
    return jsonEncode([NostrConstants.close, subscriptionId]);
  }

  @override
  List<Object?> get props => [subscriptionId];
}
