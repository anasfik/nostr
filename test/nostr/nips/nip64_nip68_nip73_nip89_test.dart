import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip64/nip64.dart';
import 'package:dart_nostr/nostr/nips/nip68/nip68.dart';
import 'package:dart_nostr/nostr/nips/nip73/nip73.dart';
import 'package:dart_nostr/nostr/nips/nip89/nip89.dart';
import 'package:dart_nostr/nostr/nips/nip92/nip92.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

const String _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _hash =
    '3093509d1e0bc604ff60cb9286f4cd7c781553bc8991937befaacfdc28ec5cdc';
const String _otherHash =
    'b2e0a7a82ac9f3f3a71f1d9a78c381d5be9d1cf19dce258765c17c8a76287c93';

NostrEvent _event(
  List<List<String>> tags, {
  int kind = 1,
  String content = '',
  String pubkey = _pubkey,
}) {
  return NostrEvent(
    id: null,
    kind: kind,
    content: content,
    sig: null,
    pubkey: pubkey,
    createdAt: DateTime.utc(2024),
    tags: tags,
  );
}

/// PGN samples from 64.md at the pinned spec revision.
const String _fischerPgn = r'''[Event "F/S Return Match"]
[Site "Belgrade, Serbia JUG"]
[Date "1992.11.04"]
[Round "29"]
[White "Fischer, Robert J."]
[Black "Spassky, Boris V."]
[Result "1/2-1/2"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 {This opening is called the Ruy Lopez.} 3... a6
4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7
11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5
Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6
23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5
hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5
35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6
Nf2 42. g4 Bd3 43. Re6 1/2-1/2''';

const String _lichessDatabase = r'''[Event "Hourly HyperBullet Arena"]
[Site "https://lichess.org/wxx4GldJ"]
[Date "2017.04.01"]
[White "T_LUKE"]
[Black "decidement"]
[Result "1-0"]
[UTCDate "2017.04.01"]
[UTCTime "11:56:14"]
[WhiteElo "2047"]
[BlackElo "1984"]
[WhiteRatingDiff "+10"]
[BlackRatingDiff "-7"]
[Variant "Standard"]
[TimeControl "30+0"]
[ECO "B00"]
[Termination "Abandoned"]

1. e4 1-0


[Event "Hourly HyperBullet Arena"]
[Site "https://lichess.org/rospUdSk"]
[Date "2017.04.01"]
[White "Bastel"]
[Black "oslochess"]
[Result "1-0"]
[UTCDate "2017.04.01"]
[UTCTime "11:55:56"]
[WhiteElo "2212"]
[BlackElo "2000"]
[WhiteRatingDiff "+6"]
[BlackRatingDiff "-4"]
[Variant "Standard"]
[TimeControl "30+0"]
[ECO "A01"]
[Termination "Normal"]

1. b3 d5 2. Bb2 c6 3. Nc3 Bf5 4. d4 Nf6 5. e3 Nbd7 6. f4 Bg6 7. Nf3 Bh5
8. Bd3 e6 9. O-O Be7 10. Qe1 O-O 11. Ne5 Bg6 12. Nxg6 hxg6 13. e4 dxe4
14. Nxe4 Nxe4 15. Bxe4 Nf6 16. c4 Bd6 17. Bc2 Qc7 18. f5 Be7 19. fxe6 fxe6
20. Qxe6+ Kh8 21. Qh3+ Kg8 22. Bxg6 Qd7 23. Qe3 Bd6 24. Bf5 Qe7 25. Be6+ Kh8
26. Qh3+ Nh7 27. Bf5 Rf6 28. Qxh7# 1-0''';

/// `imeta` vectors from 68.md, with concrete hashes and pubkeys.
const List<String> _imageOne = [
  'imeta',
  'url https://nostr.build/i/my-image.jpg',
  'm image/jpeg',
  'thumbhash zOcFFIIKmXdCinaXaHcmcHUFSA==',
  'blurhash eVF\$^OI:\${M{o#*0-nNFxakD-?xVM}WEWB%iNKxvR-oetmo#R-aen\$',
  'dim 3024x4032',
  'alt A scenic photo overlooking the coast of Costa Rica',
  'x $_hash',
  'fallback https://nostrcheck.me/alt1.jpg',
  'fallback https://void.cat/alt1.jpg',
];

const List<String> _imageTwo = [
  'imeta',
  'url https://nostr.build/i/my-image2.jpg',
  'm image/jpeg',
  'thumbhash zOcFFIIKmXgzmWaXWIcmcFQEGA',
  'dim 3024x4032',
  'alt Another scenic photo overlooking the coast of Costa Rica',
  'x $_otherHash',
  'fallback https://nostrcheck.me/alt2.jpg',
  'fallback https://void.cat/alt2.jpg',
  'annotate-user $_otherPubkey:120:340',
];

void main() {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
  final appAddress = NostrEventAddress.parse('31990:$_pubkey:abcd');

  group('NIP-64', () {
    test('kind and template tags', () {
      expect(NostrNip64.kind, 64);

      final event = NostrNip64.generateTemplate(
        pgn: '1. e4 *',
        alt: 'Chess game',
      );

      expect(event.kind, 64);
      expect(event.content, '1. e4 *');
      expect(event.tags, [
        ['alt', 'Chess game'],
      ]);
    });

    test('parses every PGN sample from the spec', () {
      final unknown = NostrPgnGame.parse('*');
      expect(unknown.tags, isEmpty);
      expect(unknown.result, '*');

      final oneMove = NostrPgnGame.parse('1. e4 *');
      expect(oneMove.movetext, '1. e4 *');

      final opening = NostrPgnGame.parse(
        '[White "Fischer, Robert J."]\n'
        '[Black "Spassky, Boris V."]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 {This opening is called the Ruy Lopez.} *',
      );
      expect(opening.tag('White'), 'Fischer, Robert J.');
      expect(opening.tag('Black'), 'Spassky, Boris V.');
      expect(opening.movetext,
          contains('{This opening is called the Ruy Lopez.}'));

      final full = NostrPgnGame.parse(_fischerPgn);
      expect(full.tag('Event'), 'F/S Return Match');
      expect(full.tag('Result'), '1/2-1/2');
      expect(full.result, '1/2-1/2');
      expect(full.movetext, endsWith('43. Re6 1/2-1/2'));
    });

    test('parses a multi-game PGN database', () {
      final games = NostrPgnGame.parseDatabase(_lichessDatabase);

      expect(games, hasLength(2));
      expect(games.first.tag('White'), 'T_LUKE');
      expect(games.first.tag('ECO'), 'B00');
      expect(games.first.movetext, '1. e4 1-0');
      expect(games.last.tag('White'), 'Bastel');
      expect(games.last.result, '1-0');
      expect(
        () => NostrPgnGame.parse(_lichessDatabase),
        throwsArgumentError,
      );
    });

    test('round-trips PGN tag escapes', () {
      const escaped = r'[Event "a \"quoted\" \\ name"]';
      final game = NostrPgnGame.parse('$escaped\n\n1. e4 *');

      expect(game.tag('Event'), 'a "quoted" \\ name');
      expect(game.toPgn(), '$escaped\n\n1. e4 *');
    });

    test('exports the seven tag roster first', () {
      final game = NostrPgnGame.parse(
        '[White "W"]\n[Event "E"]\n\n1. e4 *',
      );

      expect(
        game.toPgn().split('\n').take(2).toList(),
        ['[Event "E"]', '[White "W"]'],
      );
    });

    test('rejects contradictory results and empty games', () {
      expect(
        () => NostrPgnGame.parse('[Result "1-0"]\n\n1. e4 0-1'),
        throwsArgumentError,
      );
      expect(() => NostrPgnGame.parse('   '), throwsArgumentError);
      expect(NostrPgnGame.tryParse('[Result "1-0"]\n\n1. e4 0-1'), isNull);
      expect(NostrPgnGame.tryParse('1. e4 *'), isNotNull);
    });

    test('parses kind 64 events only', () {
      final event = NostrNip64.generateTemplate(pgn: _fischerPgn);

      final games = NostrNip64.parseEvent(event);
      expect(games, hasLength(1));
      expect(games.first.tag('Site'), 'Belgrade, Serbia JUG');

      expect(
        () => NostrNip64.parseEvent(_event(const [], kind: 1)),
        throwsArgumentError,
      );
      expect(NostrNip64.tryParseEvent(_event(const [], kind: 1)), isNull);
    });

    test('publishes with the bound signer', () async {
      final nips = NostrNip64(signer: signer);
      final event = NostrNip64.generateTemplate(pgn: '1. e4 *');
      final signed = await nips.publish(event);

      expect(signed.pubkey, signer.publicKey);
      expect(signed.sig, isNotNull);
      expect(signed.id, isNotNull);
    });
  });

  group('NIP-68', () {
    test('kind and accepted MIME types', () {
      expect(NostrNip68.kind, 20);
      expect(NostrNip68.isAcceptedMimeType('image/jpeg'), isTrue);
      expect(NostrNip68.isAcceptedMimeType('image/webp'), isTrue);
      expect(NostrNip68.isAcceptedMimeType('video/mp4'), isFalse);
      expect(NostrNip68.isAcceptedMimeType(null), isFalse);
    });

    test('parses the spec picture vector', () {
      final event = _event(
        const [
          ['title', 'My picture post'],
          _imageOne,
          _imageTwo,
          ['p', _otherPubkey],
          ['t', 'nature'],
          ['location', 'Costa Rica'],
          ['g', 'djk3'],
          ['L', 'ISO-639-1'],
          ['l', 'en', 'ISO-639-1'],
        ],
        kind: 20,
        content: 'Two scenic photos',
      );

      final picture = NostrPictureEvent.parse(event);

      expect(picture.title, 'My picture post');
      expect(picture.description, 'Two scenic photos');
      expect(picture.images, hasLength(2));
      expect(picture.mimeTypes, ['image/jpeg']);
      expect(picture.hashes, [_hash, _otherHash]);
      expect(picture.hashtags, ['nature']);
      expect(picture.participants, [_otherPubkey]);
      expect(picture.location, 'Costa Rica');
      expect(picture.geohash, 'djk3');
      expect(picture.language, 'en');
      expect(picture.languageType, 'ISO-639-1');
      expect(picture.annotations, hasLength(1));
      expect(picture.annotations.first.pubkey, _otherPubkey);
      expect(picture.annotations.first.x, '120');
      expect(picture.annotations.first.y, '340');
    });

    test('builds the spec tag array exactly', () {
      final event = NostrNip68.generateTemplate(
        title: 'My picture post',
        description: 'Two scenic photos',
        images: [
          NostrImeta.parse(_imageOne),
          NostrImeta.parse(_imageTwo),
        ],
        contentWarning: 'nsfw',
        participants: const [_otherPubkey],
        hashtags: const ['nature'],
        location: 'Costa Rica',
        geohash: 'djk3',
        language: 'en',
      );

      expect(event.kind, 20);
      expect(event.content, 'Two scenic photos');
      expect(event.tags, const [
        ['title', 'My picture post'],
        _imageOne,
        _imageTwo,
        ['content-warning', 'nsfw'],
        ['p', _otherPubkey],
        ['m', 'image/jpeg'],
        ['x', _hash],
        ['x', _otherHash],
        ['t', 'nature'],
        ['location', 'Costa Rica'],
        ['g', 'djk3'],
        ['L', 'ISO-639-1'],
        ['l', 'en', 'ISO-639-1'],
      ]);
    });

    test('buildImage validates its fields', () {
      final image = NostrNip68.buildImage(
        url: 'https://example.com/a.jpg',
        mime: 'image/png',
        dim: '640x480',
        alt: 'A cat',
        hash: _hash,
      );

      expect(image.toTag(), [
        'imeta',
        'url https://example.com/a.jpg',
        'm image/png',
        'dim 640x480',
        'alt A cat',
        'x $_hash',
      ]);

      expect(
        () => NostrNip68.buildImage(
          url: 'https://example.com/a.mp4',
          mime: 'video/mp4',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip68.buildImage(
          url: 'https://example.com/a.jpg',
          mime: 'image/jpeg',
          dim: 'large',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip68.buildImage(
          url: 'https://example.com/a.jpg',
          mime: 'image/jpeg',
          hash: 'abc',
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed picture events', () {
      expect(
        () => NostrPictureEvent.parse(_event(const [], kind: 1)),
        throwsArgumentError,
      );
      expect(
        () => NostrPictureEvent.parse(
          _event(
            const [
              ['title', 'No image'],
            ],
            kind: 20,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrPictureEvent.parse(
          _event(
            const [
              [
                'imeta',
                'url https://example.com/a.mp4',
                'm video/mp4',
              ],
            ],
            kind: 20,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrPictureEvent.parse(
          _event(
            const [
              ['title', '  '],
              _imageOne,
            ],
            kind: 20,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip68.generateTemplate(title: 'No image', images: const []),
        throwsArgumentError,
      );
      expect(
        () => NostrNip68.generateTemplate(
          title: 'Bad mime',
          images: [
            NostrImeta.parse(
              const [
                'imeta',
                'url https://example.com/a.mp4',
                'm video/mp4',
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(NostrPictureEvent.tryParse(_event(const [], kind: 1)), isNull);
    });

    test('publishes with the bound signer', () async {
      final nips = NostrNip68(signer: signer);
      final event = NostrNip68.generateTemplate(
        title: 'Picture',
        images: [NostrImeta.parse(_imageOne)],
      );
      final signed = await nips.publish(event);

      expect(signed.pubkey, signer.publicKey);
      expect(signed.sig, isNotNull);
    });
  });

  group('NIP-73', () {
    test('builds the spec i/k tag vectors', () {
      expect(
        NostrNip73.tagsFor(
          'https://myblog.example.com/post/2012-03-27/hello-world',
        ),
        const [
          ['i', 'https://myblog.example.com/post/2012-03-27/hello-world'],
          ['k', 'web'],
        ],
      );
      expect(
        NostrNip73.tagsFor('geo:ezs42e44yx96'),
        const [
          ['i', 'geo:ezs42e44yx96'],
          ['k', 'geo'],
        ],
      );
      expect(
        NostrNip73.tagsFor('osm:node:240949599'),
        const [
          ['i', 'osm:node:240949599'],
          ['k', 'osm'],
        ],
      );
      expect(
        NostrNip73.tagsFor('iso3166:US-CA'),
        const [
          ['i', 'iso3166:US-CA'],
          ['k', 'iso3166'],
        ],
      );
      expect(
        NostrNip73.tagsFor('isbn:9780765382030'),
        const [
          ['i', 'isbn:9780765382030'],
          ['k', 'isbn'],
        ],
      );
      expect(
        NostrNip73.tagsFor('isan:0000-0000-401A-0000-7'),
        const [
          ['i', 'isan:0000-0000-401A-0000-7'],
          ['k', 'isan'],
        ],
      );
      expect(
        NostrNip73.tagsFor(
          'podcast:item:guid:d98d189b-dc7b-45b1-8720-d4b98690f31f',
        ),
        const [
          ['i', 'podcast:item:guid:d98d189b-dc7b-45b1-8720-d4b98690f31f'],
          ['k', 'podcast:item:guid'],
        ],
      );
      expect(
        NostrNip73.tagsFor(
          'bitcoin:tx:'
          'a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d',
        ),
        const [
          [
            'i',
            'bitcoin:tx:'
                'a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d',
          ],
          ['k', 'bitcoin:tx'],
        ],
      );
      expect(
        NostrNip73.tagsFor(
          'ethereum:1:address:0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
        ),
        const [
          [
            'i',
            'ethereum:1:address:0xd8da6bf26964af9d7eed9e03e53415d37aa96045'
          ],
          ['k', 'ethereum:address'],
        ],
      );
      expect(
        NostrNip73.tagsFor('#nostr'),
        const [
          ['i', '#nostr'],
          ['k', '#'],
        ],
      );
    });

    test('normalizes URLs and keeps URL hints', () {
      final parsed = NostrNip73.parse(
        'https://example.com/post#section',
        urlHint: 'https://example.com/post',
      );

      expect(parsed.id, 'https://example.com/post');
      expect(parsed.kind, 'web');
      expect(parsed.toITag(), [
        'i',
        'https://example.com/post',
        'https://example.com/post',
      ]);
      expect(parsed.toTags(), [
        ['i', 'https://example.com/post', 'https://example.com/post'],
        ['k', 'web'],
      ]);
    });

    test('rejects ids that violate the spec casing rules', () {
      for (final invalid in const [
        'isbn:978-0765382030',
        'geo:EZ42',
        'iso3166:ve',
        'doi:10.1000/ABC',
        '#NotLower',
        'bitcoin:tx:ABCDEF',
        'ethereum:1:address:nothex',
        'https://',
        'unknown:thing',
      ]) {
        expect(
          NostrNip73.tryParse(invalid),
          isNull,
          reason: invalid,
        );
        expect(
          () => NostrNip73.parse(invalid),
          throwsArgumentError,
          reason: invalid,
        );
      }
    });

    test('extracts i tags from events', () {
      final event = _event(const [
        ['i', 'isbn:9780765382030'],
        ['i', 'geo:ezs42e44yx96', 'https://example.com/place'],
        ['k', 'isbn'],
        ['i', 'unknown:thing'],
      ]);

      final parsed = NostrNip73.parseEvent(event);

      expect(parsed, hasLength(2));
      expect(parsed.first.kind, 'isbn');
      expect(parsed.last.kind, 'geo');
      expect(parsed.last.urlHint, 'https://example.com/place');
      expect(NostrNip73.kindFor('geo:ezs42e44yx96'), 'geo');
    });

    test('builds #i/#k filters', () {
      final filter = NostrNip73.buildFilter(
        ids: const ['isbn:9780765382030'],
        kinds: const ['isbn'],
        authors: const [_pubkey],
        limit: 10,
      );

      expect(filter.toMap(), {
        '#i': ['isbn:9780765382030'],
        '#k': ['isbn'],
        'authors': [_pubkey],
        'limit': 10,
      });
      expect(
        () => NostrNip73.buildFilter(),
        throwsArgumentError,
      );
      expect(
        () => NostrNip73.buildFilter(ids: const ['nope']),
        throwsArgumentError,
      );
    });
  });

  group('NIP-89', () {
    test('kind constants and entity names', () {
      expect(NostrNip89.recommendationKind, 31989);
      expect(NostrNip89.handlerKind, 31990);
      expect(NostrNip89.manifestKind, 35128);
      expect(NostrNip89.entityNames, contains('nevent'));
      expect(NostrNip89.entityNames, isNot(contains('nsec')));
    });

    test('builds the spec recommendation tag array', () {
      final event = NostrNip89.generateRecommendationTemplate(
        supportedKind: 31337,
        handlers: [
          NostrHandlerReference(
            address: appAddress,
            relay: 'wss://relay1',
            platform: 'web',
          ),
        ],
      );

      expect(event.kind, 31989);
      expect(event.tags, [
        ['d', '31337'],
        ['a', '31990:$_pubkey:abcd', 'wss://relay1', 'web'],
      ]);

      final parsed = NostrAppRecommendation.parse(event);
      expect(parsed.supportedKind, 31337);
      expect(parsed.handlers, hasLength(1));
      expect(parsed.handlers.first.address.address, appAddress.address);
      expect(parsed.handlers.first.relay, 'wss://relay1');
      expect(parsed.handlers.first.platform, 'web');
    });

    test('builds the spec handler tag array', () {
      final event = NostrNip89.generateHandlerTemplate(
        dTag: 'app1',
        kinds: const [31337, 1],
        content: '{"name":"Zapstr"}',
        urls: const [
          NostrAppHandlerUrl(
            platform: 'web',
            url: 'https://app.example/a/<bech32>',
            entity: 'nevent',
          ),
          NostrAppHandlerUrl(
            platform: 'ios',
            url: 'https://app.example/<bech32>',
          ),
        ],
        latest: [
          NostrNsiteManifestRef(
            address: NostrEventAddress.parse('35128:$_pubkey:site1'),
            relay: 'wss://relay1',
          ),
        ],
      );

      expect(event.kind, 31990);
      expect(event.tags, [
        ['d', 'app1'],
        ['k', '31337'],
        ['k', '1'],
        ['latest', '35128:$_pubkey:site1', 'wss://relay1'],
        ['web', 'https://app.example/a/<bech32>', 'nevent'],
        ['ios', 'https://app.example/<bech32>'],
      ]);

      final parsed = NostrAppHandler.parse(event);
      expect(parsed.dTag, 'app1');
      expect(parsed.kinds, [31337, 1]);
      expect(parsed.metadata, {'name': 'Zapstr'});
      expect(parsed.urls, hasLength(2));
      expect(parsed.urls.first.platform, 'web');
      expect(parsed.urls.first.entity, 'nevent');
      expect(parsed.latest, hasLength(1));
      expect(parsed.latest.first.relay, 'wss://relay1');
    });

    test('builds the client tag', () {
      expect(
        NostrNip89.clientTag(
          name: 'My Client',
          address: appAddress,
          relay: 'wss://relay1',
        ),
        [
          'client',
          'My Client',
          '31990:$_pubkey:abcd',
          'wss://relay1',
        ],
      );
      expect(
        () => NostrNip89.clientTag(
          name: '',
          address: appAddress,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid recommendations and handlers', () {
      expect(
        () => NostrNip89.generateRecommendationTemplate(
          supportedKind: -1,
          handlers: [
            NostrHandlerReference(address: appAddress),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip89.generateRecommendationTemplate(
          supportedKind: 1,
          handlers: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrHandlerReference(
          address: NostrEventAddress.parse('30023:$_pubkey:art'),
        ).toTag(),
        throwsArgumentError,
      );
      expect(
        () => NostrNip89.generateHandlerTemplate(dTag: '', kinds: const [1]),
        throwsArgumentError,
      );
      expect(
        () => NostrNip89.generateHandlerTemplate(dTag: 'x', kinds: const []),
        throwsArgumentError,
      );
      expect(
        () => NostrNip89.generateHandlerTemplate(
          dTag: 'x',
          kinds: const [1],
          content: 'not json',
        ),
        throwsArgumentError,
      );
      expect(
        () => const NostrAppHandlerUrl(
          platform: 'web',
          url: 'https://example.com/<bech32>',
          entity: 'nsec',
        ).toTag(),
        throwsArgumentError,
      );
      expect(
        () => const NostrAppHandlerUrl(
          platform: 'k',
          url: 'https://example.com',
        ).toTag(),
        throwsArgumentError,
      );
      expect(
        NostrAppRecommendation.tryParse(_event(const [], kind: 1)),
        isNull,
      );
      expect(
        NostrAppHandler.tryParse(_event(const [], kind: 1)),
        isNull,
      );
      expect(
        () => NostrAppRecommendation.parse(
          _event(const [
            ['d', '1']
          ], kind: 31989),
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrAppHandler.parse(
          _event(const [
            ['k', '1']
          ], kind: 31990),
        ),
        throwsArgumentError,
      );
    });

    test('builds #d/#k handler filters', () {
      expect(
        NostrNip89.buildRecommendationFilter(
          kind: 31337,
          authors: const [_pubkey],
        ).toMap(),
        {
          '#d': ['31337'],
          'kinds': [31989],
          'authors': [_pubkey],
        },
      );
      expect(
        NostrNip89.buildHandlerFilter(kind: 31337).toMap(),
        {
          '#k': ['31337'],
          'kinds': [31990],
        },
      );
    });

    test('publishes both event kinds with the bound signer', () async {
      final nips = NostrNip89(signer: signer);
      final recommendation = NostrNip89.generateRecommendationTemplate(
        supportedKind: 31337,
        handlers: [NostrHandlerReference(address: appAddress)],
      );
      final handler = NostrNip89.generateHandlerTemplate(
        dTag: 'app1',
        kinds: const [31337],
      );

      final signedRecommendation = await nips.publish(recommendation);
      final signedHandler = await nips.publish(handler);

      expect(signedRecommendation.sig, isNotNull);
      expect(signedHandler.sig, isNotNull);
      expect(signedRecommendation.pubkey, signer.publicKey);
      expect(signedHandler.pubkey, signer.publicKey);
    });
  });
}
