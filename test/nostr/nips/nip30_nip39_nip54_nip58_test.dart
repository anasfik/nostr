import 'package:dart_nostr/dart_nostr.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final logger = Nostr.instance.services.logger;

  NostrEventSigner newSigner() => NostrLocalKeySigner(NostrKeyPairs.generate());

  group('NIP-30 custom emoji', () {
    const nip30 = NostrNip30();

    test('finds shortcodes like nostr-tools does', () {
      final matches =
          NostrNip30.matchAll('Hello :blobcat: :disputed: ::joy:joy:');

      expect(matches, hasLength(2));
      expect(matches[0].name, 'blobcat');
      expect(matches[0].shortcode, ':blobcat:');
      expect(matches[0].start, 6);
      expect(matches[0].end, 15);
      expect(matches[1].name, 'disputed');
      expect(matches[1].start, 16);
      expect(matches[1].end, 26);
    });

    test('shortcodes can contain hyphens and underscores', () {
      final matches =
          NostrNip30.matchAll('Hi :party-parrot: :blob_cat-2: a-:smile:');

      expect(
        [for (final m in matches) '${m.name}@${m.start}-${m.end}'],
        ['party-parrot@3-17', 'blob_cat-2@18-30', 'smile@33-40'],
      );
    });

    test('replaces matched shortcodes only', () {
      final result = NostrNip30.replaceAll(
        'Hello :blobcat: :disputed: ::joy:joy:',
        (m) => '<img src="https://ditto.pub/emoji/${m.name}.png" />',
      );

      expect(
        result,
        'Hello <img src="https://ditto.pub/emoji/blobcat.png" /> '
        '<img src="https://ditto.pub/emoji/disputed.png" /> ::joy:joy:',
      );
    });

    test('parses emoji tags, including the set address', () {
      final event = NostrEvent(
        id: null,
        kind: 1,
        content: 'Hello :gleasonator:',
        sig: null,
        pubkey: 'a' * 64,
        createdAt: DateTime.now(),
        tags: [
          const [
            'emoji',
            'gleasonator',
            'https://example.com/g.png',
            '30030:p:set',
          ],
          const ['emoji', 'short', 'https://example.com/s.png'],
          const ['emoji', 'broken'],
          ['p', 'b' * 64],
        ],
      );

      final emojis = NostrNip30.parseEmojiTags(event);
      expect(emojis, hasLength(2));
      expect(emojis[0].name, 'gleasonator');
      expect(emojis[0].shortcode, ':gleasonator:');
      expect(emojis[0].url, 'https://example.com/g.png');
      expect(emojis[0].setAddress, '30030:p:set');
      expect(emojis[1].setAddress, isNull);
      expect(NostrNip30.emojiTag(emojis[0]), [
        'emoji',
        'gleasonator',
        'https://example.com/g.png',
        '30030:p:set',
      ]);
    });

    test('builds a signed kind 30030 emoji set and parses it back', () async {
      final signer = newSigner();
      final event = await NostrNip30.createEmojiSet(
        signer: signer,
        identifier: 'blobcats',
        title: 'Blobcats',
        emojis: const [
          Nip30Emoji(name: 'blobcat', url: 'https://example.com/b.png'),
        ],
      );

      expect(event.kind, 30030);
      expect(event.id, isNotNull);
      expect(event.sig, isNotNull);
      expect(event.pubkey, signer.publicKey);
      expect(event.tags, [
        ['d', 'blobcats'],
        ['title', 'Blobcats'],
        ['emoji', 'blobcat', 'https://example.com/b.png'],
      ]);

      final parsed = NostrNip30.parseEmojiSet(event);
      expect(parsed.single.name, 'blobcat');
      expect(
        NostrNip30.parseEmojiSet(
          NostrEvent(
            id: null,
            kind: 1,
            content: '',
            sig: null,
            pubkey: signer.publicKey,
            createdAt: DateTime.now(),
            tags: const [
              ['emoji', 'x', 'https://example.com/x.png'],
            ],
          ),
        ),
        isEmpty,
      );
      expect(nip30, isNotNull);
    });
  });

  group('NIP-39 identity claims', () {
    final nips = NostrNips(logger: logger);
    final signer = newSigner();
    final pubkey = signer.publicKey;

    NostrEvent proofsEvent(List<List<String>> tags) => NostrEvent(
          id: null,
          kind: 10011,
          content: '',
          sig: null,
          pubkey: pubkey,
          createdAt: DateTime.now(),
          tags: tags,
        );

    test('parses i tags and ignores malformed ones', () {
      final claims = NostrNip39.parseClaims(
        proofsEvent([
          ['i', 'github:semisol', '9721ce4ee4fceb91c9711ca2a6c9a5ab'],
          ['i', 'mastodon:bitcoinhackers.org/@semisol', '109775066'],
          ['i', 'telegram:1087295469', 'nostrdirectory/770', 'extra', 'ok'],
          ['i', 'nocolon', 'proof'],
          ['i', 'github:', 'proof'],
          ['p', pubkey],
          ['i', 'twitter:semisol_public'],
        ]),
      );

      expect(claims, hasLength(3));
      expect(claims[0].platform, 'github');
      expect(claims[0].identity, 'semisol');
      expect(claims[0].platformIdentity, 'github:semisol');
      expect(claims[1].platform, 'mastodon');
      expect(claims[1].identity, 'bitcoinhackers.org/@semisol');
      expect(claims[2].platform, 'telegram');
      expect(claims[2].proof, 'nostrdirectory/770');
    });

    test('validates platform names and builds proof urls', () {
      expect(NostrNip39.isValidPlatform('github'), isTrue);
      expect(NostrNip39.isValidPlatform('foo.bar-baz/qux'), isTrue);
      expect(NostrNip39.isValidPlatform('has:colon'), isFalse);
      expect(NostrNip39.isValidPlatform('UPPER'), isFalse);

      const github = Nip39IdentityClaim(
        platform: 'github',
        identity: 'alice',
        proof: 'abc',
      );
      const discord = Nip39IdentityClaim(
        platform: 'discord',
        identity: 'alice',
        proof: 'g/c/m',
      );
      const unknown =
          Nip39IdentityClaim(platform: 'nope', identity: 'a', proof: 'b');

      expect(
        NostrNip39.proofUrl(github).toString(),
        'https://gist.github.com/alice/abc',
      );
      expect(
        NostrNip39.proofUrl(discord).toString(),
        'https://discord.com/channels/g/c/m',
      );
      expect(NostrNip39.proofUrl(unknown), isNull);
      expect(NostrNip39.identityTag(github), ['i', 'github:alice', 'abc']);
    });

    test('verification text uses the npub form', () {
      final npub = nips.nip19.encodePublicKeyToNpub(pubkey);
      final text = NostrNip39.verificationText(npub);

      expect(
        text,
        'Verifying that I control the following Nostr public key: $npub',
      );
      expect(NostrNip39.containsVerificationText(text, npub), isTrue);
      expect(NostrNip39.containsVerificationText('other', npub), isFalse);

      final nip39 = NostrNip39(signer: signer, bech32: nips.nip19);
      expect(nip39.npubOf(pubkey), npub);
      expect(nip39.npubOf(npub), npub);
    });

    test('publishes a signed kind 10011 list and reparses it', () async {
      final nip39 = NostrNip39(signer: signer, bech32: nips.nip19);
      final event = await nip39.publishIdentityProofs(
        claims: const [
          Nip39IdentityClaim(
            platform: 'github',
            identity: 'alice',
            proof: 'gist1',
          ),
          Nip39IdentityClaim(
            platform: 'twitter',
            identity: 'alice',
            proof: 'tweet1',
          ),
        ],
      );

      expect(event.kind, 10011);
      expect(event.pubkey, pubkey);
      expect(event.id, isNotNull);
      expect(NostrNip39.parseClaims(event), hasLength(2));
    });

    test('verifies a github gist through an injected client', () async {
      final npub = nips.nip19.encodePublicKeyToNpub(pubkey);
      final nip39 = NostrNip39(
        signer: signer,
        bech32: nips.nip19,
        httpClient: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://gist.github.com/alice/gist1/raw',
          );
          return http.Response(
            'Verifying that I control the following Nostr public key: $npub',
            200,
          );
        }),
      );

      expect(
        await nip39.verifyGithub(
          pubkey: pubkey,
          username: 'alice',
          proof: 'gist1',
        ),
        isTrue,
      );

      final failing = NostrNip39(
        signer: signer,
        bech32: nips.nip19,
        httpClient: MockClient((_) async => http.Response('nope', 200)),
      );
      expect(
        await failing.verifyGithub(
          pubkey: pubkey,
          username: 'alice',
          proof: 'gist1',
        ),
        isFalse,
      );

      expect(
        () => nip39.verifyClaim(
          claim: const Nip39IdentityClaim(
            platform: 'twitter',
            identity: 'alice',
            proof: '1',
          ),
          pubkey: pubkey,
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('NIP-54 wiki and highlights', () {
    final signer = newSigner();

    test('normalizes d tags per the spec examples', () {
      const cases = {
        'Wiki Article': 'wiki-article',
        "What's Up?": 'whats-up',
        '  Hello  World  ': 'hello-world',
        'Article 1': 'article-1',
        'ウィキペディア': 'ウィキペディア',
        'Ñoño': 'ñoño',
        'Москва': 'москва',
        '日本語 Article': '日本語-article',
        '日本語 記事': '日本語-記事',
        'Биткойн': 'биткойн',
        'lightning network': 'lightning-network',
        'user@example.com': 'userexamplecom',
        r'$special#chars!': 'specialchars',
        'C++ & C#': 'c-c',
        'snake_case': 'snakecase',
        'multiple   spaces': 'multiple-spaces',
        '-- dashes --': 'dashes',
        'a -- b': 'a-b',
        '😀 smile': 'smile',
        'love ❤️': 'love',
        'family 👨‍👩‍👧 trip': 'family-trip',
        '👍🏽 ok': 'ok',
        'user123': 'user123',
        'привет': 'привет',
        'こんにちは': 'こんにちは',
      };
      for (final entry in cases.entries) {
        expect(
          NostrNip54.normalizeIdentifier(entry.key),
          entry.value,
          reason: 'input: ${entry.key}',
        );
      }
    });

    test('builds a signed article and parses it back', () async {
      final nip54 = NostrNip54(signer: signer);
      final event = await nip54.createArticle(
        title: 'Wiki Article',
        content: 'A wiki is a hypertext publication.',
        summary: 'About wikis',
      );

      expect(event.kind, 30818);
      expect(event.pubkey, signer.publicKey);
      expect(event.id, isNotNull);
      expect(event.tags!.first, ['d', 'wiki-article']);

      final article = NostrNip54.parseArticle(event);
      expect(article.identifier, 'wiki-article');
      expect(article.title, 'Wiki Article');
      expect(article.summary, 'About wikis');
      expect(article.content, 'A wiki is a hypertext publication.');
    });

    test('article requires a non-empty d tag', () async {
      final nip54 = NostrNip54(signer: signer);
      expect(
        () => nip54.createArticle(title: '!!!', content: 'x'),
        throwsArgumentError,
      );
      expect(
        () => NostrNip54.parseArticle(
          NostrEvent(
            id: null,
            kind: 30818,
            content: 'x',
            sig: null,
            pubkey: signer.publicKey,
            createdAt: DateTime.now(),
            tags: const [],
          ),
        ),
        throwsFormatException,
      );
    });

    test('builds a merge request and a redirect', () async {
      final nip54 = NostrNip54(signer: signer);

      final merge = await nip54.createMergeRequest(
        destinationAddress: '30818:${signer.publicKey}:bitcoin',
        destinationPubkey: signer.publicKey,
        sourceEventId: 'e' * 64,
        baseEventId: 'b' * 64,
        explanation: 'block size limit',
      );

      expect(merge.kind, 818);
      expect(merge.tags, [
        ['a', '30818:${signer.publicKey}:bitcoin'],
        ['e', 'b' * 64],
        ['p', signer.publicKey],
        ['e', 'e' * 64, 'source'],
      ]);

      final redirect = await nip54.createRedirect(
        identifier: 'BTC',
        targetAddresses: ['30818:${signer.publicKey}:bitcoin'],
      );
      expect(redirect.kind, 30819);
      expect(redirect.tags, [
        ['d', 'btc'],
        ['a', '30818:${signer.publicKey}:bitcoin'],
      ]);
      expect(NostrNip54.parseRedirect(redirect).identifier, 'btc');
    });

    test('builds a highlight and parses e/a/p/context tags', () async {
      final nip54 = NostrNip54(signer: signer);
      final event = await nip54.createHighlight(
        content: 'highlighted text',
        eventId: 'h' * 64,
        relayUrl: 'wss://relay.example',
        context: 'surrounding paragraph',
        sourceUrl: 'https://example.com/article',
        authors: [
          Nip54HighlightAuthor(
            pubkey: signer.publicKey,
            relay: 'wss://relay.example',
            role: 'author',
          ),
        ],
      );

      expect(event.kind, 9802);
      expect(event.content, 'highlighted text');
      expect(event.tags, [
        ['e', 'h' * 64, 'wss://relay.example'],
        ['r', 'https://example.com/article'],
        ['context', 'surrounding paragraph'],
        ['p', signer.publicKey, 'wss://relay.example', 'author'],
      ]);

      final highlight = NostrNip54.parseHighlight(event);
      expect(highlight.content, 'highlighted text');
      expect(highlight.eventId, 'h' * 64);
      expect(highlight.address, isNull);
      expect(highlight.relay, 'wss://relay.example');
      expect(highlight.context, 'surrounding paragraph');
      expect(highlight.sourceUrl, 'https://example.com/article');
      expect(highlight.authors.single.pubkey, signer.publicKey);
      expect(highlight.authors.single.role, 'author');

      final addressed = await nip54.createHighlight(
        content: 'part',
        address: '30023:${signer.publicKey}:post',
      );
      final parsed = NostrNip54.parseHighlight(addressed);
      expect(parsed.address, '30023:${signer.publicKey}:post');
      expect(parsed.eventId, isNull);
    });
  });

  group('NIP-58 badges', () {
    final signer = newSigner();
    final issuer = signer.publicKey;
    final bob = newSigner().publicKey;

    test('builds a signed badge definition and parses it back', () async {
      final nip58 = NostrNip58(signer: signer);
      final event = await nip58.createBadgeDefinition(
        identifier: 'bravery',
        name: 'Medal of Bravery',
        description: 'Awarded to users demonstrating bravery',
        imageUrl: 'https://example.com/bravery.png',
        imageDimensions: '1024x1024',
        thumbs: const [
          Nip58Thumbnail(
            url: 'https://example.com/b-256.png',
            dimensions: '256x256',
          ),
          Nip58Thumbnail(
            url: 'https://example.com/b-64.png',
            dimensions: '64x64',
          ),
        ],
      );

      expect(event.kind, 30009);
      expect(event.tags, [
        ['d', 'bravery'],
        ['name', 'Medal of Bravery'],
        ['description', 'Awarded to users demonstrating bravery'],
        ['image', 'https://example.com/bravery.png', '1024x1024'],
        ['thumb', 'https://example.com/b-256.png', '256x256'],
        ['thumb', 'https://example.com/b-64.png', '64x64'],
      ]);
      expect(NostrNip58.validateBadgeDefinition(event), isTrue);

      final definition = NostrNip58.parseBadgeDefinition(event)!;
      expect(definition.identifier, 'bravery');
      expect(definition.pubkey, issuer);
      expect(definition.name, 'Medal of Bravery');
      expect(definition.imageUrl, 'https://example.com/bravery.png');
      expect(definition.imageDimensions, '1024x1024');
      expect(definition.thumbs, hasLength(2));
      expect(definition.thumbs.last.dimensions, '64x64');
      expect(definition.address, '30009:$issuer:bravery');
    });

    test('builds a signed badge award and parses it back', () async {
      final nip58 = NostrNip58(signer: signer);
      final definition = await nip58.createBadgeDefinition(
        identifier: 'bravery',
      );
      final address = NostrNip58.parseBadgeDefinition(definition)!.address;

      final event = await nip58.createBadgeAward(
        definitionAddress: address,
        recipients: [
          Nip58Recipient(pubkey: bob, relay: 'wss://relay.example'),
          Nip58Recipient(pubkey: 'c' * 64),
        ],
      );

      expect(event.kind, 8);
      expect(event.tags, [
        ['a', address],
        ['p', bob, 'wss://relay.example'],
        ['p', 'c' * 64],
      ]);
      expect(NostrNip58.validateBadgeAward(event), isTrue);

      final award = NostrNip58.parseBadgeAward(event)!;
      expect(award.address, address);
      expect(award.pubkey, issuer);
      expect(award.recipients, hasLength(2));
      expect(award.recipients.first.relay, 'wss://relay.example');
      expect(award.recipients.last.relay, isNull);

      expect(
        () => nip58.createBadgeAward(
          definitionAddress: address,
          recipients: const [],
        ),
        throwsArgumentError,
      );
    });

    test('builds profile badges (10008) and badge sets (30008)', () async {
      final nip58 = NostrNip58(signer: signer);

      final profile = await nip58.createProfileBadges(
        badges: [
          Nip58BadgePair(
            address: '30009:$issuer:bravery',
            awardEventIds: ['d' * 64],
            relays: ['wss://nostr.academy'],
          ),
          Nip58BadgePair(
            address: '30009:$issuer:honor',
            awardEventIds: ['f' * 64],
          ),
        ],
      );

      expect(profile.kind, 10008);
      expect(profile.tags, [
        ['d', 'profile_badges'],
        ['a', '30009:$issuer:bravery'],
        ['e', 'd' * 64, 'wss://nostr.academy'],
        ['a', '30009:$issuer:honor'],
        ['e', 'f' * 64],
      ]);
      expect(NostrNip58.validateProfileBadges(profile), isTrue);

      final parsedProfile = NostrNip58.parseBadgeList(profile)!;
      expect(parsedProfile.identifier, 'profile_badges');
      expect(parsedProfile.pairs, hasLength(2));
      expect(parsedProfile.pairs.first.awardEventIds, ['d' * 64]);
      expect(parsedProfile.pairs.first.relays, ['wss://nostr.academy']);
      expect(parsedProfile.pairs.last.relays, isEmpty);

      final set = await nip58.createBadgeSet(
        identifier: 'nostr-academy',
        title: 'Nostr Academy',
        description: 'Graduates',
        badges: [
          Nip58BadgePair(
            address: '30009:$issuer:bravery',
            awardEventIds: ['d' * 64],
          ),
        ],
      );

      expect(set.kind, 30008);
      final parsedSet = NostrNip58.parseBadgeList(set)!;
      expect(parsedSet.title, 'Nostr Academy');
      expect(parsedSet.pairs.single.awardEventIds, ['d' * 64]);
    });

    test('drops a tags without a matching e tag', () {
      final list = NostrNip58.parseBadgeList(
        NostrEvent(
          id: null,
          kind: 10008,
          content: '',
          sig: null,
          pubkey: issuer,
          createdAt: DateTime.now(),
          tags: const [
            ['d', 'profile_badges'],
            ['a', '30009:alice:one'],
            ['a', '30009:alice:two'],
            ['e', 'event-two'],
          ],
        ),
      )!;

      expect(list.pairs, hasLength(1));
      expect(list.pairs.single.address, '30009:alice:two');
    });
  });

  group('NIP-30/39/54/58 accessor wiring', () {
    test('stateless nip30 is cached without a signer', () {
      final nips = NostrNips(logger: logger);
      expect(nips.nip30, same(nips.nip30));
      expect(Nostr.instance.nips.nip30, same(Nostr.instance.nips.nip30));
      expect(NostrNip30.matchAll(':wave:'), hasLength(1));
    });

    test('signer-bound accessors require and cache a signer', () {
      final nips = NostrNips(logger: logger);

      expect(() => nips.nip39, throwsStateError);
      expect(() => nips.nip54, throwsStateError);
      expect(() => nips.nip58, throwsStateError);

      final signer = newSigner();
      nips.bindSigner(signer);

      expect(nips.nip39, same(nips.nip39));
      expect(nips.nip39.signer, same(signer));
      expect(nips.nip54, same(nips.nip54));
      expect(nips.nip54.signer, same(signer));
      expect(nips.nip58, same(nips.nip58));
      expect(nips.nip58.signer, same(signer));

      final other = newSigner();
      nips.bindSigner(other);
      expect(nips.nip54.signer, same(other));
      expect(nips.nip58.signer, same(other));
    });
  });
}
