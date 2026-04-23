import 'dart:math';

/// {@template nostr_retry_policy}
/// Policy for retrying failed operations with configurable backoff strategies.
/// {@endtemplate}
class NostrRetryPolicy {
  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Initial delay before first retry in milliseconds.
  final int initialDelayMs;

  /// Maximum delay between retries in milliseconds.
  final int maxDelayMs;

  /// Backoff multiplier for exponential backoff.
  final double backoffMultiplier;

  /// {@macro nostr_retry_policy}
  const NostrRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelayMs = 100,
    this.maxDelayMs = 5000,
    this.backoffMultiplier = 2.0,
  });

  /// Linear backoff policy (constant delay).
  factory NostrRetryPolicy.linear({
    int maxAttempts = 3,
    int delayMs = 1000,
  }) {
    return NostrRetryPolicy(
      maxAttempts: maxAttempts,
      initialDelayMs: delayMs,
      maxDelayMs: delayMs,
      backoffMultiplier: 1,
    );
  }

  /// Exponential backoff policy (doubling delay).
  factory NostrRetryPolicy.exponential({
    int maxAttempts = 3,
    int initialDelayMs = 100,
    int maxDelayMs = 5000,
  }) {
    return NostrRetryPolicy(
      maxAttempts: maxAttempts,
      initialDelayMs: initialDelayMs,
      maxDelayMs: maxDelayMs,
      backoffMultiplier: 2,
    );
  }

  /// No retry policy (single attempt).
  factory NostrRetryPolicy.none() {
    return const NostrRetryPolicy(maxAttempts: 1);
  }

  /// Get the delay for retry attempt.
  Duration getDelayForAttempt(int attemptNumber) {
    // Calculate delay using backoff multiplier
    final exponent = (attemptNumber - 1).clamp(0, 10);
    final multiplier = pow(backoffMultiplier, exponent);
    final delayMs =
        (initialDelayMs * multiplier).round().clamp(initialDelayMs, maxDelayMs);
    return Duration(milliseconds: delayMs);
  }

  /// Check if should retry based on attempt number.
  bool shouldRetry(int attemptNumber) => attemptNumber < maxAttempts;
}
