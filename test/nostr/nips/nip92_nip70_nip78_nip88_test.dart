import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

const _specPollId =
    '9d1b6b9562e66f2ecf35eb0a3c2decc736c47fddb13d6fb8f87185a153ea3634';

void main() {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

  group('common tag helpers', () {
    const pubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const tags = [
      ['e', 'id1', 'wss://relay.example', 'root'],
      ['e', 'id2'],
      ['-'],
      ['d'],
    ];

    test('reads first, all, has and require', () {
      expect(NostrTags.first(tags, 'e'), 'id1');
      expect(NostrTags.first(tags, 'd'), isNull);
      expect(NostrTags.first(null, 'e'), isNull);
      expect(NostrTags.all(tags, 'e'), ['id1', 'id2']);
      expect(NostrTags.all(tags, 'x'), isEmpty);
      expect(NostrTags.has(tags, 'e'), isTrue);
      expect(NostrTags.has(tags, '-'), isTrue);
      expect(NostrTags.has(tags, 'x'), isFalse);
      expect(NostrTags.require(tags, 'e'), ['id1', 'id2']);
      expect(NostrTags.require(tags, '-'), isEmpty);
      expect(() => NostrTags.require(tags, 'x'), throwsStateError);
    });

    test('round-trips event addresses', () {
      final address = NostrEventAddress.build(
        kind: 30023,
        pubkey: pubkey,
        identifier: 'my-post',
      );

      expect(address, '30023:$pubkey:my-post');

      final parsed = NostrEventAddress.parse(address);
      expect(parsed.kind, 30023);
      expect(parsed.pubkey, pubkey);
      expect(parsed.identifier, 'my-post');
      expect(parsed.isAddressable, isTrue);
      expect(parsed.address, address);
      expect(parsed.toString(), address);

      final regular = NostrEventAddress.parse('1:$pubkey:');
      expect(regular.identifier, isEmpty);
      expect(regular.isAddressable, isFalse);

      final withColon = NostrEventAddress.parse('30023:$pubkey:a:b');
      expect(withColon.identifier, 'a:b');
    });

    test('rejects malformed addresses', () {
      expect(NostrEventAddress.tryParse(null), isNull);
      expect(NostrEventAddress.tryParse('nope'), isNull);
      expect(NostrEventAddress.tryParse('1:short:'), isNull);
      expect(NostrEventAddress.tryParse('30023:$pubkey:'), isNull);
      expect(NostrEventAddress.tryParse('abc:$pubkey:d'), isNull);
      expect(
        () => NostrEventAddress.parse('bad'),
        throwsFormatException,
      );

      expect(
        () => NostrEventAddress.build(kind: 1, pubkey: 'zz'),
        throwsArgumentError,
      );
      expect(
        () => NostrEventAddress.build(kind: 30000, pubkey: pubkey),
        throwsArgumentError,
      );
      expect(
        () => NostrEventAddress.build(kind: -1, pubkey: pubkey),
        throwsArgumentError,
      );
    });

    test('validates hex, timestamps and ISO dates', () {
      expect(NostrValidators.isHex64(pubkey), isTrue);
      expect(NostrValidators.isHex64('A' * 64), isFalse);
      expect(NostrValidators.isHex64('a' * 63), isFalse);
      expect(NostrValidators.isHex64(null), isFalse);

      expect(NostrValidators.tryUnixSeconds('1700000000'), 1700000000);
      expect(NostrValidators.tryUnixSeconds(1700000000), 1700000000);
      expect(NostrValidators.tryUnixSeconds(' 1700000000 '), 1700000000);
      expect(NostrValidators.tryUnixSeconds('-1'), isNull);
      expect(NostrValidators.tryUnixSeconds('x'), isNull);
      expect(NostrValidators.tryUnixSeconds(null), isNull);

      final date = NostrValidators.tryIsoDate('2024-01-02T03:04:05Z');
      expect(date, isNotNull);
      expect(date!.isUtc, isTrue);
      expect(date.year, 2024);
      expect(NostrValidators.tryIsoDate('nope'), isNull);
      expect(NostrValidators.tryIsoDate(5), isNull);

      expect(NostrValidators.dayIndex(86400), 1);
      expect(NostrValidators.dayIndex(86399), 0);
      expect(NostrValidators.dayIndex(-1), -1);
      expect(NostrValidators.dayIndex(-86400), -1);
      expect(NostrValidators.dayIndex(-86401), -2);
    });
  });

  group('NIP-92', () {
    const imageUrl = 'https://nostr.build/i/my-image.jpg';
    const blurhash = r'eVF$^OI:${M{o#*0-nNFxakD-?xVM}WEWB%iNKxvR-oetmo#R-aen$';

    final imetaTag = <String>[
      'imeta',
      'url $imageUrl',
      'm image/jpeg',
      'blurhash $blurhash',
      'dim 3024x4032',
      'alt A scenic photo overlooking the coast of Costa Rica',
      'x <sha256 hash as specified in NIP 94>',
      'fallback https://nostrcheck.me/alt1.jpg',
      'fallback https://void.cat/alt1.jpg',
    ];

    test('parses the spec example with repeated fallbacks', () {
      final metas = NostrNip92.parseAll(
        _event(
          content: 'More image metadata tests do not mind me $imageUrl',
          tags: [imetaTag],
        ),
      );

      expect(metas.length, 1);

      final imeta = metas.single;
      expect(imeta.url, imageUrl);
      expect(imeta.m, 'image/jpeg');
      expect(imeta.blurhash, blurhash);
      expect(imeta.dim, '3024x4032');
      expect(
        imeta.alt,
        'A scenic photo overlooking the coast of Costa Rica',
      );
      expect(imeta.x, '<sha256 hash as specified in NIP 94>');
      expect(imeta.fallback, [
        'https://nostrcheck.me/alt1.jpg',
        'https://void.cat/alt1.jpg',
      ]);
      expect(imeta.image, isEmpty);
      expect(imeta.extras, isEmpty);
      expect(imeta.isValid, isTrue);
      expect(imeta.toTag(), imetaTag);
      expect(NostrImeta.parse(imetaTag).url, imageUrl);
    });

    test('splits entries on the first space only and keeps extras', () {
      final imeta = NostrImeta.parse(const [
        'imeta',
        'url https://cdn.example/a b.png',
        'm image/png',
        'service https://cdn.example',
        'size 42',
        'image https://cdn.example/preview1.png',
        'image https://cdn.example/preview2.png',
      ]);

      expect(imeta.url, 'https://cdn.example/a b.png');
      expect(imeta.service, 'https://cdn.example');
      expect(imeta.extras, {
        'size': ['42'],
      });
      expect(imeta.image, [
        'https://cdn.example/preview1.png',
        'https://cdn.example/preview2.png',
      ]);
      expect(imeta.getAll('image').length, 2);
      expect(imeta.toTag().first, 'imeta');
    });

    test('rejects tags without a url or a second field', () {
      expect(NostrImeta.tryParse(const ['imeta', 'm image/png']), isNull);
      expect(NostrImeta.tryParse(const ['imeta', 'url https://x']), isNull);
      expect(
        NostrImeta.parse(const ['imeta', 'url https://x']).isValid,
        isFalse,
      );
      expect(
          NostrNip92.parseTags(const [
            ['imeta', 'm image/png'],
            ['imeta', 'url https://x', 'm image/png'],
            ['t', 'not-imeta'],
          ]).single.url,
          'https://x');
    });

    test('requires a value on the second field', () {
      expect(
        NostrImeta.parse(const ['imeta', 'url https://x', 'x']).isValid,
        isFalse,
      );
      expect(
        NostrImeta.tryParse(const ['imeta', 'url https://x', 'x']),
        isNull,
      );
      expect(
        NostrImeta.parse(const ['imeta', 'url', 'x abc']).isValid,
        isFalse,
      );
      expect(
        NostrImeta.parse(const ['imeta', 'url https://x', 'x abc']).isValid,
        isTrue,
      );
    });

    test('matches urls in content', () {
      final imeta = NostrImeta.parse(imetaTag);

      expect(NostrNip92.matchesUrl(imeta, imageUrl), isTrue);
      expect(NostrNip92.matchesUrl(imeta, '$imageUrl?x=1'), isFalse);
      expect(NostrNip92.matchesUrl(imeta, null), isFalse);
      expect(NostrNip92.matchesUrl(imeta, ''), isFalse);
    });

    test('resolves profile picture and banner metadata', () {
      const picture = 'https://blossom.example/1f2e...a9.jpg';
      const banner = 'https://blossom.example/7c3d...04.webp';

      final profile = _event(
        kind: 0,
        content: jsonEncode({
          'name': 'luna',
          'picture': picture,
          'banner': banner,
        }),
        tags: const [
          [
            'imeta',
            'url https://blossom.example/1f2e...a9.jpg',
            'm image/jpeg',
            'x 1f2e...a9',
            'dim 400x400',
            'blurhash LEHV6nWB2yk8pyo0adR*.7kCMdnj',
            'fallback https://mirror.example/1f2e...a9.jpg',
          ],
          [
            'imeta',
            'url https://blossom.example/7c3d...04.webp',
            'm image/webp',
            'x 7c3d...04',
            'dim 1500x500',
          ],
          [
            'imeta',
            'url https://blossom.example/unused.jpg',
            'm image/jpeg',
          ],
        ],
      );

      final pictureMeta = NostrNip92.forProfileField(profile, 'picture');
      expect(pictureMeta, isNotNull);
      expect(pictureMeta!.dim, '400x400');
      expect(pictureMeta.blurhash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
      expect(pictureMeta.fallback, ['https://mirror.example/1f2e...a9.jpg']);

      final bannerMeta = NostrNip92.forProfileField(profile, 'banner');
      expect(bannerMeta, isNotNull);
      expect(bannerMeta!.m, 'image/webp');

      expect(NostrNip92.forProfileField(profile, 'about'), isNull);
      expect(
        NostrNip92.forProfileField(
          _event(kind: 0, content: 'not json'),
          'picture',
        ),
        isNull,
      );
      expect(
        NostrNip92.forProfileField(
          _event(kind: 0, content: jsonEncode({'picture': 5})),
          'picture',
        ),
        isNull,
      );
    });
  });

  group('NIP-70', () {
    const secretPubkey =
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

    test('detects the spec example as protected', () {
      final event = _event(
        id: 'cb8feca582979d91fe90455867b34dbf4d65e4b86e86b3c68c368ca9f9eef6f2',
        pubkey: secretPubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1707409439000),
        content: 'hello members of the secret group',
        tags: const [
          ['-'],
        ],
      );

      expect(NostrNip70.isProtected(event), isTrue);
      expect(NostrNip70.canRepostEmbed(event), isFalse);
    });

    test('marks events once and requires re-signing', () {
      final open = _event(
        tags: const [
          ['t', 'news'],
        ],
      );

      expect(NostrNip70.isProtected(open), isFalse);
      expect(NostrNip70.canRepostEmbed(open), isTrue);

      final marked = NostrNip70.markProtected(open);
      expect(marked.tags, [
        ['t', 'news'],
        ['-'],
      ]);
      expect(marked.id, isNull);
      expect(marked.sig, isNull);

      final again = NostrNip70.markProtected(marked);
      expect(again.tags, hasLength(2));
    });

    test('dedupes protection tags and keeps the subscription id', () {
      final event = _event(
        tags: const [
          ['-'],
          ['t', 'news'],
          ['-'],
          ['p', secretPubkey],
        ],
        subscriptionId: 'sub-1',
      );

      final marked = NostrNip70.markProtected(event);

      expect(marked.tags, [
        ['t', 'news'],
        ['p', secretPubkey],
        ['-'],
      ]);
      expect(marked.subscriptionId, 'sub-1');
      expect(marked.id, isNull);
      expect(marked.sig, isNull);
    });
  });

  group('NIP-78', () {
    const dTag = 'com.example.app/settings';

    test('generates addressable app data templates', () {
      final template = NostrNip78.generateAppDataTemplate(
        content: '{"theme":"dark"}',
        kind: NostrNip78.addressableKind,
        dTag: dTag,
        tags: const [
          ['t', 'settings'],
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(template.kind, 30078);
      expect(template.content, '{"theme":"dark"}');
      expect(template.tags, [
        ['d', dTag],
        ['t', 'settings'],
      ]);

      final plain = NostrNip78.generateAppDataTemplate(content: 'raw');
      expect(plain.kind, NostrNip78.appDataKind);
      expect(plain.tags, isEmpty);
      expect(NostrNip78.isAppDataKind(78), isTrue);
      expect(NostrNip78.isAppDataKind(30078), isTrue);
      expect(NostrNip78.isAppDataKind(1), isFalse);
    });

    test('rejects invalid kinds and missing d tags', () {
      expect(
        () => NostrNip78.generateAppDataTemplate(content: 'x', kind: 1),
        throwsArgumentError,
      );
      expect(
        () => NostrNip78.generateAppDataTemplate(
          content: 'x',
          kind: NostrNip78.addressableKind,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip78.generateAppDataTemplate(
          content: 'x',
          kind: NostrNip78.addressableKind,
          dTag: '',
        ),
        throwsArgumentError,
      );
    });

    test('parses and signs app data', () async {
      final signed = await NostrNip78(signer: signer).publish(
        content: '{"theme":"dark"}',
        kind: NostrNip78.addressableKind,
        dTag: dTag,
        tags: const [
          ['t', 'settings'],
        ],
      );

      expect(signed.isVerified(), isTrue);
      expect(signed.pubkey, signer.publicKey);

      final parsed = NostrNip78.parseAppData(signed);
      expect(parsed.kind, NostrNip78.addressableKind);
      expect(parsed.isAddressable, isTrue);
      expect(parsed.identifier, dTag);
      expect(parsed.content, '{"theme":"dark"}');
      expect(parsed.tags, [
        ['t', 'settings'],
      ]);

      expect(
        NostrNip78.tryParseAppData(_event(content: 'x')),
        isNull,
      );
      expect(
        NostrNip78.tryParseAppData(
          _event(kind: NostrNip78.addressableKind, content: 'x'),
        ),
        isNull,
      );
      expect(
        () => NostrNip78.parseAppData(_event(content: 'x')),
        throwsArgumentError,
      );
    });
  });

  group('NIP-88', () {
    const pollId =
        '9d1b6b9562e66f2ecf35eb0a3c2decc736c47fddb13d6fb8f87185a153ea3634';
    const responseEventId =
        '1fc80cf813f1af33d5a435862b7ef7fb96b47e68a48f1abcadf8081f5a545550';
    const pollCreator =
        'dee45a23c4f1d93f3a2043650c5081e4ac14a778e0acbef03de3768e4f81ac7b';
    const yay = 'qj518h583';
    const nay = 'gga6cdnqj';
    const endsAt = 1719999999;

    final poll = _event(
      id: pollId,
      pubkey: pollCreator,
      kind: NostrNip88.pollKind,
      content: 'Pineapple on pizza',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1719888496000),
      tags: const [
        ['option', yay, 'Yay'],
        ['option', nay, 'Nay'],
        ['relay', '<relay url1>'],
        ['relay', '<relay url2>'],
        ['polltype', 'singlechoice'],
        ['endsAt', '$endsAt'],
      ],
    );

    test('generates the spec poll template', () {
      final template = NostrNip88.generatePollTemplate(
        content: 'Pineapple on pizza',
        options: const [
          NostrPollOption(id: yay, label: 'Yay'),
          NostrPollOption(id: nay, label: 'Nay'),
        ],
        relays: const ['<relay url1>', '<relay url2>'],
        endsAt: endsAt,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1719888496000),
      );

      expect(template.kind, 1068);
      expect(template.tags, poll.tags);

      final parsed = NostrNip88.parsePoll(poll);
      expect(parsed.options.map((option) => option.id), [yay, nay]);
      expect(parsed.options.last.label, 'Nay');
      expect(parsed.pollType, NostrNip88.singleChoice);
      expect(parsed.relays, ['<relay url1>', '<relay url2>']);
      expect(parsed.endsAt, endsAt);
      expect(parsed.id, pollId);

      final defaults = NostrNip88.parsePoll(
        _event(
          kind: NostrNip88.pollKind,
          tags: const [
            ['option', yay, 'Yay'],
          ],
        ),
      );
      expect(defaults.pollType, NostrNip88.singleChoice);
      expect(defaults.endsAt, isNull);
    });

    test('generates the spec response template and filter', () {
      final response = NostrNip88.generateResponseTemplate(
        pollEventId: responseEventId,
        responses: const [nay, 'm3agjsdq1'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(1720097117000),
      );

      expect(response.kind, 1018);
      expect(response.content, isEmpty);
      expect(response.tags, [
        ['e', responseEventId],
        ['response', nay],
        ['response', 'm3agjsdq1'],
      ]);

      final filter = NostrNip88.buildResponseFilter(
        pollEventId: pollId,
        authors: const [pollCreator],
        until: endsAt,
        limit: 10,
      );

      expect(filter.kinds, [1018]);
      expect(filter.e, [pollId]);
      expect(filter.authors, [pollCreator]);
      expect(filter.limit, 10);
      expect(filter.until!.millisecondsSinceEpoch ~/ 1000, endsAt);

      final bare = NostrNip88.buildResponseFilter(pollEventId: pollId);
      expect(bare.until, isNull);
      expect(bare.authors, isNull);

      expect(
        () => NostrNip88.generateResponseTemplate(
          pollEventId: 'abc',
          responses: const [yay],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip88.generateResponseTemplate(
          pollEventId: responseEventId,
          responses: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip88.generatePollTemplate(
          content: 'x',
          options: const [
            NostrPollOption(id: yay, label: 'A'),
            NostrPollOption(id: yay, label: 'B'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip88.generatePollTemplate(
          content: 'x',
          options: const [NostrPollOption(id: yay, label: 'A')],
          pollType: 'ranked',
        ),
        throwsArgumentError,
      );
    });

    test('tallies singlechoice with one latest vote per pubkey', () {
      final tally = NostrPollTally.compute(
        poll: poll,
        responses: [
          _vote('a' * 64, [nay], 100),
          _vote('a' * 64, [yay], 200),
          _vote('b' * 64, [nay, yay], 150),
          _vote('c' * 64, ['unknown'], 160),
          _event(
            tags: const [
              ['response', yay],
            ],
          ),
          _vote(
            'd' * 64,
            [yay],
            170,
            pollId: 'f' * 64,
          ),
        ],
      );

      expect(tally.countFor(yay), 1);
      expect(tally.countFor(nay), 1);
      expect(tally.countFor('unknown'), 0);
      expect(tally.totalVoters, 2);
      expect(tally.voters, {'a' * 64, 'b' * 64});
      expect(tally.counts.keys, [yay, nay]);
    });

    test('tallies multiplechoice with the first tag per option', () {
      final multi = NostrNip88.generatePollTemplate(
        content: 'Pick many',
        options: const [
          NostrPollOption(id: yay, label: 'Yay'),
          NostrPollOption(id: nay, label: 'Nay'),
        ],
        pollType: NostrNip88.multipleChoice,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1719888496000),
      );

      final tally = NostrPollTally.compute(
        poll: _event(
          id: pollId,
          kind: NostrNip88.pollKind,
          tags: multi.tags ?? const [],
        ),
        responses: [
          _vote('a' * 64, [nay, yay, nay], 100),
          _vote('b' * 64, [yay], 200),
        ],
      );

      expect(tally.countFor(yay), 2);
      expect(tally.countFor(nay), 1);
      expect(tally.totalVoters, 2);
    });

    test('applies the endsAt cutoff before deduplication', () {
      final limited = NostrNip88.generatePollTemplate(
        content: 'Ends soon',
        options: const [
          NostrPollOption(id: yay, label: 'Yay'),
          NostrPollOption(id: nay, label: 'Nay'),
        ],
        endsAt: 1000,
      );

      final tally = NostrPollTally.compute(
        poll: _event(
          id: pollId,
          kind: NostrNip88.pollKind,
          tags: limited.tags ?? const [],
        ),
        responses: [
          _vote('a' * 64, [yay], 1000),
          _vote('b' * 64, [yay], 1001),
          _vote('c' * 64, [nay], 999),
          _vote('c' * 64, [yay], 1001),
          _vote('d' * 64, [nay], 2000),
        ],
      );

      expect(tally.countFor(yay), 1);
      expect(tally.countFor(nay), 1);
      expect(tally.voters, {'a' * 64, 'c' * 64});
    });

    test('rejects tallies without a poll id', () {
      expect(
        () => NostrPollTally.compute(
          poll: _event(kind: NostrNip88.pollKind),
          responses: const [],
        ),
        throwsArgumentError,
      );
    });

    test('signs polls and responses through the accessor', () async {
      final nips = NostrNips(logger: Nostr.instance.services.logger)
        ..bindSigner(signer);

      final signedPoll = await nips.nip88.createPoll(
        content: 'Pineapple on pizza',
        options: const [
          NostrPollOption(id: yay, label: 'Yay'),
          NostrPollOption(id: nay, label: 'Nay'),
        ],
      );

      expect(signedPoll.isVerified(), isTrue);
      expect(signedPoll.kind, 1068);

      final signedResponse = await nips.nip88.createResponse(
        pollEventId: signedPoll.id!,
        responses: const [nay],
      );

      expect(signedResponse.isVerified(), isTrue);
      expect(signedResponse.kind, 1018);
    });
  });

  group('NostrNips wiring', () {
    test('stateless accessors are cached', () {
      final nips = NostrNips(logger: Nostr.instance.services.logger);

      expect(nips.nip70, same(nips.nip70));
      expect(nips.nip92, same(nips.nip92));
    });

    test('signer-bound accessors require and reset a signer', () {
      final nips = NostrNips(logger: Nostr.instance.services.logger);

      expect(() => nips.nip78, throwsStateError);
      expect(() => nips.nip88, throwsStateError);

      nips.bindSigner(signer);

      expect(nips.nip78.signer, same(signer));
      expect(nips.nip88.signer, same(signer));
      expect(nips.nip78, same(nips.nip78));
      expect(nips.nip88, same(nips.nip88));

      nips.bindSigner(null);

      expect(() => nips.nip78, throwsStateError);
      expect(() => nips.nip88, throwsStateError);
    });
  });
}

NostrEvent _event({
  int kind = 1,
  String content = '',
  List<List<String>> tags = const [],
  String? id,
  String? pubkey,
  DateTime? createdAt,
  String? sig,
  String? subscriptionId,
}) {
  return NostrEvent(
    id: id,
    kind: kind,
    content: content,
    sig: sig,
    pubkey: pubkey ?? 'a' * 64,
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(1700000000000),
    tags: tags,
    subscriptionId: subscriptionId,
  );
}

NostrEvent _vote(
  String pubkey,
  List<String> options,
  int createdAt, {
  String pollId = _specPollId,
}) {
  return _event(
    kind: NostrNip88.responseKind,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    tags: [
      ['e', pollId],
      for (final option in options) ['response', option],
    ],
  );
}
