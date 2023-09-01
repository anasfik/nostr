import 'dart:async';

import '../model/export.dart';

class NostrStreamsControllers {
  NostrStreamsControllers._();
  static final _instance = NostrStreamsControllers._();
  static NostrStreamsControllers get instance => _instance;

  /// This is the controller which will receive all events from all relays.
  final eventsController = StreamController<ReceivedNostrEvent>.broadcast();

  /// This is the controller which will receive all notices from all relays.
  final noticesController = StreamController<NostrNotice>.broadcast();

  /// This is the stream which will have all events from all relays, all your sent requests will be included in this stream, and so in order to filter them, you will need to use the [Stream.where] method.
  /// ```dart
  /// Nostr.instance.relays.stream.where((event) {
  ///  return event.subscriptionId == "your_subscription_id";
  /// });
  /// ```
  ///
  /// You can also use the [Nostr.startEventsSubscription] method to get a stream of events that will be filtered by the [subscriptionId] that you passed to it automatically.
  Stream<ReceivedNostrEvent> get events => eventsController.stream;

  /// This is the stream which will have all notices from all relays, all of them will be included in this stream, and so in order to filter them, you will need to use the [Stream.where] method.
  Stream<NostrNotice> get notices => noticesController.stream;
}
