import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  const validInput = '''
[
    "EVENT",
    "subscriptionId",
    {
        "id": "identifier",
        "pubkey": "author",
        "kind": 0,
        "created_at": 1740549558,
        "tags": [
            [
                "p",
                "pubkey"
            ]
        ],
        "content": "content",
        "sig": "event signature"
    }
]
''';

  const inputWithNullContent = '''
 [
    "EVENT",
    "subscriptionId",
    {
        "id": "identifier",
        "pubkey": "author",
        "kind": 0,
        "created_at": 1740549558,
        "tags": [
            [
                "p",
                "pubkey"
            ]
        ],
        "content": null,
        "sig": "event signature"
    }
]
''';

  final parsedEvent = NostrEvent(
    content: 'content',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1740549558 * 1000),
    id: 'identifier',
    kind: 0,
    pubkey: 'author',
    sig: 'event signature',
    subscriptionId: 'subscriptionId',
    tags: const [
      [
        'p',
        'pubkey',
      ]
    ],
  );

  final parsedEventWithNullContent = NostrEvent(
    content: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1740549558 * 1000),
    id: 'identifier',
    kind: 0,
    pubkey: 'author',
    subscriptionId: 'subscriptionId',
    sig: 'event signature',
    tags: const [
      [
        'p',
        'pubkey',
      ]
    ],
  );

  group('NostrEvent model test', () {
    test('event is correctly parsed from payload', () {
      final eventFromPayload = NostrEvent.deserialized(validInput);

      expect(eventFromPayload, parsedEvent);
    });

    test('event is correctly parsed when content is null', () {
      final eventFromPayload = NostrEvent.deserialized(inputWithNullContent);

      expect(parsedEventWithNullContent, eventFromPayload);
    });
  });
}
