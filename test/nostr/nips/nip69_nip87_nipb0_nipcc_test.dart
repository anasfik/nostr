import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';
import 'package:dart_nostr/nostr/nips/nip69/nip69.dart';
import 'package:dart_nostr/nostr/nips/nip87/nip87.dart';
import 'package:dart_nostr/nostr/nips/nipb0/nipb0.dart';
import 'package:dart_nostr/nostr/nips/nipcc/nipcc.dart';
import 'package:dart_nostr/nostr/nips/social/social_builder.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

const String _pubkey =
    '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd';
const String _verificationKey =
    '6805d4e5c0df48b4f76e2fdcb67a2acb1d97567b01c6fe17a236dc32f34f1c07';
const String _otherKey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _finderNpub =
    'npub1qc0lc5lxnhxnfxlw2lxkv4x4vp6xsf4d5qwvlhfx6qmz6x4nfhqd8h2z3';
const String _specNaddr =
    'naddr1qqxnzd3e8q6n2dfk8qcnjve48qmnsw3jsqgswaehxw309aex2mrp0yhx6tpdsek6'
    'w309aex2mrp0yh56tnwdus8vatjvs6kzdrz956k7tjzw6qzypzgd2dmgxhxf34hnlw2y03n'
    'ckr8f4g6mw9flxqq65v94zkp77rqfgrf8';
const String _geocacheCoordinate =
    '37516:$_pubkey:verified-treasure-1748619568669';
const String _verificationJson =
    '{"kind":7517,"content":"Geocache verification for $_finderNpub",'
    '"tags":[["a","$_pubkey:$_specNaddr"]],'
    '"pubkey":"$_verificationKey","created_at":1672531200,'
    '"sig":"a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456'
    '789012345678901234567890abcdef1234567890abcdef1234567890abcdef12"}';

NostrEvent _event(
  List<List<String>> tags, {
  required int kind,
  String content = '',
  String pubkey = _pubkey,
  String? id,
  String? sig,
  DateTime? createdAt,
}) {
  return NostrEvent(
    id: id,
    kind: kind,
    content: content,
    sig: sig,
    pubkey: pubkey,
    createdAt: createdAt ?? DateTime.utc(2024),
    tags: tags,
  );
}

void main() {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
  final bech32 = NostrBech32();

  group('NIP-69', () {
    /// 69.md example tags, verbatim.
    const specTags = <List<String>>[
      ['d', 'ede61c96-4c13-4519-bf3a-dcf7f1e9d842'],
      ['k', 'sell'],
      ['f', 'VES'],
      ['s', 'pending'],
      ['amt', '0'],
      ['fa', '100'],
      ['pm', 'face to face', 'bank transfer'],
      ['premium', '1'],
      [
        'rating',
        '{"total_reviews":1,"total_rating":3.0,"last_rating":3,'
            '"max_rate":5,"min_rate":1}',
      ],
      ['source', 'https://t.me/p2plightning/xxxxxxx'],
      ['network', 'mainnet'],
      ['layer', 'lightning'],
      ['name', 'Nakamoto'],
      ['g', '<geohash>'],
      ['bond', '0'],
      ['expires_at', '1719391096'],
      ['expiration', '1719995896'],
      ['y', 'lnp2pbot'],
      ['z', 'order'],
    ];

    test('parses the 69.md example', () {
      final event = _event(specTags, kind: 38383);
      final order = NostrP2pOrder.parse(event);

      expect(order.orderId, 'ede61c96-4c13-4519-bf3a-dcf7f1e9d842');
      expect(order.orderType, 'sell');
      expect(order.fiatCurrency, 'VES');
      expect(order.status, 'pending');
      expect(order.amount, 0);
      expect(order.fiatAmounts, ['100']);
      expect(order.isRange, isFalse);
      expect(order.fiatMin, '100');
      expect(order.fiatMax, isNull);
      expect(order.paymentMethods, ['face to face', 'bank transfer']);
      expect(order.premium, '1');
      expect(order.rating?['total_reviews'], 1);
      expect(order.source, 'https://t.me/p2plightning/xxxxxxx');
      expect(order.network, 'mainnet');
      expect(order.layer, 'lightning');
      expect(order.makerName, 'Nakamoto');
      expect(order.geohash, '<geohash>');
      expect(order.bond, '0');
      expect(order.expiresAt, 1719391096);
      expect(order.expiration, 1719995896);
      expect(order.platform, 'lnp2pbot');
      expect(order.document, 'order');
      expect(order.tags, specTags);
    });

    test('builds the example tag order, with a real geohash', () {
      final event = NostrNip69.generateOrderTemplate(
        orderId: 'ede61c96-4c13-4519-bf3a-dcf7f1e9d842',
        orderType: 'sell',
        fiatCurrency: 'VES',
        status: 'pending',
        amount: 0,
        fiatAmount: '100',
        paymentMethods: const ['face to face', 'bank transfer'],
        premium: '1',
        ratingJson: specTags[8][1],
        source: 'https://t.me/p2plightning/xxxxxxx',
        network: 'mainnet',
        layer: 'lightning',
        makerName: 'Nakamoto',
        geohash: 'u4xsu6ry',
        bond: '0',
        expiresAt: 1719391096,
        expiration: 1719995896,
        platform: 'lnp2pbot',
        createdAt: DateTime.utc(2024),
      );

      expect(event.kind, 38383);
      expect(event.tags, [
        ...specTags.take(13),
        ['g', 'u4xsu6ry'],
        ...specTags.skip(14),
      ]);

      final parsed = NostrP2pOrder.parse(event);
      expect(parsed.geohash, 'u4xsu6ry');
      expect(parsed.rating, isA<Map<String, dynamic>>());
    });

    test('accepts a fiat range and comma-separated payment methods', () {
      final event = NostrNip69.generateOrderTemplate(
        orderId: 'range-1',
        orderType: 'buy',
        fiatCurrency: 'USD',
        status: 'in-progress',
        amount: 150000,
        fiatAmount: '10',
        fiatAmountMax: '50',
        paymentMethods: const ['bank transfer'],
      );

      expect(event.tags, contains(equals(['fa', '10', '50'])));

      final parsed = NostrP2pOrder.parse(event);
      expect(parsed.isRange, isTrue);
      expect(parsed.fiatMin, '10');
      expect(parsed.fiatMax, '50');

      final comma = _event(
        [
          ['d', 'd1'],
          ['k', 'sell'],
          ['f', 'EUR'],
          ['s', 'success'],
          ['amt', '1'],
          ['fa', '5'],
          ['pm', 'cash, lightning'],
          ['z', 'order'],
        ],
        kind: 38383,
      );
      expect(NostrP2pOrder.parse(comma).paymentMethods, ['cash', 'lightning']);
    });

    test('rejects invalid orders', () {
      expect(
        () => NostrNip69.generateOrderTemplate(
          orderId: 'x',
          orderType: 'swap',
          fiatCurrency: 'USD',
          status: 'pending',
          amount: 1,
          fiatAmount: '1',
          paymentMethods: const ['cash'],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip69.generateOrderTemplate(
          orderId: 'x',
          orderType: 'sell',
          fiatCurrency: 'usd',
          status: 'pending',
          amount: 1,
          fiatAmount: '1',
          paymentMethods: const ['cash'],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip69.generateOrderTemplate(
          orderId: 'x',
          orderType: 'sell',
          fiatCurrency: 'USD',
          status: 'completed',
          amount: 1,
          fiatAmount: '1',
          paymentMethods: const ['cash'],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip69.generateOrderTemplate(
          orderId: 'x',
          orderType: 'sell',
          fiatCurrency: 'USD',
          status: 'pending',
          amount: 1,
          fiatAmount: '10',
          fiatAmountMax: '5',
          paymentMethods: const ['cash'],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip69.generateOrderTemplate(
          orderId: 'x',
          orderType: 'sell',
          fiatCurrency: 'USD',
          status: 'pending',
          amount: 1,
          fiatAmount: '1',
          paymentMethods: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip69.generateOrderTemplate(
          orderId: 'x',
          orderType: 'sell',
          fiatCurrency: 'USD',
          status: 'pending',
          amount: 1,
          fiatAmount: '1',
          paymentMethods: const ['cash'],
          geohash: 'not a geohash',
        ),
        throwsArgumentError,
      );

      final noZ = _event(
        [
          ['d', 'd1'],
          ['k', 'sell'],
          ['f', 'USD'],
          ['s', 'pending'],
          ['amt', '1'],
          ['fa', '1'],
          ['pm', 'cash'],
        ],
        kind: 38383,
      );
      expect(NostrP2pOrder.tryParse(noZ), isNull);
      expect(NostrP2pOrder.tryParse(_event(specTags, kind: 1)), isNull);
      expect(NostrP2pOrder.tryParse(_event(const [], kind: 38383)), isNull);
    });

    test('publishes with the bound signer', () async {
      final nips = NostrNip69(signer: signer);
      final event = NostrNip69.generateOrderTemplate(
        orderId: 'x',
        orderType: 'sell',
        fiatCurrency: 'USD',
        status: 'pending',
        amount: 1000,
        fiatAmount: '10',
        paymentMethods: const ['cash'],
      );
      final signed = await nips.publish(event);

      expect(signed.pubkey, signer.publicKey);
      expect(signed.sig, isNotNull);
    });
  });

  group('NIP-87', () {
    test('builds the recommendation example tag order', () {
      final fedimint = NostrEcashMintAddress(
        address: NostrEventAddress(
          kind: 38173,
          pubkey: _verificationKey,
          identifier: 'fedimint-d',
        ),
        relay: 'wss://relay1',
        type: 'fedimint',
      );
      final cashu = NostrEcashMintAddress(
        address: NostrEventAddress(
          kind: 38172,
          pubkey: _otherKey,
          identifier: 'cashu-d',
        ),
        relay: 'wss://relay2',
        type: 'cashu',
      );

      final event = NostrNip87.generateRecommendationTemplate(
        recommendedKind: 38173,
        dTag: 'fedimint-d',
        urls: const [
          NostrEcashUrl(value: 'fed11abc..', type: 'fedimint'),
          NostrEcashUrl(value: 'https://cashu.example.com', type: 'cashu'),
        ],
        addresses: [fedimint, cashu],
        content: 'I trust this mint with my life',
      );

      expect(event.kind, 38000);
      expect(event.tags, [
        ['k', '38173'],
        ['d', 'fedimint-d'],
        ['u', 'fed11abc..', 'fedimint'],
        ['u', 'https://cashu.example.com', 'cashu'],
        ['a', '38173:$_verificationKey:fedimint-d', 'wss://relay1', 'fedimint'],
        ['a', '38172:$_otherKey:cashu-d', 'wss://relay2', 'cashu'],
      ]);

      final parsed = NostrEcashRecommendation.parse(event);
      expect(parsed.recommendedKind, 38173);
      expect(parsed.urls, hasLength(2));
      expect(parsed.urls.first.type, 'fedimint');
      expect(parsed.addresses, hasLength(2));
      expect(parsed.addresses.last.relay, 'wss://relay2');
    });

    test('rejects recommendation kinds other than 38172/38173', () {
      expect(
        () => NostrNip87.generateRecommendationTemplate(
          recommendedKind: 38174,
          dTag: 'x',
        ),
        throwsArgumentError,
      );

      final wrong = _event(
        const [
          ['k', '38174'],
          ['d', 'x'],
        ],
        kind: 38000,
      );
      expect(NostrEcashRecommendation.tryParse(wrong), isNull);
      expect(
          NostrEcashRecommendation.tryParse(_event(const [], kind: 1)), isNull);
    });

    test('parses and builds the cashu mint example', () {
      const tags = <List<String>>[
        ['d', _verificationKey],
        ['u', 'https://cashu.example.com'],
        ['nuts', '1,2,3,4,5,6,7'],
        ['n', 'mainnet'],
      ];

      final parsed = NostrCashuMintInfo.parse(
        _event(tags, kind: 38172, content: '{"name":"Example Mint"}'),
      );
      expect(parsed.dTag, _verificationKey);
      expect(parsed.url, 'https://cashu.example.com');
      expect(parsed.nuts, ['1', '2', '3', '4', '5', '6', '7']);
      expect(parsed.network, 'mainnet');
      expect(parsed.metadata?['name'], 'Example Mint');

      final built = NostrNip87.generateCashuMintTemplate(
        mintPubkey: _verificationKey,
        url: 'https://cashu.example.com',
        nuts: const ['1', '2', '3', '4', '5', '6', '7'],
      );
      expect(built.tags, tags);
      expect(NostrCashuMintInfo.parse(built).nuts, parsed.nuts);

      // A `nuts/...` marker inside the u tag.
      final marker = _event(
        const [
          ['d', _verificationKey],
          ['u', 'https://cashu.example.com', 'nuts/1,2,3,n4,n5'],
          ['n', 'mainnet'],
        ],
        kind: 38172,
      );
      expect(
        NostrCashuMintInfo.parse(marker).nuts,
        ['1', '2', '3', 'n4', 'n5'],
      );

      expect(
        () => NostrNip87.generateCashuMintTemplate(
          mintPubkey: 'not-a-key',
          url: 'https://cashu.example.com',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip87.generateCashuMintTemplate(
          mintPubkey: _verificationKey,
          url: 'cashu.example.com',
        ),
        throwsArgumentError,
      );
      final prose = NostrCashuMintInfo.tryParse(
        _event(
          const [
            ['d', _verificationKey],
            ['n', 'mainnet'],
          ],
          kind: 38172,
          content: 'not json',
        ),
      );
      expect(prose, isNotNull);
      expect(prose?.metadata, isNull);
    });

    test('parses and builds the fedimint example', () {
      const tags = <List<String>>[
        ['d', 'federation-id'],
        ['u', 'fed11abc..'],
        ['u', 'fed11xyz..'],
        ['modules', 'lightning,wallet,mint'],
        ['n', 'signet'],
      ];

      final parsed = NostrFedimintInfo.parse(_event(tags, kind: 38173));
      expect(parsed.dTag, 'federation-id');
      expect(parsed.inviteCodes, ['fed11abc..', 'fed11xyz..']);
      expect(parsed.modules, ['lightning', 'wallet', 'mint']);
      expect(parsed.network, 'signet');

      final built = NostrNip87.generateFedimintTemplate(
        federationId: 'federation-id',
        inviteCodes: const ['fed11abc..', 'fed11xyz..'],
        modules: const ['lightning', 'wallet', 'mint'],
        network: 'signet',
      );
      expect(built.tags, tags);
      expect(NostrFedimintInfo.parse(built).modules, parsed.modules);

      expect(
        () => NostrNip87.generateFedimintTemplate(
          federationId: 'x',
          inviteCodes: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip87.generateFedimintTemplate(
          federationId: 'x',
          inviteCodes: const ['fed11abc..'],
          network: 'devnet',
        ),
        throwsArgumentError,
      );
    });

    test('publishes with the bound signer', () async {
      final nips = NostrNip87(signer: signer);
      final signed = await nips.publish(
        NostrNip87.generateRecommendationTemplate(
          recommendedKind: 38172,
          dTag: 'mint',
        ),
      );

      expect(signed.pubkey, signer.publicKey);
      expect(signed.kind, 38000);
    });

    test('parses leniently when optional fields are malformed', () {
      final recommendation = NostrEcashRecommendation.parse(
        _event(
          const [
            ['k', '38172'],
            ['d', 'not-hex-but-allowed'],
            ['u', ''],
            ['u', 'https://cashu.example.com', 'cashu'],
            ['a', '30023:$_pubkey:article'],
            ['a', '38172:$_pubkey:mint-d', 'wss://relay1'],
          ],
          kind: 38000,
          content: 'A prose review, not JSON',
        ),
      );
      expect(recommendation.dTag, 'not-hex-but-allowed');
      expect(
        recommendation.urls.map((url) => url.value),
        ['https://cashu.example.com'],
      );
      expect(
        recommendation.addresses.single.address.address,
        '38172:$_pubkey:mint-d',
      );
      expect(recommendation.content, 'A prose review, not JSON');

      final cashu = NostrCashuMintInfo.parse(
        _event(
          const [
            ['d', 'not-a-mint-key'],
            ['u', 'https://cashu.example.com'],
            ['n', 'mainnet'],
          ],
          kind: 38172,
          content: 'prose metadata',
        ),
      );
      expect(cashu.dTag, 'not-a-mint-key');
      expect(cashu.metadata, isNull);
      expect(cashu.content, 'prose metadata');
      expect(NostrNip87.isCashuMintKey(cashu.dTag), isFalse);

      final fedimint = NostrFedimintInfo.parse(
        _event(
          const [
            ['d', 'federation-id'],
            ['u', 'fed11abc..'],
            ['n', 'signet'],
          ],
          kind: 38173,
          content: 'not json either',
        ),
      );
      expect(fedimint.dTag, 'federation-id');
      expect(fedimint.metadata, isNull);
    });
  });

  group('NIP-B0', () {
    test('parses the B0 example and rebuilds its tag order', () {
      const tags = <List<String>>[
        ['d', 'alice.blog/post'],
        ['published_at', '1738863000'],
        ['title', 'Blog insights by Alice'],
        ['t', 'post'],
        ['t', 'insight'],
      ];

      final parsed = NostrWebBookmark.parse(
        _event(
          tags,
          kind: 39701,
          content: 'A marvelous insight by Alice about the nature of blogs and '
              'posts.',
        ),
      );
      expect(parsed.coordinate, 'alice.blog/post');
      expect(parsed.url, 'https://alice.blog/post');
      expect(parsed.domain, 'alice.blog');
      expect(parsed.publishedAt, 1738863000);
      expect(parsed.title, 'Blog insights by Alice');
      expect(parsed.topics, ['post', 'insight']);
      expect(
        parsed.address.address,
        '39701:$_pubkey:alice.blog/post',
      );

      final built = NostrNipB0.generateBookmarkTemplate(
        url: 'https://alice.blog/post',
        publishedAt: 1738863000,
        title: 'Blog insights by Alice',
        topics: const ['post', 'insight'],
        content: 'A marvelous insight by Alice about the nature of blogs and '
            'posts.',
      );
      expect(built.kind, 39701);
      expect(built.tags, tags);
      expect(NostrWebBookmark.parse(built).url, parsed.url);
    });

    test('omits only the https scheme and accepts both d forms', () {
      expect(
        NostrNipB0.coordinateForUrl('https://alice.blog/post'),
        'alice.blog/post',
      );
      expect(
        NostrNipB0.coordinateForUrl('http://alice.blog/post'),
        'http://alice.blog/post',
      );
      expect(
        NostrNipB0.urlForCoordinate('alice.blog/post'),
        'https://alice.blog/post',
      );
      expect(
        NostrNipB0.urlForCoordinate('https://alice.blog/post'),
        'https://alice.blog/post',
      );

      final explicit = NostrWebBookmark.tryParse(
        _event(
          const [
            ['d', 'https://alice.blog/post'],
          ],
          kind: 39701,
        ),
      );
      expect(explicit?.coordinate, 'https://alice.blog/post');
      expect(explicit?.url, 'https://alice.blog/post');

      expect(
        NostrNipB0.generateBookmarkTemplate(
          url: 'https://alice.blog/post',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ).tags!.first,
        ['d', 'alice.blog/post'],
      );
      expect(
        NostrWebBookmark.parse(
          NostrNipB0.generateBookmarkTemplate(url: 'https://alice.blog/post'),
        ).publishedAt,
        isNotNull,
      );
    });

    test('keeps the d tag verbatim for http URLs, case and fragments', () {
      expect(
        NostrNipB0.coordinateForUrl('http://alice.blog/post'),
        'http://alice.blog/post',
      );
      expect(
        NostrNipB0.coordinateForUrl('https://Alice.Blog/Post#Section'),
        'Alice.Blog/Post#Section',
      );
      expect(
        NostrNipB0.urlForCoordinate('alice.blog/post#section'),
        'https://alice.blog/post#section',
      );
      expect(
        NostrNipB0.urlForCoordinate('http://alice.blog/post'),
        'http://alice.blog/post',
      );
      expect(
        NostrNipB0.urlForCoordinate('//alice.blog/post'),
        'https://alice.blog/post',
      );
    });

    test('builds an address-scoped kind-1111 reply from the bookmark',
        () async {
      final bookmark = NostrWebBookmark.parse(
        _event(
          const [
            ['d', 'alice.blog/post'],
            ['title', 'Blog insights by Alice'],
          ],
          kind: 39701,
          pubkey: _pubkey,
        ),
      );
      final address = bookmark.address.address;

      final comment = await NostrSocialBuilder(signer: signer).createComment(
        content: 'Nice post',
        parentAddress: address,
      );

      expect(comment.kind, 1111);
      expect(
        comment.tags,
        containsAll([
          ['A', address],
          ['K', '39701'],
          ['P', _pubkey],
          ['a', address],
          ['k', '39701'],
          ['p', _pubkey],
        ]),
      );
    });

    test('rejects invalid bookmarks', () {
      expect(
        () => NostrNipB0.generateBookmarkTemplate(url: 'alice.blog/post'),
        throwsArgumentError,
      );
      expect(
        () => NostrNipB0.generateBookmarkTemplate(url: 'https://'),
        throwsArgumentError,
      );
      expect(() => NostrNipB0.urlForCoordinate(''), throwsArgumentError);
      expect(
        NostrWebBookmark.tryParse(_event(const [], kind: 39701)),
        isNull,
      );
      expect(NostrWebBookmark.tryParse(_event(const [], kind: 1)), isNull);
    });

    test('publishes with the bound signer', () async {
      final nips = NostrNipB0(signer: signer);
      final signed = await nips.publish(
        NostrNipB0.generateBookmarkTemplate(url: 'https://alice.blog/post'),
      );

      expect(signed.pubkey, signer.publicKey);
      expect(signed.kind, 39701);
    });
  });

  group('NIP-CC', () {
    const cacheAddress = NostrEventAddress(
      kind: 37516,
      pubkey: _pubkey,
      identifier: 'first-treasure-1748619568668',
    );

    test('builds the basic cache example tag order', () {
      final event = NostrNipCC.generateCacheTemplate(
        dTag: 'first-treasure-1748619568668',
        name: 'First Treasure',
        geohashes: const [
          'u4x',
          'u4xs',
          'u4xsu',
          'u4xsu6',
          'u4xsu6r',
          'u4xsu6ry',
          'u4xsu6ryb',
        ],
        difficulty: 1,
        terrain: 1,
        size: 'small',
        hint: 'In the branches',
        images: const [
          'https://blossom.primal.net/74efe01a767b27dead71b8a9bb8278a1083604'
              '38e78e55194ed9ab14a9382dd3.jpg',
        ],
        content: 'The first Nostr treasure, left in the aftermath of Oslo '
            'Freedom Forum!',
      );

      expect(event.kind, 37516);
      expect(event.tags, [
        ['d', 'first-treasure-1748619568668'],
        ['name', 'First Treasure'],
        ['g', 'u4x'],
        ['g', 'u4xs'],
        ['g', 'u4xsu'],
        ['g', 'u4xsu6'],
        ['g', 'u4xsu6r'],
        ['g', 'u4xsu6ry'],
        ['g', 'u4xsu6ryb'],
        ['D', '1'],
        ['T', '1'],
        ['S', 'small'],
        ['t', 'traditional'],
        ['hint', 'In the branches'],
        [
          'image',
          'https://blossom.primal.net/74efe01a767b27dead71b8a9bb8278a1083604'
              '38e78e55194ed9ab14a9382dd3.jpg',
        ],
      ]);

      final parsed = NostrGeocache.parse(event);
      expect(parsed.name, 'First Treasure');
      expect(parsed.geohashes, hasLength(7));
      expect(parsed.type, 'traditional');
      expect(parsed.difficulty, 1);
      expect(parsed.terrain, 1);
      expect(parsed.size, 'small');
      expect(parsed.requiresVerification, isFalse);
    });

    test('parses the verified and key-quest cache examples', () {
      final verified = _event(
        const [
          ['d', 'verified-treasure-1748619568669'],
          ['name', 'Verified Treasure'],
          ['g', 'u4xsu6ry'],
          ['D', '3'],
          ['T', '2'],
          ['S', 'small'],
          ['t', 'traditional'],
          ['hint', 'Look for the secret code'],
          ['verification', _verificationKey],
        ],
        kind: 37516,
      );
      final parsed = NostrGeocache.parse(verified);
      expect(parsed.verificationPubkey, _verificationKey);
      expect(parsed.requiresVerification, isTrue);
      expect(parsed.firstToFind, isNull);

      final quest = _event(
        const [
          ['d', 'key-quest-treasure-1748619568670'],
          ['name', 'Riddle of the Old Oak'],
          ['g', 'u4xsu6ry'],
          ['D', '4'],
          ['T', '2'],
          ['S', 'small'],
          ['t', 'mystery'],
          ['hint', 'Count the rings on the fallen log'],
          ['mission', 'Bring a token of nature you found along the way'],
          ['mission', 'Ignored second mission'],
          ['verification', _verificationKey],
        ],
        kind: 37516,
      );
      final parsedQuest = NostrGeocache.parse(quest);
      expect(parsedQuest.type, 'mystery');
      expect(
        parsedQuest.mission,
        'Bring a token of nature you found along the way',
      );
    });

    test('builds and parses the first-to-find art example', () {
      final event = NostrNipCC.generateCacheTemplate(
        dTag: 'linocut-aftermath-1748619568671',
        name: 'Aftermath (Linocut #1)',
        geohashes: const ['u4xsu6ry'],
        difficulty: 2,
        terrain: 2,
        size: 'small',
        modifiers: const ['first-to-find', 'art'],
        hint: 'Behind glass, but not in a frame',
        images: const ['https://blossom.primal.net/example-linocut.jpg'],
        verificationPubkey: _verificationKey,
        content: 'Hand-pulled linocut, edition of 1, signed on the back next '
            'to the QR. Whoever finds it keeps it.',
      );

      expect(event.tags, [
        ['d', 'linocut-aftermath-1748619568671'],
        ['name', 'Aftermath (Linocut #1)'],
        ['g', 'u4xsu6ry'],
        ['D', '2'],
        ['T', '2'],
        ['S', 'small'],
        ['t', 'traditional'],
        ['n', 'first-to-find'],
        ['n', 'art'],
        ['hint', 'Behind glass, but not in a frame'],
        ['image', 'https://blossom.primal.net/example-linocut.jpg'],
        ['verification', _verificationKey],
      ]);

      final parsed = NostrGeocache.parse(event);
      expect(parsed.isFirstToFind, isTrue);
      expect(parsed.isArt, isTrue);
      expect(parsed.isArchived, isFalse);
    });

    test('rejects invalid cache listings', () {
      NostrEvent cache({List<String>? geohashes, List<String>? modifiers}) {
        return _event(
          [
            ['d', 'd'],
            ['name', 'n'],
            for (final geohash in geohashes ?? ['u4xsu6ry']) ['g', geohash],
            ['D', '1'],
            ['T', '1'],
            ['S', 'small'],
            for (final modifier in modifiers ?? const <String>[])
              ['n', modifier],
          ],
          kind: 37516,
        );
      }

      expect(NostrGeocache.tryParse(cache(geohashes: ['u4'])), isNull);
      expect(
        NostrGeocache.tryParse(cache(geohashes: ['u4xsu6ryb1'])),
        isNull,
      );
      expect(NostrGeocache.tryParse(cache(geohashes: ['u4xsu6rya'])), isNull);
      expect(
        NostrGeocache.tryParse(
          cache(
            modifiers: const [
              'first-to-find',
              'first-to-find',
              'mystery',
              'mystery',
            ],
          ),
        )?.modifiers,
        ['first-to-find', 'mystery'],
      );
      expect(NostrGeocache.tryParse(_event(const [], kind: 1)), isNull);
      expect(
        NostrGeocache.tryParse(
          _event(
            const [
              ['d', 'd'],
              ['name', 'n'],
              ['g', 'u4xsu6ry'],
              ['D', '6'],
              ['T', '1'],
              ['S', 'small'],
            ],
            kind: 37516,
          ),
        ),
        isNull,
      );
      expect(
        NostrGeocache.tryParse(
          _event(
            const [
              ['d', 'd'],
              ['name', 'n'],
              ['g', 'u4xsu6ry'],
              ['D', '1'],
              ['T', '1'],
              ['S', 'huge'],
            ],
            kind: 37516,
          ),
        ),
        isNull,
      );
      expect(
        NostrGeocache.tryParse(
          _event(
            const [
              ['d', 'd'],
              ['name', 'n'],
              ['g', 'u4xsu6ry'],
              ['D', '1'],
              ['T', '1'],
              ['S', 'small'],
              ['F', _pubkey],
            ],
            kind: 37516,
          ),
        ),
        isNull,
      );

      expect(
        () => NostrNipCC.generateCacheTemplate(
          dTag: 'd',
          name: 'n',
          geohashes: const ['u4'],
          difficulty: 1,
          terrain: 1,
          size: 'small',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipCC.generateCacheTemplate(
          dTag: 'd',
          name: 'n',
          geohashes: const ['u4xsu6ry'],
          difficulty: 0,
          terrain: 1,
          size: 'small',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipCC.generateCacheTemplate(
          dTag: 'd',
          name: 'n',
          geohashes: const ['u4xsu6ry'],
          difficulty: 1,
          terrain: 1,
          size: 'small',
          firstToFind: _pubkey,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipCC.generateCacheTemplate(
          dTag: 'd',
          name: 'n',
          geohashes: const ['u4xsu6ry'],
          difficulty: 1,
          terrain: 1,
          size: 'small',
          modifiers: const ['first-to-find'],
          firstToFind: _pubkey,
        ),
        throwsArgumentError,
      );
    });

    test('builds the found log and verified found log examples', () {
      final found = NostrNipCC.generateFoundLogTemplate(
        cache: cacheAddress,
        content: 'Found it! Great hiding spot.',
      );
      expect(found.kind, 7516);
      expect(found.tags, [
        ['a', cacheAddress.address],
      ]);

      final verification = _event(
        const [
          ['a', '$_pubkey:$_specNaddr'],
        ],
        kind: 7517,
        content: 'Geocache verification for $_finderNpub',
        pubkey: _verificationKey,
        sig: 'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456'
            '789012345678901234567890abcdef1234567890abcdef1234567890abcdef12',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1672531200000),
      );
      final withProof = NostrNipCC.generateFoundLogTemplate(
        cache: NostrEventAddress.parse(_geocacheCoordinate),
        content: 'Found it! Great hiding spot.',
        verification: verification,
      );
      expect(withProof.tags, [
        ['a', _geocacheCoordinate],
        ['verification', NostrNipCC.encodeEventJson(verification)],
      ]);
      expect(
        NostrNipCC.encodeEventJson(verification),
        _verificationJson,
      );

      final parsed = NostrGeocacheFoundLog.parse(withProof);
      expect(parsed.address.address, _geocacheCoordinate);
      expect(parsed.isVerified, isTrue);
      expect(parsed.proof?.finderPubkey, _pubkey);
      expect(parsed.proof?.naddr, _specNaddr);
      expect(parsed.proof?.content, 'Geocache verification for $_finderNpub');

      expect(
        NostrGeocacheFoundLog.tryParse(
          _event(
            const [
              ['a', _geocacheCoordinate],
              ['verification', 'not json'],
            ],
            kind: 7516,
          ),
        ),
        isNull,
      );
      expect(
        NostrGeocacheFoundLog.tryParse(
          _event(
            const [
              ['a', '37516:$_pubkey:d'],
            ],
            kind: 1,
          ),
        ),
        isNull,
      );
    });

    test('builds the DNF comment with identical root and parent tags', () {
      final event = NostrNipCC.generateCommentTemplate(
        cache: cacheAddress,
        content: 'Searched for 30 minutes but could not find it. Maybe it is '
            'missing?',
        logType: 'dnf',
      );

      expect(event.kind, 1111);
      expect(event.tags, [
        ['A', cacheAddress.address],
        ['K', '37516'],
        ['P', _pubkey],
        ['a', cacheAddress.address],
        ['k', '37516'],
        ['p', _pubkey],
        ['t', 'dnf'],
      ]);

      final parsed = NostrGeocacheComment.parse(event);
      expect(parsed.logType, 'dnf');
      expect(parsed.address.address, cacheAddress.address);

      final note = NostrGeocacheComment.parse(
        _event(
          const [
            ['A', '37516:$_pubkey:d'],
            ['K', '37516'],
            ['P', _pubkey],
            ['a', '37516:$_pubkey:d'],
            ['k', '37516'],
            ['p', _pubkey],
          ],
          kind: 1111,
        ),
      );
      expect(note.logType, 'note');

      final mismatched = _event(
        const [
          ['A', '37516:$_pubkey:d'],
          ['K', '37516'],
          ['P', _pubkey],
          ['a', '37516:$_otherKey:d'],
          ['k', '37516'],
          ['p', _pubkey],
        ],
        kind: 1111,
      );
      expect(NostrGeocacheComment.tryParse(mismatched), isNull);

      expect(
        () => NostrNipCC.generateCommentTemplate(
          cache: cacheAddress,
          content: '',
          logType: 'found',
        ),
        throwsArgumentError,
      );
    });

    test('parses the verification example and rejects bad coordinates', () {
      final event = _event(
        const [
          ['a', '$_pubkey:$_specNaddr'],
        ],
        kind: 7517,
        content: 'Geocache verification for $_finderNpub',
        pubkey: _verificationKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1672531200000),
      );
      final verification = NostrGeocacheVerification.parse(event);
      expect(verification.finderPubkey, _pubkey);
      expect(verification.naddr, _specNaddr);
      expect(
        NostrGeocacheVerification.npubFromContent(verification.content),
        _finderNpub,
      );
      expect(
        NostrGeocacheVerification.isVerificationContent(verification.content),
        isTrue,
      );
      expect(
        NostrGeocacheVerification.isVerificationContent(
            'Geocache verification'),
        isFalse,
      );

      final built = NostrNipCC.generateVerificationTemplate(
        finderPubkey: _pubkey,
        cache: NostrEventAddress.parse(_geocacheCoordinate),
        bech32: bech32,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1672531200000),
      );
      expect(
        built.content,
        'Geocache verification for '
        '${bech32.encodePublicKeyToNpub(_pubkey)}',
      );
      expect(
        built.tags!.single.first,
        'a',
      );
      expect(built.tags!.single[1], startsWith('$_pubkey:naddr1'));
      expect(
        NostrGeocacheVerification.tryParseEvent(built)?.finderPubkey,
        _pubkey,
      );

      for (final value in [
        'not-a-coordinate',
        '$_pubkey',
        '${_pubkey.substring(1)}:$_specNaddr',
        '${_pubkey.toUpperCase()}:$_specNaddr',
        '$_pubkey:naddr1qqqqb',
        '$_pubkey:nevent1qqqq',
      ]) {
        expect(
          NostrGeocacheVerificationRef.tryParse(value),
          isNull,
          reason: value,
        );
      }
      expect(
        NostrGeocacheVerificationRef.tryParse('$_pubkey:$_specNaddr')?.value,
        '$_pubkey:$_specNaddr',
      );
      expect(
        NostrGeocacheVerification.tryParseEvent(
          _event(
            const [
              ['a', '$_pubkey:$_specNaddr'],
            ],
            kind: 7517,
            content: 'wrong content',
          ),
        ),
        isNull,
      );
    });

    test('builds the curation list example tag order', () {
      const first = NostrEventAddress(
        kind: 37516,
        pubkey: _pubkey,
        identifier: 'first-treasure-1748619568668',
      );
      const verified = NostrEventAddress(
        kind: 37516,
        pubkey: _pubkey,
        identifier: 'verified-treasure-1748619568669',
      );

      final event = NostrNipCC.generateCurationTemplate(
        dTag: 'ren-fest-hunt-1748619568670',
        title: 'Texas Ren Fest Treasure Hunt',
        description: 'Find all the hidden treasures at the festival!',
        image: 'https://blossom.primal.net/banner-example.jpg',
        geohashes: const ['9vk', '9vk5', '9vk5b', '9vk5b7'],
        theme: 'adventure',
        mapStyle: 'adventure',
        geocaches: const [first, verified],
        content: 'Explore the festival grounds and find all hidden treasures '
            'before the jousting tournament!',
      );

      expect(event.kind, 37517);
      expect(event.tags, [
        ['d', 'ren-fest-hunt-1748619568670'],
        ['title', 'Texas Ren Fest Treasure Hunt'],
        ['description', 'Find all the hidden treasures at the festival!'],
        ['image', 'https://blossom.primal.net/banner-example.jpg'],
        ['g', '9vk'],
        ['g', '9vk5'],
        ['g', '9vk5b'],
        ['g', '9vk5b7'],
        ['theme', 'adventure'],
        ['map', 'adventure'],
        ['a', first.address],
        ['a', verified.address],
      ]);

      final parsed = NostrGeocacheCuration.parse(event);
      expect(parsed.geocaches.map((address) => address.address), [
        first.address,
        verified.address,
      ]);
      expect(parsed.theme, 'adventure');
      expect(parsed.mapStyle, 'adventure');

      expect(
        () => NostrNipCC.generateCurationTemplate(
          dTag: 'x',
          title: 'x',
          geocaches: const [first],
          theme: 'neon',
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipCC.generateCurationTemplate(
          dTag: 'x',
          title: 'x',
          geocaches: const [first],
          geohashes: const ['9vk5b7a'],
        ),
        throwsArgumentError,
      );
      expect(
        NostrGeocacheCuration.tryParse(
          _event(
            const [
              ['d', 'x'],
              ['title', 'x'],
              ['a', '30023:$_pubkey:article'],
            ],
            kind: 37517,
          ),
        ),
        isNull,
      );
    });

    test('orders verified finds and honours the locked F winner', () {
      final cache = NostrGeocache.parse(
        _event(
          const [
            ['d', 'verified-treasure-1748619568669'],
            ['name', 'Verified Treasure'],
            ['g', 'u4xsu6ry'],
            ['D', '3'],
            ['T', '2'],
            ['S', 'small'],
            ['n', 'first-to-find'],
            ['verification', _verificationKey],
          ],
          kind: 37516,
        ),
      );
      final address = NostrEventAddress(
        kind: 37516,
        pubkey: _pubkey,
        identifier: cache.dTag,
      );

      NostrGeocacheFoundLog log(
        String author,
        String id,
        DateTime at, {
        String proofPubkey = _verificationKey,
      }) {
        final event = _event(
          const [
            ['a', _geocacheCoordinate],
          ],
          kind: 7516,
          pubkey: author,
          id: id,
          createdAt: at,
        );
        final template = NostrNipCC.generateVerificationTemplate(
          finderPubkey: author,
          cache: address,
          bech32: bech32,
          createdAt: at,
        );
        // The template has an empty author; pin the cache verification key to
        // model a published proof, or another key for a forged proof.
        final proof = NostrEvent(
          id: null,
          kind: 7517,
          content: template.content,
          sig: null,
          pubkey: proofPubkey,
          createdAt: template.createdAt,
          tags: template.tags,
        );
        return NostrGeocacheFoundLog.parse(
          NostrEvent(
            id: id,
            kind: 7516,
            content: '',
            sig: null,
            pubkey: author,
            createdAt: at,
            tags: [
              ...event.tags!,
              ['verification', NostrNipCC.encodeEventJson(proof)],
            ],
          ),
        );
      }

      final early = log(_otherKey, 'a' * 64, DateTime.utc(2024, 1, 1));
      final late = log(_verificationKey, 'b' * 64, DateTime.utc(2024, 1, 2));
      final tie = log(_pubkey, 'a' * 64, DateTime.utc(2024, 1, 1));
      final forged = log(
        _otherKey,
        'd' * 64,
        DateTime.utc(2023, 12, 31),
        proofPubkey: _otherKey,
      );
      final unverified = NostrGeocacheFoundLog.parse(
        _event(
          const [
            ['a', _geocacheCoordinate],
          ],
          kind: 7516,
          pubkey: _pubkey,
          id: 'c' * 64,
          createdAt: DateTime.utc(2023),
        ),
      );

      expect(NostrNipCC.sortVerifiedFinds([late], cache: cache), hasLength(1));
      expect(
        NostrNipCC.sortVerifiedFinds(
          [late, early, unverified, tie, forged],
          cache: cache,
        ).first.id,
        'a' * 64,
      );
      expect(
        NostrNipCC.firstVerifiedFind([late, early], cache: cache)?.pubkey,
        _otherKey,
      );
      expect(
        NostrNipCC.claimWinner(
          cache: cache,
          logs: [late, early],
        ),
        _otherKey,
      );

      expect(forged.isVerified, isTrue);
      expect(forged.isVerifiedFor(cache), isFalse);
      expect(NostrNipCC.sortVerifiedFinds([forged], cache: cache), isEmpty);
      expect(
        NostrNipCC.firstVerifiedFind([forged], cache: cache),
        isNull,
      );
      expect(
        NostrNipCC.claimWinner(cache: cache, logs: [forged]),
        isNull,
      );

      final locked = NostrGeocache.parse(
        _event(
          const [
            ['d', 'verified-treasure-1748619568669'],
            ['name', 'Verified Treasure'],
            ['g', 'u4xsu6ry'],
            ['D', '3'],
            ['T', '2'],
            ['S', 'small'],
            ['t', 'archived'],
            ['n', 'first-to-find'],
            ['verification', _verificationKey],
            ['F', _verificationKey],
          ],
          kind: 37516,
        ),
      );
      expect(locked.isArchived, isTrue);
      expect(locked.type, 'traditional');
      expect(
        NostrNipCC.claimWinner(cache: locked, logs: [late, early]),
        _verificationKey,
      );
    });

    test('validates a verified find structure', () {
      final cache = NostrGeocache.parse(
        _event(
          const [
            ['d', 'verified-treasure-1748619568669'],
            ['name', 'Verified Treasure'],
            ['g', 'u4xsu6ry'],
            ['D', '3'],
            ['T', '2'],
            ['S', 'small'],
            ['n', 'first-to-find'],
            ['verification', _verificationKey],
          ],
          kind: 37516,
        ),
      );
      final address = NostrEventAddress(
        kind: 37516,
        pubkey: _pubkey,
        identifier: cache.dTag,
      );
      final proof = NostrNipCC.generateVerificationTemplate(
        finderPubkey: _pubkey,
        cache: address,
        bech32: bech32,
        createdAt: DateTime.utc(2024),
      );

      final log = NostrGeocacheFoundLog.parse(
        NostrEvent(
          id: 'd' * 64,
          kind: 7516,
          content: '',
          sig: null,
          pubkey: _pubkey,
          createdAt: DateTime.utc(2024),
          tags: [
            ['a', address.address],
            ['verification', NostrNipCC.encodeEventJson(proof)],
          ],
        ),
      );
      // The template author is empty; the verification key signs the final
      // event, so pin it here to model a published verification.
      final signedProof = NostrGeocacheFoundLog.parse(
        NostrEvent(
          id: 'e' * 64,
          kind: 7516,
          content: '',
          sig: null,
          pubkey: _pubkey,
          createdAt: DateTime.utc(2024),
          tags: [
            ['a', address.address],
            [
              'verification',
              NostrNipCC.encodeEventJson(
                NostrEvent(
                  id: null,
                  kind: 7517,
                  content: proof.content,
                  sig: null,
                  pubkey: _verificationKey,
                  createdAt: proof.createdAt,
                  tags: proof.tags,
                ),
              ),
            ],
          ],
        ),
      );

      expect(
        NostrNipCC.validateVerifiedFind(
          log: log,
          cache: cache,
          cacheAddress: address,
          bech32: bech32,
        ).valid,
        isFalse,
      );
      expect(
        NostrNipCC.validateVerifiedFind(
          log: signedProof,
          cache: cache,
          cacheAddress: address,
          bech32: bech32,
        ).valid,
        isTrue,
      );
    });

    test('accepts a naddr carrying relay hints for the same coordinate', () {
      final cache = NostrGeocache.parse(
        _event(
          const [
            ['d', 'verified-treasure-1748619568669'],
            ['name', 'Verified Treasure'],
            ['g', 'u4xsu6ry'],
            ['D', '3'],
            ['T', '2'],
            ['S', 'small'],
            ['verification', _verificationKey],
          ],
          kind: 37516,
        ),
      );
      const address = NostrEventAddress(
        kind: 37516,
        pubkey: _pubkey,
        identifier: 'verified-treasure-1748619568669',
      );

      NostrGeocacheFoundLog logWith(String naddr) {
        final proof = NostrEvent(
          id: null,
          kind: 7517,
          content: 'Geocache verification for '
              '${bech32.encodePublicKeyToNpub(_pubkey)}',
          sig: null,
          pubkey: _verificationKey,
          createdAt: DateTime.utc(2024),
          tags: [
            ['a', '$_pubkey:$naddr'],
          ],
        );

        return NostrGeocacheFoundLog.parse(
          NostrEvent(
            id: 'f' * 64,
            kind: 7516,
            content: '',
            sig: null,
            pubkey: _pubkey,
            createdAt: DateTime.utc(2024),
            tags: [
              ['a', address.address],
              ['verification', NostrNipCC.encodeEventJson(proof)],
            ],
          ),
        );
      }

      final plain = bech32.encodeNAddr(
        kind: address.kind,
        authorPubkey: address.pubkey,
        identifier: address.identifier,
      );
      final hinted = bech32.encodeNAddr(
        kind: address.kind,
        authorPubkey: address.pubkey,
        identifier: address.identifier,
        userRelays: const ['wss://relay.example.com'],
      );
      expect(hinted, isNot(plain));

      for (final naddr in [plain, hinted]) {
        final validation = NostrNipCC.validateVerifiedFind(
          log: logWith(naddr),
          cache: cache,
          cacheAddress: address,
          bech32: bech32,
        );
        expect(validation.problems, isEmpty, reason: naddr);
      }
    });

    test('rejects a log whose a tag is not the cache address', () {
      final cache = NostrGeocache.parse(
        _event(
          const [
            ['d', 'verified-treasure-1748619568669'],
            ['name', 'Verified Treasure'],
            ['g', 'u4xsu6ry'],
            ['D', '3'],
            ['T', '2'],
            ['S', 'small'],
            ['verification', _verificationKey],
          ],
          kind: 37516,
        ),
      );
      const address = NostrEventAddress(
        kind: 37516,
        pubkey: _pubkey,
        identifier: 'verified-treasure-1748619568669',
      );
      const other = NostrEventAddress(
        kind: 37516,
        pubkey: _pubkey,
        identifier: 'another-treasure',
      );
      final naddr = bech32.encodeNAddr(
        kind: address.kind,
        authorPubkey: address.pubkey,
        identifier: address.identifier,
      );
      final proof = NostrEvent(
        id: null,
        kind: 7517,
        content: 'Geocache verification for '
            '${bech32.encodePublicKeyToNpub(_pubkey)}',
        sig: null,
        pubkey: _verificationKey,
        createdAt: DateTime.utc(2024),
        tags: [
          ['a', '$_pubkey:$naddr'],
        ],
      );
      final log = NostrGeocacheFoundLog.parse(
        NostrEvent(
          id: 'f' * 64,
          kind: 7516,
          content: '',
          sig: null,
          pubkey: _pubkey,
          createdAt: DateTime.utc(2024),
          tags: [
            ['a', other.address],
            ['verification', NostrNipCC.encodeEventJson(proof)],
          ],
        ),
      );

      final validation = NostrNipCC.validateVerifiedFind(
        log: log,
        cache: cache,
        cacheAddress: address,
        bech32: bech32,
      );
      expect(validation.valid, isFalse);
      expect(
        validation.problems,
        contains(
          'log address ${other.address} does not match the cache '
          'address ${address.address}',
        ),
      );
    });

    test('requires a non-empty cache identifier in builders', () {
      expect(
        () => NostrNipCC.generateFoundLogTemplate(
          cache: const NostrEventAddress(kind: 37516, pubkey: _pubkey),
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNipCC.generateCommentTemplate(
          cache: const NostrEventAddress(kind: 37516, pubkey: _pubkey),
          content: 'note',
        ),
        throwsArgumentError,
      );
    });

    test('publishes with the bound signer and the verification signer',
        () async {
      final nips = NostrNipCC(signer: signer, bech32: bech32);
      final signed = await nips.publish(
        NostrNipCC.generateCacheTemplate(
          dTag: 'd',
          name: 'n',
          geohashes: const ['u4xsu6ry'],
          difficulty: 1,
          terrain: 1,
          size: 'small',
        ),
      );
      expect(signed.pubkey, signer.publicKey);

      final verificationSigner = NostrLocalKeySigner(NostrKeyPairs.generate());
      final proof = NostrNipCC.generateVerificationTemplate(
        finderPubkey: _pubkey,
        cache: cacheAddress,
        bech32: bech32,
      );
      final signedProof = await nips.publishVerification(
        proof,
        verificationSigner: verificationSigner,
      );
      expect(signedProof.pubkey, verificationSigner.publicKey);
      expect(signedProof.kind, 7517);

      expect(
        () => nips.publishVerification(
          signed,
          verificationSigner: verificationSigner,
        ),
        throwsArgumentError,
      );
    });
  });
}
