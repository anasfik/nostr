import 'package:dart_nostr/nostr/core/utils.dart';

/// {@template relay_pool_manager}
/// Manages a pool of relays with load balancing, health checks, and failover strategies.
/// {@endtemplate}
class RelayPoolManager {
  /// {@macro relay_pool_manager}
  RelayPoolManager({
    required this.logger,
  });

  final NostrLogger logger;

  /// Tracks the health status of each relay.
  final Map<String, RelayHealthStatus> _relayHealth = {};

  /// Tracks active connections per relay.
  final Map<String, int> _activeConnections = {};

  /// Tracks failure counts for each relay.
  final Map<String, int> _failureCount = {};

  /// Maximum failures before marking relay as unhealthy.
  static const int maxFailureThreshold = 5;

  /// Get the health status of a specific relay.
  RelayHealthStatus? getRelayHealth(String relayUrl) => _relayHealth[relayUrl];

  /// Get all relay health statuses.
  Map<String, RelayHealthStatus> getAllRelayHealth() =>
      Map.unmodifiable(_relayHealth);

  /// Get active connection count for a relay.
  int getActiveConnections(String relayUrl) =>
      _activeConnections[relayUrl] ?? 0;

  /// Initialize relay pool with a list of relay URLs.
  void initialize(List<String> relayUrls) {
    for (final url in relayUrls) {
      _relayHealth[url] = RelayHealthStatus(
        url: url,
        isHealthy: true,
        lastCheckedAt: DateTime.now(),
      );
      _activeConnections[url] = 0;
      _failureCount[url] = 0;
    }

    logger.log('RelayPoolManager initialized with ${relayUrls.length} relays');
  }

  /// Record a successful connection to a relay.
  void recordSuccess(String relayUrl) {
    final health = _relayHealth[relayUrl];
    if (health != null) {
      _failureCount[relayUrl] = 0;
      _relayHealth[relayUrl] = health.copyWith(
        isHealthy: true,
        lastCheckedAt: DateTime.now(),
      );
    }
  }

  /// Record a failed connection attempt to a relay.
  void recordFailure(String relayUrl) {
    final failures = (_failureCount[relayUrl] ?? 0) + 1;
    _failureCount[relayUrl] = failures;

    final health = _relayHealth[relayUrl];
    if (health != null) {
      final isHealthy = failures < maxFailureThreshold;
      _relayHealth[relayUrl] = health.copyWith(
        isHealthy: isHealthy,
        lastCheckedAt: DateTime.now(),
      );

      if (!isHealthy) {
        logger.log(
          'Relay $relayUrl marked as unhealthy after $failures failures',
        );
      }
    }
  }

  /// Increment active connection count for a relay.
  void incrementConnections(String relayUrl) {
    _activeConnections[relayUrl] = (_activeConnections[relayUrl] ?? 0) + 1;
  }

  /// Decrement active connection count for a relay.
  void decrementConnections(String relayUrl) {
    final current = _activeConnections[relayUrl] ?? 0;
    if (current > 0) {
      _activeConnections[relayUrl] = current - 1;
    }
  }

  /// Get the best relay based on health and load (round-robin with health awareness).
  String? selectBestRelay(List<String> availableRelays) {
    final healthyRelays = availableRelays
        .where((url) => _relayHealth[url]?.isHealthy ?? true)
        .toList();

    if (healthyRelays.isEmpty) {
      logger.log('No healthy relays available, falling back to all relays');
      return availableRelays.isNotEmpty ? availableRelays.first : null;
    }

    // Select relay with least active connections (load balancing)
    healthyRelays.sort((a, b) {
      final aConnections = getActiveConnections(a);
      final bConnections = getActiveConnections(b);
      return aConnections.compareTo(bConnections);
    });

    return healthyRelays.first;
  }

  /// Get all healthy relays sorted by load.
  List<String> getHealthyRelays(List<String> availableRelays) {
    final healthyRelays = availableRelays
        .where((url) => _relayHealth[url]?.isHealthy ?? true)
        .toList();

    healthyRelays.sort((a, b) {
      final aConnections = getActiveConnections(a);
      final bConnections = getActiveConnections(b);
      return aConnections.compareTo(bConnections);
    });

    return healthyRelays;
  }

  /// Reset health status for a relay (useful for manual recovery).
  void resetRelayHealth(String relayUrl) {
    _failureCount[relayUrl] = 0;
    final health = _relayHealth[relayUrl];
    if (health != null) {
      _relayHealth[relayUrl] = health.copyWith(
        isHealthy: true,
        lastCheckedAt: DateTime.now(),
      );
    }
  }

  /// Reset all relay health statuses.
  void resetAllRelayHealth() {
    for (final url in _relayHealth.keys) {
      resetRelayHealth(url);
    }
  }

  /// Remove a relay from the pool.
  void removeRelay(String relayUrl) {
    _relayHealth.remove(relayUrl);
    _activeConnections.remove(relayUrl);
    _failureCount.remove(relayUrl);
    logger.log('Relay $relayUrl removed from pool');
  }

  /// Add a relay to the pool.
  void addRelay(String relayUrl) {
    _relayHealth[relayUrl] = RelayHealthStatus(
      url: relayUrl,
      isHealthy: true,
      lastCheckedAt: DateTime.now(),
    );
    _activeConnections[relayUrl] = 0;
    _failureCount[relayUrl] = 0;
    logger.log('Relay $relayUrl added to pool');
  }

  /// Get relay statistics.
  RelayPoolStatistics getStatistics() {
    final totalRelays = _relayHealth.length;
    final healthyRelays =
        _relayHealth.values.where((h) => h.isHealthy).length;
    final totalConnections =
        _activeConnections.values.fold<int>(0, (sum, count) => sum + count);

    return RelayPoolStatistics(
      totalRelays: totalRelays,
      healthyRelays: healthyRelays,
      unhealthyRelays: totalRelays - healthyRelays,
      totalActiveConnections: totalConnections,
      averageConnectionsPerRelay: totalRelays > 0
          ? totalConnections / totalRelays
          : 0,
    );
  }
}

/// Represents the health status of a relay.
class RelayHealthStatus {
  final String url;
  final bool isHealthy;
  final DateTime lastCheckedAt;

  RelayHealthStatus({
    required this.url,
    required this.isHealthy,
    required this.lastCheckedAt,
  });

  RelayHealthStatus copyWith({
    String? url,
    bool? isHealthy,
    DateTime? lastCheckedAt,
  }) {
    return RelayHealthStatus(
      url: url ?? this.url,
      isHealthy: isHealthy ?? this.isHealthy,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

/// Statistics for the relay pool.
class RelayPoolStatistics {
  final int totalRelays;
  final int healthyRelays;
  final int unhealthyRelays;
  final int totalActiveConnections;
  final double averageConnectionsPerRelay;

  RelayPoolStatistics({
    required this.totalRelays,
    required this.healthyRelays,
    required this.unhealthyRelays,
    required this.totalActiveConnections,
    required this.averageConnectionsPerRelay,
  });

  @override
  String toString() {
    return 'RelayPoolStatistics('
        'total: $totalRelays, '
        'healthy: $healthyRelays, '
        'unhealthy: $unhealthyRelays, '
        'activeConnections: $totalActiveConnections, '
        'avgPerRelay: ${averageConnectionsPerRelay.toStringAsFixed(2)})';
  }
}
