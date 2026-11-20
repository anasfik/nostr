import 'dart:convert';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip24/nip24.dart';
import 'package:dart_nostr/nostr/nips/social/social_builder.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

void main() {
  late NostrEventSigner signer;
  late NostrSocialBuilder social;

  setUp(() {
    signer = NostrLocalKeySigner(NostrKeyPairs.generate());
    social = NostrSocialBuilder(signer: signer);
  });

  bool hasTag(NostrEvent event, List<String> expected) => event.tags!.any(
        (t) =>
            t.length == expected.length &&
            List.generate(expected.length, (i) => t[i] == expected[i])
                .every((m) => m),
      );

  String? tagValue(NostrEvent event, String name) {
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isNotEmpty && tag.first == name) {
        return tag.length > 1 ? tag[1] : null;
      }
    }
    return null;
  }

  group('NostrSocialBuilder', () {
    test('text note with NIP-10 reply and NIP-27 mentions', () async {
      final event = await social.createTextNote(
        'replying with a mention',
        subject: 're: thread',
        mentionedPubkeys: ['aa' * 32],
        replyTo: (
          eventId: 'bb' * 32,
          authorPubkey: 'cc' * 32,
          rootEventId: 'dd' * 32,
        ),
      );

      expect(event.kind, 1);
      expect(event.isVerified(), isTrue);
      expect(hasTag(event, ['subject', 're: thread']), isTrue);
      expect(hasTag(event, ['p', 'aa' * 32]), isTrue);
      expect(hasTag(event, ['e', 'dd' * 32, '', 'root']), isTrue);
      expect(hasTag(event, ['e', 'bb' * 32, '', 'reply']), isTrue);
      expect(hasTag(event, ['p', 'cc' * 32]), isTrue);
    });

    test('profile metadata is a JSON kind-0 event', () async {
      final event = await social.updateProfile(
        name: 'alice',
        displayName: 'Alice',
        about: 'hi',
        picture: 'https://example.com/a.png',
        nip05: 'alice@example.com',
        lud16: 'alice@wallet.example',
        bot: true,
        birthday: const NostrMetadataBirthday(year: 1990, month: 5),
      );

      expect(event.kind, 0);
      expect(event.isVerified(), isTrue);

      final metadata = jsonDecode(event.content!) as Map<String, dynamic>;
      expect(metadata['name'], 'alice');
      expect(metadata['display_name'], 'Alice');
      expect(metadata['nip05'], 'alice@example.com');
      expect(metadata['lud16'], 'alice@wallet.example');
      expect(metadata['bot'], isTrue);
      expect(metadata['birthday'], {'year': 1990, 'month': 5});
    });

    test('follow list uses p tags with relay hints', () async {
      final event = await social.updateFollowList(
        followedPubkeys: ['aa' * 32, 'bb' * 32],
        relayHints: {'aa' * 32: 'wss://relay.example'},
      );

      expect(event.kind, 3);
      expect(hasTag(event, ['p', 'aa' * 32, 'wss://relay.example']), isTrue);
      expect(hasTag(event, ['p', 'bb' * 32]), isTrue);
    });

    test('deletion, repost, reaction and comment carry the right tags',
        () async {
      final deletion = await social.createDeletionRequest(
        eventIds: ['aa' * 32],
        addressCoordinates: ['30023:bb:slug'],
        reason: 'duplicate',
      );
      expect(deletion.kind, 5);
      expect(hasTag(deletion, ['e', 'aa' * 32]), isTrue);
      expect(hasTag(deletion, ['a', '30023:bb:slug']), isTrue);
      expect(hasTag(deletion, ['k', '5']), isTrue);

      final note = await social.createTextNote('original');
      final repost = await social.createRepost(
        note: note,
        relayUrl: 'wss://relay.example',
      );
      expect(repost.kind, 6);
      expect(hasTag(repost, ['e', note.id!, 'wss://relay.example']), isTrue);
      expect(hasTag(repost, ['p', signer.publicKey]), isTrue);
      expect(repost.content, note.serialized());

      final reaction = await social.createReaction(
        targetEventId: 'cc' * 32,
        targetAuthorPubkey: 'dd' * 32,
        emoji: '🤙',
        targetKind: '1',
        relayUrl: 'wss://relay.example',
      );
      expect(reaction.kind, 7);
      expect(reaction.content, '🤙');
      expect(hasTag(reaction, ['e', 'cc' * 32, 'wss://relay.example']), isTrue);
      expect(hasTag(reaction, ['p', 'dd' * 32]), isTrue);
      expect(hasTag(reaction, ['k', '1']), isTrue);

      final comment = await social.createComment(
        content: 'nice',
        targetEventId: 'ee' * 32,
        targetAuthorPubkey: 'ff' * 32,
        targetKind: 1111,
        rootEventId: '11' * 32,
        rootAuthorPubkey: '22' * 32,
        rootKind: 30023,
        relayUrl: 'wss://relay.example',
      );
      expect(comment.kind, 1111);
      expect(comment.isVerified(), isTrue);
      // root scope is uppercase, direct parent is lowercase (NIP-22).
      expect(hasTag(comment, ['K', '30023']), isTrue);
      expect(
        hasTag(comment, ['E', '11' * 32, 'wss://relay.example', '22' * 32]),
        isTrue,
      );
      expect(hasTag(comment, ['P', '22' * 32, 'wss://relay.example']), isTrue);
      expect(hasTag(comment, ['k', '1111']), isTrue);
      expect(
        hasTag(comment, ['e', 'ee' * 32, 'wss://relay.example', 'ff' * 32]),
        isTrue,
      );
      expect(hasTag(comment, ['p', 'ff' * 32, 'wss://relay.example']), isTrue);
      expect(comment.tags!.any((t) => t[0] == 'I'), isFalse);
      expect(comment.tags!.any((t) => t[0] == 'A'), isFalse);
    });

    test('top-level comment scopes root to the commented event', () async {
      final comment = await social.createComment(
        content: 'great article',
        targetEventId: 'aa' * 32,
        targetAuthorPubkey: 'bb' * 32,
        targetKind: 30023,
      );

      expect(comment.kind, 1111);
      expect(comment.isVerified(), isTrue);
      expect(hasTag(comment, ['K', '30023']), isTrue);
      expect(hasTag(comment, ['E', 'aa' * 32, '', 'bb' * 32]), isTrue);
      expect(hasTag(comment, ['P', 'bb' * 32]), isTrue);
      expect(hasTag(comment, ['k', '30023']), isTrue);
      expect(hasTag(comment, ['e', 'aa' * 32, '', 'bb' * 32]), isTrue);
      expect(hasTag(comment, ['p', 'bb' * 32]), isTrue);
    });

    test('old event-comment call shape emits the same tags as before',
        () async {
      final comment = await social.createComment(
        content: 'nice',
        targetEventId: 'ee' * 32,
        targetAuthorPubkey: 'ff' * 32,
        targetKind: 1111,
        rootEventId: '11' * 32,
        rootAuthorPubkey: '22' * 32,
        rootKind: 30023,
        relayUrl: 'wss://relay.example',
      );

      expect(comment.tags, [
        ['K', '30023'],
        ['E', '11' * 32, 'wss://relay.example', '22' * 32],
        ['P', '22' * 32, 'wss://relay.example'],
        ['k', '1111'],
        ['e', 'ee' * 32, 'wss://relay.example', 'ff' * 32],
        ['p', 'ff' * 32, 'wss://relay.example'],
      ]);
    });

    test('spec vector: comment on a NIP-94 file (E/K/P + e/k/p)', () async {
      const fileId =
          '768ac8720cdeb59227cf95e98b66560ef03d8bc9a90d721779e76e68fb42f5e6';
      const author =
          '3721e07b079525289877c366ccab47112bdff3d1b44758ca333feb2dbbbbe5bb';

      final comment = await social.createComment(
        content: 'Great file!',
        targetEventId: fileId,
        targetAuthorPubkey: author,
        targetKind: 1063,
        relayUrl: 'wss://example.relay',
      );

      expect(
        hasTag(comment, ['E', fileId, 'wss://example.relay', author]),
        isTrue,
      );
      expect(hasTag(comment, ['K', '1063']), isTrue);
      expect(
        hasTag(comment, ['e', fileId, 'wss://example.relay', author]),
        isTrue,
      );
      expect(hasTag(comment, ['k', '1063']), isTrue);
      expect(tagValue(comment, 'P'), author);
      expect(tagValue(comment, 'p'), author);
    });

    test('spec vector: reply to a comment (root and parent differ)', () async {
      const rootId =
          '768ac8720cdeb59227cf95e98b66560ef03d8bc9a90d721779e76e68fb42f5e6';
      const rootAuthor =
          'fd913cd6fa9edb8405750cd02a8bbe16e158b8676c0e69fdc27436cc4a54cc9a';
      const parentId =
          '5c83da77af1dec6d7289834998ad7aafbd9e2191396d75ec3cc27f5a77226f36';
      const parentAuthor =
          '93ef2ebaaf9554661f33e79949007900bbc535d239a4c801c33a4d67d3e7f546';

      final comment = await social.createComment(
        content: 'This is a reply to "Great file!"',
        targetEventId: parentId,
        targetAuthorPubkey: parentAuthor,
        targetKind: 1111,
        rootEventId: rootId,
        rootAuthorPubkey: rootAuthor,
        rootKind: 1063,
        relayUrl: 'wss://example.relay',
      );

      expect(
        hasTag(comment, ['E', rootId, 'wss://example.relay', rootAuthor]),
        isTrue,
      );
      expect(hasTag(comment, ['K', '1063']), isTrue);
      expect(
        hasTag(comment, ['e', parentId, 'wss://example.relay', parentAuthor]),
        isTrue,
      );
      expect(hasTag(comment, ['k', '1111']), isTrue);
      expect(tagValue(comment, 'P'), rootAuthor);
      expect(tagValue(comment, 'p'), parentAuthor);
    });

    test('spec vector: blog post address comment (A/a + K/k)', () async {
      const address =
          '30023:3c9849383bdea883b0bd16fece1ed36d37e37cdde3ce43b17ea4e9192'
          'ec11289:f9347ca7';
      const author =
          '3c9849383bdea883b0bd16fece1ed36d37e37cdde3ce43b17ea4e9192ec11289';
      const parentId =
          '5b4fc7fed15672fefe65d2426f67197b71ccc82aa0cc8a9e94f683eb78e07651';
      const relay = 'wss://example.relay';

      final comment = await social.createComment(
        content: 'Great blog post!',
        rootAddress: address,
        parentAddress: address,
        rootKind: 30023,
        targetKind: 30023,
        targetEventId: parentId,
        targetAuthorPubkey: author,
        relayUrl: relay,
      );

      expect(comment.tags, [
        ['A', address, relay],
        ['K', '30023'],
        ['P', author, relay],
        ['a', address, relay],
        ['e', parentId, relay, author],
        ['k', '30023'],
        ['p', author, relay],
      ]);
    });

    test('address comment derives K/k and author from the coordinate',
        () async {
      const address =
          '30023:3c9849383bdea883b0bd16fece1ed36d37e37cdde3ce43b17ea4e9192'
          'ec11289:f9347ca7';

      final comment = await social.createComment(
        content: 'top level',
        rootAddress: address,
      );

      expect(hasTag(comment, ['A', address]), isTrue);
      expect(hasTag(comment, ['K', '30023']), isTrue);
      expect(hasTag(comment, ['a', address]), isTrue);
      expect(hasTag(comment, ['k', '30023']), isTrue);
      expect(
        tagValue(comment, 'P'),
        '3c9849383bdea883b0bd16fece1ed36d37e37cdde3ce43b17ea4e9192ec11289',
      );
    });

    test('spec vector: website URL comment (I/i + K/k)', () async {
      const url = 'https://abc.com/articles/1';

      final comment = await social.createComment(
        content: 'Nice article!',
        rootExternalId: url,
        externalKind: 'web',
      );

      expect(comment.tags, [
        ['I', url],
        ['K', 'web'],
        ['i', url],
        ['k', 'web'],
      ]);
    });

    test('spec vector: podcast comment and podcast reply', () async {
      const episode = 'podcast:item:guid:d98d189b-dc7b-45b1-8720-d4b98690f31f';
      const hint = 'https://fountain.fm/episode/z1y9TMQRuqXl2awyrQxg';
      const commentId =
          '80c48d992a38f9c445b943a9c9f1010b396676013443765750431a9004bdac05';
      const author =
          '252f10c83610ebca1a059c0bae8255eba2f95be4d1d7bcfa89d7248a82d9f111';

      final topLevel = await social.createComment(
        content: 'This was a great episode!',
        rootExternalId: episode,
        externalKind: 'podcast:item:guid',
        relayUrl: hint,
      );

      expect(topLevel.tags, [
        ['I', episode, hint],
        ['K', 'podcast:item:guid'],
        ['i', episode, hint],
        ['k', 'podcast:item:guid'],
      ]);

      final reply = await social.createComment(
        content: "I'm replying to the above comment.",
        rootExternalId: episode,
        externalKind: 'podcast:item:guid',
        targetEventId: commentId,
        targetAuthorPubkey: author,
        targetKind: 1111,
        relayUrl: 'wss://example.relay',
      );

      expect(tagValue(reply, 'I'), episode);
      expect(hasTag(reply, ['K', 'podcast:item:guid']), isTrue);
      expect(
        hasTag(reply, [
          'e',
          commentId,
          'wss://example.relay',
          author,
        ]),
        isTrue,
      );
      expect(hasTag(reply, ['k', '1111']), isTrue);
      expect(tagValue(reply, 'p'), author);
      expect(NostrComment.tryParse(reply)?.parentEventId, commentId);
    });

    test('mixed scope families are rejected', () async {
      const address =
          '30023:3c9849383bdea883b0bd16fece1ed36d37e37cdde3ce43b17ea4e9192'
          'ec11289:f9347ca7';

      await expectLater(
        social.createComment(
          content: 'mixed roots',
          rootAddress: address,
          rootExternalId: 'https://abc.com/articles/1',
        ),
        throwsArgumentError,
      );

      await expectLater(
        social.createComment(
          content: 'mixed parents',
          rootExternalId: 'https://abc.com/articles/1',
          externalKind: 'web',
          parentAddress: address,
        ),
        throwsArgumentError,
      );

      await expectLater(
        social.createComment(
          content: 'event root with address parent',
          targetEventId: 'aa' * 32,
          targetAuthorPubkey: 'bb' * 32,
          targetKind: 1,
          parentAddress: address,
        ),
        throwsArgumentError,
      );
    });

    test('invalid comment scopes throw ArgumentError', () async {
      await expectLater(
        social.createComment(content: '   ', targetEventId: 'aa' * 32),
        throwsArgumentError,
      );

      await expectLater(
        social.createComment(
          content: 'bad address',
          rootAddress: 'not-an-address',
        ),
        throwsArgumentError,
      );

      await expectLater(
        social.createComment(
          content: 'empty external',
          rootExternalId: ' ',
          externalKind: 'web',
        ),
        throwsArgumentError,
      );

      await expectLater(
        social.createComment(
          content: 'no kind',
          targetEventId: 'aa' * 32,
          targetAuthorPubkey: 'bb' * 32,
        ),
        throwsArgumentError,
      );
    });

    test('NostrComment parses event, address and external scopes', () async {
      const address =
          '30023:3c9849383bdea883b0bd16fece1ed36d37e37cdde3ce43b17ea4e9192'
          'ec11289:f9347ca7';

      final eventComment = await social.createComment(
        content: 'event',
        targetEventId: 'aa' * 32,
        targetAuthorPubkey: 'bb' * 32,
        targetKind: 1,
      );
      final parsedEvent = NostrComment.parse(eventComment);
      expect(parsedEvent.rootEventId, 'aa' * 32);
      expect(parsedEvent.rootAuthorPubkey, 'bb' * 32);
      expect(parsedEvent.rootKind, '1');
      expect(parsedEvent.parentEventId, 'aa' * 32);
      expect(parsedEvent.parentKind, '1');
      expect(parsedEvent.rootAddress, isNull);
      expect(parsedEvent.rootExternalId, isNull);

      final addressComment = await social.createComment(
        content: 'address',
        rootAddress: address,
      );
      final parsedAddress = NostrComment.parse(addressComment);
      expect(parsedAddress.rootAddress, address);
      expect(parsedAddress.parentAddress, address);
      expect(parsedAddress.rootEventId, isNull);
      expect(parsedAddress.rootExternalId, isNull);
      expect(parsedAddress.rootKind, '30023');
      expect(parsedAddress.parentKind, '30023');

      final externalComment = await social.createComment(
        content: 'external',
        rootExternalId: 'https://abc.com/articles/1',
        externalKind: 'web',
      );
      final parsedExternal = NostrComment.parse(externalComment);
      expect(parsedExternal.rootExternalId, 'https://abc.com/articles/1');
      expect(parsedExternal.parentExternalId, 'https://abc.com/articles/1');
      expect(parsedExternal.rootKind, 'web');
      expect(parsedExternal.parentKind, 'web');

      expect(
        NostrComment.tryParse(await social.createTextNote('note')),
        isNull,
      );
    });

    test('relay list maps read/write flags', () async {
      final event = await social.updateRelayList(
        relays: {
          'wss://both.example': (read: true, write: true),
          'wss://read.example': (read: true, write: false),
          'wss://write.example': (read: false, write: true),
        },
      );

      expect(event.kind, 10002);
      final tags = event.tags!;
      expect(
        tags.any(
          (t) => t[0] == 'r' && t[1] == 'wss://both.example' && t.length == 2,
        ),
        isTrue,
      );
      expect(
        tags.any(
          (t) => t[0] == 'r' && t[1] == 'wss://read.example' && t[2] == 'read',
        ),
        isTrue,
      );
      expect(
        tags.any(
          (t) =>
              t[0] == 'r' && t[1] == 'wss://write.example' && t[2] == 'write',
        ),
        isTrue,
      );
    });

    test('long-form article and generic list events are signed', () async {
      final article = await social.createLongFormArticle(
        content: '# body',
        dTagIdentifier: 'slug',
        title: 'Title',
        image: 'https://example.com/cover.png',
        summary: 'summary',
        publishedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        hashtags: ['nostr'],
        references: ['https://example.com'],
      );

      expect(article.kind, 30023);
      expect(article.isVerified(), isTrue);
      expect(hasTag(article, ['d', 'slug']), isTrue);
      expect(hasTag(article, ['title', 'Title']), isTrue);
      expect(hasTag(article, ['published_at', '1700000000']), isTrue);
      expect(hasTag(article, ['t', 'nostr']), isTrue);
      expect(hasTag(article, ['r', 'https://example.com']), isTrue);

      final list = await social.createListEvent(
        kind: 10000,
        entries: [
          ['p', 'aa' * 32],
        ],
        dTag: 'mute',
        title: 'Muted',
      );

      expect(list.kind, 10000);
      expect(list.isVerified(), isTrue);
      expect(hasTag(list, ['p', 'aa' * 32]), isTrue);
      expect(hasTag(list, ['d', 'mute']), isTrue);
      expect(hasTag(list, ['title', 'Muted']), isTrue);
    });
  });
}
