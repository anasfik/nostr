import 'package:equatable/equatable.dart';

import '../dart_nostr.dart';
import 'event.dart';
import 'request/request.dart';

/// {@template nostr_events_stream}
/// Represents a holde class for the stream of nostr events and the subscription id.
/// {@endtemplate}
class NostrEventsStream extends Equatable {
  /// This the stream of nostr events that you can listen to and get the events.
  final Stream<NostrEvent> stream;

  /// This is the subscription id of the stream. You can use this to unsubscribe from the stream.
  final String subscriptionId;

  final NostrRequest request;

  /// {@macro nostr_events_stream}
  const NostrEventsStream({
    required this.stream,
    required this.subscriptionId,
    required this.request,
  });

  /// {@macro close_events_subscription}
  void close() {
    return Nostr.instance.relaysService.closeEventsSubscription(subscriptionId);
  }

  @override
  List<Object?> get props => [stream, subscriptionId, request];
}
