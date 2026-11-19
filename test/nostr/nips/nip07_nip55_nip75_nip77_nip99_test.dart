import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
  const filter = NostrFilter(kinds: [1]);

  group('NIP-07', () {
    test('builds the provider event template', () {
      final event = NostrEvent(
        id: null,
        kind: 1,
        content: 'hi',
        sig: null,
        pubkey: 'a' * 64,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        tags: const [
          ['t', 'x'],
        ],
      );

      expect(NostrNip07.eventTemplate(event), {
        'kind': 1,
        'created_at': 1700000000,
        'tags': [
          ['t', 'x'],
        ],
        'content': 'hi',
      });
    });

    test('signs through the capable and exposes a signer adapter', () async {
      final capable = _WebNostr(signer);
      final adapter = await NostrNip07Signer.connect(capable);

      expect(adapter.publicKey, signer.publicKey);
      expect(await NostrNip07.getPublicKey(capable), signer.publicKey);

      final signed = await adapter.sign(
        NostrEvent(
          id: null,
          kind: 1,
          content: 'hello',
          sig: null,
          pubkey: signer.publicKey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          tags: const [],
        ),
      );

      expect(signed.kind, 1);
      expect(signed.pubkey, signer.publicKey);
      expect(signed.isVerified(), isTrue);
    });

    test('delegates nip04 and nip44 when the provider supports them', () async {
      final capable = _WebNostr(signer);

      expect(
        await NostrNip07.nip04Encrypt(capable, 'b' * 64, 'secret'),
        'nip04:b:secret',
      );
      expect(
        await NostrNip07.nip44Encrypt(capable, 'b' * 64, 'secret'),
        'nip44:b:secret',
      );
      expect(
        await NostrNip07.nip04Decrypt(capable, 'b' * 64, 'cipher'),
        'nip04-dec:b:cipher',
      );
      expect(
        await NostrNip07.nip44Decrypt(capable, 'b' * 64, 'cipher'),
        'nip44-dec:b:cipher',
      );
    });

    test('throws when the provider lacks nip44', () {
      final capable = _CoreWebNostr(signer);

      expect(
        () => NostrNip07.nip44Encrypt(capable, 'b' * 64, 'x'),
        throwsUnsupportedError,
      );
    });

    test('rejects unsigned provider responses', () {
      expect(
        () => NostrNip07.fromSignedMap(const {'kind': 1}),
        throwsFormatException,
      );
    });
  });

  group('NIP-55', () {
    test('builds a get_public_key intent', () {
      final uri = NostrNip55.getPublicKeyUri(
        permissions: const [
          {'type': 'sign_event', 'kind': 1},
        ],
        callbackUrl: 'https://app.example/cb',
        appName: 'Example',
      );

      final params = Uri.parse(uri).queryParameters;

      expect(params['type'], 'get_public_key');
      expect(params['returnType'], 'signature');
      expect(params['compressionType'], 'none');
      expect(params['callbackUrl'], 'https://app.example/cb');
      expect(params['appName'], 'Example');
      expect(
        Uri.decodeComponent(params['permissions']!),
        jsonEncode([
          {'type': 'sign_event', 'kind': 1},
        ]),
      );
    });

    test('embeds the event in sign_event intents', () {
      final event = NostrEvent(
        id: null,
        kind: 1,
        content: 'hello',
        sig: null,
        pubkey: 'a' * 64,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        tags: const [],
      );
      final uri = NostrNip55.signEventUri(event: event, id: 'req-1');

      expect(Uri.parse(uri).queryParameters['type'], 'sign_event');
      expect(Uri.parse(uri).queryParameters['id'], 'req-1');

      final raw = uri.substring(
        NostrNip55.scheme.length,
        uri.indexOf('?'),
      );
      final decoded = jsonDecode(Uri.decodeComponent(raw));
      expect((decoded as Map<String, dynamic>)['kind'], 1);
    });

    test('maps encrypt/decrypt payloads to plainText/encryptedText', () {
      final encrypt = NostrNip55.encryptNip04Uri(
        pubKey: 'b' * 64,
        content: 'hello world',
      );
      final decrypt = NostrNip55.decryptNip44Uri(
        pubKey: 'b' * 64,
        content: 'cipher text',
      );

      final encryptParams = Uri.parse(encrypt).queryParameters;
      final decryptParams = Uri.parse(decrypt).queryParameters;

      expect(encryptParams['type'], 'nip04_encrypt');
      expect(encryptParams['plainText'], 'hello world');
      expect(encryptParams['pubKey'], 'b' * 64);
      expect(decryptParams['type'], 'nip44_decrypt');
      expect(decryptParams['encryptedText'], 'cipher text');
      expect(decryptParams.containsKey('plainText'), isFalse);
    });

    test('parses signer responses', () {
      final event = NostrEvent(
        id: null,
        kind: 1,
        content: 'x',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        tags: const [],
      );

      final rejected = NostrNip55.parseResultUri(
        Uri(
          scheme: 'nostrsigner',
          queryParameters: const {
            'result': 'sig',
            'package': 'com.example.signer',
            'id': '1',
            'current_user': 'npub1me',
            'rejected': 'true',
          },
        ).toString(),
      );

      expect(rejected.result, 'sig');
      expect(rejected.package, 'com.example.signer');
      expect(rejected.currentUser, 'npub1me');
      expect(rejected.rejected, isTrue);

      final withEvent = NostrNip55.parseResultUri(
        Uri(
          scheme: 'nostrsigner',
          queryParameters: {'event': jsonEncode(event.toMap())},
        ).toString(),
      );

      expect(withEvent.event, isNotNull);
      expect(withEvent.event!['kind'], 1);
    });
  });

  group('NIP-75', () {
    test('generates a goal template with stable tag order', () {
      final event = NostrNip75.generateGoalTemplate(
        content: 'Fundraising',
        amount: '100000000',
        relays: const ['wss://relay1', 'wss://relay2'],
        closedAt: 1671150419,
        image: 'https://example.com/goal.jpg',
        summary: 'Help us',
        r: 'https://example.com/info',
        a: 'fef2a50f',
        zapTags: const [
          ['zap', 'beneficiary1'],
          ['zap', 'beneficiary2'],
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(event.kind, NostrNip75.goalKind);
      expect(event.tags, [
        ['amount', '100000000'],
        ['relays', 'wss://relay1', 'wss://relay2'],
        ['closed_at', '1671150419'],
        ['image', 'https://example.com/goal.jpg'],
        ['summary', 'Help us'],
        ['r', 'https://example.com/info'],
        ['a', 'fef2a50f'],
        ['zap', 'beneficiary1'],
        ['zap', 'beneficiary2'],
      ]);
    });

    test('validates and signs goals', () async {
      final event = await NostrNip75(
        signer: signer,
      ).createGoal(
        content: 'Fundraising',
        amount: '1000',
        relays: const ['wss://relay1'],
      );

      expect(event.isVerified(), isTrue);
      expect(NostrNip75.validateGoalEvent(event), isTrue);

      expect(
        NostrNip75.validateGoalEvent(
          NostrEvent(
            id: null,
            kind: 0,
            content: '',
            sig: null,
            pubkey: signer.publicKey,
            createdAt: DateTime.now(),
            tags: event.tags,
          ),
        ),
        isFalse,
      );
      expect(
        NostrNip75.validateGoalEvent(
          NostrEvent(
            id: null,
            kind: NostrNip75.goalKind,
            content: '',
            sig: null,
            pubkey: signer.publicKey,
            createdAt: DateTime.now(),
            tags: const [
              ['amount', '1000'],
            ],
          ),
        ),
        isFalse,
      );
    });
  });

  group('NIP-77', () {
    final a = 'a' * 64;
    final b = 'b' * 64;
    final c = 'c' * 64;

    test('sorts on seal and rejects duplicates', () {
      final storage = NostrNegentropyStorageVector()
        ..insert(300, c)
        ..insert(100, a)
        ..insert(200, b)
        ..seal();

      expect(storage.length, 3);
      expect(
        [for (var i = 0; i < 3; i++) storage.getItem(i).timestamp],
        [100, 200, 300],
      );
      expect(storage.isSealed, isTrue);

      final duplicate = NostrNegentropyStorageVector()
        ..insert(100, a)
        ..insert(100, a);

      expect(duplicate.seal, throwsStateError);
      expect(
        () => NostrNegentropyStorageVector().length,
        throwsStateError,
      );
      expect(
        () => NostrNegentropyStorageVector().insert(1, 'zz'),
        throwsA(isA<FormatException>()),
      );
    });

    test('reconciles identical sets without diffs', () {
      final client = NostrNegentropy(_storage([(100, a), (200, b)]));
      final server = NostrNegentropy(_storage([(100, a), (200, b)]));

      final incoming = client.initiate();
      expect(incoming.startsWith('61'), isTrue);

      final reply = server.reconcile(incoming);
      expect(reply.message, isNull);
      expect(reply.have, isEmpty);
      expect(reply.need, isEmpty);
    });

    test('reports have/need in both directions', () {
      final client = NostrNegentropy(_storage([(100, a), (200, b)]));
      final server = NostrNegentropy(_storage([(100, a), (300, c)]));

      final clientResult = client.reconcile(server.initiate());
      expect(clientResult.have, [b]);
      expect(clientResult.need, [c]);
      expect(clientResult.message, isNull);

      final serverResult = server.reconcile(client.initiate());
      expect(serverResult.have, [c]);
      expect(serverResult.need, [b]);
    });

    test('converges on fingerprint ranges for larger sets', () {
      final clientItems = [
        for (var i = 0; i < 40; i++) (i, _idAt(i)),
      ];
      final serverItems = [
        ...clientItems,
        (40, _idAt(40)),
      ];

      final client = NostrNegentropy(_storage(clientItems));
      final server = NostrNegentropy(_storage(serverItems));

      final clientNeed = <String>[];
      var serverReply = server.reconcile(client.initiate());

      var guard = 0;
      while (serverReply.message != null) {
        final clientReply = client.reconcile(serverReply.message!);
        clientNeed.addAll(clientReply.need);

        if (clientReply.message == null) {
          break;
        }

        serverReply = server.reconcile(clientReply.message!);
        guard++;
        if (guard > 20) {
          fail('negentropy did not converge');
        }
      }

      expect(clientNeed, [_idAt(40)]);
    });

    test('validates the frame size limit', () {
      expect(
        () => NostrNegentropy(_storage(const []), frameSizeLimit: 100),
        throwsArgumentError,
      );
    });

    test('drives a session through NEG frames', () {
      final session = NostrNegentropySession(
        storage: _storage([(100, a)]),
        filter: filter,
      );

      final open = jsonDecode(session.startMessage()) as List<dynamic>;
      expect(open[0], 'NEG-OPEN');
      expect(open[1], 'negentropy');
      expect((open[2] as Map<String, dynamic>)['kinds'], [1]);
      expect(open[3], isA<String>());

      final payload = NostrNegentropy(
        _storage([(100, a), (300, c)]),
      ).initiate();

      final reply = session.handleMessage(['NEG-MSG', 'negentropy', payload]);
      expect(reply, isNull);
      expect(session.need, [c]);

      final closed = NostrNegentropySession(
        storage: _storage([(100, a)]),
        filter: filter,
      )..handleMessage(['NEG-ERR', 'negentropy', 'disabled']);

      expect(closed.isClosed, isTrue);
      expect(closed.closeReason, 'disabled');

      expect(
        NostrNegentropy.negMsgMessage(
          subscriptionId: 'sub',
          message: 'abc',
        ),
        jsonEncode(['NEG-MSG', 'sub', 'abc']),
      );
      expect(
        NostrNegentropy.negCloseMessage('sub'),
        jsonEncode(['NEG-CLOSE', 'sub']),
      );
    });
  });

  group('NIP-99', () {
    const listing = NostrClassifiedListing(
      title: 'Sample Title',
      summary: 'Sample Summary',
      content: 'Lorem ipsum',
      publishedAt: '1296962229',
      location: 'NYC',
      price: NostrClassifiedPrice(amount: '100', currency: 'USD'),
      images: [
        NostrClassifiedImage(
          url: 'https://example.com/image1.jpg',
          dimensions: '800x600',
        ),
        NostrClassifiedImage(url: 'https://example.com/image2.jpg'),
      ],
      hashtags: ['tag1', 'tag2'],
      additionalTags: {
        'e': ['value1', 'value2'],
        'a': ['value1', 'value2'],
      },
    );

    test('generates and parses a classified listing', () async {
      final template = NostrNip99.generateEventTemplate(
        listing,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(template.kind, NostrNip99.classifiedListingKind);
      expect(template.tags, [
        ['d', 'sample-title'],
        ['title', 'Sample Title'],
        ['published_at', '1296962229'],
        ['summary', 'Sample Summary'],
        ['location', 'NYC'],
        ['price', '100', 'USD'],
        ['image', 'https://example.com/image1.jpg', '800x600'],
        ['image', 'https://example.com/image2.jpg'],
        ['t', 'tag1'],
        ['t', 'tag2'],
        ['e', 'value1', 'value2'],
        ['a', 'value1', 'value2'],
      ]);
      expect(NostrNip99.validateEvent(template), isTrue);

      final parsed = NostrNip99.parseEvent(template);
      expect(parsed.title, 'Sample Title');
      expect(parsed.price.amount, '100');
      expect(parsed.price.currency, 'USD');
      expect(parsed.price.frequency, isNull);
      expect(parsed.images.length, 2);
      expect(parsed.images.first.dimensions, '800x600');
      expect(parsed.hashtags, ['tag1', 'tag2']);
      expect(parsed.additionalTags['e'], ['value1', 'value2']);

      final signed = await NostrNip99(signer: signer).publish(
        listing,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(signed.kind, NostrNip99.classifiedListingKind);
      expect(signed.isVerified(), isTrue);
    });

    test('rejects malformed listings', () {
      NostrEvent make({
        int kind = NostrNip99.classifiedListingKind,
        List<List<String>>? tags,
      }) {
        return NostrEvent(
          id: null,
          kind: kind,
          content: '',
          sig: null,
          pubkey: signer.publicKey,
          createdAt: DateTime.now(),
          tags: tags,
        );
      }

      final validTags = [
        ['d', 'sample-title'],
        ['title', 'Sample Title'],
        ['summary', 'Sample Summary'],
        ['published_at', '1296962229'],
        ['location', 'NYC'],
        ['price', '100', 'USD'],
      ];

      expect(NostrNip99.validateEvent(make(tags: validTags)), isTrue);
      expect(
        NostrNip99.validateEvent(
          make(
            tags: [
              ...validTags.sublist(0, 5),
              ['price', '10.50', 'USD'],
            ],
          ),
        ),
        isTrue,
        reason: 'NIP-99 amounts may be decimal',
      );
      expect(
        NostrNip99.validateEvent(
          make(
            tags: [
              ...validTags.sublist(0, 5),
              ['price', 'ten', 'USD'],
            ],
          ),
        ),
        isFalse,
      );
      expect(NostrNip99.validateEvent(make(kind: 1, tags: validTags)), isFalse);
      expect(
        NostrNip99.validateEvent(
          make(tags: validTags.sublist(0, validTags.length - 1)),
        ),
        isFalse,
      );
      expect(
        NostrNip99.validateEvent(
          make(
            tags: [
              ...validTags,
              ['title', 'duplicate'],
            ],
          ),
        ),
        isFalse,
      );
      expect(
        NostrNip99.validateEvent(
          make(
            tags: [
              ...validTags.sublist(0, 5),
              ['price', '100', 'US'],
            ],
          ),
        ),
        isFalse,
      );
      expect(
        () => NostrNip99.parseEvent(make(kind: 1, tags: validTags)),
        throwsArgumentError,
      );
    });
  });

  group('NIP-AD', () {
    test('matches web addresses', () {
      expect(NostrNipAD.isWebAddress('https://example.com/a/b'), isTrue);
      expect(NostrNipAD.isWebAddress('example.com'), isTrue);
      expect(NostrNipAD.isWebAddress('not a url'), isFalse);
      expect(NostrNipAD.isWebAddress(null), isFalse);
    });

    test('resolves a well-known pointer', () async {
      late Uri requested;
      final client = http_testing.MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            '/blog': {
              'filter': {
                'kinds': [1],
              },
              'relays': ['wss://relay.example'],
            },
          }),
          200,
        );
      });

      final pointer = await NostrNipAD(httpClient: client).queryWebAddress(
        'https://example.com/blog',
      );

      expect(requested.host, 'example.com');
      expect(requested.path, '/.well-known/nostr.json');
      expect(requested.queryParameters['path'], '/blog');
      expect(pointer, isNotNull);
      expect(pointer!.filter.kinds, [1]);
      expect(pointer.relays, ['wss://relay.example']);
    });

    test('returns null for misses and failures', () async {
      final unavailable = http_testing.MockClient(
        (_) async => http.Response('{}', 404),
      );
      expect(
        await NostrNipAD(httpClient: unavailable)
            .queryWebAddress('example.com/blog'),
        isNull,
      );

      final malformed = http_testing.MockClient(
        (_) async => http.Response('not json', 200),
      );
      expect(
        await NostrNipAD(httpClient: malformed)
            .queryWebAddress('example.com/blog'),
        isNull,
      );

      expect(
        await NostrNipAD(httpClient: unavailable).queryWebAddress('not a url'),
        isNull,
      );
    });

    test('encodes reserved characters in the path query', () async {
      late Uri requested;
      final client = http_testing.MockClient((request) async {
        requested = request.url;
        return http.Response('{}', 404);
      });

      await NostrNipAD(httpClient: client).queryWebAddress(
        'example.com/a?b&c=d',
      );

      expect(requested.queryParameters['path'], '/a?b&c=d');
    });

    test('times out instead of hanging', () async {
      final hanging = http_testing.MockClient(
        (_) => Future.delayed(const Duration(seconds: 5), () {
          return http.Response('{}', 200);
        }),
      );

      final pointer = await NostrNipAD(httpClient: hanging).queryWebAddress(
        'example.com/blog',
        timeout: const Duration(milliseconds: 1),
      );

      expect(pointer, isNull);
    });

    test('closes its HTTP client', () {
      final client =
          http_testing.MockClient((_) async => http.Response('{}', 200));
      NostrNipAD(httpClient: client).close();
    });
  });

  group('NIP-B7', () {
    final hash = 'ab' * 32;

    test('creates signed authorization events', () async {
      final nipB7 = NostrNipB7(signer: signer);
      final auth = await nipB7.createUploadAuth(
        [hash, hash],
        expiration: 1700003600,
        servers: const ['https://Media.Example/', 'media.example'],
      );

      expect(auth.kind, NostrNipB7.authKind);
      expect(auth.content, 'Upload Blob');
      expect(auth.isVerified(), isTrue);
      expect(NostrNipB7.getAuthTagValues(auth, 't'), ['upload']);
      expect(NostrNipB7.getAuthTagValues(auth, 'x'), [hash]);
      expect(NostrNipB7.getAuthTagValues(auth, 'server'), ['media.example']);
      expect(NostrNipB7.getAuthExpiration(auth), 1700003600);
      expect(NostrNipB7.isAuthExpired(auth, timestamp: 1700003601), isTrue);
      expect(NostrNipB7.isAuthExpired(auth, timestamp: 1700003599), isFalse);

      final header = NostrNipB7.encodeAuthorizationHeader(auth);
      expect(header.startsWith('Nostr '), isTrue);

      final decoded = jsonDecode(
        utf8.decode(base64.decode(header.substring('Nostr '.length))),
      ) as Map<String, dynamic>;

      expect(decoded['kind'], NostrNipB7.authKind);
      expect(decoded['id'], auth.id);
    });

    test('normalizes server tags', () {
      expect(
        NostrNipB7.normalizeServerTag('https://Relay.Example/path'),
        'relay.example',
      );
      expect(NostrNipB7.normalizeServerTag('Relay.Example'), 'relay.example');
      expect(
        NostrNipB7.areServersEqual('wss://relay.example', 'relay.example'),
        isTrue,
      );
    });

    test('round-trips blossom URIs', () {
      final uri = NostrBlossomUri(
        sha256: 'ab' * 32,
        ext: 'png',
        servers: const ['https://media.example'],
        authors: const ['pubkey1'],
        size: 1024,
      );

      final built = NostrNipB7.buildBlossomUri(uri);
      expect(built.startsWith('blossom:${'ab' * 32}.png?'), isTrue);

      final parsed = NostrNipB7.parseBlossomUri(built);
      expect(parsed.sha256, uri.sha256);
      expect(parsed.ext, 'png');
      expect(parsed.servers, uri.servers);
      expect(parsed.authors, uri.authors);
      expect(parsed.size, 1024);

      expect(
        () => NostrNipB7.parseBlossomUri('blossom:abc'),
        throwsFormatException,
      );
      expect(
        () => NostrNipB7.parseBlossomUri('blossom:${'ab' * 32}.png?sz=0'),
        throwsFormatException,
      );
    });

    test('extracts hashes and mime types', () {
      expect(
        NostrNipB7.getHashFromUrl(
          'https://media.example/$hash.png?x=1#frag',
        ),
        hash,
      );
      expect(
        NostrNipB7.getHashFromUrl('https://media.example/nothex.png'),
        isNull,
      );
      expect(NostrNipB7.getExtension('image/png; charset=binary'), '.png');
      expect(NostrNipB7.getMimeType('PNG'), 'image/png');
      expect(NostrNipB7.getMimeType('.unknown'), '');
    });

    test('parses descriptors and server lists', () {
      final descriptor = NostrBlobDescriptor.fromJson({
        'url': 'https://media.example/blob.png',
        'sha256': 'ab' * 32,
        'size': 12,
        'type': 'image/png',
        'uploaded': 1700000000,
      });

      expect(descriptor.toJson()['sha256'], 'ab' * 32);
      expect(descriptor.size, 12);

      final servers = NostrNipB7.getServersFromServerListEvent(
        NostrEvent(
          id: null,
          kind: 10063,
          content: '',
          sig: null,
          pubkey: signer.publicKey,
          createdAt: DateTime.now(),
          tags: const [
            ['server', 'https://media.example/path'],
            ['server', 'not a url'],
          ],
        ),
      );

      expect(servers.length, 1);
      expect(servers.first.host, 'media.example');
      expect(servers.first.path, '/');
    });
  });

  group('NostrNips wiring', () {
    test('new stateless accessors are cached', () {
      final nips = NostrNips(
        logger: Nostr.instance.services.logger,
      );

      expect(nips.nip07, same(nips.nip07));
      expect(nips.nip55, same(nips.nip55));
      expect(nips.nip77, same(nips.nip77));
      expect(nips.nipAD, same(nips.nipAD));
    });

    test('new signer-bound accessors require and reset a signer', () {
      final nips = NostrNips(
        logger: Nostr.instance.services.logger,
      );

      expect(() => nips.nip75, throwsStateError);
      expect(() => nips.nip99, throwsStateError);
      expect(() => nips.nipB7, throwsStateError);

      final bound = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(bound);

      expect(nips.nip75.signer, same(bound));
      expect(nips.nip99.signer, same(bound));
      expect(nips.nipB7.signer, same(bound));
      expect(nips.nip75, same(nips.nip75));

      nips.bindSigner(null);
      expect(() => nips.nipB7, throwsStateError);
    });
  });
}

NostrNegentropyStorageVector _storage(List<(int, String)> items) {
  final storage = NostrNegentropyStorageVector();
  for (final item in items) {
    storage.insert(item.$1, item.$2);
  }
  storage.seal();

  return storage;
}

String _idAt(int index) {
  return index.toRadixString(16).padLeft(64, '0');
}

class _WebNostr
    implements
        NostrNip07Capable,
        NostrNip07Nip04Capable,
        NostrNip07Nip44Capable {
  _WebNostr(this._signer);

  final NostrEventSigner _signer;

  @override
  Future<String> getPublicKey() async => _signer.publicKey;

  @override
  Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event) async {
    final tags = [
      for (final tag in event['tags'] as List)
        [for (final value in tag as List) value.toString()],
    ];

    final signed = await _signer.sign(
      NostrEvent(
        id: null,
        kind: event['kind'] as int,
        content: event['content'] as String? ?? '',
        sig: null,
        pubkey: _signer.publicKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (event['created_at'] as int) * 1000,
        ),
        tags: tags,
      ),
    );

    return signed.toMap();
  }

  @override
  Future<String> nip04Encrypt(String publicKey, String plaintext) async {
    return 'nip04:${publicKey.substring(0, 1)}:$plaintext';
  }

  @override
  Future<String> nip04Decrypt(String publicKey, String ciphertext) async {
    return 'nip04-dec:${publicKey.substring(0, 1)}:$ciphertext';
  }

  @override
  Future<String> nip44Encrypt(String publicKey, String plaintext) async {
    return 'nip44:${publicKey.substring(0, 1)}:$plaintext';
  }

  @override
  Future<String> nip44Decrypt(String publicKey, String ciphertext) async {
    return 'nip44-dec:${publicKey.substring(0, 1)}:$ciphertext';
  }
}

class _CoreWebNostr implements NostrNip07Capable {
  _CoreWebNostr(this._signer);

  final NostrEventSigner _signer;

  @override
  Future<String> getPublicKey() async => _signer.publicKey;

  @override
  Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event) async {
    return const {};
  }
}
