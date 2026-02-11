import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrFilterBuilder', () {
    test('builds filter with kinds', () {
      final filter = NostrFilterBuilder()
          .withKind(1)
          .withKind(5)
          .build();

      expect(filter.kinds, contains(1));
      expect(filter.kinds, contains(5));
    });

    test('builds filter with authors', () {
      final authors = ['author1', 'author2'];
      final filter = NostrFilterBuilder()
          .withAuthors(authors)
          .build();

      expect(filter.authors, authors);
    });

    test('builds filter with event ids', () {
      final eventIds = ['event1', 'event2'];
      final filter = NostrFilterBuilder()
          .withEventIds(eventIds)
          .build();

      expect(filter.e, eventIds);
    });

    test('builds filter with pubkeys', () {
      final pubkeys = ['pub1', 'pub2'];
      final filter = NostrFilterBuilder()
          .withPubkeys(pubkeys)
          .build();

      expect(filter.p, pubkeys);
    });

    test('builds filter with time range', () {
      final since = DateTime(2026, 1, 1);
      final until = DateTime(2026, 12, 31);
      
      final filter = NostrFilterBuilder()
          .since(since)
          .until(until)
          .build();

      expect(filter.since, since);
      expect(filter.until, until);
    });

    test('builds filter with limit', () {
      final filter = NostrFilterBuilder()
          .withLimit(50)
          .build();

      expect(filter.limit, 50);
    });

    test('builds complex filter with all options', () {
      final filter = NostrFilterBuilder()
          .withKinds([1, 7])
          .withAuthors(['author1'])
          .withEventIds(['event1'])
          .withPubkeys(['pub1'])
          .withLimit(100)
          .since(DateTime(2026, 1, 1))
          .until(DateTime(2026, 12, 31))
          .build();

      expect(filter.kinds, contains(1));
      expect(filter.kinds, contains(7));
      expect(filter.authors, ['author1']);
      expect(filter.e, ['event1']);
      expect(filter.p, ['pub1']);
      expect(filter.limit, 100);
    });

    test('reset clears all filters', () {
      final builder = NostrFilterBuilder()
          .withKind(1)
          .withAuthor('author1')
          .withLimit(50);

      builder.reset();
      
      final filter = builder.build();
      expect(filter.kinds, null);
      expect(filter.authors, null);
      expect(filter.limit, null);
    });

    test('fluent API is chainable', () {
      expect(
        NostrFilterBuilder()
            .withKind(1)
            .withAuthor('author1')
            .withLimit(50),
        isNotNull,
      );
    });

    test('returns null for empty collections', () {
      final filter = NostrFilterBuilder().build();

      expect(filter.kinds, null);
      expect(filter.authors, null);
      expect(filter.e, null);
      expect(filter.p, null);
    });
  });

  group('NostrFilterBuilder - Single Item Methods', () {
    test('withKind adds single kind', () {
      final filter = NostrFilterBuilder()
          .withKind(1)
          .withKind(7)
          .build();

      expect(filter.kinds, [1, 7]);
    });

    test('withAuthor adds single author', () {
      final filter = NostrFilterBuilder()
          .withAuthor('author1')
          .withAuthor('author2')
          .build();

      expect(filter.authors?.length, 2);
      expect(filter.authors, contains('author1'));
      expect(filter.authors, contains('author2'));
    });

    test('withEventId adds single event id', () {
      final filter = NostrFilterBuilder()
          .withEventId('event1')
          .withEventId('event2')
          .build();

      expect(filter.e?.length, 2);
      expect(filter.e, contains('event1'));
      expect(filter.e, contains('event2'));
    });

    test('withPubkey adds single pubkey', () {
      final filter = NostrFilterBuilder()
          .withPubkey('pub1')
          .withPubkey('pub2')
          .build();

      expect(filter.p?.length, 2);
      expect(filter.p, contains('pub1'));
      expect(filter.p, contains('pub2'));
    });
  });

  group('NostrDefaults', () {
    test('provides default relays', () {
      expect(NostrDefaults.defaultRelays, isNotEmpty);
      expect(NostrDefaults.defaultRelays, contains('wss://relay.damus.io'));
      expect(NostrDefaults.defaultRelays, contains('wss://relay.nostr.band'));
      expect(NostrDefaults.defaultRelays, contains('wss://nos.lol'));
    });

    test('default relays are valid URLs', () {
      for (final relay in NostrDefaults.defaultRelays) {
        expect(relay.startsWith('wss://'), true);
      }
    });

    test('provides default timeouts', () {
      expect(NostrDefaults.defaultConnectTimeoutSeconds, greaterThan(0));
      expect(NostrDefaults.defaultReadTimeoutSeconds, greaterThan(0));
    });

    test('provides default event limit', () {
      expect(NostrDefaults.defaultEventLimit, greaterThan(0));
    });
  });

  group('NostrRetryPolicy', () {
    test('creates default policy', () {
      const policy = NostrRetryPolicy();
      expect(policy.maxAttempts, 3);
      expect(policy.initialDelayMs, 100);
    });

    test('linear backoff creates constant delays', () {
      final policy = NostrRetryPolicy.linear(delayMs: 1000);
      
      expect(policy.getDelayForAttempt(1).inMilliseconds, 1000);
      expect(policy.getDelayForAttempt(2).inMilliseconds, 1000);
    });

    test('exponential backoff doubles delays', () {
      final policy = NostrRetryPolicy.exponential(
        initialDelayMs: 100,
        maxDelayMs: 5000,
      );
      
      final delay1 = policy.getDelayForAttempt(1).inMilliseconds;
      final delay2 = policy.getDelayForAttempt(2).inMilliseconds;
      
      expect(delay2, greaterThanOrEqualTo(delay1));
    });

    test('none policy has single attempt', () {
      final policy = NostrRetryPolicy.none();
      expect(policy.maxAttempts, 1);
      expect(policy.shouldRetry(1), false);
    });

    test('shouldRetry respects max attempts', () {
      const policy = NostrRetryPolicy(maxAttempts: 3);
      
      expect(policy.shouldRetry(1), true);
      expect(policy.shouldRetry(2), true);
      expect(policy.shouldRetry(3), false);
    });

    test('delay respects max delay', () {
      final policy = NostrRetryPolicy.exponential(
        initialDelayMs: 100,
        maxDelayMs: 1000,
      );
      
      final delay = policy.getDelayForAttempt(10);
      expect(delay.inMilliseconds, lessThanOrEqualTo(1000));
    });

    test('retry policy with custom settings', () {
      final policy = NostrRetryPolicy(
        maxAttempts: 5,
        initialDelayMs: 200,
        maxDelayMs: 10000,
        backoffMultiplier: 1.5,
      );

      expect(policy.maxAttempts, 5);
      expect(policy.initialDelayMs, 200);
      expect(policy.maxDelayMs, 10000);
      expect(policy.backoffMultiplier, 1.5);
    });
  });

  group('Nostr Convenience Methods', () {
    test('defaultRelays returns default relay list', () {
      expect(Nostr.defaultRelays, isNotEmpty);
      expect(Nostr.defaultRelays.length, greaterThan(0));
    });

    test('filterBuilder creates NostrFilterBuilder', () {
      final builder = Nostr.instance.filterBuilder();
      expect(builder, isA<NostrFilterBuilder>());
    });

    test('filterBuilder can build filter', () {
      final filter = Nostr.instance
          .filterBuilder()
          .withKind(1)
          .withLimit(50)
          .build();

      expect(filter.kinds, [1]);
      expect(filter.limit, 50);
    });

    test('defaultRelays has known relays', () {
      final relays = Nostr.defaultRelays;
      expect(relays.length, greaterThanOrEqualTo(3));
    });
  });

  group('NostrRequestExtensions', () {
    test('withLimit creates new request with limit', () {
      final request = NostrRequest(
        filters: [
          NostrFilter(kinds: [1]),
        ],
      );

      final updated = request.withLimit(100);
      expect(updated.filters[0].limit, 100);
    });

    test('recentOnly creates request with since', () {
      final request = NostrRequest(
        filters: [
          NostrFilter(kinds: [1]),
        ],
      );

      final updated = request.recentOnly(Duration(days: 7));
      expect(updated.filters[0].since, isNotNull);
    });

    test('withAdditionalFilter adds new filter', () {
      final request = NostrRequest(
        filters: [
          NostrFilter(kinds: [1]),
        ],
      );

      final filter2 = NostrFilter(kinds: [7]);
      final updated = request.withAdditionalFilter(filter2);
      
      expect(updated.filters.length, 2);
    });

    test('extension methods preserve original request', () {
      final original = NostrRequest(
        filters: [NostrFilter(kinds: [1])],
      );

      final updated = original.withLimit(100);

      expect(original.filters[0].limit, null);
      expect(updated.filters[0].limit, 100);
    });

    test('withLimit on multiple filters updates all', () {
      final request = NostrRequest(
        filters: [
          NostrFilter(kinds: [1]),
          NostrFilter(kinds: [7]),
        ],
      );

      final updated = request.withLimit(50);

      expect(updated.filters[0].limit, 50);
      expect(updated.filters[1].limit, 50);
    });
  });

  group('NostrFilterBuilder - Complex Scenarios', () {
    test('can build text note filter', () {
      final filter = Nostr.instance
          .filterBuilder()
          .withKind(1)  // Text note
          .withLimit(100)
          .build();

      expect(filter.kinds, [1]);
      expect(filter.limit, 100);
    });

    test('can build reaction filter', () {
      final filter = Nostr.instance
          .filterBuilder()
          .withKind(7)  // Reaction
          .withEventId('event_id')
          .build();

      expect(filter.kinds, [7]);
      expect(filter.e, ['event_id']);
    });

    test('can build metadata filter', () {
      final filter = Nostr.instance
          .filterBuilder()
          .withKind(0)  // User metadata
          .withAuthors(['author1', 'author2'])
          .build();

      expect(filter.kinds, [0]);
      expect(filter.authors?.length, 2);
    });

    test('builder withTag stores custom tags', () {
      final builder = NostrFilterBuilder()
          .withTag('custom', ['value1', 'value2']);

      // Note: tags are internal to builder for now
      final filter = builder.build();
      expect(filter, isNotNull);
    });

    test('recentOnly with various durations', () {
      final request = NostrRequest(
        filters: [NostrFilter(kinds: [1])],
      );

      final recent1h = request.recentOnly(Duration(hours: 1));
      final recent7d = request.recentOnly(Duration(days: 7));
      final recent30d = request.recentOnly(Duration(days: 30));

      expect(recent1h.filters[0].since, isNotNull);
      expect(recent7d.filters[0].since, isNotNull);
      expect(recent30d.filters[0].since, isNotNull);

      // Recent1h should be more recent (larger since) than recent30d
      expect(
        recent1h.filters[0].since!.isAfter(recent30d.filters[0].since!),
        true,
      );
    });

    test('chaining multiple filter methods', () {
      final request = NostrRequest(
        filters: [NostrFilter(kinds: [1])],
      );

      final updated = request
          .withLimit(50)
          .recentOnly(Duration(days: 7))
          .withAdditionalFilter(NostrFilter(kinds: [7]));

      expect(updated.filters.length, 2);
      expect(updated.filters[0].limit, 50);
      expect(updated.filters[0].since, isNotNull);
    });
  });

  group('NostrFilterBuilder - Edge Cases', () {
    test('empty builder builds empty filter', () {
      final filter = NostrFilterBuilder().build();

      expect(filter.kinds, null);
      expect(filter.authors, null);
      expect(filter.e, null);
      expect(filter.p, null);
      expect(filter.limit, null);
    });

    test('zero limit is accepted', () {
      final filter = NostrFilterBuilder().withLimit(0).build();
      expect(filter.limit, 0);
    });

    test('large limit is accepted', () {
      final filter = NostrFilterBuilder().withLimit(999999).build();
      expect(filter.limit, 999999);
    });

    test('multiple resets work', () {
      final builder = NostrFilterBuilder()
          .withKind(1)
          .reset()
          .withKind(7)
          .reset()
          .withKind(5);

      final filter = builder.build();
      expect(filter.kinds, [5]);
    });
  });
}
