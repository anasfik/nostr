import 'package:dart_nostr/nostr/model/nostr_events_stream.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';

/// {@template nostr_extensions}
/// Convenience extensions for NostrRequest and NostrEventsStream.
/// {@endtemplate}
extension NostrRequestExtensions on NostrRequest {
  /// Create a copy with a specific limit.
  NostrRequest withLimit(int limit) {
    return NostrRequest(
      filters: filters
          .map((f) => f.copyWith(limit: limit))
          .toList(),
    );
  }

  /// Create a copy with additional filter.
  NostrRequest withAdditionalFilter(NostrFilter filter) {
    return NostrRequest(
      filters: [...filters, filter],
    );
  }

  /// Create a copy that limits to recent events (last N seconds).
  NostrRequest recentOnly(Duration duration) {
    final since = DateTime.now().subtract(duration);
    return NostrRequest(
      filters: filters
          .map((f) => f.copyWith(since: since))
          .toList(),
    );
  }
}

/// {@template nostr_events_stream_extensions}
/// Convenience extensions for NostrEventsStream.
/// {@endtemplate}
extension NostrEventsStreamExtensions on NostrEventsStream {
  /// Check if stream is still active by verifying subscription ID exists.
  bool get isActive => subscriptionId.isNotEmpty;

  /// Close the stream and cancel subscription.
  void cancelSubscription() {
    close();
  }
}
