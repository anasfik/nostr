import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_playground/src/nostr_tools.dart';

void main() {
  group('parseRelayInput', () {
    test('accepts up to three unique wss relays', () {
      final input = parseRelayInput(
        'wss://relay.damus.io\nwss://nos.lol\nwss://relay.damus.io',
      );

      expect(input.error, isNull);
      expect(input.urls, ['wss://relay.damus.io', 'wss://nos.lol']);
    });

    test('rejects empty input', () {
      expect(parseRelayInput('  ').error, contains('at least one'));
    });

    test('rejects insecure ws, https and malformed urls', () {
      expect(parseRelayInput('ws://relay.example').error, contains('wss://'));
      expect(
        parseRelayInput('https://relay.example').error,
        contains('wss://'),
      );
      expect(parseRelayInput('wss://').error, isNotNull);
      expect(parseRelayInput('not a url').error, isNotNull);
    });

    test('rejects credentials, fragments and more than three relays', () {
      expect(
        parseRelayInput('wss://user:pass@relay.example').error,
        contains('credentials'),
      );
      expect(
        parseRelayInput('wss://relay.example/#frag').error,
        contains('fragment'),
      );
      expect(
        parseRelayInput(
          'wss://a.example wss://b.example wss://c.example wss://d.example',
        ).error,
        contains('3 relays'),
      );
    });
  });

  group('filter parsing', () {
    test('parses kinds separated by commas or spaces', () {
      expect(parseKinds('1, 7 30023'), [1, 7, 30023]);
      expect(parseKinds(''), isEmpty);
    });

    test('rejects invalid and out-of-range kinds', () {
      expect(() => parseKinds('1,abc'), throwsFormatException);
      expect(() => parseKinds('-1'), throwsFormatException);
      expect(() => parseKinds('70000'), throwsFormatException);
    });

    test('parses bounded tags and rejects non-string values', () {
      expect(parseTags('[]'), isEmpty);
      expect(parseTags('[["t","nostr"],["e","abc"]]'), [
        ['t', 'nostr'],
        ['e', 'abc'],
      ]);
      expect(() => parseTags('{"t":"nostr"}'), throwsFormatException);
      expect(() => parseTags('[["t",1]]'), throwsFormatException);
      expect(
        () => parseTags(
          jsonEncode([
            for (var i = 0; i < 21; i++) ['t', '$i'],
          ]),
        ),
        throwsFormatException,
      );
    });

    test('parses authors as lowercase 64 char hex only', () {
      final key = NostrKeyPairs.generate().public;
      expect(parseAuthors(key), [key]);
      expect(parseAuthors(''), isEmpty);
      expect(() => parseAuthors('npub1abc'), throwsFormatException);
      expect(() => parseAuthors('ABC'), throwsFormatException);
    });
  });

  group('filter validation', () {
    test('accepts valid filters and normalizes nothing implicitly', () {
      final key = NostrKeyPairs.generate().public;
      final input = parseFilterInput(kinds: '1, 7', authors: key, limit: '20');

      expect(input.isValid, isTrue);
      expect(input.kinds, [1, 7]);
      expect(input.authors, [key]);
      expect(input.limit, 20);
    });

    test('rejects 0, negative and over-cap limits', () {
      expect(
        parseFilterInput(kinds: '1', authors: '', limit: '0').error,
        contains('between 1 and'),
      );
      expect(
        parseFilterInput(kinds: '1', authors: '', limit: '101').error,
        contains('between 1 and'),
      );
      expect(
        parseFilterInput(kinds: '1', authors: '', limit: '-2').error,
        isNotNull,
      );
    });

    test('requires at least one kind or author', () {
      final input = parseFilterInput(kinds: '', authors: '', limit: '20');

      expect(input.isValid, isFalse);
      expect(input.error, contains('kind or author'));
    });

    test('rejects malformed authors and kinds', () {
      expect(
        parseFilterInput(kinds: '1', authors: 'npub1abc', limit: '20').error,
        contains('lowercase hex'),
      );
      expect(
        parseFilterInput(kinds: 'abc', authors: '', limit: '20').error,
        contains('Kind must be'),
      );
    });
  });

  group('relay event bounds', () {
    NostrEvent event({
      String content = 'small',
      List<List<String>> tags = const [],
      String? id = 'id',
    }) {
      return NostrEvent(
        id: id,
        kind: 1,
        content: content,
        sig: 'sig',
        pubkey: 'a' * 64,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        tags: tags,
      );
    }

    test('accepts a bounded event', () {
      expect(relayEventRejection(event()), isNull);
    });

    test('rejects oversized content, tag count, tag value and tag text', () {
      expect(
        relayEventRejection(
          event(content: 'a' * (maxRelayEventContentChars + 1)),
        ),
        contains('content exceeds'),
      );
      expect(
        relayEventRejection(
          event(
            tags: [
              for (var i = 0; i < maxRelayEventTags + 1; i++) ['t', '$i'],
            ],
          ),
        ),
        contains('tags exceed'),
      );
      expect(
        relayEventRejection(
          event(
            tags: [
              ['t', 'x' * (maxRelayEventTagValueChars + 1)],
            ],
          ),
        ),
        contains('tag value'),
      );
      expect(
        relayEventRejection(
          event(
            tags: [
              for (var i = 0; i < 80; i++) ['t', 'x' * 500],
            ],
          ),
        ),
        contains('tag'),
      );
    });

    test('rejects missing kind and oversized id fields', () {
      expect(
        relayEventRejection(
          NostrEvent(
            id: 'a' * 300,
            kind: 1,
            content: '',
            sig: 'sig',
            pubkey: 'a' * 64,
            createdAt: DateTime.now(),
            tags: const [],
          ),
        ),
        contains('id field'),
      );
      expect(
        relayEventRejection(
          NostrEvent(
            id: 'id',
            kind: null,
            content: '',
            sig: 'sig',
            pubkey: 'a' * 64,
            createdAt: DateTime.now(),
            tags: const [],
          ),
        ),
        contains('kind'),
      );
    });
  });

  group('local signing and verification', () {
    test('signs an event that passes id and signature verification', () {
      final keys = NostrKeyPairs.generate();
      final event = signLocalEvent(
        keys: keys,
        kind: 1,
        content: 'hello from the playground',
        tags: [
          ['t', 'nostr'],
        ],
      );

      expect(isEventAuthentic(event), isTrue);
      expect(event.id, hasLength(64));
    });

    test('detects changed content on an event that reuses the same id', () {
      final event = signLocalEvent(
        keys: NostrKeyPairs.generate(),
        kind: 1,
        content: 'original',
        tags: const [],
      );
      final tampered = NostrEvent(
        id: event.id,
        kind: event.kind,
        content: 'tampered',
        sig: event.sig,
        pubkey: event.pubkey,
        createdAt: event.createdAt,
        tags: event.tags,
      );

      expect(isEventAuthentic(event), isTrue);
      expect(isEventAuthentic(tampered), isFalse);
    });

    test('reports missing signatures as not authentic', () {
      final event = signLocalEvent(
        keys: NostrKeyPairs.generate(),
        kind: 1,
        content: 'unsigned signature',
        tags: const [],
      );
      final unsigned = NostrEvent(
        id: event.id,
        kind: event.kind,
        content: event.content,
        sig: null,
        pubkey: event.pubkey,
        createdAt: event.createdAt,
        tags: event.tags,
      );

      expect(isEventAuthentic(unsigned), isFalse);
    });
  });
}
