// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/nips/nip67/nip67.dart';
import 'package:equatable/equatable.dart';

class NostrRequestEoseCommand extends Equatable {
  final String subscriptionId;

  /// NIP-67 completeness hints sent by the relay, e.g. `["finish"]`.
  ///
  /// Empty for legacy two-element `EOSE` messages.
  final List<String> hints;

  const NostrRequestEoseCommand({
    required this.subscriptionId,
    this.hints = const [],
  });

  @override
  List<Object?> get props => [
        subscriptionId,
        hints,
      ];

  /// Creates a [NostrRequestEoseCommand] from an already-decoded relay message list.
  factory NostrRequestEoseCommand.fromDecodedMessage(List<dynamic> decoded) {
    return NostrRequestEoseCommand(
      subscriptionId: decoded.length > 1 ? '${decoded[1]}' : '',
      hints: NostrNip67.hintsOf(decoded),
    );
  }

  static bool canBeDeserialized(String dataFromRelay) {
    final decoded = jsonDecode(dataFromRelay) as List;

    return decoded.first == NostrConstants.eose;
  }

  static NostrRequestEoseCommand fromRelayMessage(String dataFromRelay) {
    assert(canBeDeserialized(dataFromRelay));

    final decoded = jsonDecode(dataFromRelay) as List;

    return NostrRequestEoseCommand.fromDecodedMessage(decoded);
  }
}
