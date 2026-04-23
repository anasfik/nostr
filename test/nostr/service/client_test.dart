import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/instance/subscription_manager.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:dart_nostr/nostr/model/ok.dart';
import 'package:test/test.dart';

class _FakeTransport implements NostrRelayTransport {
  bool connectCalled = false;
  bool disconnectCalled = false;
  int publishAttempts = 0;
  int countAttempts = 0;
  int publishFailuresBeforeSuccess = 0;
  Object? publishError;
  List<String> connectedRelays = const [];

  @override
  Future<void> connect({
    required List<String> relays,
    required Duration connectionTimeout,
  }) async {
    connectCalled = true;
    connectedRelays = relays;
  }

  @override
  Future<NostrEventOkCommand> publish(
    NostrEvent event, {
    required Duration timeout,
    List<String>? relays,
  }) async {
    publishAttempts++;
    if (publishError != null) {
      throw publishError!;
    }

    if (publishAttempts <= publishFailuresBeforeSuccess) {
      throw TimeoutException('publish failed');
    }

    return NostrEventOkCommand(
      eventId: event.id ?? 'id',
      isEventAccepted: true,
      message: 'ok',
    );
  }

  @override
  Future<NostrCountResponse> count(
    NostrCountEvent countEvent, {
    required Duration timeout,
    List<String>? relays,
  }) async {
    countAttempts++;
    return NostrCountResponse(
      subscriptionId: countEvent.subscriptionId,
      count: 1,
    );
  }

  @override
  NostrEventsStream subscribe({
    required NostrRequest request,
    List<String>? relays,
  }) {
    return NostrEventsStream(
      stream: const Stream<NostrEvent>.empty(),
      subscriptionId: request.subscriptionId ?? 'sub',
      request: request,
    );
  }

  @override
  void closeSubscription(String subscriptionId, [String? relay]) {}

  @override
  Future<bool> disconnect() async {
    disconnectCalled = true;
    connectedRelays = const [];
    return true;
  }
}

void main() {
  group('NostrClient', () {
    late _FakeTransport transport;
    late NostrClient client;
    late SubscriptionManager subscriptionManager;

    setUp(() {
      transport = _FakeTransport();
      subscriptionManager = SubscriptionManager(
        logger: NostrLogger(
          passedDebugOptions: NostrDebugOptions(
            tag: 'sub-test',
            isLogsEnabled: false,
          ),
        ),
      );
      client = NostrClient(
        transport: transport,
        logger: NostrLogger(
          passedDebugOptions: NostrDebugOptions(
            tag: 'client-test',
            isLogsEnabled: false,
          ),
        ),
        options: NostrClientOptions(
          retryPolicy: const NostrRetryPolicy(
            maxAttempts: 3,
            initialDelayMs: 1,
            maxDelayMs: 1,
          ),
          requestTimeout: const Duration(milliseconds: 10),
        ),
        subscriptionManager: subscriptionManager,
      );
    });

    tearDown(() {
      subscriptionManager.dispose();
    });

    test('connect validates, normalizes, and marks connected', () async {
      final result = await client.connect([
        ' wss://relay.damus.io ',
        'wss://relay.damus.io',
        'wss://nos.lol',
      ]);

      expect(result.isSuccess, isTrue);
      expect(client.isConnected, isTrue);
      expect(transport.connectCalled, isTrue);
      expect(client.connectedRelays, ['wss://relay.damus.io', 'wss://nos.lol']);
      expect(
          transport.connectedRelays, ['wss://relay.damus.io', 'wss://nos.lol']);
    });

    test('connect fails on invalid relay URL scheme', () async {
      final result = await client.connect(['https://relay.example.com']);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, NostrFailureCode.invalidArgument);
      expect(client.isConnected, isFalse);
    });

    test('publish retries and succeeds', () async {
      transport.publishFailuresBeforeSuccess = 2;
      await client.connect(['wss://relay.damus.io']);

      final event = NostrEvent.fromPartialData(
        kind: 1,
        content: 'hello',
        keyPairs: NostrKeyPairs.generate(),
      );

      final result = await client.publish(event);

      expect(result.isSuccess, isTrue);
      expect(transport.publishAttempts, 3);
    });

    test('publish fails with invalidState when disconnected', () async {
      final event = NostrEvent.fromPartialData(
        kind: 1,
        content: 'hello',
        keyPairs: NostrKeyPairs.generate(),
      );

      final result = await client.publish(event);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, NostrFailureCode.invalidState);
    });

    test('subscribe fails when request has no filters', () async {
      await client.connect(['wss://relay.damus.io']);

      final result = client.subscribe(NostrRequest(filters: []));

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, NostrFailureCode.invalidArgument);
    });

    test('subscribe returns stream when connected', () async {
      await client.connect(['wss://relay.damus.io']);

      final request = NostrRequest(
        filters: [
          NostrFilter(kinds: [1])
        ],
      );

      final result = client.subscribe(request);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.request, request);
    });

    test('subscribe tracks active subscription metadata', () async {
      await client.connect(['wss://relay.damus.io']);

      final request = NostrRequest(
        filters: [
          NostrFilter(kinds: [1], limit: 10)
        ],
      );

      final result = client.subscribe(request);

      expect(result.isSuccess, isTrue);
      final subscriptionId = result.valueOrNull!.subscriptionId;
      expect(subscriptionManager.isSubscriptionActive(subscriptionId), isTrue);
      expect(client.getActiveSubscriptions().keys, contains(subscriptionId));

      client.closeSubscription(subscriptionId);
      expect(subscriptionManager.isSubscriptionActive(subscriptionId), isFalse);
    });

    test('subscribe rejects invalid filter ranges', () async {
      await client.connect(['wss://relay.damus.io']);

      final result = client.subscribe(
        NostrRequest(
          filters: [
            NostrFilter(
              since: DateTime(2026, 1, 2),
              until: DateTime(2026, 1, 1),
            ),
          ],
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, NostrFailureCode.invalidArgument);
    });

    test('publish maps format exceptions to serialization failures', () async {
      transport.publishError = const FormatException('bad payload');
      await client.connect(['wss://relay.damus.io']);

      final event = NostrEvent.fromPartialData(
        kind: 1,
        content: 'hello',
        keyPairs: NostrKeyPairs.generate(),
      );

      final result = await client.publish(event);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, NostrFailureCode.serialization);
    });

    test('disconnect resets connection state', () async {
      await client.connect(['wss://relay.damus.io']);
      final sub = client.subscribe(
        NostrRequest(filters: [
          NostrFilter(kinds: [1])
        ]),
      );
      expect(sub.isSuccess, isTrue);

      final result = await client.disconnect();

      expect(result.isSuccess, isTrue);
      expect(client.isConnected, isFalse);
      expect(transport.disconnectCalled, isTrue);
    });
  });

  group('NostrFilter validation', () {
    test('empty filter reports empty state', () {
      const filter = NostrFilter();

      expect(filter.isEmpty, isTrue);
      expect(filter.validate(), isEmpty);
    });

    test('invalid limit is reported', () {
      const filter = NostrFilter(limit: 0);

      expect(
          filter.validate(), contains('Filter limit must be greater than 0.'));
    });
  });

  group('Nostr facade', () {
    late _FakeTransport transport;
    late SubscriptionManager subscriptionManager;
    late Nostr nostr;

    setUp(() {
      transport = _FakeTransport();
      final logger = NostrLogger(
        passedDebugOptions: NostrDebugOptions(
          tag: 'nostr-facade-test',
          isLogsEnabled: false,
        ),
      );

      subscriptionManager = SubscriptionManager(logger: logger);
      nostr = Nostr(
        services: NostrServices(
          logger: logger,
          relayTransport: transport,
          subscriptionManager: subscriptionManager,
          clientOptions: NostrClientOptions(
            retryPolicy: const NostrRetryPolicy(
              maxAttempts: 2,
              initialDelayMs: 1,
              maxDelayMs: 1,
            ),
          ),
        ),
      );
    });

    tearDown(() {
      subscriptionManager.dispose();
    });

    test('connect delegates through the top-level facade', () async {
      final result = await nostr.connect(['wss://relay.damus.io']);

      expect(result.isSuccess, isTrue);
      expect(nostr.isConnected, isTrue);
      expect(transport.connectCalled, isTrue);
      expect(nostr.connectedRelays, ['wss://relay.damus.io']);
    });

    test('subscribe wrapper creates a tracked subscription', () async {
      await nostr.connect(['wss://relay.damus.io']);

      final result = nostr.subscribe(
        const NostrFilter(kinds: [1], limit: 5),
      );

      expect(result.isSuccess, isTrue);
      expect(nostr.activeSubscriptions.length, 1);
      expect(nostr.subscriptionStatistics.totalSubscriptions, 1);
    });
  });
}
