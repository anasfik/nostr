import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:test/test.dart';

void main() {
  group('NostrTags.tail', () {
    test('returns slots after the name', () {
      expect(NostrTags.tail(['e', 'id', 'relay']), ['id', 'relay']);
      expect(NostrTags.tail(['e', 'id']), ['id']);
    });

    test('returns an empty list for name-only and empty tags', () {
      expect(NostrTags.tail(['-']), isEmpty);
      expect(NostrTags.tail([]), isEmpty);
    });
  });

  group('NostrTags.withPrefix', () {
    test('keeps whole tags with a matching valued prefix', () {
      final tags = [
        ['r', 'https://a.example/x'],
        ['r', 'wss://relay.example'],
        ['r', 'https://b.example/y'],
      ];

      expect(NostrTags.withPrefix(tags, 'r', 'https://'), [
        ['r', 'https://a.example/x'],
        ['r', 'https://b.example/y'],
      ]);
    });

    test('returns an empty list without matches', () {
      expect(
        NostrTags.withPrefix(
          [
            ['r', 'wss://relay.example'],
          ],
          'r',
          'https://',
        ),
        isEmpty,
      );
    });

    test('skips name-only tags and handles null tags', () {
      expect(
        NostrTags.withPrefix(
          [
            ['r'],
            ['r', 'https://a.example'],
          ],
          'r',
          '',
        ),
        [
          ['r', 'https://a.example'],
        ],
      );
      expect(NostrTags.withPrefix(null, 'r', ''), isEmpty);
    });
  });

  group('NostrTags.toTagMap', () {
    test('maps names to the first value slot', () {
      final map = NostrTags.toTagMap([
        ['d', 'identifier'],
        ['t', 'nostr', 'extra'],
      ]);

      expect(map, {
        'd': ['identifier'],
        't': ['nostr'],
      });
    });

    test('first occurrence wins and order is preserved', () {
      final map = NostrTags.toTagMap([
        ['t', 'first'],
        ['d', 'id'],
        ['t', 'second'],
      ]);

      expect(map['t'], ['first']);
      expect(map.keys.toList(), ['t', 'd']);
    });

    test('value-less tags map to an empty string', () {
      expect(
          NostrTags.toTagMap([
            ['-'],
          ]),
          {
            '-': [''],
          });
      expect(NostrTags.toTagMap([]), isEmpty);
    });
  });

  group('NostrValidators.tryHttpUrl', () {
    test('accepts http and https with a host', () {
      expect(
        NostrValidators.tryHttpUrl('https://example.com/a')?.host,
        'example.com',
      );
      expect(NostrValidators.tryHttpUrl('http://Example.COM:80')?.port, 80);
    });

    test('rejects other schemes and hostless input', () {
      expect(NostrValidators.tryHttpUrl('ftp://example.com/a'), isNull);
      expect(NostrValidators.tryHttpUrl('mailto:a@example.com'), isNull);
      expect(NostrValidators.tryHttpUrl('http:///path'), isNull);
      expect(NostrValidators.tryHttpUrl('not a url'), isNull);
      expect(NostrValidators.tryHttpUrl(''), isNull);
    });
  });

  group('NostrValidators.normalizeUrl', () {
    test('lowercases and drops default port and fragment', () {
      expect(
        NostrValidators.normalizeUrl('HTTP://Example.COM:80/Path?Q=1#frag'),
        'http://example.com/Path?Q=1',
      );
      expect(
        NostrValidators.normalizeUrl('https://Example.com:443/x#'),
        'https://example.com/x',
      );
    });

    test('keeps non-default ports, path and query', () {
      expect(
        NostrValidators.normalizeUrl('http://example.com:8080/p?a=b'),
        'http://example.com:8080/p?a=b',
      );
    });

    test('returns null for non-http(s) or unparseable values', () {
      expect(NostrValidators.normalizeUrl('ftp://example.com/a'), isNull);
      expect(NostrValidators.normalizeUrl('mailto:a@example.com'), isNull);
      expect(NostrValidators.normalizeUrl('nope'), isNull);
    });
  });

  group('NostrValidators.isRelayUrl', () {
    test('accepts ws and wss with a host', () {
      expect(NostrValidators.isRelayUrl('ws://relay.example'), isTrue);
      expect(NostrValidators.isRelayUrl('wss://Relay.Example/path'), isTrue);
    });

    test('rejects hostless, other schemes and plain text', () {
      expect(NostrValidators.isRelayUrl('wss://'), isFalse);
      expect(NostrValidators.isRelayUrl('https://relay.example'), isFalse);
      expect(NostrValidators.isRelayUrl('relay.example'), isFalse);
    });
  });

  group('NostrValidators.tryGeohash', () {
    test('normalizes case and trims', () {
      expect(NostrValidators.tryGeohash('9Q8YYK8'), '9q8yyk8');
      expect(NostrValidators.tryGeohash(' 9q8yyk8 '), '9q8yyk8');
    });

    test('rejects characters outside the base32 alphabet', () {
      for (final value in [
        '9q8yya8',
        '9q8yyi8',
        '9q8yyl8',
        '9q8yyo8',
        '9q8-yy',
      ]) {
        expect(NostrValidators.tryGeohash(value), isNull, reason: value);
      }
    });

    test('rejects empty and over-long values', () {
      expect(NostrValidators.tryGeohash(''), isNull);
      expect(NostrValidators.tryGeohash('9q8yyk8u4n0xz'), isNull);
      expect(NostrValidators.tryGeohash('9q8yyk8u4n0x'), '9q8yyk8u4n0x');
    });
  });
}
