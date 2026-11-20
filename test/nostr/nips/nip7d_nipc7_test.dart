import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

/// Spec vectors, verbatim from NIP-7D and NIP-C7.
const Map<String, dynamic> _specThread = {
  'kind': 11,
  'content': 'Good morning',
  'tags': [
    ['title', 'GM'],
  ],
};

const Map<String, dynamic> _specThreadReply = {
  'kind': 1111,
  'content': 'Cool beans',
  'tags': [
    ['K', '11'],
    ['E', '<event-id>', '<relay-url>', '<pubkey>'],
  ],
};

const Map<String, dynamic> _specChat = {
  'kind': 9,
  'content': 'GM',
  'tags': <List<String>>[],
};

const Map<String, dynamic> _specChatReply = {
  'kind': 9,
  'content': 'nostr:nevent1...\nyes',
  'tags': [
    ['q', '<event-id>', '<relay-url>', '<pubkey>'],
  ],
};

NostrEvent _event(Map<String, dynamic> json) {
  return NostrEvent(
    id: json['id'] as String?,
    kind: json['kind'] as int?,
    content: json['content'] as String?,
    pubkey: (json['pubkey'] as String?) ?? '',
    sig: json['sig'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    tags: [
      for (final tag in json['tags'] as List) List<String>.from(tag as List),
    ],
  );
}

void main() {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

  group('NIP-7D forum threads', () {
    test('parses the spec thread vector', () {
      final event = _event(_specThread);
      final thread = NostrNip7d.parseThread(event);

      expect(thread.title, 'GM');
      expect(thread.content, 'Good morning');
      expect(thread.tags, isEmpty);
      expect(NostrNip7d.validateThread(event), isTrue);
      expect(NostrNip7d.titleOf(event), 'GM');
      expect(NostrNip7d.threadKind, 11);
      expect(NostrNip7d.commentKind, 1111);
    });

    test('builds the spec thread vector as an unsigned template', () {
      final event = NostrNip7d.generateThreadTemplate(
        title: 'GM',
        content: 'Good morning',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 11);
      expect(event.content, 'Good morning');
      expect(event.tags, [
        ['title', 'GM'],
      ]);
      expect(event.id, isNull);
      expect(event.sig, isNull);
      expect(event.pubkey, isEmpty);
    });

    test('extraTags cannot inject a second title', () {
      final event = NostrNip7d.generateThreadTemplate(
        title: 'GM',
        extraTags: [
          ['title', 'imposter'],
          ['t', 'nostr'],
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.tags, [
        ['title', 'GM'],
        ['t', 'nostr'],
      ]);
      expect(event.tags!.where((tag) => tag.first == 'title'), hasLength(1));
      expect(NostrNip7d.parseThread(event).title, 'GM');
    });

    test('rejects empty or blank titles', () {
      expect(
        () => NostrNip7d.generateThreadTemplate(title: ''),
        throwsArgumentError,
      );
      expect(
        () => NostrNip7d.generateThreadTemplate(title: '   '),
        throwsArgumentError,
      );
      expect(
        NostrNip7d.tryParseThread(
          _event({
            'kind': 11,
            'content': 'no title',
            'tags': <List<String>>[],
          }),
        ),
        isNull,
      );
      expect(
        NostrNip7d.tryParseThread(
          _event({
            'kind': 11,
            'content': 'blank title',
            'tags': [
              ['title', ''],
            ],
          }),
        ),
        isNull,
      );
    });

    test('tryParse returns null and parse throws for wrong kinds', () {
      final note = _event({
        'kind': 1,
        'content': 'GM',
        'tags': [
          ['title', 'GM'],
        ],
      });

      expect(NostrNip7d.tryParseThread(note), isNull);
      expect(
        () => NostrNip7d.parseThread(note),
        throwsArgumentError,
      );
    });

    test('spec reply is a NIP-22 kind 1111 comment rooted at kind 11', () {
      final reply = _event(_specThreadReply);

      expect(reply.kind, NostrNip7d.commentKind);
      expect(NostrTags.first(reply.tags, 'K'), '11');
      expect(NostrTags.require(reply.tags, 'E'), ['<event-id>']);
      // Not a thread: kind 11 parsing rejects it.
      expect(NostrNip7d.tryParseThread(reply), isNull);
    });

    test('social createComment targets a thread with K/E root tags', () async {
      final social = NostrSocialBuilder(signer: signer);
      final comment = await social.createComment(
        content: 'Cool beans',
        targetEventId: 'b' * 64,
        targetAuthorPubkey: 'c' * 64,
        targetKind: NostrNip7d.threadKind,
      );

      expect(comment.kind, NostrNip7d.commentKind);
      expect(comment.tags!.first, ['K', '11']);
      expect(NostrTags.first(comment.tags, 'E'), 'b' * 64);
      expect(NostrNip7d.tryParseThread(comment), isNull);
    });
  });

  group('NIP-C7 chat messages', () {
    test('parses the spec chat vector', () {
      final message = NostrNipC7.parseChat(_event(_specChat));

      expect(NostrNipC7.chatKind, 9);
      expect(message.content, 'GM');
      expect(message.replyTo, isNull);
      expect(message.isReply, isFalse);
      expect(message.tags, isEmpty);
    });

    test('builds the spec chat vector as an unsigned template', () {
      final event = NostrNipC7.generateChatMessage(
        content: 'GM',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 9);
      expect(event.content, 'GM');
      expect(event.tags, isEmpty);
      expect(event.pubkey, isEmpty);
    });

    test('spec reply q tag carries exactly four slots', () {
      final reply = _event(_specChatReply);
      final message = NostrNipC7.parseChat(reply);

      expect(message.isReply, isTrue);
      expect(message.replyTo, '<event-id>');
      expect(message.relayHint, '<relay-url>');
      expect(message.pubkey, '<pubkey>');
      expect(message.tags, isEmpty);
      expect((reply.tags!).first, hasLength(4));
    });

    test('generateChatMessage emits q only for replies, in spec slot order',
        () {
      const parentId =
          '9d1b6b9562e66f2ecf35eb0a3c2decc736c47fddb13d6fb8f87185a153ea3634';
      const author =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      final message = NostrNipC7.generateChatMessage(content: 'yes');
      expect(message.tags, isEmpty);

      final reply = NostrNipC7.generateChatMessage(
        content: 'yes',
        replyTo: parentId,
        relayHint: 'wss://relay.example',
        pubkey: author,
      );
      expect(reply.tags, [
        ['q', parentId, 'wss://relay.example', author],
      ]);

      final bare = NostrNipC7.generateChatMessage(
        content: 'yes',
        replyTo: parentId,
      );
      expect(bare.tags, [
        ['q', parentId, '', ''],
      ]);
      expect(bare.tags!.first, hasLength(4));

      final parsed = NostrNipC7.parseChat(bare);
      expect(parsed.replyTo, parentId);
      expect(parsed.relayHint, isEmpty);
      expect(parsed.pubkey, isEmpty);
    });

    test('rejects a blank replyTo instead of emitting an unusable q tag', () {
      expect(
        () => NostrNipC7.generateChatMessage(content: 'yes', replyTo: ''),
        throwsArgumentError,
      );
      expect(
        () => NostrNipC7.generateChatMessage(content: 'yes', replyTo: '  '),
        throwsArgumentError,
      );

      const parentId =
          '9d1b6b9562e66f2ecf35eb0a3c2decc736c47fddb13d6fb8f87185a153ea3634';
      final reply = NostrNipC7.generateChatMessage(
        content: 'yes',
        replyTo: parentId,
      );
      expect(reply.tags, [
        ['q', parentId, '', ''],
      ]);
      expect(NostrNipC7.parseChat(reply).replyTo, parentId);
    });

    test('appends extraTags after the q tag', () {
      const parentId =
          '9d1b6b9562e66f2ecf35eb0a3c2decc736c47fddb13d6fb8f87185a153ea3634';

      final reply = NostrNipC7.generateChatMessage(
        content: 'yes',
        replyTo: parentId,
        extraTags: [
          ['t', 'nostr'],
          ['client', 'dart-nostr'],
        ],
      );

      expect(reply.tags, [
        ['q', parentId, '', ''],
        ['t', 'nostr'],
        ['client', 'dart-nostr'],
      ]);
    });

    test('rejects empty or blank content', () {
      expect(
        () => NostrNipC7.generateChatMessage(content: ''),
        throwsArgumentError,
      );
      expect(
        () => NostrNipC7.generateChatMessage(content: '  \n'),
        throwsArgumentError,
      );
      expect(
        NostrNipC7.tryParseChat(
          _event({'kind': 9, 'content': '', 'tags': <List<String>>[]}),
        ),
        isNull,
      );
      expect(
        NostrNipC7.validateChat(
          _event({'kind': 9, 'content': 'GM', 'tags': <List<String>>[]}),
        ),
        isTrue,
      );
    });

    test('tryParse returns null and parse throws for wrong kinds', () {
      final note =
          _event({'kind': 1, 'content': 'GM', 'tags': <List<String>>[]});

      expect(NostrNipC7.tryParseChat(note), isNull);
      expect(() => NostrNipC7.parseChat(note), throwsArgumentError);
    });

    test('rejects a q tag without a parent id', () {
      expect(
        NostrNipC7.tryParseChat(
          _event({
            'kind': 9,
            'content': 'yes',
            'tags': [
              ['q'],
            ],
          }),
        ),
        isNull,
      );
      expect(
        NostrNipC7.tryParseChat(
          _event({
            'kind': 9,
            'content': 'yes',
            'tags': [
              ['q', ''],
            ],
          }),
        ),
        isNull,
      );
    });

    test('chatFilter fetches kind 9 only', () {
      final stream = NostrNipC7.chatFilter();

      expect(stream.kinds, [9]);
      expect(stream.toMap(), {
        'kinds': [9],
      });

      final thread = NostrNipC7.chatFilter(
        subjects: ['b' * 64],
        authors: ['c' * 64],
        limit: 50,
      );
      expect(thread.kinds, [9]);
      expect(thread.toMap(), {
        '#q': ['b' * 64],
        'kinds': [9],
        'authors': ['c' * 64],
        'limit': 50,
      });
    });

    test('chatFilter forwards since and until', () {
      final since = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final until = DateTime.fromMillisecondsSinceEpoch(1700003600000);

      final stream = NostrNipC7.chatFilter(since: since, until: until);

      expect(stream.since, since);
      expect(stream.until, until);
      expect(stream.toMap(), {
        'kinds': [9],
        'since': 1700000000,
        'until': 1700003600,
      });
    });

    test('extra q tags stay in tags while the first one is decoded', () {
      final message = NostrNipC7.parseChat(
        _event({
          'kind': 9,
          'content': 'yes',
          'tags': [
            ['q', 'first'],
            ['t', 'nostr'],
            ['q', 'second'],
          ],
        }),
      );

      expect(message.replyTo, 'first');
      expect(message.tags, [
        ['t', 'nostr'],
        ['q', 'second'],
      ]);
    });
  });

  group('wiring', () {
    test('accessors are cached const, signer-free, on NostrNips', () {
      final nips = NostrNips(logger: Nostr.instance.services.logger);

      expect(nips.nip7d, same(nips.nip7d));
      expect(nips.nipc7, same(nips.nipc7));
      expect(nips.nip7d, isA<NostrNip7d>());
      expect(nips.nipc7, isA<NostrNipC7>());
      expect(const NostrNip7d(), same(const NostrNip7d()));
      expect(const NostrNipC7(), same(const NostrNipC7()));
      expect(
        NostrNip7d.generateThreadTemplate(title: 'GM').kind,
        NostrNip7d.threadKind,
      );
      expect(
        NostrNipC7.generateChatMessage(content: 'GM').kind,
        NostrNipC7.chatKind,
      );
      expect(Nostr.instance.nips.nip7d, same(Nostr.instance.nips.nip7d));
      expect(Nostr.instance.nips.nipc7, same(Nostr.instance.nips.nipc7));
    });

    test('barrel exports both NIP types and parsed models', () {
      expect(NostrNip7d, isNotNull);
      expect(NostrNipC7, isNotNull);
      expect(NostrThread, isNotNull);
      expect(NostrChatMessage, isNotNull);
    });

    test('spec tag lists survive JSON encode and decode unchanged', () {
      final thread = _event(_specThread);
      expect(
        jsonDecode(jsonEncode({..._specThread, 'tags': thread.tags})),
        _specThread,
      );
      final chat = _event(_specChatReply);
      expect(
        jsonDecode(jsonEncode({..._specChatReply, 'tags': chat.tags})),
        _specChatReply,
      );
    });
  });
}
