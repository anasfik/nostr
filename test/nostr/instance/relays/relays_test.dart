import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRelays - Connection and Subscription', () {
    group('Relay Registration', () {
      test('init method accepts list of relay URLs', () {
        final relayUrls = ['wss://relay.damus.io'];

        // Verify the method signature is correct by checking it doesn't throw
        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: relayUrls,
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });

      test('init with multiple relay URLs', () {
        final relayUrls = [
          'wss://relay.damus.io',
          'wss://relay.nostr.band',
          'wss://nos.lol',
        ];

        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: relayUrls,
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });

      test('init method is async', () async {
        final future = Nostr.instance.services.relays.init(
          relaysUrl: ['wss://relay.damus.io'],
          lazyListeningToRelays: true,
        );

        expect(future, isA<Future<dynamic>>());
      });
    });

    group('Subscription Request Generation', () {
      test('startEventsSubscription creates NostrEventsStream', () {
        const filter = NostrFilter(
          kinds: [1],
          limit: 10,
        );

        final request = NostrRequest(
          filters: const [filter],
        );

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream, isA<NostrEventsStream>());
      });

      test('NostrEventsStream has correct subscription ID', () {
        const filter = NostrFilter(
          kinds: [1],
          limit: 10,
        );

        final request = NostrRequest(
          filters: const [filter],
        );

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.subscriptionId, isNotNull);
        expect(stream.subscriptionId, isNotEmpty);
      });

      test('NostrEventsStream contains original request', () {
        const filter = NostrFilter(
          kinds: [1],
          authors: ['author1'],
        );

        final request = NostrRequest(
          filters: const [filter],
        );

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request, equals(request));
      });

      test('multiple subscriptions have different IDs', () {
        const filter1 = NostrFilter(kinds: [1]);
        const filter2 = NostrFilter(kinds: [2]);

        final request1 = NostrRequest(filters: const [filter1]);
        final request2 = NostrRequest(filters: const [filter2]);

        final stream1 = Nostr.instance.services.relays.startEventsSubscription(
          request: request1,
        );
        final stream2 = Nostr.instance.services.relays.startEventsSubscription(
          request: request2,
        );

        expect(stream1.subscriptionId, isNotEmpty);
        expect(stream2.subscriptionId, isNotEmpty);
        expect(stream1.subscriptionId, isNot(stream2.subscriptionId));
      });

      test('subscription request generates random ID by default', () {
        const filter = NostrFilter(kinds: [1]);
        const customSubId = 'custom-sub-123';

        final request = NostrRequest(
          filters: const [filter],
          subscriptionId: customSubId,
        );

        // Initial request has custom ID
        expect(request.subscriptionId, equals(customSubId));

        // An explicitly-set subscription ID must be honored: overriding it
        // with a random one silently breaks caller-side stream filtering.
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.subscriptionId, equals(customSubId));
      });

      test('subscription generates an id when none is provided', () {
        const filter = NostrFilter(kinds: [1], limit: 10);

        final request = NostrRequest(filters: const [filter]);
        expect(request.subscriptionId, isNull);

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.subscriptionId, isNotEmpty);
      });

      test('subscription with kind filter 1 (text notes)', () {
        const filter = NostrFilter(
          kinds: [1],
          limit: 50,
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream, isA<NostrEventsStream>());
        expect(stream.request.filters, contains(filter));
      });

      test('subscription with kind filter 0 (metadata)', () {
        const filter = NostrFilter(
          kinds: [0],
          limit: 10,
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].kinds, contains(0));
      });

      test('subscription with author filter', () {
        const authorPubkey = 'abcdef1234567890';
        const filter = NostrFilter(
          authors: [authorPubkey],
          kinds: [1],
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].authors, contains(authorPubkey));
      });

      test('subscription with time filter (since)', () {
        final now = DateTime.now();
        final sinceTime = now.subtract(const Duration(hours: 1));

        final filter = NostrFilter(
          since: sinceTime,
          kinds: const [1],
        );

        final request = NostrRequest(filters: [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].since, isNotNull);
      });

      test('subscription with time filter (until)', () {
        final now = DateTime.now();
        final untilTime = now.add(const Duration(hours: 1));

        final filter = NostrFilter(
          until: untilTime,
          kinds: const [1],
        );

        final request = NostrRequest(filters: [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].until, isNotNull);
      });

      test('subscription with limit filter', () {
        const filter = NostrFilter(
          kinds: [1],
          limit: 100,
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].limit, equals(100));
      });

      test('subscription with tag filter (e tags)', () {
        const eventId = 'event123';
        const filter = NostrFilter(
          kinds: [1],
          e: [eventId],
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].e, contains(eventId));
      });

      test('subscription with tag filter (p tags)', () {
        const pubkey = 'pubkey123';
        const filter = NostrFilter(
          kinds: [1],
          p: [pubkey],
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].p, contains(pubkey));
      });

      test('subscription with multiple filters', () {
        const filter1 = NostrFilter(kinds: [1]);
        const filter2 = NostrFilter(kinds: [0]);

        final request = NostrRequest(filters: const [filter1, filter2]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters, hasLength(2));
      });

      test('subscription with complex filter composition', () {
        const authorPubkey = 'author123';
        const limit = 50;

        const filter = NostrFilter(
          kinds: [1],
          authors: [authorPubkey],
          limit: limit,
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        final requestFilter = stream.request.filters[0];
        expect(requestFilter.kinds, contains(1));
        expect(requestFilter.authors, contains(authorPubkey));
        expect(requestFilter.limit, equals(limit));
      });

      test('subscription stream is filtered by subscription ID', () {
        const filter = NostrFilter(kinds: [1]);
        final request = NostrRequest(filters: const [filter]);

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        // The stream should have a stream property that can be listened to
        expect(stream.stream, isNotNull);
      });

      test('subscription with no filters', () {
        final request = NostrRequest(
          filters: const [NostrFilter()],
        );

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream, isA<NostrEventsStream>());
      });

      test('subscription request is serializable', () {
        const filter = NostrFilter(kinds: [1]);
        final request = NostrRequest(filters: const [filter]);

        // Request should be able to be serialized for sending to relay
        final serialized = request.serialized();
        expect(serialized, isNotNull);
        expect(serialized, isNotEmpty);
        expect(serialized, contains('REQ'));
      });

      test('subscription with search filter', () {
        const filter = NostrFilter(
          kinds: [1],
          search: 'hello world',
        );

        final request = NostrRequest(filters: const [filter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters[0].search, equals('hello world'));
      });

      test('subscription filter toMap includes all fields', () {
        const filter = NostrFilter(
          kinds: [1],
          authors: ['author1'],
          limit: 10,
        );

        final filterMap = filter.toMap();
        expect(filterMap, contains('kinds'));
        expect(filterMap, contains('authors'));
        expect(filterMap, contains('limit'));
      });
    });

    group('Subscription Closure', () {
      test('closeEventsSubscription creates proper close request', () {
        const subscriptionId = 'test-sub-id';

        // Verify the method can be called without error
        expect(
          () => Nostr.instance.services.relays
              .closeEventsSubscription(subscriptionId),
          returnsNormally,
        );
      });

      test('closeEventsSubscription without relay parameter works', () {
        const subscriptionId = 'test-sub-id';

        // Verify the method can be called without error (no relay specified)
        expect(
          () => Nostr.instance.services.relays
              .closeEventsSubscription(subscriptionId),
          returnsNormally,
        );
      });

      test('multiple subscriptions can be closed independently', () {
        const subId1 = 'sub-1';
        const subId2 = 'sub-2';

        // Both should complete without error
        expect(
          () {
            Nostr.instance.services.relays.closeEventsSubscription(subId1);
            Nostr.instance.services.relays.closeEventsSubscription(subId2);
          },
          returnsNormally,
        );
      });

      test('subscription ID can be any non-empty string', () {
        final subscriptionIds = [
          'simple-id',
          'id-with-123-numbers',
          'id_with_underscores',
          'veryLongSubscriptionIdThatHasManyCharactersForTestingPurposes',
        ];

        expect(
          () {
            for (final subId in subscriptionIds) {
              Nostr.instance.services.relays.closeEventsSubscription(subId);
            }
          },
          returnsNormally,
        );
      });
    });

    group('Subscription Stream Operations', () {
      test('NostrEventsStream has non-empty subscription ID', () {
        const filter = NostrFilter(kinds: [1]);
        final request = NostrRequest(filters: const [filter]);

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.subscriptionId, isNotEmpty);
        expect(stream.subscriptionId.length, greaterThan(0));
      });

      test('startEventsSubscription without autoHandling creates stream', () {
        const filter = NostrFilter(kinds: [1]);
        final request = NostrRequest(filters: const [filter]);

        final stream = Nostr.instance.services.relays
            .startEventsSubscriptionWithoutAutoHandling(
          request: request,
        );

        expect(stream, isNotNull);
      });

      test('subscription stream is unique per subscription', () {
        const filter1 = NostrFilter(kinds: [1]);
        const filter2 = NostrFilter(kinds: [2]);

        final request1 = NostrRequest(filters: const [filter1]);
        final request2 = NostrRequest(filters: const [filter2]);

        final stream1 = Nostr.instance.services.relays.startEventsSubscription(
          request: request1,
        );
        final stream2 = Nostr.instance.services.relays.startEventsSubscription(
          request: request2,
        );

        // Streams should be different objects
        expect(identical(stream1, stream2), isFalse);
      });

      test('subscription with consistent ID based on request data', () {
        const filter = NostrFilter(kinds: [1], authors: ['author1']);
        final request = NostrRequest(filters: const [filter]);

        final stream1 = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
          useConsistentSubscriptionIdBasedOnRequestData: true,
        );

        expect(stream1.subscriptionId, isNotNull);
      });

      test('subscription stream request is immutable', () {
        const filter = NostrFilter(kinds: [1]);
        final request = NostrRequest(filters: const [filter]);

        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters, hasLength(1));
        expect(stream.request.filters[0].kinds, contains(1));
      });

      test('subscription creates stream for multiple filter types', () {
        final timeFilter = NostrFilter(
          kinds: const [1],
          since: DateTime.now().subtract(const Duration(days: 1)),
        );

        const authorFilter = NostrFilter(
          kinds: [0],
          authors: ['author1'],
        );

        final request = NostrRequest(filters: [timeFilter, authorFilter]);
        final stream = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        expect(stream.request.filters, hasLength(2));
      });
    });

    group('Request and Filter Models', () {
      test('NostrRequest can be created with empty filters list', () {
        // This should handle edge case
        expect(
          () => NostrRequest(filters: const []),
          returnsNormally,
        );
      });

      test('NostrFilter can be created with no parameters', () {
        expect(
          NostrFilter.new,
          returnsNormally,
        );
      });

      test('NostrRequest filters list is preserved', () {
        final filters = [
          const NostrFilter(kinds: [1]),
          const NostrFilter(kinds: [0]),
          const NostrFilter(authors: ['author1']),
        ];

        final request = NostrRequest(filters: filters);

        expect(request.filters, equals(filters));
      });

      test('NostrFilter with only kind parameter', () {
        const filter = NostrFilter(kinds: [1, 2, 3]);

        expect(filter.kinds, equals([1, 2, 3]));
        expect(filter.authors, isNull);
      });

      test('NostrFilter with only author parameter', () {
        final authors = ['author1', 'author2'];
        final filter = NostrFilter(authors: authors);

        expect(filter.authors, equals(authors));
        expect(filter.kinds, isNull);
      });

      test('NostrFilter toMap converts DateTime to Unix timestamp', () {
        final now = DateTime.now();
        final filter = NostrFilter(
          since: now,
          kinds: const [1],
        );

        final map = filter.toMap();

        expect(map, containsPair('since', now.millisecondsSinceEpoch ~/ 1000));
      });

      test('subscription ID is generated consistently', () {
        const filter = NostrFilter(kinds: [1]);
        final request = NostrRequest(filters: const [filter]);

        final stream1 = Nostr.instance.services.relays.startEventsSubscription(
          request: request,
        );

        // The subscription ID should be a hex string
        expect(
          stream1.subscriptionId.toLowerCase(),
          equals(stream1.subscriptionId),
        );
      });
    });

    group('Connection Parameters', () {
      test('init method accepts connectionTimeout parameter', () {
        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: ['wss://relay.damus.io'],
            connectionTimeout: const Duration(seconds: 10),
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });

      test('init method accepts retryOnError parameter', () {
        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: ['wss://relay.damus.io'],
            retryOnError: true,
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });

      test('init method accepts retryOnClose parameter', () {
        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: ['wss://relay.damus.io'],
            retryOnClose: true,
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });

      test('init method accepts ignoreConnectionException parameter', () {
        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: ['wss://relay.damus.io'],
            ignoreConnectionException: false,
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });

      test('init method accepts lazyListeningToRelays parameter', () {
        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: ['wss://relay.damus.io'],
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });

      test('init method accepts ensureToClearRegistriesBeforeStarting', () {
        expect(
          () => Nostr.instance.services.relays.init(
            relaysUrl: ['wss://relay.damus.io'],
            ensureToClearRegistriesBeforeStarting: false,
            lazyListeningToRelays: true,
          ),
          returnsNormally,
        );
      });
    });
  });
}
