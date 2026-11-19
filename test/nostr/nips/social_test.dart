import 'dart:convert';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
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
      );

      expect(event.kind, 0);
      expect(event.isVerified(), isTrue);

      final metadata = jsonDecode(event.content!) as Map<String, dynamic>;
      expect(metadata['name'], 'alice');
      expect(metadata['display_name'], 'Alice');
      expect(metadata['nip05'], 'alice@example.com');
      expect(metadata['lud16'], 'alice@wallet.example');
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
        targetKind: 30023,
        rootEventId: '11' * 32,
        rootAuthorPubkey: '22' * 32,
      );
      expect(comment.kind, 22);
      expect(hasTag(comment, ['I', 'ee' * 32]), isTrue);
      expect(hasTag(comment, ['P', 'ff' * 32]), isTrue);
      expect(hasTag(comment, ['K', '30023']), isTrue);
      expect(hasTag(comment, ['E', '11' * 32]), isTrue);
      expect(hasTag(comment, ['A', '22' * 32]), isTrue);
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
