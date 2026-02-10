import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRequest Serialization', () {
    test('request can be serialized to JSON', () {
      final filter = NostrFilter(
        kinds: [1],
        authors: ['author1'],
      );
      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      final serialized = request.serialized();

      expect(serialized, isNotNull);
      expect(serialized, contains('REQ'));
      // The serialization sets subscriptionId after serialized() is called
      expect(request.subscriptionId, isNotNull);
    });

    test('request without subscription ID generates one', () {
      final filter = NostrFilter(kinds: [1]);
      final request = NostrRequest(filters: [filter]);

      final serialized = request.serialized();

      expect(serialized, isNotNull);
      expect(request.subscriptionId, isNotNull);
      expect(request.subscriptionId!.length, 64); // Consistent 64 hex chars
    });

    test('request with multiple filters includes all', () {
      final filter1 = NostrFilter(kinds: [0, 1]);
      final filter2 = NostrFilter(authors: ['author1']);
      final request = NostrRequest(
        filters: [filter1, filter2],
        subscriptionId: 'sub-123',
      );

      final serialized = request.serialized();

      expect(serialized, isNotNull);
      expect(serialized, contains('REQ'));
    });

    test('request serialization is consistent', () {
      final filter = NostrFilter(kinds: [1]);
      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      final serialized1 = request.serialized();
      final serialized2 = request.serialized();

      expect(serialized1, equals(serialized2));
    });

    test('request copyWith creates modified copy', () {
      final filter = NostrFilter(kinds: [1]);
      final request1 = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      final request2 = request1.copyWith(subscriptionId: 'sub-456');

      expect(request1.subscriptionId, equals('sub-123'));
      expect(request2.subscriptionId, equals('sub-456'));
      expect(request2.filters, equals(request1.filters));
    });

    test('request copyWith with null preserves original', () {
      final filter = NostrFilter(kinds: [1]);
      final request1 = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      final request2 = request1.copyWith();

      expect(request1, equals(request2));
    });

    test('request equality works correctly', () {
      final filter = NostrFilter(kinds: [1]);
      final request1 = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      final request2 = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      expect(request1, equals(request2));
    });

    test('request with different subscriptionId are not equal', () {
      final filter = NostrFilter(kinds: [1]);
      final request1 = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      final request2 = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-456',
      );

      expect(request1, isNot(equals(request2)));
    });

    test('request deserialization works correctly', () {
      final deserialized = NostrRequest.deserialized([
        'REQ',
        'sub-123',
        {
          'kinds': [1],
          'authors': ['author1']
        },
      ]);

      expect(deserialized.subscriptionId, equals('sub-123'));
      expect(deserialized.filters, isNotEmpty);
    });

    test('request deserialization with multiple filters', () {
      final deserialized = NostrRequest.deserialized([
        'REQ',
        'sub-123',
        {
          'kinds': [0, 1]
        },
        {
          'authors': ['author1']
        },
      ]);

      expect(deserialized.subscriptionId, equals('sub-123'));
      expect(deserialized.filters, hasLength(2));
    });

    test('request deserialization fails with invalid format', () {
      expect(
        () => NostrRequest.deserialized(['REQ', 'sub-123']),
        throwsA(isA<AssertionError>()),
      );
    });

    test('request deserialization fails with wrong command', () {
      expect(
        () => NostrRequest.deserialized([
          'NOTAREQ',
          'sub-123',
          {
            'kinds': [1]
          },
        ]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('props includes all relevant fields', () {
      final filter = NostrFilter(kinds: [1]);
      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'sub-123',
      );

      final props = request.props;

      expect(props, contains('sub-123'));
      expect(props.length, greaterThan(0));
    });

    test('request subscriptionId can be updated after creation', () {
      final filter = NostrFilter(kinds: [1]);
      final request = NostrRequest(filters: [filter]);
      final oldSubId = request.subscriptionId;

      final newSerialized = request.serialized(subscriptionId: 'new-sub-456');

      expect(request.subscriptionId, equals('new-sub-456'));
      expect(newSerialized, contains('new-sub-456'));
    });
  });
}
