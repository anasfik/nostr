import 'dart:async';

import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';

/// {@template subscription_manager}
/// Manages the lifecycle of event subscriptions with automatic cleanup and tracking.
/// {@endtemplate}
class SubscriptionManager {
  /// {@macro subscription_manager}
  SubscriptionManager({
    required this.logger,
  });

  final NostrLogger logger;

  /// Tracks active subscriptions.
  final Map<String, SubscriptionMetadata> _activeSubscriptions = {};

  /// Timers for subscription auto-cleanup.
  final Map<String, Timer> _cleanupTimers = {};

  /// Get all active subscriptions.
  Map<String, SubscriptionMetadata> getActiveSubscriptions() =>
      Map.unmodifiable(_activeSubscriptions);

  /// Get a specific subscription by ID.
  SubscriptionMetadata? getSubscription(String subscriptionId) =>
      _activeSubscriptions[subscriptionId];

  /// Register a new subscription.
  void registerSubscription({
    required String subscriptionId,
    required List<NostrFilter> filters,
    required List<String> relays,
    Duration? autoCloseAfter,
  }) {
    final metadata = SubscriptionMetadata(
      subscriptionId: subscriptionId,
      filters: filters,
      relays: relays,
      createdAt: DateTime.now(),
      eventCount: 0,
      lastEventAt: null,
    );

    _activeSubscriptions[subscriptionId] = metadata;

    logger.log(
      'Subscription registered: $subscriptionId on ${relays.length} relays',
    );

    // Auto-cleanup if specified
    if (autoCloseAfter != null) {
      _setAutoCleanupTimer(subscriptionId, autoCloseAfter);
    }
  }

  /// Update subscription metadata (e.g., event count).
  void updateSubscription(String subscriptionId, {int? eventCount}) {
    final metadata = _activeSubscriptions[subscriptionId];
    if (metadata != null) {
      _activeSubscriptions[subscriptionId] = metadata.copyWith(
        eventCount: eventCount ?? metadata.eventCount,
        lastEventAt: DateTime.now(),
      );
    }
  }

  /// Close a subscription and perform cleanup.
  void closeSubscription(String subscriptionId) {
    _activeSubscriptions.remove(subscriptionId);
    _cleanupTimers[subscriptionId]?.cancel();
    _cleanupTimers.remove(subscriptionId);

    logger.log('Subscription closed: $subscriptionId');
  }

  /// Close all subscriptions.
  void closeAllSubscriptions() {
    for (final subscriptionId in _activeSubscriptions.keys.toList()) {
      closeSubscription(subscriptionId);
    }
    logger.log('All subscriptions closed');
  }

  /// Get active subscription count.
  int getActiveSubscriptionCount() => _activeSubscriptions.length;

  /// Check if a subscription is active.
  bool isSubscriptionActive(String subscriptionId) =>
      _activeSubscriptions.containsKey(subscriptionId);

  /// Get subscriptions for a specific relay.
  List<SubscriptionMetadata> getSubscriptionsForRelay(String relayUrl) {
    return _activeSubscriptions.values
        .where((sub) => sub.relays.contains(relayUrl))
        .toList();
  }

  /// Extend the auto-close timer for a subscription.
  void extendAutoCloseTimer(String subscriptionId, Duration duration) {
    _cleanupTimers[subscriptionId]?.cancel();
    _setAutoCleanupTimer(subscriptionId, duration);
    logger.log('Auto-close timer extended for subscription: $subscriptionId');
  }

  /// Set auto-cleanup timer for a subscription.
  void _setAutoCleanupTimer(String subscriptionId, Duration duration) {
    _cleanupTimers[subscriptionId]?.cancel();
    _cleanupTimers[subscriptionId] = Timer(duration, () {
      logger.log(
        'Auto-closing subscription: $subscriptionId (timeout after ${duration.inSeconds}s)',
      );
      closeSubscription(subscriptionId);
    });
  }

  /// Get subscription statistics.
  SubscriptionStatistics getStatistics() {
    final subscriptions = _activeSubscriptions.values.toList();

    if (subscriptions.isEmpty) {
      return SubscriptionStatistics(
        totalSubscriptions: 0,
        totalEventCount: 0,
        averageEventsPerSubscription: 0,
        oldestSubscriptionAgeSeconds: 0,
        newestSubscriptionAgeSeconds: 0,
      );
    }

    final now = DateTime.now();
    final totalEvents =
        subscriptions.fold<int>(0, (sum, sub) => sum + sub.eventCount);
    final ages = subscriptions
        .map((sub) => now.difference(sub.createdAt).inSeconds)
        .toList();

    return SubscriptionStatistics(
      totalSubscriptions: subscriptions.length,
      totalEventCount: totalEvents,
      averageEventsPerSubscription: totalEvents / subscriptions.length,
      oldestSubscriptionAgeSeconds: ages.reduce((a, b) => a > b ? a : b),
      newestSubscriptionAgeSeconds: ages.reduce((a, b) => a < b ? a : b),
    );
  }

  /// Clean up the manager resources.
  void dispose() {
    closeAllSubscriptions();
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
  }
}

/// Metadata for a subscription.
class SubscriptionMetadata {
  final String subscriptionId;
  final List<NostrFilter> filters;
  final List<String> relays;
  final DateTime createdAt;
  final int eventCount;
  final DateTime? lastEventAt;

  SubscriptionMetadata({
    required this.subscriptionId,
    required this.filters,
    required this.relays,
    required this.createdAt,
    required this.eventCount,
    required this.lastEventAt,
  });

  /// Calculate subscription age in seconds.
  int getAgeInSeconds() => DateTime.now().difference(createdAt).inSeconds;

  SubscriptionMetadata copyWith({
    String? subscriptionId,
    List<NostrFilter>? filters,
    List<String>? relays,
    DateTime? createdAt,
    int? eventCount,
    DateTime? lastEventAt,
  }) {
    return SubscriptionMetadata(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      filters: filters ?? this.filters,
      relays: relays ?? this.relays,
      createdAt: createdAt ?? this.createdAt,
      eventCount: eventCount ?? this.eventCount,
      lastEventAt: lastEventAt ?? this.lastEventAt,
    );
  }

  @override
  String toString() {
    return 'SubscriptionMetadata('
        'id: $subscriptionId, '
        'relays: ${relays.length}, '
        'filters: ${filters.length}, '
        'events: $eventCount, '
        'age: ${getAgeInSeconds()}s)';
  }
}

/// Statistics for subscriptions.
class SubscriptionStatistics {
  final int totalSubscriptions;
  final int totalEventCount;
  final double averageEventsPerSubscription;
  final int oldestSubscriptionAgeSeconds;
  final int newestSubscriptionAgeSeconds;

  SubscriptionStatistics({
    required this.totalSubscriptions,
    required this.totalEventCount,
    required this.averageEventsPerSubscription,
    required this.oldestSubscriptionAgeSeconds,
    required this.newestSubscriptionAgeSeconds,
  });

  @override
  String toString() {
    return 'SubscriptionStatistics('
        'total: $totalSubscriptions, '
        'totalEvents: $totalEventCount, '
        'avgEvents: ${averageEventsPerSubscription.toStringAsFixed(2)}, '
        'oldest: ${oldestSubscriptionAgeSeconds}s, '
        'newest: ${newestSubscriptionAgeSeconds}s)';
  }
}
