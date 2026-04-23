import 'dart:async';
import 'dart:io';

import 'package:dart_nostr/nostr/core/failures.dart';
import 'package:dart_nostr/nostr/core/result.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/subscription_manager.dart';
import 'package:dart_nostr/nostr/model/count.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/nostr_events_stream.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:dart_nostr/nostr/service/client_options.dart';
import 'package:dart_nostr/nostr/service/relay_transport.dart';

class NostrClient {
  NostrClient({
    required this.transport,
    required this.logger,
    this.options = const NostrClientOptions(),
    SubscriptionManager? subscriptionManager,
  }) : subscriptionManager = subscriptionManager;

  final NostrRelayTransport transport;
  final NostrLogger logger;
  final NostrClientOptions options;
  final SubscriptionManager? subscriptionManager;

  bool _connected = false;
  List<String> _connectedRelays = const [];

  bool get isConnected => _connected;
  List<String> get connectedRelays => List.unmodifiable(_connectedRelays);

  Future<NostrResult<void>> connect(List<String> relays) async {
    if (relays.isEmpty) {
      return NostrFailureResult<void>(
        NostrFailure.invalidArgument(
          'At least one relay is required to connect.',
        ),
      );
    }

    final normalizedRelays = relays
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedRelays.isEmpty) {
      return NostrFailureResult<void>(
        NostrFailure.invalidArgument(
          'Provided relays are empty after normalization.',
          context: <String, Object?>{'relays': relays},
        ),
      );
    }

    for (final relay in normalizedRelays) {
      if (!relay.startsWith('ws://') && !relay.startsWith('wss://')) {
        return NostrFailureResult<void>(
          NostrFailure.invalidArgument(
            'Invalid relay URL scheme. Relay must start with ws:// or wss://.',
            context: <String, Object?>{'relay': relay},
          ),
        );
      }
    }

    final result = await _runWithRetry<void>(
      operationName: 'connect',
      operation: () async {
        await transport.connect(
          relays: normalizedRelays,
          connectionTimeout: options.connectionTimeout,
        );
      },
      relayContext: normalizedRelays.join(','),
    );

    if (result.isFailure) {
      return NostrFailureResult<void>(result.failureOrNull!);
    }

    _connected = true;
    _connectedRelays = normalizedRelays;

    return const NostrSuccess<void>(null);
  }

  Future<NostrResult<NostrEventOkCommand>> publish(
    NostrEvent event, {
    List<String>? relays,
  }) {
    final disconnectedFailure = _buildDisconnectedFailure('publish');
    if (disconnectedFailure != null) {
      return Future.value(
        NostrFailureResult<NostrEventOkCommand>(
          disconnectedFailure,
        ),
      );
    }

    if (event.id == null || event.id!.isEmpty) {
      return Future.value(
        NostrFailureResult<NostrEventOkCommand>(
          NostrFailure.invalidArgument('Event id cannot be null or empty.'),
        ),
      );
    }

    return _runWithRetry(
      operationName: 'publish',
      operation: () => transport.publish(
        event,
        timeout: options.requestTimeout,
        relays: relays,
      ),
      relayContext: (relays ?? _connectedRelays).join(','),
    );
  }

  Future<NostrResult<NostrCountResponse>> count(
    NostrCountEvent event, {
    List<String>? relays,
  }) {
    final disconnectedFailure = _buildDisconnectedFailure('count');
    if (disconnectedFailure != null) {
      return Future.value(
        NostrFailureResult<NostrCountResponse>(
          disconnectedFailure,
        ),
      );
    }

    return _runWithRetry(
      operationName: 'count',
      operation: () => transport.count(
        event,
        timeout: options.requestTimeout,
        relays: relays,
      ),
      relayContext: (relays ?? _connectedRelays).join(','),
    );
  }

  NostrResult<NostrEventsStream> subscribe(
    NostrRequest request, {
    List<String>? relays,
  }) {
    final disconnectedFailure = _buildDisconnectedFailure('subscribe');
    if (disconnectedFailure != null) {
      return NostrFailureResult<NostrEventsStream>(disconnectedFailure);
    }

    if (request.filters.isEmpty) {
      return NostrFailureResult<NostrEventsStream>(
        NostrFailure.invalidArgument(
          'Subscription request must contain at least one filter.',
        ),
      );
    }

    final validationErrors = request.filters
        .expand((filter) => filter.validate())
        .toList(growable: false);

    if (validationErrors.isNotEmpty) {
      return NostrFailureResult<NostrEventsStream>(
        NostrFailure.invalidArgument(
          validationErrors.join(' '),
          context: <String, Object?>{
            'errors': validationErrors,
          },
        ),
      );
    }

    if (request.filters.every((filter) => filter.isEmpty)) {
      return NostrFailureResult<NostrEventsStream>(
        NostrFailure.invalidArgument(
          'Subscription request must include at least one non-empty filter.',
        ),
      );
    }

    try {
      final stream = transport.subscribe(request: request, relays: relays);
      final managedStream = _trackSubscription(
        stream,
        relays: relays ?? _connectedRelays,
      );
      return NostrSuccess<NostrEventsStream>(managedStream);
    } catch (error, stackTrace) {
      return NostrFailureResult<NostrEventsStream>(
        _mapErrorToFailure(
          operationName: 'subscribe',
          error: error,
          stackTrace: stackTrace,
          relayContext: (relays ?? _connectedRelays).join(','),
        ),
      );
    }
  }

  void closeSubscription(String subscriptionId, [String? relay]) {
    subscriptionManager?.closeSubscription(subscriptionId);
    transport.closeSubscription(subscriptionId, relay);
  }

  void closeAllSubscriptions() {
    final subscriptionIds = subscriptionManager
            ?.getActiveSubscriptions()
            .keys
            .toList(growable: false) ??
        const <String>[];

    for (final subscriptionId in subscriptionIds) {
      closeSubscription(subscriptionId);
    }
  }

  Map<String, SubscriptionMetadata> getActiveSubscriptions() {
    return subscriptionManager?.getActiveSubscriptions() ??
        const <String, SubscriptionMetadata>{};
  }

  SubscriptionStatistics getSubscriptionStatistics() {
    return subscriptionManager?.getStatistics() ??
        SubscriptionStatistics(
          totalSubscriptions: 0,
          totalEventCount: 0,
          averageEventsPerSubscription: 0,
          oldestSubscriptionAgeSeconds: 0,
          newestSubscriptionAgeSeconds: 0,
        );
  }

  NostrFailure? _buildDisconnectedFailure(String operationName) {
    if (_connected) {
      return null;
    }

    return NostrFailure.invalidState(
      'Client is not connected. Call connect() before $operationName().',
      context: <String, Object?>{'operation': operationName},
    );
  }

  NostrEventsStream _trackSubscription(
    NostrEventsStream stream, {
    required List<String> relays,
  }) {
    subscriptionManager?.registerSubscription(
      subscriptionId: stream.subscriptionId,
      filters: stream.request.filters,
      relays: relays,
    );

    final trackedStream = Stream<NostrEvent>.multi(
      (controller) {
        var eventCount = 0;

        final subscription = stream.stream.listen(
          (event) {
            eventCount++;
            subscriptionManager?.updateSubscription(
              stream.subscriptionId,
              eventCount: eventCount,
            );
            controller.add(event);
          },
          onError: controller.addError,
          onDone: () {
            subscriptionManager?.closeSubscription(stream.subscriptionId);
            controller.close();
          },
        );

        controller.onCancel = () async {
          await subscription.cancel();
          closeSubscription(stream.subscriptionId);
        };
      },
      isBroadcast: true,
    );

    return NostrEventsStream(
      stream: trackedStream,
      subscriptionId: stream.subscriptionId,
      request: stream.request,
      onClose: () => closeSubscription(stream.subscriptionId),
    );
  }

  Future<NostrResult<void>> disconnect() async {
    try {
      closeAllSubscriptions();
      await transport.disconnect();
      _connected = false;
      _connectedRelays = const [];
      return const NostrSuccess<void>(null);
    } catch (error, stackTrace) {
      return NostrFailureResult<void>(
        _mapErrorToFailure(
          operationName: 'disconnect',
          error: error,
          stackTrace: stackTrace,
          relayContext: _connectedRelays.join(','),
        ),
      );
    }
  }

  Future<NostrResult<T>> _runWithRetry<T>({
    required String operationName,
    required Future<T> Function() operation,
    required String relayContext,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1;
        attempt <= options.retryPolicy.maxAttempts;
        attempt++) {
      try {
        final result = await operation();
        return NostrSuccess<T>(result);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        final failure = _mapErrorToFailure(
          operationName: operationName,
          error: error,
          stackTrace: stackTrace,
          relayContext: relayContext,
        );

        logger.log(
          'NostrClient $operationName failed at attempt $attempt/${options.retryPolicy.maxAttempts}: ${failure.message}',
          error,
        );

        if (options.failFast || !options.retryPolicy.shouldRetry(attempt)) {
          return NostrFailureResult<T>(failure);
        }

        await Future<void>.delayed(
          options.retryPolicy.getDelayForAttempt(attempt),
        );
      }
    }

    return NostrFailureResult<T>(
      _mapErrorToFailure(
        operationName: operationName,
        error: lastError ?? Exception('Unknown error during $operationName'),
        stackTrace: lastStackTrace,
        relayContext: relayContext,
      ),
    );
  }

  NostrFailure _mapErrorToFailure({
    required String operationName,
    required Object error,
    required StackTrace? stackTrace,
    required String relayContext,
  }) {
    final context = <String, Object?>{
      'operation': operationName,
      'relays': relayContext,
    };

    if (error is TimeoutException) {
      return NostrFailure.timeout(
        'Operation $operationName timed out.',
        cause: error,
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (error is NostrException) {
      return error.failure.copyWith(
        context: <String, Object?>{
          ...error.failure.context,
          ...context,
        },
      );
    }

    if (error is SocketException || error is WebSocketException) {
      return NostrFailure.connection(
        'Connection error while performing $operationName.',
        cause: error,
        stackTrace: stackTrace,
        context: context,
      );
    }

    if (error is FormatException) {
      return NostrFailure.serialization(
        'Serialization error while performing $operationName.',
        cause: error,
        stackTrace: stackTrace,
        context: context,
      );
    }

    return NostrFailure.unknown(
      'Unexpected failure during $operationName.',
      cause: error,
      stackTrace: stackTrace,
      context: context,
      isRetryable: true,
    );
  }
}
