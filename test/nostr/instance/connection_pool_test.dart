import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/connection_pool.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionPoolManager', () {
    late ConnectionPoolManager manager;

    setUp(() {
      manager = ConnectionPoolManager(
        logger: _createMockLogger(),
        maxConnectionsPerRelay: 3,
      );
      manager.initialize();
    });

    tearDown(() {
      manager.dispose();
    });

    test('initialize starts the manager', () {
      expect(manager, isNotNull);
    });

    test('acquireConnection creates new connection', () async {
      final connection = await manager.acquireConnection('wss://relay1.example.com');

      expect(connection, isNotNull);
      expect(connection?.relayUrl, equals('wss://relay1.example.com'));
      expect(connection?.isInUse, isTrue);
    });

    test('releaseConnection returns connection to pool', () async {
      final connection1 = await manager.acquireConnection('wss://relay1.example.com');
      expect(connection1?.isInUse, isTrue);

      manager.releaseConnection(connection1!);
      expect(connection1.isInUse, isFalse);

      final connection2 = await manager.acquireConnection('wss://relay1.example.com');
      expect(connection2?.id, equals(connection1.id));
    });

    test('respects max connections per relay limit', () async {
      const maxConnections = 3;

      final connections = <PooledConnection>[];
      for (int i = 0; i < maxConnections; i++) {
        final conn =
            await manager.acquireConnection('wss://relay1.example.com');
        if (conn != null) {
          connections.add(conn);
        }
      }

      expect(connections.length, equals(maxConnections));

      final excess = await manager.acquireConnection('wss://relay1.example.com');
      expect(excess, isNull);
    });

    test('multiple relays have separate connection pools', () async {
      final conn1 = await manager.acquireConnection('wss://relay1.example.com');
      final conn2 = await manager.acquireConnection('wss://relay2.example.com');

      expect(conn1?.relayUrl, equals('wss://relay1.example.com'));
      expect(conn2?.relayUrl, equals('wss://relay2.example.com'));
      expect(conn1?.id, isNot(conn2?.id));
    });

    test('closeConnection removes from pool', () async {
      final connection = await manager.acquireConnection('wss://relay1.example.com');
      expect(connection, isNotNull);

      await manager.closeConnection(connection!);

      final stats = manager.getStatistics();
      expect(stats.totalConnections, equals(0));
    });

    test('closeAllConnectionsForRelay removes all relay connections', () async {
      await manager.acquireConnection('wss://relay1.example.com');
      await manager.acquireConnection('wss://relay1.example.com');
      await manager.acquireConnection('wss://relay2.example.com');

      await manager.closeAllConnectionsForRelay('wss://relay1.example.com');

      final stats = manager.getStatistics();
      expect(stats.totalConnections, equals(1));
    });

    test('getStatistics returns correct metrics', () async {
      final conn1 = await manager.acquireConnection('wss://relay1.example.com');
      final conn2 = await manager.acquireConnection('wss://relay1.example.com');
      
      manager.releaseConnection(conn1!);

      final stats = manager.getStatistics();

      expect(stats.totalConnections, equals(2));
      expect(stats.inUseConnections, equals(1));
      expect(stats.availableConnections, equals(1));
    });

    test('poolUtilization calculated correctly', () async {
      await manager.acquireConnection('wss://relay1.example.com');
      await manager.acquireConnection('wss://relay1.example.com');

      final stats = manager.getStatistics();

      expect(stats.poolUtilization, equals(100.0));
    });

    test('PooledConnection tracks age', () async {
      final connection = await manager.acquireConnection('wss://relay1.example.com');
      
      expect(connection?.getAgeInSeconds(), equals(0));
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

