import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/export.dart';

/// {@template nostr_streams_controllers}
/// A service that manages the relays streams messages
/// {@endtemplate}
class NostrStreamsControllers {
  final allDataEntittyEventController = StreamController<String>.broadcast();

  /// This is the controller which will receive all events from all relays.
  final eventsController = StreamController<NostrEvent>.broadcast();

  /// This is the controller which will receive all notices from all relays.
  final noticesController = StreamController<NostrNotice>.broadcast();

  ///
  Stream<String> get allDataEntities => allDataEntittyEventController.stream;

  /// This is the stream which will have all events from all relays, all your sent requests will be included in this stream, and so in order to filter them, you will need to use the [Stream.where] method.
  /// ```dart
  /// Nostr.instance.relays.stream.where((event) {
  ///  return event.subscriptionId == "your_subscription_id";
  /// });
  /// ```
  ///
  /// You can also use the [Nostr.startEventsSubscription] method to get a stream of events that will be filtered by the [subscriptionId] that you passed to it automatically.
  Stream<NostrEvent> get events => eventsController.stream;

  /// This is the stream which will have all notices from all relays, all of them will be included in this stream, and so in order to filter them, you will need to use the [Stream.where] method.
  Stream<NostrNotice> get notices => noticesController.stream;

  /// Closes all streams.
  Future<void> close() async {
    await Future.wait([
      eventsController.close(),
      noticesController.close(),
      allDataEntittyEventController.close(),
    ]);
  }

  bool get isClosed {
    return eventsController.isClosed ||
        noticesController.isClosed ||
        allDataEntittyEventController.isClosed;
  }
}
