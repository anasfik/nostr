import 'dart:async';
import 'dart:io';

import 'package:dart_nostr/nostr/model/request/request.dart';

import 'package:dart_nostr/nostr/model/event.dart';

import '../../core/registry.dart';
import '../../core/utils.dart';
import '../../model/relay.dart';
import '../../model/request/close.dart';
import 'base/relays.dart';

/// {@template nostr_relays}
/// This class is responsible for all the relays related operations.
/// {@endtemplate}
class NostrRelays implements NostrRelaysBase {
  /// This is the controller which will receive all events from all relays.
  final _streamController = StreamController<NostrEvent>.broadcast();

  /// This is the stream which will have all events from all relays.
  @override
  Stream<NostrEvent> get stream => _streamController.stream;

  /// This method is responsible for initializing the connection to all relays.
  /// It takes a [List<String>] of relays urls, then it connects to each relay and registers it for future use, if [relayUrl] is empty, it will throw an [AssertionError] since it doesn't make sense to connect to an empty list of relays.
  ///
  ///
  /// The [WebSocket]s of the relays will start being listened to get events from them immediately after calling this method, unless you set the [lazyListeningToRelays] parameter to `true`, then you will have to call the [startListeningToRelays] method to start listening to the relays manually.
  ///
  ///
  /// You can also pass a callback to the [onRelayListening] parameter to be notified when a relay starts listening to it's websocket.
  ///
  ///
  /// You can also pass a callback to the [onRelayError] parameter to be notified when a relay websocket throws an error.
  ///
  ///
  /// You can also pass a callback to the [onRelayDone] parameter to be notified when a relay websocket is closed.
  ///
  ///
  /// You will need to call this method before using any other method, as example, in your `main()` method to make sure that the connection is established before using any other method.
  /// ```dart
  /// void main() async {
  ///  await Nostr.instance.init(relaysUrl: ["wss://relay.damus.io"]);
  /// // ...
  /// runApp(MyApp()); // if it is a flutter app
  /// }
  /// ```
  ///
  /// You can also use this method to re-connect to all relays in case of a connection failure.
  @override
  Future<void> init({
    required List<String> relaysUrl,
    void Function(String relayUrl, dynamic receivedData)? onRelayListening,
    void Function(String relayUrl, Object? error)? onRelayError,
    void Function(String relayUrl)? onRelayDone,
    bool lazyListeningToRelays = false,
    bool retryOnError = false,
    bool retryOnClose = false,
    bool removeDuplicatedEvents = true,
  }) async {
    assert(
      relaysUrl.isNotEmpty,
      "initiating relays with an empty list doesn't make sense, please provide at least one relay url.",
    );

    for (String relay in relaysUrl) {
      NostrRegistry.registerRelayWebSocket(
        relayUrl: relay,
        webSocket: await WebSocket.connect(relay),
      );
      NostrClientUtils.log(
        "the websocket for the relay with url: $relay, is registered.",
      );
      NostrClientUtils.log(
        "listening to the websocket for the relay with url: $relay...",
      );
      if (!lazyListeningToRelays) {
        startListeningToRelays(
          relay: relay,
          onRelayListening: onRelayListening,
          onRelayError: onRelayError,
          onRelayDone: onRelayDone,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
          removeDuplicatedEvents: removeDuplicatedEvents,
        );
      }
    }
  }

  /// This method is responsible for sending an event to all relays that you did registered with the [init] method.
  ///
  /// It takes a [NostrEvent] object, then it serializes it internally and sends it to all relays [WebSocket]s.
  ///
  @override
  void sendEventToRelays(NostrEvent event) async {
    final serialized = event.serialized();

    _runFunctionOverRelationIteration((relay) {
      relay.socket.add(serialized);
      NostrClientUtils.log(
        "event with id: ${event.id} is sent to relay with url: ${relay.url}",
      );
    });
  }

  /// This method will send a [request] to all relays that you did registered with the [init] method, and gets your a [Stream] of [NostrEvent]s that will be filtered by the [request]'s [subscriptionId] automatically.
  ///
  /// if the you do not specify a [subscriptionId] in the [request], it will be generated automatically from the library. (This is recommended only of you're not planning to use the [closeEventsSubscription] method.
  @override
  Stream<NostrEvent> startEventsSubscription({
    required NostrRequest request,
  }) {
    final serialized = request.serialized();

    _runFunctionOverRelationIteration((relay) {
      relay.socket.add(serialized);
      NostrClientUtils.log(
        "request with subscription id: ${request.subscriptionId} is sent to relay with url: ${relay.url}",
      );
    });

    return stream.where((event) {
      return event.subscriptionId == request.subscriptionId;
    });
  }

  /// This method will close the subscription of the [subscriptionId] that you passed to it.
  ///
  /// You can use after calling the [startEventsSubscription] method to close the subscription of the [subscriptionId] that you passed to it.
  @override
  void closeEventsSubscription(String subscriptionId) {
    final close = NostrRequestClose(subscriptionId: subscriptionId);
    final serialized = close.serialized();

    _runFunctionOverRelationIteration((relay) {
      relay.socket.add(serialized);
      NostrClientUtils.log(
        "close request with subscription id: $subscriptionId is sent to relay with url: ${relay.url}",
      );
    });
  }

  void _runFunctionOverRelationIteration(
    Function(NostrRelay) function,
  ) {
    for (int index = 0;
        index < NostrRegistry.allRelaysEntries().length;
        index++) {
      final entries = NostrRegistry.allRelaysEntries();
      final current = entries[index];
      function(
        NostrRelay(
          url: current.key,
          socket: current.value,
        ),
      );
    }
  }

  /// This method will start listening to all relays that you did registered with the [init] method.
  ///
  /// you need to call this method manually only if you set the [lazyListeningToRelays] parameter to `true` in the [init] method, otherwise it will be called automatically by the [init] method.
  @override
  void startListeningToRelays({
    required String relay,
    void Function(String relayUrl, dynamic receivedData)? onRelayListening,
    void Function(String relayUrl, Object? error)? onRelayError,
    void Function(String relayUrl)? onRelayDone,
    bool retryOnError = false,
    bool retryOnClose = false,
    bool removeDuplicatedEvents = true,
  }) {
    NostrRegistry.getRelayWebSocket(relayUrl: relay)!.listen((d) {
      if (onRelayListening != null) {
        onRelayListening(relay, d);
      }

      if (NostrEvent.canBeDeserializedEvent(d)) {
        final event = NostrEvent.fromRelayMessage(d, relay);

        NostrClientUtils.log(
          "received event with content: ${event.content} from relay: $relay",
        );
        if (removeDuplicatedEvents) {
          NostrClientUtils.log(
            "removeDuplicatedEvents: true, so duplicated events will be ignored on the stream.",
          );
          if (NostrRegistry.isEventAlreadyReceived(event)) {
            NostrClientUtils.log(
              "event with id: ${event.id} is already received in the events registry, so it will be ignored and not added to the stream.",
            );
          } else {
            NostrClientUtils.log(
              "event with id: ${event.id} is received for the first time, so it will be added to the stream.",
            );
            NostrRegistry.registerEvent(event);
            _streamController.sink.add(event);
          }
        } else {
          NostrClientUtils.log(
            "removeDuplicatedEvents: false, so duplicated events will be added to the stream.",
          );
          _streamController.sink.add(event);
        }
      } else {
        NostrClientUtils.log(
            "received non-event message from relay: $relay, message: $d");
      }
      // else if (NostrEOSE.canBeDeserialized(d)) {
      //   print(
      //       "EOS from relay $relay with id: ${NostrEOSE.fromRelayMessage(d).subscriptionId}");
      // }
    }, onError: (error) {
      if (retryOnError) {
        NostrClientUtils.log(
          "retrying to listen to relay with url: $relay...",
        );
        startListeningToRelays(
          relay: relay,
          onRelayListening: onRelayListening,
          onRelayError: onRelayError,
          onRelayDone: onRelayDone,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
        );
      }

      if (onRelayError != null) {
        onRelayError(relay, error);
      }
      NostrClientUtils.log(
        "web socket of relay with $relay had an error: $error",
        error,
      );
    }, onDone: () {
      if (retryOnClose) {
        NostrClientUtils.log(
          "retrying to listen to relay with url: $relay...",
        );
        startListeningToRelays(
          relay: relay,
          onRelayListening: onRelayListening,
          onRelayError: onRelayError,
          onRelayDone: onRelayDone,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
        );
      }

      if (onRelayDone != null) {
        onRelayDone(relay);
      }
      NostrClientUtils.log("""
web socket of relay with $relay is done:
close code: ${NostrRegistry.getRelayWebSocket(relayUrl: relay)!.closeCode}.
close reason: ${NostrRegistry.getRelayWebSocket(relayUrl: relay)!.closeReason}.
""");
    });
  }
}
