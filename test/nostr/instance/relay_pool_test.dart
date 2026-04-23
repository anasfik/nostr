import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/relay_pool.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:test/test.dart';

void main() {
  group('RelayPoolManager', () {
    late RelayPoolManager manager;

    setUp(() {
      manager = RelayPoolManager(logger: _createMockLogger());
    });

    test('initialize adds relays to pool', () {
      final relays = ['wss://relay1.example.com', 'wss://relay2.example.com'];
      manager.initialize(relays);

      expect(manager.getAllRelayHealth().length, equals(2));
      expect(
          manager.getActiveConnections('wss://relay1.example.com'), equals(0));
    });

    test('recordSuccess marks relay as healthy', () {
      manager.initialize(['wss://relay1.example.com']);
      manager.recordFailure('wss://relay1.example.com');
      manager.recordSuccess('wss://relay1.example.com');

      expect(
        manager.getRelayHealth('wss://relay1.example.com')?.isHealthy,
        isTrue,
      );
    });

    test('recordFailure tracks failure count', () {
      manager.initialize(['wss://relay1.example.com']);

      for (int i = 0; i < 5; i++) {
        manager.recordFailure('wss://relay1.example.com');
      }

      expect(
        manager.getRelayHealth('wss://relay1.example.com')?.isHealthy,
        isFalse,
      );
    });

    test('selectBestRelay returns healthy relay with lowest load', () {
      manager.initialize([
        'wss://relay1.example.com',
        'wss://relay2.example.com',
      ]);

      manager.incrementConnections('wss://relay1.example.com');
      manager.incrementConnections('wss://relay1.example.com');

      final best = manager.selectBestRelay([
        'wss://relay1.example.com',
        'wss://relay2.example.com',
      ]);

      expect(best, equals('wss://relay2.example.com'));
    });

    test('getHealthyRelays filters and sorts by load', () {
      manager.initialize([
        'wss://relay1.example.com',
        'wss://relay2.example.com',
        'wss://relay3.example.com',
      ]);

      manager.recordFailure('wss://relay3.example.com');
      for (int i = 0; i < 5; i++) {
        manager.recordFailure('wss://relay3.example.com');
      }

      manager.incrementConnections('wss://relay1.example.com');

      final healthy = manager.getHealthyRelays([
        'wss://relay1.example.com',
        'wss://relay2.example.com',
        'wss://relay3.example.com',
      ]);

      expect(healthy.length, equals(2));
      expect(healthy.first, equals('wss://relay2.example.com'));
    });

    test('resetRelayHealth clears failure count', () {
      manager.initialize(['wss://relay1.example.com']);

      for (int i = 0; i < 5; i++) {
        manager.recordFailure('wss://relay1.example.com');
      }

      manager.resetRelayHealth('wss://relay1.example.com');

      expect(
        manager.getRelayHealth('wss://relay1.example.com')?.isHealthy,
        isTrue,
      );
    });

    test('addRelay and removeRelay manage pool', () {
      manager.initialize(['wss://relay1.example.com']);

      manager.addRelay('wss://relay2.example.com');
      expect(manager.getAllRelayHealth().length, equals(2));

      manager.removeRelay('wss://relay2.example.com');
      expect(manager.getAllRelayHealth().length, equals(1));
    });

    test('getStatistics returns correct metrics', () {
      manager.initialize([
        'wss://relay1.example.com',
        'wss://relay2.example.com',
      ]);

      manager.incrementConnections('wss://relay1.example.com');
      manager.incrementConnections('wss://relay1.example.com');

      final stats = manager.getStatistics();

      expect(stats.totalRelays, equals(2));
      expect(stats.healthyRelays, equals(2));
      expect(stats.totalActiveConnections, equals(2));
    });

    test('connection count increments and decrements correctly', () {
      manager.initialize(['wss://relay1.example.com']);

      manager.incrementConnections('wss://relay1.example.com');
      expect(
          manager.getActiveConnections('wss://relay1.example.com'), equals(1));

      manager.incrementConnections('wss://relay1.example.com');
      expect(
          manager.getActiveConnections('wss://relay1.example.com'), equals(2));

      manager.decrementConnections('wss://relay1.example.com');
      expect(
          manager.getActiveConnections('wss://relay1.example.com'), equals(1));
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
