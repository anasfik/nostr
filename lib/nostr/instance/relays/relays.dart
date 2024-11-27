import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/core/extensions.dart';
import 'package:dart_nostr/nostr/instance/relays/base/relays.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/relay.dart';
import 'package:dart_nostr/nostr/model/relay_informations.dart';
import 'package:dart_nostr/nostr/instance/registry.dart';
import 'package:dart_nostr/nostr/instance/streams.dart';
import 'package:dart_nostr/nostr/instance/web_sockets.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// {@template nostr_relays}
/// This class is responsible for all the relays related operations.
/// {@endtemplate}

class NostrRelays implements NostrRelaysBase {
  /// {@macro nostr_relays}
  NostrRelays({
    required this.logger,
  }) {
    nostrRegistry = NostrRegistry(logger: logger);
  }

  /// Represents a registry of all relays that you did registered with the [init] method.
  @override
  Map<String, WebSocketChannel> get relaysWebSocketsRegistry =>
      nostrRegistry.relaysWebSocketsRegistry;

  /// Represents a registry of all events you received from all relays so far.
  @override
  Map<String, NostrEvent> get eventsRegistry => nostrRegistry.eventsRegistry;

  /// The list of relays urls that you did registered with the [init] method.
  @override
  List<String>? relaysList;

  /// {@macro nostr_streams_controllers}
  final streamsController = NostrStreamsControllers();

  /// {@macro nostr_web_sockets_service}

  late final webSocketsService = NostrWebSocketsService(
    logger: logger,
  );

  /// {@macro nostr_registry}
  late final NostrRegistry nostrRegistry;

  final NostrLogger logger;

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
      String relayUrl,
      dynamic receivedData,
      WebSocketChannel? relayWebSocket,
    )? onRelayListening,
    void Function(
            String relayUrl, Object? error, WebSocketChannel? relayWebSocket)?
        onRelayConnectionError,
    void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
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
    relaysList = List.of(relaysUrl);

    return _startConnectingAndRegisteringRelays(
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
  /// ```dar
  /// Nostr.instance.relays.sendEventToRelays(event);
  /// ```
  @override
  Future<void> sendEventToRelays(
    NostrEvent event, {
    List<String>? relays,
    void Function(String relay, NostrEventOkCommand ok)? onOk,
  }) async {
    await _registerNewRelays(relays ?? relaysList!);

    final serialized = event.serialized();

    if (event.id == null) {
      throw Exception('event id cannot be null');
    }

    _runFunctionOverRelationIteration((relay) {
      final relayUrl = relay.url;

      if (relays?.containsRelay(relayUrl) ?? true) {
        _registerOnOklCallBack(
          associatedEventId: event.id!,
          onOk: onOk ?? (relay, ok) {},
          relay: relayUrl,
        );

        relay.socket.sink.add(serialized);
        logger.log(
          'event with id: ${event.id} is sent to relay with url: ${relay.url}',
        );
      }
    });
  }

  /// {@template send_event_to_relays_async}
  /// This method is responsible for sending an event to all relays that you did registered with the [init] method, and gets you a [Future] of [NostrEventOkCommand] that will be triggered when the event is accepted by the relays.
  /// {@endtemplate}
  @override
  Future<NostrEventOkCommand> sendEventToRelaysAsync(
    NostrEvent event, {
    required Duration timeout,
    List<String>? relays,
  }) async {
    await _registerNewRelays(relays ?? relaysList!);

    var isSomeOkTriggered = false;

    final completers = <Completer<NostrEventOkCommand>>[];

    _runFunctionOverRelationIteration((relay) {
      final relayUrl = relay.url;

      if (relays?.containsRelay(relayUrl) ?? true) {
        final completer = Completer<NostrEventOkCommand>();
        completers.add(completer);

        Future.delayed(timeout, () {
          if (!isSomeOkTriggered) {
            throw TimeoutException(
              'the event with id: ${event.id} has timed out after: ${timeout.inSeconds} seconds',
            );
          }
        });

        final serialized = event.serialized();

        if (event.id == null) {
          throw Exception('event id cannot be null');
        }

        _registerOnOklCallBack(
          associatedEventId: event.id!,
          relay: relayUrl,
          onOk: (relay, ok) {
            isSomeOkTriggered = true;
            completer.complete(ok);
          },
        );

        relay.socket.sink.add(serialized);
        logger.log(
          'event with id: ${event.id} is sent to relay with url: $relayUrl',
        );
      }
    });

    return Future.any(completers.map((e) => e.future));
  }

  @override
  Future<void> sendCountEventToRelays(
    NostrCountEvent countEvent, {
    required void Function(String relay, NostrCountResponse countResponse)
        onCountResponse,
    List<String>? relays,
  }) async {
    await _registerNewRelays(relays ?? relaysList!);

    final serialized = countEvent.serialized();

    _runFunctionOverRelationIteration((relay) {
      final relayUrl = relay.url;

      if (relays?.containsRelay(relayUrl) ?? true) {
        _registerOnCountCallBack(
          subscriptionId: countEvent.subscriptionId,
          onCountResponse: onCountResponse,
          relay: relayUrl,
        );

        relay.socket.sink.add(serialized);
        logger.log(
          'Count Event with subscription id: ${countEvent.subscriptionId} is sent to relay with url: ${relay.url}',
        );
      }
    });
  }

  @override
  Future<NostrCountResponse> sendCountEventToRelaysAsync(
    NostrCountEvent countEvent, {
    required Duration timeout,
    List<String>? relays,
  }) async {
    await _registerNewRelays(relays ?? relaysList!);

    var isSomeOkTriggered = false;

    final completers = <Completer<NostrCountResponse>>[];

    _runFunctionOverRelationIteration((relay) {
      final relayUrl = relay.url;
      if (relays?.containsRelay(relayUrl) ?? true) {
        _registerOnCountCallBack(
          relay: relayUrl,
          subscriptionId: countEvent.subscriptionId,
          onCountResponse: (relay, countRes) {
            final completer = Completer<NostrCountResponse>();

            Future.delayed(timeout, () {
              if (!isSomeOkTriggered) {
                throw TimeoutException(
                  'the count event with subscription id: ${countEvent.subscriptionId} has timed out after: ${timeout.inSeconds} seconds',
                );
              }
            });

            isSomeOkTriggered = true;
            completer.complete(countRes);
          },
        );

        final serialized = countEvent.serialized();
        relay.socket.sink.add(serialized);
        logger.log(
          'count event with subscription id: ${countEvent.subscriptionId} is sent to relay with url: ${relayUrl}',
        );
      }
    });

    return Future.any(completers.map((e) => e.future));
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
    void Function(String relay, NostrRequestEoseCommand ease)? onEose,
    bool useConsistentSubscriptionIdBasedOnRequestData = false,
    List<String>? relays,
  }) {
    final serialized = request.serialized(
      subscriptionId: useConsistentSubscriptionIdBasedOnRequestData
          ? null
          : Nostr.instance.services.utils.random64HexChars(),
    );

    _registerNewRelays(relays ?? relaysList!).then((_) {
      _runFunctionOverRelationIteration((relay) {
        final relayUrl = relay.url;

        if (relays?.containsRelay(relayUrl) ?? true) {
          _registerOnEoselCallBack(
            subscriptionId: request.subscriptionId!,
            onEose: onEose ?? (relay, eose) {},
            relay: relayUrl,
          );

          relay.socket.sink.add(serialized);
          logger.log(
            'request with subscription id: ${request.subscriptionId} is sent to relay with url: ${relayUrl}',
          );
        }
      });
    });

    final requestSubId = request.subscriptionId;
    final subStream = streamsController.events.where(
      (event) => _filterNostrEventsWithId(event, requestSubId),
    );

    return NostrEventsStream(
      request: request,
      stream: subStream,
      subscriptionId: request.subscriptionId!,
    );
  }

  /// {@template start_events_subscription_async}
  /// Retuens a [Future] of [List<NostrEvent>] that will be triggered when the [onEose] callback is triggered of the subscription created by your [request].
  /// {@endtemplate}
  @override
  Future<List<NostrEvent>> startEventsSubscriptionAsync({
    required NostrRequest request,
    required Duration timeout,
    void Function(String relay, NostrRequestEoseCommand ease)? onEose,
    bool useConsistentSubscriptionIdBasedOnRequestData = false,
    bool shouldThrowErrorOnTimeoutWithoutEose = true,
    List<String>? relays,
  }) async {
    await _registerNewRelays(relays ?? relaysList!);

    final subscription = startEventsSubscription(
      request: request,
      onEose: onEose,
      useConsistentSubscriptionIdBasedOnRequestData:
          useConsistentSubscriptionIdBasedOnRequestData,
    );

    final subId = subscription.subscriptionId;

    var isSomeEoseTriggered = false;

    final events = <NostrEvent>[];

    final completers = <Completer<List<NostrEvent>>>[];

    _runFunctionOverRelationIteration((relay) {
      final relayUrl = relay.url;

      if (relays?.containsRelay(relayUrl) ?? true) {
        final completer = Completer<List<NostrEvent>>();
        completers.add(completer);

        _registerOnEoselCallBack(
          subscriptionId: subId,
          relay: relayUrl,
          onEose: (relay, eose) {
            if (!isSomeEoseTriggered) {
              // subscription.close();
              completer.complete(events);
              isSomeEoseTriggered = true;
            }
          },
        );
      }
    });

    subscription.stream.listen(events.add);

    Future.delayed(
      timeout,
      () {
        if (!isSomeEoseTriggered) {
          if (shouldThrowErrorOnTimeoutWithoutEose) {
            throw TimeoutException(
              'the subscription with id: $subId has timed out after: ${timeout.inSeconds} seconds',
            );
          } else {
            for (final completer in completers) {
              completer.complete(events);
            }
          }
        }
      },
    );

    return Future.any(completers.map((e) => e.future));
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
  /// {@endtemplate}
  @override
  void closeEventsSubscription(String subscriptionId, [String? relay]) {
    final close = NostrRequestClose(
      subscriptionId: subscriptionId,
    );

    final serialized = close.serialized();

    if (relay != null) {
      final registeredRelay = nostrRegistry.getRelayWebSocket(relayUrl: relay);

      registeredRelay?.sink.add(serialized);

      logger.log(
        'Close request with subscription id: $subscriptionId is sent to relay with url: $relay',
      );

      return;
    }
    _runFunctionOverRelationIteration(
      (relay) {
        relay.socket.sink.add(serialized);
        logger.log(
          'Close request with subscription id: $subscriptionId is sent to relay with url: ${relay.url}',
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
      String relayUrl,
      dynamic receivedData,
      WebSocketChannel? relayWebSocket,
    )? onRelayListening,
    required void Function(
      String relayUrl,
      Object? error,
      WebSocketChannel? relayWebSocket,
    )? onRelayConnectionError,
    required void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    void Function(
            String relay, WebSocketChannel? relayWebSocket, NostrNotice notice)?
        onNoticeMessageFromRelay,
  }) {
    final relayWebSocket = nostrRegistry.getRelayWebSocket(relayUrl: relay);

    relayWebSocket!.stream.listen(
      (d) {
        final data = d.toString();

        onRelayListening?.call(relay, d, relayWebSocket);

        if (NostrEvent.canBeDeserialized(data)) {
          _handleAddingEventToSink(
            event: NostrEvent.deserialized(data),
            relay: relay,
          );
        } else if (NostrNotice.canBeDeserialized(data)) {
          final notice = NostrNotice.fromRelayMessage(data);

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
        } else if (NostrEventOkCommand.canBeDeserialized(data)) {
          _handleOkCommandMessageFromRelay(
            okCommand: NostrEventOkCommand.fromRelayMessage(data),
            relay: relay,
          );
        } else if (NostrRequestEoseCommand.canBeDeserialized(data)) {
          _handleEoseCommandMessageFromRelay(
            eoseCommand: NostrRequestEoseCommand.fromRelayMessage(data),
            relay: relay,
          );
        } else if (NostrCountResponse.canBeDeserialized(data)) {
          final countResponse = NostrCountResponse.deserialized(data);

          _handleCountResponseMessageFromRelay(
            relay: relay,
            countResponse: countResponse,
          );
        } else {
          logger.log(
            'received unknown message from relay: $relay, message: $d',
          );
        }
      },
      onError: (error) {
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

        logger.log(
          'web socket of relay with $relay had an error: $error',
          error,
        );
      },
      onDone: () {
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
      },
    );
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
          webSocketsService.getHttpUrlFromWebSocketUrl(relayUrl);

      final res = await http.get(
        relayHttpUri,
        headers: {
          'Accept': 'application/nostr+json',
        },
      );
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;

      return RelayInformations.fromNip11Response(decoded);
    } catch (e) {
      logger.log(
        'error while getting relay informations from nip11 for relay url: $relayUrl',
        e,
      );

      if (throwExceptionIfExists) {
        rethrow;
      }
    }
    return null;
  }

  @override
  Future<void> reconnectToRelays({
    required void Function(
      String relayUrl,
      dynamic receivedData,
      WebSocketChannel? relayWebSocket,
    )? onRelayListening,
    required void Function(
      String relayUrl,
      Object? error,
      WebSocketChannel? relayWebSocket,
    )? onRelayConnectionError,
    required void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
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

    if (relaysList == null || relaysList!.isEmpty) {
      throw Exception(
        'you need to call the init method before calling this method.',
      );
    }

    for (final relay in relaysList!) {
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

  Future<bool> disconnectFromRelays({
    int Function(String relayUrl)? closeCode,
    String Function(String relayUrl)? closeReason,
    void Function(
      String relayUrl,
      WebSocketChannel relayWebSOcket,
      dynamic webSocketDisconnectionMessage,
    )? onRelayDisconnect,
  }) async {
    final webSockets = nostrRegistry.relaysWebSocketsRegistry;
    for (var index = 0; index < webSockets.length; index++) {
      final current = webSockets.entries.elementAt(index);
      final relayUrl = current.key;
      final relayWebSocket = current.value;

      final returnedMessage = await relayWebSocket.sink.close(
        closeCode?.call(relayUrl),
        closeReason?.call(relayUrl),
      );

      onRelayDisconnect?.call(relayUrl, relayWebSocket, returnedMessage);
    }

    nostrRegistry.clearWebSocketsRegistry();
    relaysList = [];

    return true;
  }

  @override
  Future<bool> freeAllResources([bool throwOnFailure = false]) async {
    try {
      await disconnectFromRelays();
      await streamsController.close();

      nostrRegistry.clear();

      return true;
    } catch (e) {
      if (throwOnFailure) {
        rethrow;
      }

      return false;
    }
  }

  Future<void> _reconnectToRelay({
    required String relay,
    required void Function(
      String relayUrl,
      dynamic receivedData,
      WebSocketChannel? relayWebSocket,
    )? onRelayListening,
    required void Function(
      String relayUrl,
      Object? error,
      WebSocketChannel? relayWebSocket,
    )? onRelayConnectionError,
    required void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    bool relayUnregistered = true,
  }) async {
    logger.log('retrying to listen to relay with url: $relay...');

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
      String relayUrl,
      dynamic receivedData,
      WebSocketChannel? relayWebSocket,
    )? onRelayListening,
    required void Function(
      String relayUrl,
      Object? error,
      WebSocketChannel? relayWebSocket,
    )? onRelayConnectionError,
    required void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
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
      String relayUrl,
      dynamic receivedData,
      WebSocketChannel? relayWebSocket,
    )? onRelayListening,
    required void Function(
      String relayUrl,
      Object? error,
      WebSocketChannel? relayWebSocket,
    )? onRelayConnectionError,
    required void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
        onRelayConnectionDone,
    required bool lazyListeningToRelays,
    required bool retryOnError,
    required bool retryOnClose,
    required bool ignoreConnectionException,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
  }) async {
    final completer = Completer();

    for (final relay in relaysUrl) {
      if (nostrRegistry.isRelayRegisteredAndConnectedSuccesfully(relay)) {
        logger.log(
          'relay with url: $relay is already connected successfully, skipping...',
        );

        continue;
      }

      try {
        await webSocketsService.connectRelay(
          relay: relay,
          onConnectionSuccess: (relayWebSocket) {
            nostrRegistry.registerRelayWebSocket(
              relayUrl: relay,
              webSocket: relayWebSocket,
            );
            logger.log(
              'the websocket for the relay with url: $relay, is registered.',
            );
            logger.log(
              'listening to the websocket for the relay with url: $relay...',
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
          },
        );
      } catch (e) {
        onRelayConnectionError?.call(relay, e, null);
      }
    }

    completer.complete();

    return completer.future;
  }

  bool _filterNostrEventsWithId(
    NostrEvent event,
    String? requestSubId,
  ) {
    final eventSubId = event.subscriptionId;

    return eventSubId == requestSubId;
  }

  void _handleAddingEventToSink({
    required String? relay,
    required NostrEvent event,
  }) {
    logger.log(
      'received event with content: ${event.content} from relay: $relay',
    );

    if (!nostrRegistry.isEventRegistered(event)) {
      if (streamsController.isClosed) {
        logger.log(
          'streams controller is closed, event with id: ${event.id} will be ignored and not added to the sink.',
        );

        return;
      }

      streamsController.eventsController.sink.add(event);
      nostrRegistry.registerEvent(event);
    }
  }

  void _handleNoticeFromRelay({
    required NostrNotice notice,
    required String relay,
    required void Function(
      String relayUrl,
      dynamic receivedData,
      WebSocketChannel? relayWebSocket,
    )? onRelayListening,
    required void Function(
      String relayUrl,
      Object? error,
      WebSocketChannel? relayWebSocket,
    )? onRelayConnectionError,
    required void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
        onRelayConnectionDone,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
  }) {
    logger.log(
      'received notice with message: ${notice.message} from relay: $relay',
    );

    if (nostrRegistry.isRelayRegistered(relay)) {
      final registeredRelay = nostrRegistry.getRelayWebSocket(relayUrl: relay);

      registeredRelay?.sink.close().then((value) {
        final relayUnregistered = nostrRegistry.unregisterRelay(relay);

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

  void _registerOnOklCallBack({
    required String associatedEventId,
    required void Function(String relay, NostrEventOkCommand ok) onOk,
    required String relay,
  }) {
    nostrRegistry.registerOkCommandCallBack(
      associatedEventId: associatedEventId,
      onOk: onOk,
      relay: relay,
    );
  }

  void _handleOkCommandMessageFromRelay({
    required NostrEventOkCommand okCommand,
    required String relay,
  }) {
    final okCallBack = nostrRegistry.getOkCommandCallBack(
      associatedEventIdWithOkCommand: okCommand.eventId,
      relay: relay,
    );

    okCallBack?.call(relay, okCommand);
  }

  void _registerOnEoselCallBack({
    required String subscriptionId,
    required void Function(String relay, NostrRequestEoseCommand eose) onEose,
    required String relay,
  }) {
    nostrRegistry.registerEoseCommandCallBack(
      subscriptionId: subscriptionId,
      onEose: onEose,
      relay: relay,
    );
  }

  void _handleEoseCommandMessageFromRelay({
    required NostrRequestEoseCommand eoseCommand,
    required String relay,
  }) {
    final eoseCallBack = nostrRegistry.getEoseCommandCallBack(
      subscriptionId: eoseCommand.subscriptionId,
      relay: relay,
    );

    eoseCallBack?.call(relay, eoseCommand);
  }

  void _registerOnCountCallBack({
    required String subscriptionId,
    required void Function(String relay, NostrCountResponse countResponse)
        onCountResponse,
    required String relay,
  }) {
    nostrRegistry.registerCountResponseCallBack(
      subscriptionId: subscriptionId,
      relay: relay,
      onCountResponse: onCountResponse,
    );
  }

  void _handleCountResponseMessageFromRelay({
    required NostrCountResponse countResponse,
    required String relay,
  }) {
    final countCallBack = nostrRegistry.getCountResponseCallBack(
      subscriptionId: countResponse.subscriptionId,
      relay: relay,
    );

    countCallBack?.call(
      relay,
      countResponse,
    );
  }

  void _runFunctionOverRelationIteration(
    void Function(NostrRelay) relayCallback,
  ) {
    final entries = nostrRegistry.allRelaysEntries();

    for (var index = 0; index < entries.length; index++) {
      final current = entries[index];
      final relay = NostrRelay(
        url: current.key,
        socket: current.value,
      );

      relayCallback.call(relay);
    }
  }

  Future<void> _registerNewRelays(List<String> newRelaysList) async {
    return init(
      relaysUrl: newRelaysList,
    );
  }
}
