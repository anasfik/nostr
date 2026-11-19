import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:async/async.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/core/crypto_utils.dart';
import 'package:dart_nostr/nostr/core/extensions.dart';
import 'package:dart_nostr/nostr/instance/registry.dart';
import 'package:dart_nostr/nostr/instance/relays/base/relays.dart';
import 'package:dart_nostr/nostr/instance/streams.dart';
import 'package:dart_nostr/nostr/instance/web_sockets.dart';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/relay.dart';
import 'package:dart_nostr/nostr/nips/nip11/nip11.dart';
import 'package:dart_nostr/nostr/nips/nip42/nip42.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
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

  /// Signer used for NIP-42 relay authentication challenges, if provided.
  NostrEventSigner? _authSigner;

  /// Callbacks invoked when a relay sends an AUTH challenge (NIP-42).
  final _authChallengeCallbacks =
      <void Function(String relay, String challenge)>[];

  /// Registers a callback for NIP-42 AUTH challenges. The library answers
  /// challenges automatically when a signer was passed to [init]; this
  /// callback lets applications observe the process.
  void onAuthChallenge(void Function(String relay, String challenge) handler) {
    _authChallengeCallbacks.add(handler);
  }

  /// Configuration captured from the last [init] call, so that implicit
  /// re-registrations (e.g. when sending to a new relay) preserve the caller's
  /// callbacks and options instead of silently resetting them.
  _RelayInitConfig? _lastInitConfig;

  /// Tracks consecutive reconnect attempts per relay, used to compute the
  /// exponential backoff delay and prevent hot reconnect loops.
  final Map<String, int> _reconnectAttempts = {};

  /// Incremented whenever a relay session is explicitly torn down or replaced.
  /// In-flight connections and delayed retries compare this token before they
  /// register a socket, so disconnect/free cannot be undone by a stale attempt.
  int _connectionGeneration = 0;

  /// Per-relay generation tokens, bumped when one relay is explicitly removed
  /// without invalidating the rest of the pool.
  final Map<String, int> _relayGenerations = {};

  /// Relays with a reconnect attempt currently in flight, so error+done
  /// callbacks from the same socket cannot schedule duplicate reconnects.
  final Set<String> _reconnectingRelays = {};

  /// Active REQ payloads keyed by subscription id, replayed after reconnect.
  final Map<String, _ActiveSubscription> _activeSubscriptions = {};

  int _relayGeneration(String relay) => _relayGenerations[relay] ?? 0;

  void _invalidateRelay(String relay) {
    _relayGenerations[relay] = _relayGeneration(relay) + 1;
    _reconnectAttempts.remove(relay);
  }

  bool _isGenerationCurrent(
    int sessionGeneration,
    int relayGeneration,
    String relay,
  ) {
    return sessionGeneration == _connectionGeneration &&
        relayGeneration == _relayGeneration(relay);
  }

  Future<void> _closeSocketQuietly(WebSocketChannel socket) async {
    try {
      await socket.sink
          .close()
          .timeout(const Duration(seconds: 2), onTimeout: () {});
    } catch (_) {
      // Best-effort close; the stale socket must never be registered.
    }
  }

  /// Base delay for the exponential reconnect backoff.
  static const Duration _reconnectBaseDelay = Duration(milliseconds: 500);

  /// Maximum reconnect backoff delay.
  static const Duration _reconnectMaxDelay = Duration(seconds: 30);

  /// Random source used for reconnect backoff jitter.
  static final math.Random random = math.Random();

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
      String relayUrl,
      Object? error,
      WebSocketChannel? relayWebSocket,
    )? onRelayConnectionError,
    void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
        onRelayConnectionDone,
    void Function(
      String relay,
      WebSocketChannel? relayWebSocket,
      NostrNotice notice,
    )? onNoticeMessageFromRelay,
    bool lazyListeningToRelays = false,
    bool retryOnError = false,
    bool retryOnClose = false,
    bool ensureToClearRegistriesBeforeStarting = true,
    bool ignoreConnectionException = true,
    bool shouldReconnectToRelayOnNotice = false,
    Duration connectionTimeout = const Duration(seconds: 5),
    NostrEventSigner? signer,
  }) async {
    assert(
      relaysUrl.isNotEmpty,
      "initiating relays with an empty list doesn't make sense, please provide at least one relay url.",
    );
    relaysList = List.of(relaysUrl);

    _authSigner = signer;

    _lastInitConfig = _RelayInitConfig(
      onRelayListening: onRelayListening,
      onRelayConnectionError: onRelayConnectionError,
      onRelayConnectionDone: onRelayConnectionDone,
      onNoticeMessageFromRelay: onNoticeMessageFromRelay,
      retryOnError: retryOnError,
      retryOnClose: retryOnClose,
      shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
      ignoreConnectionException: ignoreConnectionException,
      connectionTimeout: connectionTimeout,
    );

    if (ensureToClearRegistriesBeforeStarting) {
      // A new session invalidates delayed retries and in-flight handshakes
      // from the previous one before their callbacks can register a socket.
      _connectionGeneration++;
      _relayGenerations.clear();
      _reconnectAttempts.clear();

      // Drop stale websocket registrations from previous sessions so they
      // don't receive sends or dispatch messages.
      nostrRegistry.clearWebSocketsRegistry();
      _connectionGeneration++;
      _relayGenerations.clear();
      _reconnectAttempts.clear();
      _reconnectingRelays.clear();
      _activeSubscriptions.clear();
    }

    return _startConnectingAndRegisteringRelays(
      relaysUrl: relaysUrl,
      onRelayListening: onRelayListening,
      onRelayConnectionError: onRelayConnectionError,
      onRelayConnectionDone: onRelayConnectionDone,
      onNoticeMessageFromRelay: onNoticeMessageFromRelay,
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
    final timeoutTimers = <Timer>[];

    _runFunctionOverRelationIteration((relay) {
      final relayUrl = relay.url;

      if (relays?.containsRelay(relayUrl) ?? true) {
        final completer = Completer<NostrEventOkCommand>();
        completers.add(completer);

        // A cancellable timer per relay; cancelled as soon as any OK arrives
        // so completers/timers don't linger until expiry.
        timeoutTimers.add(
          Timer(timeout, () {
            if (!isSomeOkTriggered && !completer.isCompleted) {
              completer.completeError(
                TimeoutException(
                  'the event with id: ${event.id} has timed out after: ${timeout.inSeconds} seconds',
                ),
              );
            }
          }),
        );

        final serialized = event.serialized();

        if (event.id == null) {
          for (final timer in timeoutTimers) {
            timer.cancel();
          }
          throw Exception('event id cannot be null');
        }

        _registerOnOklCallBack(
          associatedEventId: event.id!,
          relay: relayUrl,
          onOk: (relay, ok) {
            if (!completer.isCompleted) {
              isSomeOkTriggered = true;
              completer.complete(ok);
            }
          },
        );

        relay.socket.sink.add(serialized);
        logger.log(
          'event with id: ${event.id} is sent to relay with url: $relayUrl',
        );
      }
    });

    if (completers.isEmpty) {
      throw StateError(
        'No matching connected relay found to send the event to. '
        'Make sure the relays are registered via init() or pass an explicit relays list.',
      );
    }

    return Future.any(completers.map((e) => e.future)).whenComplete(() {
      for (final timer in timeoutTimers) {
        timer.cancel();
      }
    });
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
    final timeoutTimers = <Timer>[];

    _runFunctionOverRelationIteration((relay) {
      final relayUrl = relay.url;
      if (relays?.containsRelay(relayUrl) ?? true) {
        final completer = Completer<NostrCountResponse>();
        completers.add(completer);

        timeoutTimers.add(
          Timer(timeout, () {
            if (!isSomeOkTriggered && !completer.isCompleted) {
              completer.completeError(
                TimeoutException(
                  'the count event with subscription id: ${countEvent.subscriptionId} has timed out after: ${timeout.inSeconds} seconds',
                ),
              );
            }
          }),
        );

        _registerOnCountCallBack(
          relay: relayUrl,
          subscriptionId: countEvent.subscriptionId,
          onCountResponse: (relay, countRes) {
            if (!isSomeOkTriggered && !completer.isCompleted) {
              isSomeOkTriggered = true;
              completer.complete(countRes);
            }
          },
        );

        final serialized = countEvent.serialized();
        relay.socket.sink.add(serialized);
        logger.log(
          'count event with subscription id: ${countEvent.subscriptionId} is sent to relay with url: $relayUrl',
        );
      }
    });

    if (completers.isEmpty) {
      throw StateError(
        'No matching connected relay found to send the count event to. '
        'Make sure the relays are registered via init() or pass an explicit relays list.',
      );
    }

    return Future.any(completers.map((e) => e.future)).whenComplete(() {
      for (final timer in timeoutTimers) {
        timer.cancel();
      }
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
    void Function(String relay, NostrRequestEoseCommand ease)? onEose,
    bool useConsistentSubscriptionIdBasedOnRequestData = false,
    List<String>? relays,
  }) {
    // Honor an explicitly-set subscriptionId on the request; only fall back
    // to a random one when the caller didn't provide any.
    final serialized = request.serialized(
      subscriptionId: useConsistentSubscriptionIdBasedOnRequestData
          ? null
          : (request.subscriptionId ?? NostrCryptoUtils.randomHex()),
    );

    _activeSubscriptions[request.subscriptionId!] = _ActiveSubscription(
      serialized: serialized,
      relays: relays?.toSet(),
    );

    _registerNewRelays(relays ?? relaysList!).then((_) {
      _runFunctionOverRelationIteration((relay) {
        final relayUrl = relay.url;

        if (relays?.containsRelay(relayUrl) ?? true) {
          if (onEose != null) {
            _registerOnEoselCallBack(
              subscriptionId: request.subscriptionId!,
              onEose: onEose,
              relay: relayUrl,
            );
          }

          relay.socket.sink.add(serialized);
          logger.log(
            'request with subscription id: ${request.subscriptionId} is sent to relay with url: $relayUrl',
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
      onClose: () => closeEventsSubscription(request.subscriptionId!),
    );
  }

  ///
  NostrDataEntitiesStream startEventsSubscriptionWithoutAutoHandling({
    required NostrRequest request,
    List<String>? relays,
    bool includeRequestEntity = false,
  }) {
    final serialized = request.serialized(
      subscriptionId: request.subscriptionId ?? NostrCryptoUtils.randomHex(),
    );

    _activeSubscriptions[request.subscriptionId!] = _ActiveSubscription(
      serialized: serialized,
      relays: relays?.toSet(),
    );

    _registerNewRelays(relays ?? relaysList!).then(
      (_) {
        _runFunctionOverRelationIteration(
          (relay) {
            final relayUrl = relay.url;

            if (relays?.containsRelay(relayUrl) ?? true) {
              // if (onEose != null) {
              //   _registerOnEoselCallBack(
              //     subscriptionId: request.subscriptionId!,
              //     onEose: onEose,
              //     relay: relayUrl,
              //   );
              // }

              relay.socket.sink.add(serialized);
              logger.log(
                'request with subscription id: ${request.subscriptionId} is sent to relay with url: $relayUrl',
              );
            }
          },
        );
      },
    );

    final requestSubId = request.subscriptionId;

    final requestDataEntityStream = Stream.value(serialized);

    final allFetchedDataEntities = streamsController.allDataEntities;

    final mergedStream = includeRequestEntity
        ? requestDataEntityStream.mergeWith([allFetchedDataEntities])
        : allFetchedDataEntities;

    final subStream = mergedStream.where(
      (dataEntity) => _filterDataEntitiesBySubscriptionId(
        dataEntity,
        requestSubId,
      ),
    );

    return NostrDataEntitiesStream(
      request: request,
      stream: subStream,
      subscriptionId: request.subscriptionId!,
      onClose: () => closeEventsSubscription(request.subscriptionId!),
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

    if (completers.isEmpty) {
      throw StateError(
        'No matching connected relay found for the subscription. '
        'Make sure the relays are registered via init() or pass an explicit relays list.',
      );
    }

    final eventsSubscription = subscription.stream.listen(events.add);

    Timer? timeoutTimer;

    timeoutTimer = Timer(
      timeout,
      () {
        if (!isSomeEoseTriggered && !completers.every((c) => c.isCompleted)) {
          if (shouldThrowErrorOnTimeoutWithoutEose) {
            for (final completer in completers) {
              if (!completer.isCompleted) {
                completer.completeError(
                  TimeoutException(
                    'the subscription with id: $subId has timed out after: ${timeout.inSeconds} seconds',
                  ),
                );
              }
            }
          } else {
            for (final completer in completers) {
              if (!completer.isCompleted) {
                completer.complete(events);
              }
            }
          }
        }
      },
    );

    try {
      final result = await Future.any(completers.map((e) => e.future));
      return result;
    } finally {
      timeoutTimer.cancel();
      unawaited(eventsSubscription.cancel());
    }
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

    // Free the per-subscription callbacks so closed subscriptions don't leak.
    nostrRegistry.removeCallBacksForSubscription(subscriptionId);

    final active = _activeSubscriptions[subscriptionId];
    if (relay == null) {
      _activeSubscriptions.remove(subscriptionId);
    } else if (active != null) {
      // Closing on one relay keeps the subscription active elsewhere.
      if (active.relays == null) {
        active.relays = (relaysList ?? const <String>[])
            .where((url) => url != relay)
            .toSet();
      } else {
        active.relays!.remove(relay);
      }

      if (active.relays!.isEmpty) {
        _activeSubscriptions.remove(subscriptionId);
      }
    }

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
      String relay,
      WebSocketChannel? relayWebSocket,
      NostrNotice notice,
    )? onNoticeMessageFromRelay,
  }) {
    final relayWebSocket = nostrRegistry.getRelayWebSocket(relayUrl: relay);
    final sessionGeneration = _connectionGeneration;
    final relayGeneration = _relayGeneration(relay);

    relayWebSocket!.stream.listen(
      (d) {
        final data = d.toString();

        _handleRegisteringDataFromRelay(
          dataEntity: data,
        );

        onRelayListening?.call(relay, d, relayWebSocket);

        // Decode once and dispatch by type — avoids up to 6 jsonDecode calls
        // that the old canBeDeserialized + deserialized chain required.
        List<dynamic> decoded;
        try {
          decoded = jsonDecode(data) as List;
        } catch (_) {
          logger.log(
            'received non-JSON message from relay: $relay, message: $data',
          );
          return;
        }

        if (decoded.isEmpty) {
          logger.log('received empty message array from relay: $relay');
          return;
        }

        final messageType = decoded[0] as String?;

        if (messageType == NostrConstants.event) {
          _handleAddingEventToSink(
            event: NostrEvent.fromDecodedMessage(decoded),
            relay: relay,
          );
        } else if (messageType == NostrConstants.notice) {
          final notice = NostrNotice.fromDecodedMessage(decoded);

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
            onNoticeMessageFromRelay: onNoticeMessageFromRelay,
            retryOnError: retryOnError,
            retryOnClose: retryOnClose,
            shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
          );
        } else if (messageType == NostrConstants.ok) {
          _handleOkCommandMessageFromRelay(
            okCommand: NostrEventOkCommand.fromDecodedMessage(decoded),
            relay: relay,
          );
        } else if (messageType == NostrConstants.eose) {
          _handleEoseCommandMessageFromRelay(
            eoseCommand: NostrRequestEoseCommand.fromDecodedMessage(decoded),
            relay: relay,
          );
        } else if (messageType == NostrConstants.count) {
          _handleCountResponseMessageFromRelay(
            relay: relay,
            countResponse: NostrCountResponse.fromDecodedMessage(decoded),
          );
        } else if (messageType == NostrConstants.closed) {
          // NIP-01 CLOSED: a REQ was rejected/closed by the relay.
          if (decoded.length >= 2 && decoded[1] is String) {
            streamsController.closedSubscriptionsController.sink.add(
              (
                subscriptionId: decoded[1] as String,
                reason: decoded.length >= 3 ? '${decoded[2]}' : null,
              ),
            );
          }
          logger.log('relay $relay closed subscription: $data');
        } else if (messageType == NostrConstants.auth) {
          // NIP-42: ["AUTH", <challenge-string>]
          if (decoded.length >= 2) {
            final challenge = '${decoded[1]}';

            for (final callback in List.of(_authChallengeCallbacks)) {
              try {
                callback(relay, challenge);
              } catch (_) {}
            }

            unawaited(_answerAuthChallenge(relay: relay, challenge: challenge));
          }
        } else {
          logger.log(
            'received unknown message from relay: $relay, message: $data',
          );
        }
      },
      onError: (Object error) {
        if (retryOnError &&
            _isGenerationCurrent(sessionGeneration, relayGeneration, relay)) {
          unawaited(
            _reconnectToRelay(
              relay: relay,
              onRelayListening: onRelayListening,
              onRelayConnectionError: onRelayConnectionError,
              onRelayConnectionDone: onRelayConnectionDone,
              onNoticeMessageFromRelay: onNoticeMessageFromRelay,
              retryOnError: retryOnError,
              retryOnClose: retryOnClose,
              shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
              connectionTimeout: connectionTimeout,
              ignoreConnectionException: ignoreConnectionException,
              lazyListeningToRelays: lazyListeningToRelays,
              expectedSessionGeneration: sessionGeneration,
              expectedRelayGeneration: relayGeneration,
            ),
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
        if (retryOnClose &&
            _isGenerationCurrent(sessionGeneration, relayGeneration, relay)) {
          unawaited(
            _reconnectToRelay(
              relay: relay,
              onRelayListening: onRelayListening,
              onRelayConnectionError: onRelayConnectionError,
              onRelayConnectionDone: onRelayConnectionDone,
              onNoticeMessageFromRelay: onNoticeMessageFromRelay,
              retryOnError: retryOnError,
              retryOnClose: retryOnClose,
              shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
              connectionTimeout: connectionTimeout,
              ignoreConnectionException: ignoreConnectionException,
              lazyListeningToRelays: lazyListeningToRelays,
              expectedSessionGeneration: sessionGeneration,
              expectedRelayGeneration: relayGeneration,
            ),
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
  }) {
    return NostrNip11(logger: logger).fetch(
      relayUrl: relayUrl,
      throwExceptionIfExists: throwExceptionIfExists,
    );
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
    void Function(
      String relay,
      WebSocketChannel? relayWebSocket,
      NostrNotice notice,
    )? onNoticeMessageFromRelay,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    bool relayUnregistered = true,
  }) async {
    final completer = Completer<void>();

    if (relaysList == null || relaysList!.isEmpty) {
      throw Exception(
        'you need to call the init method before calling this method.',
      );
    }

    final sessionGeneration = _connectionGeneration;

    for (final relay in relaysList!) {
      if (sessionGeneration != _connectionGeneration) {
        completer.complete();
        return completer.future;
      }

      await _reconnectToRelay(
        relayUnregistered: relayUnregistered,
        relay: relay,
        onRelayListening: onRelayListening,
        onRelayConnectionError: onRelayConnectionError,
        onRelayConnectionDone: onRelayConnectionDone,
        onNoticeMessageFromRelay: onNoticeMessageFromRelay,
        retryOnError: retryOnError,
        retryOnClose: retryOnClose,
        shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
        connectionTimeout: connectionTimeout,
        ignoreConnectionException: ignoreConnectionException,
        lazyListeningToRelays: lazyListeningToRelays,
        expectedSessionGeneration: sessionGeneration,
        expectedRelayGeneration: _relayGeneration(relay),
      );
    }

    completer.complete();

    return completer.future;
  }

  /// Connects additional relays without dropping existing ones, merging
  /// them into the tracked relay list so implicit reconnections keep working
  /// for every relay in the pool.
  Future<void> connectAdditionalRelays(
    List<String> newRelaysUrl, {
    required Duration connectionTimeout,
    NostrEventSigner? signer,
    bool ignoreConnectionException = true,
  }) async {
    final previous = List<String>.of(relaysList ?? const []);

    await init(
      relaysUrl: newRelaysUrl,
      connectionTimeout: connectionTimeout,
      retryOnClose: true,
      retryOnError: true,
      ignoreConnectionException: ignoreConnectionException,
      ensureToClearRegistriesBeforeStarting: false,
      signer: signer,
    );

    // init() replaced relaysList with only the new set; restore the full
    // pool view so implicit reconnects cover every relay.
    relaysList = {...previous, ...newRelaysUrl}.toList();
  }

  /// Disconnects a single relay at runtime, leaving all other connections
  /// untouched. Returns true when the relay was connected and is now closed.
  Future<bool> disconnectFromRelay(String relayUrl) async {
    // Invalidate any pending reconnect for this relay before closing it.
    _relayGenerations[relayUrl] = (_relayGenerations[relayUrl] ?? 0) + 1;
    _reconnectAttempts.remove(relayUrl);

    final webSocket = nostrRegistry.getRelayWebSocketOrNull(
      relayUrl: relayUrl,
    );

    // Invalidate first: a reconnect scheduled from onDone/onError must see the
    // new token even if the close below completes asynchronously.
    _invalidateRelay(relayUrl);
    relaysList?.remove(relayUrl);
    nostrRegistry.unregisterRelay(relayUrl);

    if (webSocket == null) {
      return false;
    }

    try {
      await webSocket.sink.close();
    } catch (_) {
      // Already closing/closed; still unregistered.
    }

    logger.log('relay $relayUrl disconnected and removed from the pool');
    return true;
  }

  /// The list of relay URLs that are currently registered and believed to be
  /// connected successfully.
  List<String> get connectedRelayUrls =>
      nostrRegistry.relaysWebSocketsRegistry.keys
          .where(
            (relay) =>
                nostrRegistry.isRelayRegisteredAndConnectedSuccesfully(relay),
          )
          .toList(growable: false);

  Future<bool> disconnectFromRelays({
    int Function(String relayUrl)? closeCode,
    String Function(String relayUrl)? closeReason,
    void Function(
      String relayUrl,
      WebSocketChannel relayWebSOcket,
      dynamic webSocketDisconnectionMessage,
    )? onRelayDisconnect,
  }) async {
    // Invalidate the whole session before closing anything so delayed
    // reconnects and in-flight handshakes cannot register after disconnect.
    _connectionGeneration++;
    _relayGenerations.clear();
    _reconnectAttempts.clear();
    _reconnectingRelays.clear();
    _activeSubscriptions.clear();

    final webSockets = List.of(nostrRegistry.relaysWebSocketsRegistry.entries);
    relaysList = [];
    nostrRegistry.clearWebSocketsRegistry();
    Object? firstError;
    StackTrace? firstStackTrace;

    for (final current in webSockets) {
      final relayUrl = current.key;
      final relayWebSocket = current.value;

      try {
        final returnedMessage = await relayWebSocket.sink.close(
          closeCode?.call(relayUrl),
          closeReason?.call(relayUrl),
        );

        onRelayDisconnect?.call(relayUrl, relayWebSocket, returnedMessage);
      } catch (error, stackTrace) {
        // Keep closing the rest, then rethrow the first failure so
        // freeAllResources keeps its false/throw failure semantics.
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }

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
    void Function(
      String relay,
      WebSocketChannel? relayWebSocket,
      NostrNotice notice,
    )? onNoticeMessageFromRelay,
    required bool retryOnError,
    required bool retryOnClose,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    required bool ignoreConnectionException,
    required bool lazyListeningToRelays,
    bool relayUnregistered = true,
    int? expectedSessionGeneration,
    int? expectedRelayGeneration,
  }) async {
    final sessionGeneration = expectedSessionGeneration ?? _connectionGeneration;
    final relayGeneration = expectedRelayGeneration ?? _relayGeneration(relay);

    if (!_isGenerationCurrent(sessionGeneration, relayGeneration, relay)) {
      return;
    }

    // Error and done callbacks can both fire for the same dead socket.
    if (!_reconnectingRelays.add(relay)) {
      return;
    }

    try {
      logger.log('retrying to listen to relay with url: $relay...');

      // Exponential backoff with jitter: reconnecting immediately in a loop
      // against a down relay burns CPU and battery and hammers the relay.
      final attempts = (_reconnectAttempts[relay] ?? 0);
      _reconnectAttempts[relay] = attempts + 1;

      final backoffMs = math.min(
        _reconnectBaseDelay.inMilliseconds * math.pow(2, attempts).toInt(),
        _reconnectMaxDelay.inMilliseconds,
      );
      final jitteredDelay =
          Duration(milliseconds: backoffMs + random.nextInt(backoffMs + 1));

      await Future<void>.delayed(jitteredDelay);

      // Disconnect/free may have happened while waiting; never revive the socket.
      if (!_isGenerationCurrent(sessionGeneration, relayGeneration, relay) ||
          !(relaysList?.contains(relay) ?? false)) {
        logger.log(
          'reconnect for relay $relay cancelled: session or relay changed',
        );
        return;
      }

      if (nostrRegistry.isRelayRegisteredAndConnectedSuccesfully(relay)) {
        logger.log('relay $relay is already reconnected; skipping');
        return;
      }

      if (relayUnregistered) {
        await _startConnectingAndRegisteringRelay(
          relayUrl: relay,
          onRelayListening: onRelayListening,
          onRelayConnectionError: onRelayConnectionError,
          onRelayConnectionDone: onRelayConnectionDone,
          onNoticeMessageFromRelay: onNoticeMessageFromRelay,
          retryOnError: retryOnError,
          retryOnClose: retryOnClose,
          shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
          connectionTimeout: connectionTimeout,
          ignoreConnectionException: ignoreConnectionException,
          lazyListeningToRelays: lazyListeningToRelays,
          expectedSessionGeneration: sessionGeneration,
          expectedRelayGeneration: relayGeneration,
        );

        if (nostrRegistry.isRelayRegisteredAndConnectedSuccesfully(relay)) {
          _replayActiveSubscriptions(relay);
        }
      }
    } finally {
      _reconnectingRelays.remove(relay);
    }
  }

  /// Re-sends active REQ payloads to [relay] after a reconnect. Initial
  /// connections are skipped to avoid sending every REQ twice.
  void _replayActiveSubscriptions(String relay) {
    for (final entry in _activeSubscriptions.entries) {
      final subscription = entry.value;

      if (subscription.relays != null &&
          !subscription.relays!.contains(relay)) {
        continue;
      }

      final socket = nostrRegistry.getRelayWebSocketOrNull(relayUrl: relay);
      if (socket == null) {
        return;
      }

      socket.sink.add(subscription.serialized);
      logger.log(
        'replayed subscription ${entry.key} to relay $relay after reconnect',
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
    void Function(
      String relay,
      WebSocketChannel? relayWebSocket,
      NostrNotice notice,
    )? onNoticeMessageFromRelay,
    required bool lazyListeningToRelays,
    required bool retryOnError,
    required bool retryOnClose,
    required bool ignoreConnectionException,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    int? expectedSessionGeneration,
    int? expectedRelayGeneration,
  }) {
    return _startConnectingAndRegisteringRelays(
      relaysUrl: [relayUrl],
      onRelayListening: onRelayListening,
      onRelayConnectionError: onRelayConnectionError,
      onRelayConnectionDone: onRelayConnectionDone,
      onNoticeMessageFromRelay: onNoticeMessageFromRelay,
      lazyListeningToRelays: lazyListeningToRelays,
      retryOnError: retryOnError,
      retryOnClose: retryOnClose,
      ignoreConnectionException: ignoreConnectionException,
      shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
      connectionTimeout: connectionTimeout,
      expectedSessionGeneration: expectedSessionGeneration,
      expectedRelayGeneration: expectedRelayGeneration,
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
    void Function(
      String relay,
      WebSocketChannel? relayWebSocket,
      NostrNotice notice,
    )? onNoticeMessageFromRelay,
    required bool lazyListeningToRelays,
    required bool retryOnError,
    required bool retryOnClose,
    required bool ignoreConnectionException,
    required bool shouldReconnectToRelayOnNotice,
    required Duration connectionTimeout,
    int? expectedSessionGeneration,
    int? expectedRelayGeneration,
  }) async {
    final sessionGeneration = expectedSessionGeneration ?? _connectionGeneration;

    await Future.wait(
      relaysUrl.map((relay) async {
        final relayGeneration =
            expectedRelayGeneration ?? _relayGeneration(relay);

        if (!_isGenerationCurrent(sessionGeneration, relayGeneration, relay)) {
          return;
        }

        if (nostrRegistry.isRelayRegisteredAndConnectedSuccesfully(relay)) {
          logger.log(
            'relay with url: $relay is already connected successfully, skipping...',
          );
          return;
        }

        try {
          await webSocketsService.connectRelay(
            relay: relay,
            connectionTimeout: connectionTimeout,
            shouldIgnoreConnectionException: ignoreConnectionException,
            onConnectionSuccess: (relayWebSocket) {
              if (!_isGenerationCurrent(
                    sessionGeneration,
                    relayGeneration,
                    relay,
                  ) ||
                  !(relaysList?.contains(relay) ?? false)) {
                unawaited(_closeSocketQuietly(relayWebSocket));
                return;
              }

              nostrRegistry.registerRelayWebSocket(
                relayUrl: relay,
                webSocket: relayWebSocket,
              );
              _reconnectAttempts.remove(relay);
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
                  onNoticeMessageFromRelay: onNoticeMessageFromRelay,
                  retryOnError: retryOnError,
                  retryOnClose: retryOnClose,
                  shouldReconnectToRelayOnNotice:
                      shouldReconnectToRelayOnNotice,
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
      }),
      eagerError: false,
    );
  }

  bool _filterNostrEventsWithId(
    NostrEvent event,
    String? requestSubId,
  ) {
    final eventSubId = event.subscriptionId;

    return eventSubId == requestSubId;
  }

  bool _filterDataEntitiesBySubscriptionId(
    String dataEntity,
    String? requestSubId,
  ) {
    try {
      final tryDecode = jsonDecode(dataEntity) as List;
      if (tryDecode.length > 1) {
        final second = tryDecode[1];
        if (second is String && second == requestSubId && second.isNotEmpty) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  void _handleRegisteringDataFromRelay({
    required String dataEntity,
  }) {
    if (nostrRegistry.isDataEntityRegistered(dataEntity)) {
      logger.log(
        'data entity with content: $dataEntity is already registered, skipping...',
      );
      return;
    }

    nostrRegistry.registerDataEntity(dataEntity);
    streamsController.allDataEntittyEventController.sink.add(dataEntity);

    logger.log(
      'data entity with content: $dataEntity is registered and added to the sink.',
    );
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
    void Function(
      String relay,
      WebSocketChannel? relayWebSocket,
      NostrNotice notice,
    )? onNoticeMessageFromRelay,
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

    if (!shouldReconnectToRelayOnNotice) return;

    if (nostrRegistry.isRelayRegistered(relay)) {
      final registeredRelay = nostrRegistry.getRelayWebSocket(relayUrl: relay);

      if (registeredRelay != null) {
        // Invalidate this socket before closing it. Its onDone listener also
        // has retryOnClose; without this bump it would schedule a second
        // reconnect alongside the NOTICE-driven one.
        _invalidateRelay(relay);
        final sessionGeneration = _connectionGeneration;
        final relayGeneration = _relayGeneration(relay);

        registeredRelay.sink.close().then((value) {
          if (!_isGenerationCurrent(
            sessionGeneration,
            relayGeneration,
            relay,
          )) {
            return;
          }

          final relayUnregistered = nostrRegistry.unregisterRelay(relay);

          unawaited(
            _reconnectToRelay(
              relayUnregistered: relayUnregistered,
              relay: relay,
              onRelayListening: onRelayListening,
              onRelayConnectionError: onRelayConnectionError,
              onRelayConnectionDone: onRelayConnectionDone,
              onNoticeMessageFromRelay: onNoticeMessageFromRelay,
              retryOnError: retryOnError,
              retryOnClose: retryOnClose,
              shouldReconnectToRelayOnNotice: shouldReconnectToRelayOnNotice,
              connectionTimeout: connectionTimeout,
              ignoreConnectionException: ignoreConnectionException,
              lazyListeningToRelays: lazyListeningToRelays,
              expectedSessionGeneration: sessionGeneration,
              expectedRelayGeneration: relayGeneration,
            ),
          );
        });
      }
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

  /// Answers a NIP-42 AUTH challenge with a signed kind-22242 event.
  /// No-op when no signer is configured or signing fails.
  Future<void> _answerAuthChallenge({
    required String relay,
    required String challenge,
  }) async {
    final signer = _authSigner;

    if (signer == null) {
      logger.log(
        'relay $relay requested auth but no signer is configured; '
        'pass a signer to init() to answer NIP-42 challenges.',
      );
      return;
    }

    try {
      // NIP-42 expects the websocket URL, not its HTTP equivalent.
      final authEvent = await const NostrNip42().createAuthEvent(
        signer: signer,
        relay: relay,
        challenge: challenge,
      );

      final socket = nostrRegistry.getRelayWebSocket(relayUrl: relay);

      socket?.sink.add(
        jsonEncode([NostrConstants.auth, authEvent.toMap()]),
      );

      logger.log('answered NIP-42 auth challenge for relay: $relay');
    } catch (e) {
      logger.log('failed to answer auth challenge for relay: $relay', e);
    }
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

  Future<void> _registerNewRelays(List<String> newRelaysUrlList) async {
    final hasUnconnected = newRelaysUrlList.any(
      (r) => !nostrRegistry.isRelayRegisteredAndConnectedSuccesfully(r),
    );
    if (!hasUnconnected) return;
    return init(
      relaysUrl: newRelaysUrlList,
      onRelayListening: _lastInitConfig?.onRelayListening,
      onRelayConnectionError: _lastInitConfig?.onRelayConnectionError,
      onRelayConnectionDone: _lastInitConfig?.onRelayConnectionDone,
      onNoticeMessageFromRelay: _lastInitConfig?.onNoticeMessageFromRelay,
      retryOnError: _lastInitConfig?.retryOnError ?? false,
      retryOnClose: _lastInitConfig?.retryOnClose ?? false,
      shouldReconnectToRelayOnNotice:
          _lastInitConfig?.shouldReconnectToRelayOnNotice ?? false,
      ignoreConnectionException:
          _lastInitConfig?.ignoreConnectionException ?? true,
      connectionTimeout:
          _lastInitConfig?.connectionTimeout ?? const Duration(seconds: 5),
      ensureToClearRegistriesBeforeStarting: false,
    );
  }
}

extension on Stream<String> {
  Stream<String> mergeWith(List<Stream<String>> list) {
    return StreamGroup.merge<String>([this, ...list]);
  }
}

/// A REQ payload that must be replayed when its relay reconnects.
class _ActiveSubscription {
  _ActiveSubscription({
    required this.serialized,
    required this.relays,
  });

  final String serialized;

  /// `null` means every relay in the current pool.
  Set<String>? relays;
}

/// Captures the configuration passed to [NostrRelays.init] so implicit
/// re-connections and re-registrations preserve it.
class _RelayInitConfig {
  const _RelayInitConfig({
    this.onRelayListening,
    this.onRelayConnectionError,
    this.onRelayConnectionDone,
    this.onNoticeMessageFromRelay,
    required this.retryOnError,
    required this.retryOnClose,
    required this.shouldReconnectToRelayOnNotice,
    required this.ignoreConnectionException,
    required this.connectionTimeout,
  });

  final void Function(
    String relayUrl,
    dynamic receivedData,
    WebSocketChannel? relayWebSocket,
  )? onRelayListening;

  final void Function(
    String relayUrl,
    Object? error,
    WebSocketChannel? relayWebSocket,
  )? onRelayConnectionError;

  final void Function(String relayUrl, WebSocketChannel? relayWebSocket)?
      onRelayConnectionDone;

  final void Function(
    String relay,
    WebSocketChannel? relayWebSocket,
    NostrNotice notice,
  )? onNoticeMessageFromRelay;

  final bool retryOnError;
  final bool retryOnClose;
  final bool shouldReconnectToRelayOnNotice;
  final bool ignoreConnectionException;
  final Duration connectionTimeout;
}
