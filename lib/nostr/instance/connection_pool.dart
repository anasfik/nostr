import 'dart:async';

import 'package:dart_nostr/nostr/core/utils.dart';

/// {@template connection_pool_manager}
/// Manages a pool of WebSocket connections with connection reuse, limits, and lifecycle management.
/// {@endtemplate}
class ConnectionPoolManager {
  /// {@macro connection_pool_manager}
  ConnectionPoolManager({
    required this.logger,
    this.maxConnectionsPerRelay = 5,
    this.maxIdleTimeSeconds = 300,
  });

  final NostrLogger logger;

  /// Maximum concurrent connections per relay.
  final int maxConnectionsPerRelay;

  /// Maximum idle time before closing a connection (in seconds).
  final int maxIdleTimeSeconds;

  /// Pool of connections per relay.
  final Map<String, List<PooledConnection>> _connectionPools = {};

  /// Tracks available connections per relay.
  final Map<String, List<PooledConnection>> _availableConnections = {};

  /// Idle connection cleanup timer.
  Timer? _idleCleanupTimer;

  /// Initialize the connection pool manager.
  void initialize() {
    _startIdleConnectionCleanup();
    logger.log(
      'ConnectionPoolManager initialized (maxConnections: $maxConnectionsPerRelay, maxIdleTime: ${maxIdleTimeSeconds}s)',
    );
  }

  /// Get or create a connection from the pool.
  Future<PooledConnection?> acquireConnection(String relayUrl) async {
    _ensurePoolExists(relayUrl);

    final available = _availableConnections[relayUrl] ?? [];
    if (available.isNotEmpty) {
      final connection = available.removeAt(0);
      connection.markAsInUse();
      logger.log('Connection reused for relay: $relayUrl');
      return connection;
    }

    final pool = _connectionPools[relayUrl] ?? [];
    if (pool.length < maxConnectionsPerRelay) {
      final connection = PooledConnection(relayUrl: relayUrl);
      pool.add(connection);
      _connectionPools[relayUrl] = pool;
      connection.markAsInUse();
      logger.log(
        'New connection created for relay: $relayUrl (${pool.length}/$maxConnectionsPerRelay)',
      );
      return connection;
    }

    logger.log(
      'Connection pool limit reached for relay: $relayUrl, waiting for available connection',
    );
    return null;
  }

  /// Release a connection back to the pool.
  void releaseConnection(PooledConnection connection) {
    _ensurePoolExists(connection.relayUrl);

    final available = _availableConnections[connection.relayUrl] ?? [];
    connection.markAsAvailable();
    available.add(connection);
    _availableConnections[connection.relayUrl] = available;

    logger.log('Connection released for relay: ${connection.relayUrl}');
  }

  /// Close a specific connection and remove it from the pool.
  Future<void> closeConnection(PooledConnection connection) async {
    final pool = _connectionPools[connection.relayUrl];
    if (pool != null) {
      pool.removeWhere((c) => c.id == connection.id);
    }

    final available = _availableConnections[connection.relayUrl];
    if (available != null) {
      available.removeWhere((c) => c.id == connection.id);
    }

    logger.log('Connection closed for relay: ${connection.relayUrl}');
  }

  /// Close all connections for a relay.
  Future<void> closeAllConnectionsForRelay(String relayUrl) async {
    final connections = _connectionPools[relayUrl] ?? [];
    // Future: Add WebSocket close logic if needed
    connections.clear();
    _connectionPools[relayUrl] = [];
    _availableConnections[relayUrl] = [];
    logger.log('All connections closed for relay: $relayUrl');
  }

  /// Close all connections in the pool.
  Future<void> closeAllConnections() async {
    for (final relayUrl in _connectionPools.keys.toList()) {
      await closeAllConnectionsForRelay(relayUrl);
    }
    logger.log('All connections in pool closed');
  }

  /// Get connection pool statistics.
  ConnectionPoolStatistics getStatistics() {
    int totalConnections = 0;
    int totalAvailableConnections = 0;
    int totalInUseConnections = 0;

    for (final connections in _connectionPools.values) {
      totalConnections += connections.length;
      totalInUseConnections += connections.where((c) => c.isInUse).length;
    }

    for (final connections in _availableConnections.values) {
      totalAvailableConnections += connections.length;
    }

    totalInUseConnections = totalConnections - totalAvailableConnections;

    return ConnectionPoolStatistics(
      totalConnections: totalConnections,
      availableConnections: totalAvailableConnections,
      inUseConnections: totalInUseConnections,
      poolUtilization: totalConnections > 0
          ? (totalInUseConnections / totalConnections) * 100
          : 0,
    );
  }

  /// Ensure a pool exists for a relay.
  void _ensurePoolExists(String relayUrl) {
    _connectionPools.putIfAbsent(relayUrl, () => []);
    _availableConnections.putIfAbsent(relayUrl, () => []);
  }

  /// Start idle connection cleanup timer.
  void _startIdleConnectionCleanup() {
    _idleCleanupTimer?.cancel();
    _idleCleanupTimer =
        Timer.periodic(Duration(seconds: maxIdleTimeSeconds), (_) {
      _cleanupIdleConnections();
    });
  }

  /// Clean up idle connections.
  void _cleanupIdleConnections() {
    final now = DateTime.now();

    for (final relayUrl in _availableConnections.keys.toList()) {
      final available = _availableConnections[relayUrl] ?? [];
      final toRemove = <PooledConnection>[];

      for (final connection in available) {
        final idleTime = now.difference(connection.lastUsedAt).inSeconds;
        if (idleTime > maxIdleTimeSeconds) {
          toRemove.add(connection);
        }
      }

      for (final connection in toRemove) {
        available.remove(connection);
        final pool = _connectionPools[relayUrl];
        pool?.removeWhere((c) => c.id == connection.id);
        logger.log(
          'Idle connection closed for relay: $relayUrl',
        );
      }
    }
  }

  /// Dispose the manager and clean up resources.
  void dispose() {
    _idleCleanupTimer?.cancel();
    closeAllConnections();
  }
}

/// Represents a pooled connection.
class PooledConnection {
  final String id;
  final String relayUrl;
  bool isInUse = false;
  DateTime createdAt;
  DateTime lastUsedAt;
  dynamic webSocket; // Can hold any WebSocket implementation

  PooledConnection({required this.relayUrl})
      : id = _generateId(),
        createdAt = DateTime.now(),
        lastUsedAt = DateTime.now();

  /// Mark connection as in use.
  void markAsInUse() {
    isInUse = true;
    lastUsedAt = DateTime.now();
  }

  /// Mark connection as available.
  void markAsAvailable() {
    isInUse = false;
    lastUsedAt = DateTime.now();
  }

  /// Get connection age in seconds.
  int getAgeInSeconds() => DateTime.now().difference(createdAt).inSeconds;

  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000).toString().padLeft(5, '0')}';
  }

  @override
  String toString() {
    return 'PooledConnection(id: $id, relay: $relayUrl, inUse: $isInUse, age: ${getAgeInSeconds()}s)';
  }
}

/// Statistics for the connection pool.
class ConnectionPoolStatistics {
  final int totalConnections;
  final int availableConnections;
  final int inUseConnections;
  final double poolUtilization;

  ConnectionPoolStatistics({
    required this.totalConnections,
    required this.availableConnections,
    required this.inUseConnections,
    required this.poolUtilization,
  });

  @override
  String toString() {
    return 'ConnectionPoolStatistics('
        'total: $totalConnections, '
        'available: $availableConnections, '
        'inUse: $inUseConnections, '
        'utilization: ${poolUtilization.toStringAsFixed(2)}%)';
  }
}
