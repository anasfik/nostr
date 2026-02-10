import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrEvent Serialization', () {
    test('event is correctly parsed from relay payload', () {
      const validInput = '''
[
    "EVENT",
    "subscriptionId",
    {
        "id": "event123",
        "pubkey": "author456",
        "kind": 1,
        "created_at": 1740549558,
        "tags": [
            [
                "p",
                "pubkey123"
            ],
            [
                "e",
                "event456"
            ]
        ],
        "content": "Hello Nostr",
        "sig": "signature789"
    }
]
''';

      final event = NostrEvent.deserialized(validInput);

      expect(event.id, equals('event123'));
      expect(event.pubkey, equals('author456'));
      expect(event.kind, equals(1));
      expect(event.content, equals('Hello Nostr'));
      expect(event.sig, equals('signature789'));
      expect(event.subscriptionId, equals('subscriptionId'));
      expect(event.tags, hasLength(2));
      expect(event.tags?[0], equals(['p', 'pubkey123']));
    });

    test('event is correctly parsed when content is null', () {
      const inputWithNullContent = '''
[
    "EVENT",
    "subId",
    {
        "id": "id1",
        "pubkey": "pub1",
        "kind": 0,
        "created_at": 1740549558,
        "tags": [],
        "content": null,
        "sig": "sig1"
    }
]
''';

      final event = NostrEvent.deserialized(inputWithNullContent);

      expect(event.content, equals(''));
      expect(event.id, equals('id1'));
    });

    test('event with empty tags is correctly parsed', () {
      const inputWithEmptyTags = '''
[
    "EVENT",
    "subId",
    {
        "id": "id1",
        "pubkey": "pub1",
        "kind": 1,
        "created_at": 1740549558,
        "tags": [],
        "content": "content",
        "sig": "sig1"
    }
]
''';

      final event = NostrEvent.deserialized(inputWithEmptyTags);

      expect(event.tags, isEmpty);
    });

    test('canBeDeserialized returns true for valid event format', () {
      const validInput = '''
[
    "EVENT",
    "subId",
    {
        "id": "id1",
        "pubkey": "pub1",
        "kind": 1,
        "created_at": 1740549558,
        "tags": [],
        "content": "content",
        "sig": "sig1"
    }
]
''';

      expect(NostrEvent.canBeDeserialized(validInput), isTrue);
    });

    test('canBeDeserialized returns false for non-event format', () {
      const invalidInput = '''
[
    "NOTANEVENT",
    "subId"
]
''';

      expect(NostrEvent.canBeDeserialized(invalidInput), isFalse);
    });

    test('getEventId generates consistent ID', () {
      final now = DateTime.now();
      const kind = 1;
      const content = 'test content';
      const pubkey = 'testpubkey123';
      const tags = [];

      final id1 = NostrEvent.getEventId(
          kind: kind,
          content: content,
          createdAt: now,
          tags: tags,
          pubkey: pubkey);
      final id2 = NostrEvent.getEventId(
          kind: kind,
          content: content,
          createdAt: now,
          tags: tags,
          pubkey: pubkey);

      expect(id1, equals(id2));
      expect(id1.length, 64); // SHA256 hash in hex format
    });

    test('getEventId generates different IDs for different content', () {
      final now = DateTime.now();
      const kind = 1;
      const pubkey = 'testpubkey123';
      const tags = [];

      final id1 = NostrEvent.getEventId(
          kind: kind,
          content: 'content1',
          createdAt: now,
          tags: tags,
          pubkey: pubkey);
      final id2 = NostrEvent.getEventId(
          kind: kind,
          content: 'content2',
          createdAt: now,
          tags: tags,
          pubkey: pubkey);

      expect(id1, isNot(equals(id2)));
    });

    test('event equality works correctly', () {
      final now = DateTime.now();
      final event1 = NostrEvent(
        id: 'id1',
        kind: 1,
        content: 'test',
        sig: 'sig1',
        pubkey: 'pub1',
        createdAt: now,
        tags: const [
          ['p', 'value']
        ],
      );

      final event2 = NostrEvent(
        id: 'id1',
        kind: 1,
        content: 'test',
        sig: 'sig1',
        pubkey: 'pub1',
        createdAt: now,
        tags: const [
          ['p', 'value']
        ],
      );

      expect(event1, equals(event2));
    });

    test('event with subscription ID is correctly parsed', () {
      const inputWithSubId = '''
[
    "EVENT",
    "custom-sub-id",
    {
        "id": "id1",
        "pubkey": "pub1",
        "kind": 1,
        "created_at": 1740549558,
        "tags": [],
        "content": "content",
        "sig": "sig1"
    }
]
''';

      final event = NostrEvent.deserialized(inputWithSubId);

      expect(event.subscriptionId, equals('custom-sub-id'));
    });

    test('event creation date is correctly parsed', () {
      const timestamp = 1740549558;
      const input = '''
[
    "EVENT",
    "subId",
    {
        "id": "id1",
        "pubkey": "pub1",
        "kind": 1,
        "created_at": $timestamp,
        "tags": [],
        "content": "content",
        "sig": "sig1"
    }
]
''';

      final event = NostrEvent.deserialized(input);

      expect(event.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)));
    });

    test('event tags with multiple elements are correctly parsed', () {
      const input = '''
[
    "EVENT",
    "subId",
    {
        "id": "id1",
        "pubkey": "pub1",
        "kind": 1,
        "created_at": 1740549558,
        "tags": [
            ["p", "pubkey1", "relay1", "author"],
            ["e", "event1"],
            ["t", "hashtag"]
        ],
        "content": "content",
        "sig": "sig1"
    }
]
''';

      final event = NostrEvent.deserialized(input);

      expect(event.tags, hasLength(3));
      expect(event.tags?[0], equals(['p', 'pubkey1', 'relay1', 'author']));
      expect(event.tags?[1], equals(['e', 'event1']));
      expect(event.tags?[2], equals(['t', 'hashtag']));
    });
  });

  group('NostrEvent Props', () {
    test('props returns all fields', () {
      final now = DateTime.now();
      final event = NostrEvent(
        id: 'id1',
        kind: 1,
        content: 'test',
        sig: 'sig1',
        pubkey: 'pub1',
        createdAt: now,
        tags: const [
          ['p', 'value']
        ],
        subscriptionId: 'subId',
      );

      final props = event.props;

      expect(props, contains('id1'));
      expect(props, contains('pub1'));
      expect(props, contains('test'));
    });
  });
}
