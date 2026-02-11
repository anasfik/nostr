import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/subscription_manager.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:test/test.dart';

void main() {
  group('SubscriptionManager', () {
    late SubscriptionManager manager;

    setUp(() {
      manager = SubscriptionManager(logger: _createMockLogger());
    });

    tearDown(() {
      manager.dispose();
    });

    test('registerSubscription tracks new subscription', () {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com'],
      );

      expect(manager.getActiveSubscriptionCount(), equals(1));
      expect(manager.isSubscriptionActive('sub1'), isTrue);
    });

    test('getSubscription returns subscription metadata', () {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com', 'wss://relay2.example.com'],
      );

      final metadata = manager.getSubscription('sub1');

      expect(metadata, isNotNull);
      expect(metadata?.subscriptionId, equals('sub1'));
      expect(metadata?.relays.length, equals(2));
    });

    test('updateSubscription increments event count', () {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com'],
      );

      manager.updateSubscription('sub1', eventCount: 5);
      final metadata = manager.getSubscription('sub1');

      expect(metadata?.eventCount, equals(5));
    });

    test('closeSubscription removes subscription', () {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com'],
      );

      manager.closeSubscription('sub1');

      expect(manager.isSubscriptionActive('sub1'), isFalse);
      expect(manager.getActiveSubscriptionCount(), equals(0));
    });

    test('closeAllSubscriptions removes all subscriptions', () {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com'],
      );

      manager.registerSubscription(
        subscriptionId: 'sub2',
        filters: [],
        relays: ['wss://relay2.example.com'],
      );

      manager.closeAllSubscriptions();

      expect(manager.getActiveSubscriptionCount(), equals(0));
    });

    test('getSubscriptionsForRelay returns only relay subscriptions', () {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com', 'wss://relay2.example.com'],
      );

      manager.registerSubscription(
        subscriptionId: 'sub2',
        filters: [],
        relays: ['wss://relay2.example.com'],
      );

      manager.registerSubscription(
        subscriptionId: 'sub3',
        filters: [],
        relays: ['wss://relay3.example.com'],
      );

      final relay2Subs =
          manager.getSubscriptionsForRelay('wss://relay2.example.com');

      expect(relay2Subs.length, equals(2));
    });

    test('autoCloseAfter cancels subscription after timeout', () async {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com'],
        autoCloseAfter: const Duration(milliseconds: 100),
      );

      expect(manager.isSubscriptionActive('sub1'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(manager.isSubscriptionActive('sub1'), isFalse);
    });

    test('extendAutoCloseTimer extends subscription lifetime', () async {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com'],
        autoCloseAfter: const Duration(milliseconds: 100),
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      manager.extendAutoCloseTimer('sub1', const Duration(milliseconds: 100));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(manager.isSubscriptionActive('sub1'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(manager.isSubscriptionActive('sub1'), isFalse);
    });

    test('getStatistics returns correct metrics', () {
      manager.registerSubscription(
        subscriptionId: 'sub1',
        filters: [],
        relays: ['wss://relay1.example.com'],
      );

      manager.registerSubscription(
        subscriptionId: 'sub2',
        filters: [],
        relays: ['wss://relay1.example.com'],
      );

      manager.updateSubscription('sub1', eventCount: 10);
      manager.updateSubscription('sub2', eventCount: 20);

      final stats = manager.getStatistics();

      expect(stats.totalSubscriptions, equals(2));
      expect(stats.totalEventCount, equals(30));
      expect(stats.averageEventsPerSubscription, equals(15.0));
    });

    test('getStatistics handles empty subscriptions', () {
      final stats = manager.getStatistics();

      expect(stats.totalSubscriptions, equals(0));
      expect(stats.totalEventCount, equals(0));
    });
  });
}

class _MockLogger implements NostrLogger {
  @override
  late NostrDebugOptions passedDebugOptions;

  @override
  void log(String message, [dynamic error]) {}

  @override
  NostrDebugOptions get debugOptions =>
      passedDebugOptions ?? NostrDebugOptions.generate();

  @override
  void disableLogs() {}

  @override
  void enableLogs() {}
}

NostrLogger _createMockLogger() => _MockLogger();

