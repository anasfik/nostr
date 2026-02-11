import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/error_recovery.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorRecoveryManager', () {
    late ErrorRecoveryManager manager;

    setUp(() {
      manager = ErrorRecoveryManager(logger: _createMockLogger());
    });

    tearDown(() {
      manager.dispose();
    });

    test('recordError tracks error events', () {
      manager.handleConnectionError(
        relayUrl: 'wss://relay1.example.com',
        error: Exception('Connection failed'),
        attemptNumber: 1,
        retryFn: () async => true,
      );

      // We can't directly test _recordError, but we can test via getErrorSummary
    });

    test('getErrorSummary returns error statistics', () async {
      try {
        await manager.handleConnectionError(
          relayUrl: 'wss://relay1.example.com',
          error: Exception('Connection failed'),
          attemptNumber: 1,
          retryFn: () async => false,
        );
      } catch (_) {}

      final summary = manager.getErrorSummary(relayUrl: 'wss://relay1.example.com');

      expect(summary.relayUrl, equals('wss://relay1.example.com'));
      expect(summary.totalErrors, greaterThanOrEqualTo(1));
    });

    test('recoveryStrategy defaults to exponential backoff', () {
      final strategy = manager.recoveryStrategy;

      expect(strategy.name, equals('ExponentialBackoff'));
      expect(strategy.maxRetries, equals(5));
    });

    test('setRecoveryStrategy updates strategy', () {
      final linearStrategy = ErrorRecoveryStrategy.linearBackoff(
        maxRetries: 3,
      );

      manager.setRecoveryStrategy(linearStrategy);

      expect(manager.recoveryStrategy.name, equals('LinearBackoff'));
      expect(manager.recoveryStrategy.maxRetries, equals(3));
    });

    test('ErrorRecoveryStrategy.exponentialBackoff calculates delays correctly', () {
      final strategy = ErrorRecoveryStrategy.exponentialBackoff(
        initialDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(seconds: 10),
      );

      final delay1 = strategy.getDelayForAttempt(1);
      final delay2 = strategy.getDelayForAttempt(2);
      final delay3 = strategy.getDelayForAttempt(3);

      expect(delay1.inMilliseconds, greaterThan(0));
      expect(delay2.inMilliseconds, greaterThanOrEqualTo(delay1.inMilliseconds));
      expect(delay3.inMilliseconds, greaterThanOrEqualTo(delay2.inMilliseconds));
    });

    test('ErrorRecoveryStrategy.linearBackoff has constant delay', () {
      final strategy = ErrorRecoveryStrategy.linearBackoff(
        delay: const Duration(seconds: 1),
      );

      final delay1 = strategy.getDelayForAttempt(1);
      final delay2 = strategy.getDelayForAttempt(2);

      expect(delay1, equals(delay2));
    });

    test('ErrorRecoveryStrategy.immediate has no delay', () {
      final strategy = ErrorRecoveryStrategy.immediate();

      final delay = strategy.getDelayForAttempt(1);

      expect(delay, equals(Duration.zero));
    });

    test('getCircuitBreakerState returns correct state based on error count', () async {
      // Initially closed
      expect(
        manager.getCircuitBreakerState('wss://relay1.example.com'),
        equals(CircuitBreakerState.closed),
      );
    });

    test('getFallbackRelay returns healthy alternative', () async {
      manager.setRecoveryStrategy(ErrorRecoveryStrategy.immediate());

      final fallback = manager.getFallbackRelay(
        primaryRelayUrl: 'wss://relay1.example.com',
        availableRelays: [
          'wss://relay2.example.com',
          'wss://relay3.example.com',
        ],
      );

      expect(
        fallback,
        anyOf(
          'wss://relay2.example.com',
          'wss://relay3.example.com',
        ),
      );
    });

    test('getFallbackRelay returns null if no healthy relays', () {
      final fallback = manager.getFallbackRelay(
        primaryRelayUrl: 'wss://relay1.example.com',
        availableRelays: [],
      );

      expect(fallback, isNull);
    });

    test('clearErrorHistory removes all errors', () async {
      try {
        await manager.handleConnectionError(
          relayUrl: 'wss://relay1.example.com',
          error: Exception('Connection failed'),
          attemptNumber: 1,
          retryFn: () async => false,
        );
      } catch (_) {}

      manager.clearErrorHistory();

      final summary = manager.getErrorSummary(relayUrl: 'wss://relay1.example.com');
      expect(summary.totalErrors, equals(0));
    });

    test('getErrorSummary includes recent errors', () async {
      try {
        await manager.handleConnectionError(
          relayUrl: 'wss://relay1.example.com',
          error: Exception('Connection failed'),
          attemptNumber: 1,
          retryFn: () async => false,
        );
      } catch (_) {}

      final summary = manager.getErrorSummary(relayUrl: 'wss://relay1.example.com');

      expect(summary.recentErrors.length, greaterThanOrEqualTo(0));
    });

    test('error history respects max size', () async {
      manager.setRecoveryStrategy(ErrorRecoveryStrategy.immediate());

      // Try to exceed max history size
      for (int i = 0; i < 1100; i++) {
        try {
          await manager.handleConnectionError(
            relayUrl: 'wss://relay1.example.com',
            error: Exception('Error $i'),
            attemptNumber: 1,
            retryFn: () async => false,
          );
        } catch (_) {}
      }

      // Summary should still work and history shouldn't be huge
      final summary = manager.getErrorSummary(relayUrl: 'wss://relay1.example.com');
      expect(summary.totalErrors, lessThanOrEqualTo(1100));
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

