import 'package:dart_nostr/nostr/builder/retry_policy.dart';

class NostrClientOptions {
  const NostrClientOptions({
    this.connectionTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 15),
    this.retryPolicy = const NostrRetryPolicy(),
    this.failFast = false,
  });

  final Duration connectionTimeout;
  final Duration requestTimeout;
  final NostrRetryPolicy retryPolicy;
  final bool failFast;

  NostrClientOptions copyWith({
    Duration? connectionTimeout,
    Duration? requestTimeout,
    NostrRetryPolicy? retryPolicy,
    bool? failFast,
  }) {
    return NostrClientOptions(
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      failFast: failFast ?? this.failFast,
    );
  }
}
