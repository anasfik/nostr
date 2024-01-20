import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:equatable/equatable.dart';

/// {@template nostr_event_ok_command}
/// The ok command that is sent to the server when an event is accepted or declined.
/// {@endtemplate}
class NostrEventOkCommand extends Equatable {
  /// {@macro nostr_event_ok_command}
  const NostrEventOkCommand({
    required this.eventId,
    this.isEventAccepted,
    this.message,
  });

  /// The event ID of which this ok command was sent.
  final String eventId;

  /// Wether the event is accepted, or not.
  final bool? isEventAccepted;

  /// The message that was sent with the ok command.
  final String? message;

  @override
  List<Object?> get props => [
        eventId,
        isEventAccepted,
        message,
      ];

  static bool canBeDeserialized(String dataFromRelay) {
    final decoded = jsonDecode(dataFromRelay) as List;

    return decoded.first == NostrConstants.ok;
  }

  static NostrEventOkCommand fromRelayMessage(String data) {
    assert(canBeDeserialized(data));

    final decoded = jsonDecode(data) as List;
    final eventId = decoded[1] as String;
    final isEventAccepted = decoded.length > 2 ? decoded[2] as bool : null;
    final message = decoded.length > 3 ? decoded[3] as String : null;

    return NostrEventOkCommand(
      eventId: eventId,
      isEventAccepted: isEventAccepted,
      message: message,
    );
  }
}
