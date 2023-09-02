import 'package:dart_nostr/dart_nostr.dart';
import 'package:equatable/equatable.dart';

/// {@template nostr_event_key}
/// This clas can be used to identify an event uniquely based on external factors such as the  subscription id.
/// {@endtemplate}
class NostrEventKey extends Equatable {
  /// The id of the event.
  final String eventId;

  /// The id of the subscription from where this event is got.
  final String sourceSubscriptionId;

  /// The source original event.
  final ReceivedNostrEvent originalSourceEvent;

  /// {@macro nostr_event_key}
  NostrEventKey({
    required this.eventId,
    required this.sourceSubscriptionId,
    required this.originalSourceEvent,
  });

  @override
  List<Object?> get props => [
        eventId,
        sourceSubscriptionId,
        originalSourceEvent,
      ];

  @override
  String toString() {
    return 'NostrEventKey{eventId: $eventId, sourceSubscriptionId: $sourceSubscriptionId, originalSourceEvent: $originalSourceEvent}';
  }
}
