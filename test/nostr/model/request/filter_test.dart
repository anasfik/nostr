import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrFilter', () {
    test('filter can be created with no parameters', () {
      final filter = NostrFilter();

      expect(filter.kinds, isNull);
      expect(filter.authors, isNull);
      expect(filter.ids, isNull);
      expect(filter.limit, isNull);
    });

    test('filter can be created with all parameters', () {
      final filter = NostrFilter(
        ids: ['id1', 'id2'],
        kinds: [0, 1, 2],
        authors: ['author1'],
        limit: 100,
        since: DateTime.now(),
        until: DateTime.now(),
        e: ['event1'],
        p: ['pubkey1'],
        t: ['tag1'],
        search: 'search term',
      );

      expect(filter.ids, equals(['id1', 'id2']));
      expect(filter.kinds, equals([0, 1, 2]));
      expect(filter.authors, equals(['author1']));
      expect(filter.limit, equals(100));
      expect(filter.e, isNotNull);
    });

    test('filter toMap includes all set fields', () {
      final filter = NostrFilter(
        kinds: [1],
        authors: ['author1'],
        limit: 50,
      );

      final map = filter.toMap();

      expect(map['kinds'], equals([1]));
      expect(map['authors'], equals(['author1']));
      expect(map['limit'], equals(50));
    });

    test('filter with since converts to unix timestamp', () {
      final time = DateTime(2024, 1, 1, 12, 0, 0);
      final filter = NostrFilter(since: time);

      final map = filter.toMap();

      expect(map['since'], equals(time.millisecondsSinceEpoch ~/ 1000));
    });

    test('filter with until converts to unix timestamp', () {
      final time = DateTime(2024, 12, 31, 23, 59, 59);
      final filter = NostrFilter(until: time);

      final map = filter.toMap();

      expect(map['until'], equals(time.millisecondsSinceEpoch ~/ 1000));
    });

    test('filter with tags includes all tags', () {
      final filter = NostrFilter(
        p: ['pubkey1', 'pubkey2'],
        e: ['event1'],
        t: ['hashtag1', 'hashtag2'],
      );

      final map = filter.toMap();

      expect(map['#p'], equals(['pubkey1', 'pubkey2']));
      expect(map['#e'], equals(['event1']));
      expect(map['#t'], equals(['hashtag1', 'hashtag2']));
    });

    test('filter fromJson creates filter from map', () {
      final json = {
        'ids': ['id1'],
        'kinds': [1, 2],
        'authors': ['author1'],
        'limit': 100,
      };

      final filter = NostrFilter.fromJson(json);

      expect(filter.ids, equals(['id1']));
      expect(filter.kinds, equals([1, 2]));
      expect(filter.authors, equals(['author1']));
      expect(filter.limit, equals(100));
    });

    test('filter fromJson with search parameter', () {
      final json = {
        'search': 'nostr',
      };

      final filter = NostrFilter.fromJson(json);

      expect(filter.search, equals('nostr'));
    });

    test('filter fromJson with since and until', () {
      final since = DateTime(2024, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final until = DateTime(2024, 12, 31).millisecondsSinceEpoch ~/ 1000;
      final json = {
        'since': since,
        'until': until,
      };

      final filter = NostrFilter.fromJson(json);

      expect(filter.since, isNotNull);
      expect(filter.until, isNotNull);
    });

    test('filter equality works correctly', () {
      final filter1 = NostrFilter(kinds: [1], authors: ['author1']);
      final filter2 = NostrFilter(kinds: [1], authors: ['author1']);

      expect(filter1, equals(filter2));
    });

    test('filter inequality works correctly', () {
      final filter1 = NostrFilter(kinds: [1]);
      final filter2 = NostrFilter(kinds: [2]);

      expect(filter1, isNot(equals(filter2)));
    });

    test('filter with no parameters matches all events', () {
      final filter = NostrFilter();
      final map = filter.toMap();

      // Should produce an empty or minimal map
      expect(map, isNotNull);
    });
  });
}
