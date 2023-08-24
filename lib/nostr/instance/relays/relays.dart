import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/event/send_event.dart';
import 'package:dart_nostr/nostr/model/nostr_event_key.dart';
import 'package:dart_nostr/nostr/service/web_sockets.dart';
import '../../model/count.dart';
import '../../model/ease.dart';
import '../../model/ok.dart';
import '../../model/relay.dart';
import '../../model/relay_informations.dart';
import '../../service/registry.dart';
import '../../service/streams.dart';
import 'base/relays.dart';
import 'package:http/http.dart' as http;

/// {@template nostr_relays}
/// This class is responsible for all the relays related operations.
/// {@endtemplate}

class NostrRelays implements NostrRelaysBase {
  /// Represents a registry of all relays that you did registered with the [init] method.
  @override
  Map<String, WebSocket> get relaysWebSocketsRegistry =>
      NostrRegistry.relaysWebSocketsRegistry;

  /// Represents a registry of all events you received from all relays so far.
  @override
  Map<NostrEventKey, ReceivedNostrEvent> get eventsRegistry =>
      NostrRegistry.eventsRegistry;

  List<String>? _relaysList;

  /// This method is responsible for initializing the connection to all relays.
  /// It takes a [List<String>] of relays urls, then it connects to each relay and registers it for future use, if [relayUrl] is empty, it will throw an [AssertionError] since it doesn't make sense to connect to an empty list of relays.
  ///
  ///
  /// The [WebSocket]s of the relays will start being listened to get events from them immediately after calling this method, unless you set the [lazyListeningToRelays] parameter to `true`, then you will have to call the [startListeningToRelay] method to start listening to the relays manually.
  ///
  ///
  /// You can also pass a callback to the [onRelayListening] parameter to be notified when a relay starts listening to it's websocket.
  ///
  ///
  /// You can also pass a callback to the [onRelayConnectionError] parameter to be notified when a relay websocket throws an error.
  ///
  ///
  /// You can also pass a callback to the [onRelayConnectionDone] parameter to be notified when a relay websocket is closed.
  ///
  /// You can choose `lazyListeningToRelays` to `true` if you want to start listening to relays manually, this is useful if you want to start listening to relays after you called the [init] method.
  ///
  /// If you want to retry connecting to relays in case of an error, you can set the [retryOnError] parameter to `true`, and if you want to retry connecting to relays in case of a close, you can set the [retryOnClose] parameter to `true`.
  ///
  ///
  /// If you want to clear all registries before starting, you can set the [ensureToClearRegistriesBeforeStarting] parameter to `true`, the first time you call the [init] method, the registries will be always cleared, but if you want to clear them before each call to the [init] method (as example for implementing a reconnect mechanism), you can set this parameter to `true`.
  ///
  /// If you want to ignore connection exceptions, you can set the [ignoreConnectionException] parameter to `true`, this is useful if you want to ignore connection exceptions and retry connecting to relays in case of an error, you can do that by setting the [retryOnError] parameter to `true`.
  ///
  ///
  /// You will need to call this method before using any other method, as example, in your `main()` method to make sure that the connection is established before using any other method.
  /// ```dart
  /// void main() async {
  ///  await Nostr.instance.relays.init(
  ///   relaysUrl: ["ws://localhost:8080"],
  ///  onRelayListening: (relayUrl) {
  ///   print("relay with url: $relayUrl is listening");
  /// },
  /// onRelayConnectionError: (relayUrl, error) {
  ///  print("relay with url: $relayUrl has thrown an error: $error");
  /// },
  /// onRelayConnectionDone: (relayUrl) {
  ///  print("relay with url: $relayUrl is closed");
  /// },
  /// );
  ///
  /// runApp(MyApp());
  /// }
  /// ```
  ///
  /// You can also use this method to re-connect to all relays in case of a connection failure.
  @override
  Future<void> init({
    required List<String> relaysUrl,
    void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    void Function(String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    bool lazyListeningToRelays = false,
    bool retryOnError = false,
    bool retryOnClose = false,
    bool ensureToClearRegistriesBeforeStarting = true,
    bool ignoreConnectionException = true,
    bool shouldReconnectToRelayOnNotice = false,
    Duration connectionTimeout = const Duration(seconds: 5),
  }) async {
    assert(
      relaysUrl.isNotEmpty,
      "initiating relays with an empty list doesn't make sense, please provide at least one relay url.",
    );
    _relaysList = List.of(relaysUrl);

    _clearRegistriesIf(ensureToClearRegistriesBeforeStarting);

    return await _startConnectingAndRegisteringRelays(
      relaysUrl: relaysUrl,
      onRelayListening: onRelayListening,
      onRelayConnectionError: onRelayConnectionError,
      onRelayConnectionDone: onRelayConnectionDone,
      lazyListeningToRelays: lazyListeningToRelays,
      retryOnError: retryOnError,
      retryOnClose: retryOnClose,
      ignoreConnectionException: ignoreConnectionException,
      shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
      connectionTimeout: connectionTimeout,
    );
  }

  /// This method is responsible for sending an event to all relays that you did registered with the [init] method.
  ///
  /// It takes a [NostrEvent] object, then it serializes it internally and sends it to all relays [WebSocket]s.
  ///
  /// example:
  /// ```dart
  /// Nostr.instance.relays.sendEventToRelays(event);
  /// ```
  @override
  void sendEventToRelays(
    SentNostrEvent event, {
    void Function(NostrEventOkCommand ok)? onOk,
  }) {
    final serialized = event.serialized();
    _registerOnOklCallBack(event.id, onOk);

    _runFunctionOverRelationIteration((relay) {
      relay.socket.add(serialized);
      NostrClientUtils.log(
        "event with id: ${event.id} is sent to relay with url: ${relay.url}",
      );
    });
  }

  @override
  void sendCountEventToRelays(
    NostrCountEvent countEvent, {
    required void Function(NostrCountResponse countResponse) onCountResponse,
  }) {
    final serialized = countEvent.serialized();

    _registerOnCountCallBack(countEvent.subscriptionId, onCountResponse);
    _runFunctionOverRelationIteration((relay) {
      relay.socket.add(serialized);
      NostrClientUtils.log(
          "Count Event with subscription id: ${countEvent.subscriptionId} is sent to relay with url: ${relay.url}");
    });
  }

  /// This method will send a [request] to all relays that you did registered with the [init] method, and gets your a [Stream] of [NostrEvent]s that will be filtered by the [request]'s [subscriptionId] automatically.
  ///
  ///
  /// if the you do not specify a [subscriptionId] in the [request], it will be generated automatically from the library. (This is recommended only of you're not planning to use the [closeEventsSubscription] method.
  ///
  /// example:
  /// ```dart
  /// Nostr.instance.relays.startEventsSubscription(request);
  /// ```
  @override
  NostrEventsStream startEventsSubscription({
    required NostrRequest request,
    void Function(NostrRequestEoseCommand ease)? onEose,
  }) {
    final serialized = request.serialized();

    _registerOnEoselCallBack(request.subscriptionId!, onEose);

    _runFunctionOverRelationIteration((relay) {
      relay.socket.add(serialized);
      NostrClientUtils.log(
        "request with subscription id: ${request.subscriptionId} is sent to relay with url: ${relay.url}",
      );
    });

    final requestSubId = request.subscriptionId;
    final subStream = NostrStreamsControllers.instance.events.where(
      (event) => _filterNostrEventsWithId(event, requestSubId),
    );

    return NostrEventsStream(
      request: request,
      stream: subStream,
      subscriptionId: request.subscriptionId!,
    );
  }

  /// {@template close_events_subscription}
  /// This method will close the subscription of the [subscriptionId] that you passed to it.
  ///
  ///
  /// You can use after calling the [startEventsSubscription] method to close the subscription of the [subscriptionId] that you passed to it.
  ///
  /// example:
  /// ```dart
  /// Nostr.instance.relays.closeEventsSubscription("<subscriptionId>");
  /// ```
  /// {endtemplate}
  @override
  void closeEventsSubscription(String subscriptionId) {
    final close = NostrRequestClose(
      subscriptionId: subscriptionId,
    );

    final serialized = close.serialized();

    _runFunctionOverRelationIteration(
      (relay) {
        relay.socket.add(serialized);
        NostrClientUtils.log(
          "Close request with subscription id: $subscriptionId is sent to relay with url: ${relay.url}",
        );
      },
    );
  }

  /// This method will start listening to all relays that you did registered with the [init] method.
  ///
  ///
  /// you need to call this method manually only if you set the [lazyListeningToRelays] parameter to `true` in the [init] method, otherwise it will be called automatically by the [init] method.
  ///
  /// example:
  /// ```dart
  /// Nostr.instance.relays.startListeningToRelay(
  ///  onRelayListening: (relayUrl, receivedData) {
  ///  print("received data: $receivedData from relay with url: $relayUrl");
  /// },
  /// onRelayConnectionError: (relayUrl, error) {
  /// print("relay with url: $relayUrl has thrown an error: $error");
  /// },
  /// onRelayConnectionDone: (relayUrl) {
  /// print("relay with url: $relayUrl is closed");
  /// },
  /// );
  /// ```
  ///
  /// You can also use this method to re-connect to all relays in case of a connection failure.
  @override
  void startListeningToRelay({
    required String relay,
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    void Function(String relay, WebSocket? relayWebSocket, NostrNotice notice)?
        onNoticeMessageFromRelay,
  }) {
    final relayWebSocket = NostrRegistry.getRelayWebSocket(relayUrl: relay);

    relayWebSocket!.listen((d) {
      onRelayListening?.call(relay, d, relayWebSocket);

      if (NostrEvent.canBeDeserialized(d)) {
        _handleAddingEventToSink(
          event: ReceivedNostrEvent.deserialized(d),
          relay: relay,
        );
      } else if (NostrNotice.canBeDeserialized(d)) {
        final notice = NostrNotice.fromRelayMessage(d);

        onNoticeMessageFromRelay?.call(relay, relayWebSocket, notice);

        _handleNoticeFromRelay(
          notice: notice,
          relay: relay,
          onRelayListening: onRelayListening,
          connectionTimeout: connectionTimeout,
          ignoreConnectionException: ignoreConnectionException,
          lazyListeningToRelays: lazyListeningToRelays,
          onRelayConnectionError: onRelayConnectionError,
          onRelayConnectionDone: onRelayConnectionDone,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
          shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
        );
      } else if (NostrEventOkCommand.canBeDeserialized(d)) {
        _handleOkCommandMessageFromRelay(
          okCommand: NostrEventOkCommand.fromRelayMessage(d),
        );
      } else if (NostrRequestEoseCommand.canBeDeserialized(d)) {
        _handleEoseCommandMessageFromRelay(
          eoseCommand: NostrRequestEoseCommand.fromRelayMessage(d),
        );
      } else if (NostrCountResponse.canBeDeserialized(d)) {
        final countResponse = NostrCountResponse.deserialized(d);

        _handleCountResponseMessageFromRelay(
          countResponse: countResponse,
        );
      } else {
        NostrClientUtils.log(
          "received unknown message from relay: $relay, message: $d",
        );
      }
    }, onError: (error) {
      if (retryOnError) {
        _reconnectToRelay(
          relay: relay,
          onRelayListening: onRelayListening,
          onRelayConnectionError: onRelayConnectionError,
          onRelayConnectionDone: onRelayConnectionDone,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
          shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
          connectionTimeout: connectionTimeout,
          ignoreConnectionException: ignoreConnectionException,
          lazyListeningToRelays: lazyListeningToRelays,
        );
      }

      if (onRelayConnectionError != null) {
        onRelayConnectionError(relay, error, relayWebSocket);
      }

      NostrClientUtils.log(
        "web socket of relay with $relay had an error: $error",
        error,
      );
    }, onDone: () {
      if (retryOnClose) {
        _reconnectToRelay(
          relay: relay,
          onRelayListening: onRelayListening,
          onRelayConnectionError: onRelayConnectionError,
          onRelayConnectionDone: onRelayConnectionDone,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
          shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
          connectionTimeout: connectionTimeout,
          ignoreConnectionException: ignoreConnectionException,
          lazyListeningToRelays: lazyListeningToRelays,
        );
      }

      if (onRelayConnectionDone != null) {
        onRelayConnectionDone(relay, relayWebSocket);
      }
    });
  }

  /// Ths method will get you [RelayInformations] that contains the given [relayUrl] using the NIP11 implementation.
  ///
  /// example:
  /// ```dart
  /// final relayInformations = await Nostr.instance.relays.relayInformationsDocumentNip11(
  /// relayUrl: "ws://relay.nostr.dev",
  /// );
  /// ```
  @override
  Future<RelayInformations?> relayInformationsDocumentNip11({
    required String relayUrl,
    bool throwExceptionIfExists = true,
  }) async {
    try {
      final relayHttpUri =
          NostrWebSocketsService.instance.getHttpUrlFromWebSocketUrl(relayUrl);

      final res = await http.get(
        relayHttpUri,
        headers: {
          "Accept": "application/nostr+json",
        },
      );
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;

      return RelayInformations.fromNip11Response(decoded);
    } catch (e) {
      NostrClientUtils.log(
        "error while getting relay informations from nip11 for relay url: $relayUrl",
        e,
      );

      if (throwExceptionIfExists) {
        rethrow;
      }
    }
  }

  void _runFunctionOverRelationIteration(
    void Function(NostrRelay) relayCallback,
  ) {
    final entries = NostrRegistry.allRelaysEntries();

    for (int index = 0; index < entries.length; index++) {
      final current = entries[index];
      final relay = NostrRelay(
        url: current.key,
        socket: current.value,
      );

      relayCallback.call(relay);
    }
  }

  void _clearRegistriesIf(bool ensureToClearRegistriesBeforeStarting) {
    if (ensureToClearRegistriesBeforeStarting) {
      NostrRegistry.clearAllRegistries();
    }
  }

  Future<void> reconnectToRelays({
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    bool relayUnregistered = true,
  }) async {
    final completer = Completer();

    if (_relaysList == null || _relaysList!.isEmpty) {
      throw Exception(
        "you need to call the init method before calling this method.",
      );
    }

    for (var relay in _relaysList!) {
      await _reconnectToRelay(
        relayUnregistered: relayUnregistered,
        relay: relay,
        onRelayListening: onRelayListening,
        onRelayConnectionError: onRelayConnectionError,
        onRelayConnectionDone: onRelayConnectionDone,
        retryOnError: retryOnError,
        retryOnClose: retryOnClose,
        shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
        connectionTimeout: connectionTimeout,
        ignoreConnectionException: ignoreConnectionException,
        lazyListeningToRelays: lazyListeningToRelays,
      );
    }

    completer.complete();

    return completer.future;
  }

  Future<void> _reconnectToRelay({
    required String relay,
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    bool relayUnregistered = true,
  }) async {
    NostrClientUtils.log("retrying to listen to relay with url: $relay...");

    if (relayUnregistered) {
      await _startConnectingAndRegisteringRelay(
        relayUrl: relay,
        onRelayListening: onRelayListening,
        onRelayConnectionError: onRelayConnectionError,
        onRelayConnectionDone: onRelayConnectionDone,
        retryOnError: retryOnError,
        retryOnClose: retryOnClose,
        shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
        connectionTimeout: connectionTimeout,
        ignoreConnectionException: ignoreConnectionException,
        lazyListeningToRelays: lazyListeningToRelays,
      );
    }
  }

  Future<void> _startConnectingAndRegisteringRelay({
    required String relayUrl,
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool lazyListeningToRelays,
    required bool retryOnError,
    required bool retryOnClose,
    required bool ignoreConnectionException,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
  }) {
    return _startConnectingAndRegisteringRelays(
      relaysUrl: [relayUrl],
      onRelayListening: onRelayListening,
      onRelayConnectionError: onRelayConnectionError,
      onRelayConnectionDone: onRelayConnectionDone,
      lazyListeningToRelays: lazyListeningToRelays,
      retryOnError: retryOnError,
      retryOnClose: retryOnClose,
      ignoreConnectionException: ignoreConnectionException,
      shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
      connectionTimeout: connectionTimeout,
    );
  }

  Future<void> _startConnectingAndRegisteringRelays({
    required List<String> relaysUrl,
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool lazyListeningToRelays,
    required bool retryOnError,
    required bool retryOnClose,
    required bool ignoreConnectionException,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
  }) async {
    Completer completer = Completer();

    for (String relay in relaysUrl) {
      await NostrWebSocketsService.instance.connectRelay(
          relay: relay,
          onConnectionSuccess: (relayWebSocket) {
            NostrRegistry.registerRelayWebSocket(
              relayUrl: relay,
              webSocket: relayWebSocket,
            );
            NostrClientUtils.log(
              "the websocket for the relay with url: $relay, is registered.",
            );
            NostrClientUtils.log(
              "listening to the websocket for the relay with url: $relay...",
            );

            if (!lazyListeningToRelays) {
              startListeningToRelay(
                relay: relay,
                onRelayListening: onRelayListening,
                onRelayConnectionError: onRelayConnectionError,
                onRelayConnectionDone: onRelayConnectionDone,
                retryOnError: retryOnError,
                retryOnClose: retryOnClose,
                shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
                connectionTimeout: connectionTimeout,
                ignoreConnectionException: ignoreConnectionException,
                lazyListeningToRelays: lazyListeningToRelays,
              );
            }
          });
    }

    completer.complete();

    return completer.future;
  }

  bool _filterNostrEventsWithId(
    ReceivedNostrEvent event,
    String? requestSubId,
  ) {
    final eventSubId = event.subscriptionId;

    return eventSubId == requestSubId;
  }

  void _handleAddingEventToSink({
    required String? relay,
    required ReceivedNostrEvent event,
  }) {
    NostrClientUtils.log(
      "received event with content: ${event.content} from relay: $relay",
    );

    if (!NostrRegistry.isEventRegistered(event)) {
      NostrStreamsControllers.instance.eventsController.sink.add(event);
      NostrRegistry.registerEvent(event);
    }
  }

  _handleNoticeFromRelay({
    required NostrNotice notice,
    required String relay,
    required void Function(
            String relayUrl, dynamic receivedData, WebSocket? relayWebSocket)?
        onRelayListening,
    required void Function(
            String relayUrl, Object? error, WebSocket? relayWebSocket)?
        onRelayConnectionError,
    required void Function(String relayUrl, WebSocket? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
  }) {
    NostrClientUtils.log(
      "received notice with message: ${notice.message} from relay: $relay",
    );

    if (NostrRegistry.isRelayRegistered(relay)) {
      final registeredRelay = NostrRegistry.getRelayWebSocket(relayUrl: relay);

      registeredRelay?.close().then((value) {
        final relayUnregistered = NostrRegistry.unregisterRelay(relay);

        _reconnectToRelay(
          relayUnregistered: relayUnregistered,
          relay: relay,
          onRelayListening: onRelayListening,
          onRelayConnectionError: onRelayConnectionError,
          onRelayConnectionDone: onRelayConnectionDone,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
          shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
          connectionTimeout: connectionTimeout,
          ignoreConnectionException: ignoreConnectionException,
          lazyListeningToRelays: lazyListeningToRelays,
        );
      });
    }
  }

  void _registerOnOklCallBack(
    String associatedEventId,
    void Function(NostrEventOkCommand ok)? onOk,
  ) {
    NostrRegistry.registerOkCommandCallBack(associatedEventId, onOk);
  }

  void _handleOkCommandMessageFromRelay({
    required NostrEventOkCommand okCommand,
  }) {
    final okCallBack = NostrRegistry.getOkCommandCallBack(okCommand.eventId);

    okCallBack?.call(okCommand);
  }

  void _registerOnEoselCallBack(
    String subscriptionId,
    void Function(NostrRequestEoseCommand eose)? onEose,
  ) {
    NostrRegistry.registerEoseCommandCallBack(subscriptionId, onEose);
  }

  void _handleEoseCommandMessageFromRelay({
    required NostrRequestEoseCommand eoseCommand,
  }) {
    final eoseCallBack =
        NostrRegistry.getEoseCommandCallBack(eoseCommand.subscriptionId);

    eoseCallBack?.call(eoseCommand);
  }

  void _registerOnCountCallBack(
    String subscriptionId,
    void Function(NostrCountResponse countResponse) onCountResponse,
  ) {
    NostrRegistry.registerCountResponseCallBack(
      subscriptionId,
      onCountResponse,
    );
  }

  void _handleCountResponseMessageFromRelay({
    required NostrCountResponse countResponse,
  }) {
    final countCallBack =
        NostrRegistry.getCountResponseCallBack(countResponse.subscriptionId);

    countCallBack?.call(countResponse);
  }
}
