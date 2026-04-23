import 'dart:async';
import 'dart:math';

import 'package:dart_nostr/nostr/core/utils.dart';

/// {@template error_recovery_manager}
/// Manages error recovery strategies, fallbacks, and retry logic for relay operations.
/// {@endtemplate}
class ErrorRecoveryManager {
  /// {@macro error_recovery_manager}
  ErrorRecoveryManager({
    required this.logger,
  });

  final NostrLogger logger;

  /// Tracks error history for analysis.
  final List<ErrorEvent> _errorHistory = [];

  /// Maximum error history size.
  static const int maxErrorHistorySize = 1000;

  /// Strategy for handling temporary failures.
  late ErrorRecoveryStrategy _strategy =
      ErrorRecoveryStrategy.exponentialBackoff();

  /// Get the current recovery strategy.
  ErrorRecoveryStrategy get recoveryStrategy => _strategy;

  /// Set a custom recovery strategy.
  void setRecoveryStrategy(ErrorRecoveryStrategy strategy) {
    _strategy = strategy;
    logger.log('Recovery strategy changed to: ${strategy.name}');
  }

  /// Handle a relay connection error with recovery attempt.
  Future<bool> handleConnectionError({
    required String relayUrl,
    required dynamic error,
    required int attemptNumber,
    required Future<bool> Function() retryFn,
  }) async {
    _recordError(
      relayUrl: relayUrl,
      errorType: ErrorType.connectionError,
      error: error,
      attemptNumber: attemptNumber,
    );

    logger.log(
      'Connection error on relay $relayUrl (attempt $attemptNumber): $error',
    );

    if (attemptNumber > _strategy.maxRetries) {
      logger.log(
        'Max retries exceeded for relay $relayUrl, giving up',
      );
      return false;
    }

    final delay = _strategy.getDelayForAttempt(attemptNumber);
    logger.log(
      'Retrying relay $relayUrl in ${delay.inMilliseconds}ms (attempt ${attemptNumber + 1})',
    );

    await Future<void>.delayed(delay);

    try {
      return await retryFn();
    } catch (e) {
      return handleConnectionError(
        relayUrl: relayUrl,
        error: e,
        attemptNumber: attemptNumber + 1,
        retryFn: retryFn,
      );
    }
  }

  /// Handle an operation timeout error.
  Future<bool> handleTimeoutError({
    required String relayUrl,
    required int attemptNumber,
    required Future<bool> Function() retryFn,
  }) async {
    _recordError(
      relayUrl: relayUrl,
      errorType: ErrorType.timeoutError,
      attemptNumber: attemptNumber,
    );

    logger.log(
      'Timeout on relay $relayUrl (attempt $attemptNumber)',
    );

    if (attemptNumber > _strategy.maxRetries) {
      logger.log('Max retries exceeded for timeout on relay $relayUrl');
      return false;
    }

    final delay = _strategy.getDelayForAttempt(attemptNumber);
    logger.log(
      'Retrying relay $relayUrl after timeout in ${delay.inMilliseconds}ms',
    );

    await Future<void>.delayed(delay);

    try {
      return await retryFn();
    } catch (e) {
      return handleTimeoutError(
        relayUrl: relayUrl,
        attemptNumber: attemptNumber + 1,
        retryFn: retryFn,
      );
    }
  }

  /// Implement circuit breaker pattern for a relay.
  CircuitBreakerState getCircuitBreakerState(String relayUrl) {
    final recentErrors = _errorHistory
        .where((e) =>
            e.relayUrl == relayUrl &&
            DateTime.now().difference(e.timestamp).inMinutes < 5)
        .length;

    if (recentErrors > 10) {
      return CircuitBreakerState.open;
    } else if (recentErrors > 5) {
      return CircuitBreakerState.halfOpen;
    } else {
      return CircuitBreakerState.closed;
    }
  }

  /// Get fallback relay (healthy alternative relay).
  String? getFallbackRelay({
    required String primaryRelayUrl,
    required List<String> availableRelays,
  }) {
    final healthyRelays = availableRelays
        .where((url) =>
            url != primaryRelayUrl &&
            getCircuitBreakerState(url) != CircuitBreakerState.open)
        .toList();

    if (healthyRelays.isEmpty) {
      logger.log('No healthy fallback relay found for $primaryRelayUrl');
      return null;
    }

    // Sort by error count (prefer relays with fewer recent errors)
    healthyRelays.sort((a, b) {
      final aErrors = _errorHistory
          .where((e) =>
              e.relayUrl == a &&
              DateTime.now().difference(e.timestamp).inMinutes < 5)
          .length;
      final bErrors = _errorHistory
          .where((e) =>
              e.relayUrl == b &&
              DateTime.now().difference(e.timestamp).inMinutes < 5)
          .length;
      return aErrors.compareTo(bErrors);
    });

    logger.log(
        'Fallback relay selected: ${healthyRelays.first} for $primaryRelayUrl');
    return healthyRelays.first;
  }

  /// Get error summary for diagnostics.
  ErrorSummary getErrorSummary({required String relayUrl}) {
    final relayErrors =
        _errorHistory.where((e) => e.relayUrl == relayUrl).toList();

    if (relayErrors.isEmpty) {
      return ErrorSummary(
        relayUrl: relayUrl,
        totalErrors: 0,
        errorsByType: {},
        recentErrors: [],
      );
    }

    final errorsByType = <ErrorType, int>{};
    for (final error in relayErrors) {
      errorsByType[error.errorType] = (errorsByType[error.errorType] ?? 0) + 1;
    }

    final recentErrors = relayErrors
        .where((e) => DateTime.now().difference(e.timestamp).inMinutes < 5)
        .toList();

    return ErrorSummary(
      relayUrl: relayUrl,
      totalErrors: relayErrors.length,
      errorsByType: Map.unmodifiable(errorsByType),
      recentErrors: recentErrors,
    );
  }

  /// Record an error event.
  void _recordError({
    required String relayUrl,
    required ErrorType errorType,
    required int attemptNumber,
    dynamic error,
  }) {
    _errorHistory.add(
      ErrorEvent(
        relayUrl: relayUrl,
        errorType: errorType,
        errorMessage: error?.toString(),
        attemptNumber: attemptNumber,
        timestamp: DateTime.now(),
      ),
    );

    // Keep error history size manageable
    if (_errorHistory.length > maxErrorHistorySize) {
      _errorHistory.removeAt(0);
    }
  }

  /// Clear error history.
  void clearErrorHistory() {
    _errorHistory.clear();
    logger.log('Error history cleared');
  }

  /// Dispose resources.
  void dispose() {
    _errorHistory.clear();
  }
}

/// Enum for error types.
enum ErrorType {
  connectionError,
  timeoutError,
  networkError,
  parseError,
  unknownError,
}

/// Error recovery strategy.
class ErrorRecoveryStrategy {
  final String name;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  ErrorRecoveryStrategy({
    required this.name,
    required this.maxRetries,
    required this.initialDelay,
    required this.maxDelay,
    required this.backoffMultiplier,
  });

  /// Exponential backoff strategy (recommended).
  factory ErrorRecoveryStrategy.exponentialBackoff({
    int maxRetries = 5,
    Duration initialDelay = const Duration(milliseconds: 100),
    Duration maxDelay = const Duration(seconds: 30),
  }) {
    return ErrorRecoveryStrategy(
      name: 'ExponentialBackoff',
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      maxDelay: maxDelay,
      backoffMultiplier: 2.0,
    );
  }

  /// Linear backoff strategy.
  factory ErrorRecoveryStrategy.linearBackoff({
    int maxRetries = 5,
    Duration delay = const Duration(seconds: 1),
  }) {
    return ErrorRecoveryStrategy(
      name: 'LinearBackoff',
      maxRetries: maxRetries,
      initialDelay: delay,
      maxDelay: delay,
      backoffMultiplier: 1.0,
    );
  }

  /// Immediate retry strategy.
  factory ErrorRecoveryStrategy.immediate({
    int maxRetries = 3,
  }) {
    return ErrorRecoveryStrategy(
      name: 'Immediate',
      maxRetries: maxRetries,
      initialDelay: Duration.zero,
      maxDelay: Duration.zero,
      backoffMultiplier: 1.0,
    );
  }

  /// Get delay for a specific attempt.
  Duration getDelayForAttempt(int attemptNumber) {
    // Calculate exponential backoff: initialDelay * (backoffMultiplier ^ attemptNumber)
    double delayMs = initialDelay.inMilliseconds *
        (pow(backoffMultiplier, attemptNumber.clamp(1, 10)) as double);

    // Clamp to max delay
    delayMs = delayMs.clamp(
      initialDelay.inMilliseconds.toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: delayMs.toInt());
  }
}

/// Circuit breaker states.
enum CircuitBreakerState {
  closed, // Normal operation
  open, // Reject requests
  halfOpen, // Allow limited requests to test recovery
}

/// Error event for tracking.
class ErrorEvent {
  final String relayUrl;
  final ErrorType errorType;
  final String? errorMessage;
  final int attemptNumber;
  final DateTime timestamp;

  ErrorEvent({
    required this.relayUrl,
    required this.errorType,
    required this.attemptNumber,
    required this.timestamp,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'ErrorEvent(relay: $relayUrl, type: $errorType, msg: $errorMessage, attempt: $attemptNumber)';
  }
}

/// Error summary for a relay.
class ErrorSummary {
  final String relayUrl;
  final int totalErrors;
  final Map<ErrorType, int> errorsByType;
  final List<ErrorEvent> recentErrors;

  ErrorSummary({
    required this.relayUrl,
    required this.totalErrors,
    required this.errorsByType,
    required this.recentErrors,
  });

  @override
  String toString() {
    return 'ErrorSummary('
        'relay: $relayUrl, '
        'total: $totalErrors, '
        'recent: ${recentErrors.length}, '
        'types: $errorsByType)';
  }
}
