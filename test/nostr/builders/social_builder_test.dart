import 'dart:convert';

import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

void main() {
  late NostrEventSigner signer;
  late NostrSocialBuilder builder;

  setUp(() {
    signer = NostrLocalKeySigner(NostrKeyPairs.generate());
    builder = NostrSocialBuilder(signer: signer);
  });

  group('NostrSocialBuilder', () {
    test('text note is signed and verifiable', () async {
      final note = await builder.createTextNote('hello nostr');

      expect(note.kind, 1);
      expect(note.content, 'hello nostr');
      expect(note.isVerified(), isTrue);
    });

    test('reply note carries NIP-10 root/reply/p tags', () async {
      final note = await builder.createTextNote(
        'a reply',
        replyTo: (
          eventId: 'ee' * 32,
          authorPubkey: 'aa' * 32,
          rootEventId: 'rr' * 32,
        ),
      );

      final eTags = note.tags!.where((t) => t.first == 'e').toList();
      expect(eTags.length, 2);
      // Root first with marker.
      expect(eTags[0][1], 'rr' * 32);
      expect(eTags[0].last, 'root');
      expect(eTags[1][1], 'ee' * 32);
      expect(eTags[1].last, 'reply');

      final pTags = note.tags!.where((t) => t.first == 'p').toList();
      expect(pTags.map((t) => t[1]), contains('aa' * 32));
    });

    test('profile metadata serializes name and nip05', () async {
      final profile = await builder.updateProfile(
        name: 'satoshi',
        about: 'building bitcoin',
        nip05: 'satoshi@example.com',
      );

      final decoded = jsonDecode(profile.content!) as Map<String, dynamic>;
      expect(decoded['name'], 'satoshi');
      expect(decoded['about'], 'building bitcoin');
      expect(decoded['nip05'], 'satoshi@example.com');
    });

    test('follow list produces one p tag per follow', () async {
      final follows = await builder.updateFollowList(
        followedPubkeys: ['11' * 32, '22' * 32],
        relayHints: {'11' * 32: 'wss://relay.example'},
      );

      expect(follows.kind, 3);
      final pTags = follows.tags!;
      expect(pTags.length, 2);
      expect(pTags[0][1], '11' * 32);
      expect(pTags[0][2], 'wss://relay.example');
    });

    test('repost embeds serialized note and e/p tags', () async {
      final target = await builder.createTextNote('original');
      final repost = await NostrSocialBuilder(
        signer: signer,
      ).createRepost(note: target, relayUrl: 'wss://relay.example');

      expect(repost.kind, 6);
      expect(
        repost.tags!
            .any((t) => t.length >= 2 && t[0] == 'e' && t[1] == target.id),
        isTrue,
      );
      expect(
        repost.tags!
            .any((t) => t.length >= 2 && t[0] == 'p' && t[1] == target.pubkey),
        isTrue,
      );
      final embedded = jsonDecode(repost.content!) as List;
      expect(embedded.first, 'EVENT');
    });

    test('reaction defaults to plus and references kind', () async {
      final reaction = await builder.createReaction(
        targetEventId: 'ab' * 32,
        targetAuthorPubkey: 'cd' * 32,
        targetKind: '1',
      );

      expect(reaction.kind, 7);
      expect(reaction.content, '+');
      expect(
        reaction.tags!.any((t) => t.length >= 2 && t[0] == 'k' && t[1] == '1'),
        isTrue,
      );
    });

    test('relay list encodes read/write markers per NIP-65', () async {
      final relays = await builder.updateRelayList(
        relays: {
          'wss://both.example': (read: true, write: true),
          'wss://read.example': (read: true, write: false),
          'wss://write.example': (read: false, write: true),
        },
      );

      expect(relays.kind, 10002);

      String? marker(String url) {
        for (final tag in relays.tags!) {
          if (tag.length >= 2 && tag[1] == url) {
            return tag.length > 2 ? tag[2] : null;
          }
        }
        return null;
      }

      expect(marker('wss://both.example'), isNull);
      expect(marker('wss://read.example'), 'read');
      expect(marker('wss://write.example'), 'write');
    });

    test('article carries d/title/published_at tags', () async {
      final article = await builder.createLongFormArticle(
        content: '# Hello\n\nBody...',
        dTagIdentifier: 'my-post',
        title: 'My Post',
        hashtags: ['nostr', 'dart'],
        publishedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(article.kind, 30023);
      bool hasTag(String a, String b) =>
          article.tags!.any((t) => t.length >= 2 && t[0] == a && t[1] == b);

      expect(hasTag('d', 'my-post'), isTrue);
      expect(hasTag('title', 'My Post'), isTrue);
      expect(hasTag('t', 'nostr'), isTrue);
      expect(hasTag('published_at', '1700000000'), isTrue);
    });

    test('generic NIP-51 list event keeps custom entries', () async {
      final muteList = await builder.createListEvent(
        kind: 10000,
        entries: [
          ['p', '33' * 32],
        ],
        title: 'my mutes',
      );

      expect(muteList.kind, 10000);
      expect(muteList.content, '');
      expect(
        muteList.tags!
            .any((t) => t.length >= 2 && t[0] == 'p' && t[1] == '33' * 32),
        isTrue,
      );
      expect(
        muteList.tags!
            .any((t) => t.length >= 2 && t[0] == 'title' && t[1] == 'my mutes'),
        isTrue,
      );
    });
  });
}
