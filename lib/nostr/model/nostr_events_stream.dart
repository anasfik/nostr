import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:equatable/equatable.dart';

/// {@template nostr_events_stream}
/// Represents a holde class for the stream of nostr events and the subscription id.
/// {@endtemplate}
class NostrEventsStream extends Equatable {
  /// {@macro nostr_events_stream}
  const NostrEventsStream({
    required this.stream,
    required this.subscriptionId,
    required this.request,
    this.onClose,
  });

  /// This the stream of nostr events that you can listen to and get the events.
  final Stream<NostrEvent> stream;

  /// This is the subscription id of the stream. You can use this to unsubscribe from the stream.
  final String subscriptionId;

  final NostrRequest request;

  final void Function()? onClose;

  /// {@macro close_events_subscription}
  void close() {
    onClose?.call();
  }

  @override
  List<Object?> get props => [stream, subscriptionId, request, onClose];
}

/// Represents a holde class for the stream of raw Nostr data entities and the subscription id.
class NostrDataEntitiesStream extends Equatable {
  /// {@macro nostr_events_stream}
  const NostrDataEntitiesStream({
    required this.stream,
    required this.subscriptionId,
    required this.request,
    this.onClose,
  });

  /// This the stream of nostr events that you can listen to and get the events.
  final Stream<String> stream;

  /// This is the subscription id of the stream. You can use this to unsubscribe from the stream.
  final String subscriptionId;

  final NostrRequest request;

  final void Function()? onClose;

  /// {@macro close_events_subscription}
  void close() {
    onClose?.call();
  }

  @override
  List<Object?> get props => [stream, subscriptionId, request, onClose];
}
