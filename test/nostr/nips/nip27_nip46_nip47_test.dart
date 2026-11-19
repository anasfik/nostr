import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  const npubA =
      'npub1hpslpc8c5sp3e2nhm2fr7swsfqpys5vyjar5dwpn7e7decps6r8qkcln63';
  const npubB =
      'npub1xtscya34g58tk0z605fvr788k263gsu6cy9x0mhnm87echrgufzsevkk5s';
  const pubkeyA =
      'b861f0e0f8a4031caa77da923f41d04802485184974746b833f67cdce030d0ce';
  const pubkeyB =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  group('NIP-27', () {
    const nip27 = NostrNip27();

    test('parses profiles and an image', () {
      const content = 'nostr:$npubA check out my profile:nostr:$npubB; '
          'and this cool image https://images.com/image.jpg';
      final blocks = nip27.parse(content);

      expect(blocks.length, 5);
      expect(blocks[0].type, Nip27BlockType.reference);
      expect(blocks[0].start, 0);
      expect(blocks[0].end, 69);
      expect(blocks[0].pointer!.type, Nip27PointerType.profile);
      expect(blocks[0].pointer!.pubkey, pubkeyA);

      expect(blocks[1].type, Nip27BlockType.text);
      expect(blocks[1].text, ' check out my profile:');
      expect(blocks[1].start, 69);
      expect(blocks[1].end, 91);

      expect(blocks[2].type, Nip27BlockType.reference);
      expect(blocks[2].start, 91);
      expect(blocks[2].end, 160);
      expect(blocks[2].pointer!.pubkey, pubkeyB);

      expect(blocks[3].type, Nip27BlockType.text);
      expect(blocks[3].text, '; and this cool image ');

      expect(blocks[4].type, Nip27BlockType.image);
      expect(blocks[4].url, 'https://images.com/image.jpg');
      expect(blocks[4].start, 182);
      expect(blocks[4].end, 210);
    });

    test('parses relays, media urls and skips broken entities', () {
      const content = ":wss://oa.ao/a/; this was a relay and now here's a "
          'video -> https://videos.com/video.mp4! and some music:\n'
          'http://music.com/song.mp3\n'
          'and a regular link: https://regular.com/page?ok=true. and now a '
          'broken link: https://kjxkxk and a broken nostr ref: '
          'nostr:nevent1qqsr0f9w78uyy09qwmjt0kv63j4l7sxahq33725lqyyp79whlf'
          'jurwspz4mhxue69uhh56nzv34hxcfwv9ehw6nyddhq0ag9xg and a fake nostr '
          'ref: nostr:llll ok but finally https://ok.com!';
      final blocks = nip27.parse(content);

      expect(blocks.map((b) => b.type).toList(), [
        Nip27BlockType.text,
        Nip27BlockType.relay,
        Nip27BlockType.text,
        Nip27BlockType.video,
        Nip27BlockType.text,
        Nip27BlockType.audio,
        Nip27BlockType.text,
        Nip27BlockType.url,
        Nip27BlockType.text,
        Nip27BlockType.url,
        Nip27BlockType.text,
      ]);

      expect(blocks[1].url, 'wss://oa.ao/a/');
      expect(blocks[1].start, 1);
      expect(blocks[1].end, 15);
      expect(blocks[3].url, 'https://videos.com/video.mp4');
      expect(blocks[5].url, 'http://music.com/song.mp3');
      expect(blocks[7].url, 'https://regular.com/page?ok=true');
      expect(blocks[9].url, 'https://ok.com/');
      expect(blocks[8].text, contains('nostr:llll'));
    });

    test('parses hashtags and emoji from event tags', () {
      final event = NostrEvent(
        kind: 1,
        tags: const [
          ['emoji', 'star', 'https://example.com/star.png'],
          ['emoji', 'alpaca', 'https://example.com/alpaca.png'],
        ],
        content: 'hey nostr:$npubA check out :alpaca::alpaca: #alpaca at '
            'wss://alpaca.com! :star:\n\n#WORDS #486 5/6',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1234567890 * 1000),
        pubkey: 'dummy',
        id: null,
        sig: null,
      );
      final blocks = nip27.parseEvent(event);

      expect(blocks.map((b) => b.type).toList(), [
        Nip27BlockType.text,
        Nip27BlockType.reference,
        Nip27BlockType.text,
        Nip27BlockType.emoji,
        Nip27BlockType.emoji,
        Nip27BlockType.text,
        Nip27BlockType.hashtag,
        Nip27BlockType.text,
        Nip27BlockType.relay,
        Nip27BlockType.text,
        Nip27BlockType.emoji,
        Nip27BlockType.text,
        Nip27BlockType.hashtag,
        Nip27BlockType.text,
        Nip27BlockType.hashtag,
        Nip27BlockType.text,
      ]);

      expect(blocks[3].shortcode, 'alpaca');
      expect(blocks[3].url, 'https://example.com/alpaca.png');
      expect(blocks[3].start, 84);
      expect(blocks[3].end, 92);
      expect(blocks[6].value, 'alpaca');
      expect(blocks[6].start, 101);
      expect(blocks[6].end, 108);
      expect(blocks[12].value, 'WORDS');
      expect(blocks[14].value, '486');
      expect(blocks[15].text, ' 5/6');
    });

    test('emoji is plain text without tags', () {
      final blocks = nip27.parse('hello :alpaca:');
      expect(blocks.length, 1);
      expect(blocks.single.type, Nip27BlockType.text);
      expect(blocks.single.text, 'hello :alpaca:');
    });

    test('lone or overlong hashtags stay text', () {
      expect(nip27.parse('a # b').single.text, 'a # b');
      expect(nip27.parse('the end #').single.text, 'the end #');

      final tag42 = 'b' * 42;
      final blocks = nip27.parse('#$tag42 and #short');
      expect(blocks[0].type, Nip27BlockType.text);
      expect(blocks[0].text, '#$tag42 and ');
      expect(blocks[1].type, Nip27BlockType.hashtag);
      expect(blocks[1].value, 'short');
    });

    test('ws url must not end a word', () {
      expect(
        nip27.parse('news:relay.example.com').single.text,
        'news:relay.example.com',
      );
      expect(nip27.parse('Reviews: #books')[1].value, 'books');
      expect(
        nip27.parse('see ws://relay.example.com now')[1].url,
        'ws://relay.example.com/',
      );
    });

    test('url trailing punctuation and parentheses', () {
      final blocks = nip27.parse(
        'go to https://example.com/a.b,c.d., or https://example.com/x.y... '
        'and wss://relay.example.com.',
      );
      expect(blocks[1].url, 'https://example.com/a.b,c.d');
      expect(blocks[3].url, 'https://example.com/x.y');
      expect(blocks[5].url, 'wss://relay.example.com/');

      final parens = nip27.parse(
        'see https://en.wikipedia.org/wiki/Bitcoin_(disambiguation). '
        '(or https://example.com/a) and https://example.com/a_(b)_(c), '
        '(https://example.com/a_(b))',
      );
      expect(
        parens[1].url,
        'https://en.wikipedia.org/wiki/Bitcoin_(disambiguation)',
      );
      expect(parens[3].url, 'https://example.com/a');
      expect(parens[5].url, 'https://example.com/a_(b)_(c)');
      expect(parens[7].url, 'https://example.com/a_(b)');
    });

    test('mentions extracts references only', () {
      final mentions = nip27.mentions(
        'nostr:$npubA and nostr:npub1 and https://example.com',
      );
      expect(mentions.length, 1);
      expect(mentions.single.pubkey, pubkeyA);
    });

    test('nsec is never surfaced', () {
      final nsec = Nostr.instance.nips.nip19.encodePrivateKeyToNsec('a' * 64);
      final blocks = nip27.parse('key nostr:$nsec end');
      expect(blocks.where((b) => b.type == Nip27BlockType.reference), isEmpty);
      // Like nostr-tools, the ignored nsec token stays inside one text block.
      expect(blocks.single.type, Nip27BlockType.text);
      expect(blocks.single.text, 'key nostr:$nsec end');
    });

    test('accessor is cached and shares the bech32 codec', () {
      final nips = Nostr.instance.nips;
      expect(nips.nip27, same(nips.nip27));
      expect(
        nips.nip27.parse('https://example.com').single.url,
        'https://example.com/',
      );
    });
  });

  group('NIP-46', () {
    late NostrLocalKeySigner clientSigner;
    late NostrLocalKeySigner bunkerSigner;
    late NostrNip46 client;
    late NostrNip46 bunker;

    setUp(() {
      clientSigner = NostrLocalKeySigner(NostrKeyPairs.generate());
      bunkerSigner = NostrLocalKeySigner(NostrKeyPairs.generate());
      client = NostrNip46(signer: clientSigner);
      bunker = NostrNip46(signer: bunkerSigner);
    });

    test('kind constants', () {
      expect(NostrNip46.kind, 24133);
      expect(NostrNip46.kinds, [24133]);
    });

    test('bunker url parsing and formatting roundtrip', () {
      final pubkey = 'a' * 64;
      final url = 'bunker://$pubkey'
          '?relay=wss%3A%2F%2Frelay.example.com&secret=s3cret';
      final pointer = NostrNip46.parseBunkerUrl(url);

      expect(pointer.pubkey, pubkey);
      expect(pointer.relays, ['wss://relay.example.com']);
      expect(pointer.secret, 's3cret');

      final roundtripped = NostrNip46.parseBunkerUrl(
        NostrNip46.toBunkerUrl(pointer),
      );
      expect(roundtripped.pubkey, pubkey);
      expect(roundtripped.relays, pointer.relays);
      expect(roundtripped.secret, pointer.secret);

      expect(
        () => NostrNip46.parseBunkerUrl('bunker://not-a-pubkey'),
        throwsFormatException,
      );
    });

    test('nostrconnect uri carries relay, secret, perms and metadata', () {
      final uri = NostrNip46.createNostrConnectUri(
        clientPubkey: 'b' * 64,
        relays: ['wss://relay.one', 'wss://relay.two'],
        secret: 'hunter2',
        perms: ['get_public_key', 'sign_event:1'],
        name: 'dart-nostr',
        url: 'https://example.com',
        image: 'https://example.com/icon.png',
      );

      final parsed = Uri.parse(uri);
      expect(parsed.scheme, 'nostrconnect');
      expect(parsed.host, 'b' * 64);
      expect(
        parsed.queryParametersAll['relay'],
        ['wss://relay.one', 'wss://relay.two'],
      );
      expect(parsed.queryParameters['secret'], 'hunter2');
      expect(parsed.queryParameters['perms'], 'get_public_key,sign_event:1');
      expect(parsed.queryParameters['name'], 'dart-nostr');
    });

    test('request and response envelopes roundtrip', () {
      const request = Nip46Request(
        id: 'abc-1',
        method: Nip46Method.getPublicKey,
        params: ['a', 'b'],
      );
      final decodedRequest = Nip46Request.parse(request.toJson());
      expect(decodedRequest.id, 'abc-1');
      expect(decodedRequest.method, 'get_public_key');
      expect(decodedRequest.params, ['a', 'b']);

      const response = Nip46Response(id: 'abc-1', result: 'pong');
      final decodedResponse = Nip46Response.parse(response.toJson());
      expect(decodedResponse.result, 'pong');
      expect(decodedResponse.error, isNull);

      const failure = Nip46Response(id: 'abc-1', error: 'nope');
      expect(Nip46Response.parse(failure.toJson()).error, 'nope');
    });

    test('request event is signed, tagged and NIP-44 encrypted', () async {
      final event = await client.createRequestEvent(
        remotePubkey: bunkerSigner.publicKey,
        method: Nip46Method.ping,
      );

      expect(event.kind, 24133);
      expect(event.pubkey, clientSigner.publicKey);
      expect(event.isVerified(), isTrue);
      expect(event.tags, [
        ['p', bunkerSigner.publicKey],
      ]);
      expect(event.content, isNot(contains('ping')));

      final request = await bunker.decryptRequest(event);
      expect(request.method, Nip46Method.ping);
      expect(request.params, isEmpty);

      final responseEvent = await bunker.createResponseEvent(
        request: request,
        remotePubkey: clientSigner.publicKey,
        result: 'pong',
      );
      expect(responseEvent.kind, 24133);
      expect(responseEvent.tags, [
        ['p', clientSigner.publicKey],
      ]);

      final response = await client.decryptResponse(responseEvent);
      expect(response.id, request.id);
      expect(response.result, 'pong');
    });

    test('response requires exactly one of result or error', () async {
      const request = Nip46Request(id: '1', method: Nip46Method.ping);
      expect(
        () => bunker.createResponseEvent(
          request: request,
          remotePubkey: clientSigner.publicKey,
        ),
        throwsArgumentError,
      );
    });

    test('client correlates responses over a fake relay', () async {
      final nip46 = NostrNip46(signer: clientSigner);
      late NostrNip46Client rpc;

      Future<void> deliver(NostrEvent event) async {
        final request = await bunker.decryptRequest(event);
        final response = await bunker.createResponseEvent(
          request: request,
          remotePubkey: clientSigner.publicKey,
          result: switch (request.method) {
            Nip46Method.ping => 'pong',
            Nip46Method.getPublicKey => bunkerSigner.publicKey,
            _ => 'ack',
          },
        );
        await rpc.handleEvent(response);
      }

      rpc = NostrNip46Client(
        nip46: nip46,
        remotePubkey: bunkerSigner.publicKey,
        publish: deliver,
        timeout: const Duration(seconds: 5),
      );

      await rpc.ping();
      expect(await rpc.getPublicKey(), bunkerSigner.publicKey);
      expect(await rpc.getPublicKey(), bunkerSigner.publicKey);
    });

    test('client signs events through the remote signer', () async {
      final nip46 = NostrNip46(signer: clientSigner);
      late NostrNip46Client rpc;

      rpc = NostrNip46Client(
        nip46: nip46,
        remotePubkey: bunkerSigner.publicKey,
        publish: (event) async {
          final request = await bunker.decryptRequest(event);
          final template =
              jsonDecode(request.params.single) as Map<String, dynamic>;
          final templateEvent = NostrEvent.fromDecodedMessage([
            'EVENT',
            '',
            {'pubkey': bunkerSigner.publicKey, ...template},
          ]);
          final signed = await bunkerSigner.sign(templateEvent);
          final response = await bunker.createResponseEvent(
            request: request,
            remotePubkey: clientSigner.publicKey,
            result: jsonEncode(signed.toMap()),
          );
          await rpc.handleEvent(response);
        },
      );

      final signed = await rpc.signEvent(
        NostrEvent(
          id: null,
          kind: 1,
          content: 'hello from a bunker',
          sig: null,
          pubkey: clientSigner.publicKey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          tags: const [
            ['t', 'test'],
          ],
        ),
      );

      expect(signed.pubkey, bunkerSigner.publicKey);
      expect(signed.content, 'hello from a bunker');
      expect(signed.isVerified(), isTrue);
    });

    test('client rejects a bad remote signature', () async {
      final nip46 = NostrNip46(signer: clientSigner);
      late NostrNip46Client rpc;

      rpc = NostrNip46Client(
        nip46: nip46,
        remotePubkey: bunkerSigner.publicKey,
        publish: (event) async {
          final request = await bunker.decryptRequest(event);
          final response = await bunker.createResponseEvent(
            request: request,
            remotePubkey: clientSigner.publicKey,
            result: jsonEncode({
              'kind': 1,
              'content': 'forged',
              'tags': <List<String>>[],
              'created_at': 1700000000,
              'pubkey': bunkerSigner.publicKey,
              'id': '0' * 64,
              'sig': '0' * 128,
            }),
          );
          await rpc.handleEvent(response);
        },
      );

      await expectLater(
        rpc.signEvent(
          NostrEvent(
            id: null,
            kind: 1,
            content: 'x',
            sig: null,
            pubkey: clientSigner.publicKey,
            createdAt: DateTime.now(),
            tags: const [],
          ),
        ),
        throwsA(isA<Nip46Exception>()),
      );
    });

    test('client settles pending calls on close', () async {
      final published = Completer<void>();
      final rpc = NostrNip46Client(
        nip46: NostrNip46(signer: clientSigner),
        remotePubkey: bunkerSigner.publicKey,
        publish: (_) {
          published.complete();
          return Future<void>.value();
        },
        timeout: const Duration(seconds: 5),
      );

      final pending = rpc.ping();
      await published.future;
      rpc.close();

      await expectLater(pending, throwsA(isA<Nip46Exception>()));
    });

    test('client ignores non-bunker events', () async {
      final rpc = NostrNip46Client(
        nip46: NostrNip46(signer: clientSigner),
        remotePubkey: bunkerSigner.publicKey,
        publish: (_) async {},
      );
      final other = NostrNip46(
        signer: NostrLocalKeySigner(NostrKeyPairs.generate()),
      );
      final fromOther = await other.createResponseEvent(
        request: const Nip46Request(id: 'x', method: Nip46Method.ping),
        remotePubkey: clientSigner.publicKey,
        result: 'pong',
      );
      expect(await rpc.handleEvent(fromOther), isFalse);

      final wrongKind = await bunkerSigner.sign(
        NostrEvent(
          id: null,
          kind: 1,
          content: fromOther.content,
          sig: null,
          pubkey: bunkerSigner.publicKey,
          createdAt: DateTime.now(),
          tags: const [],
        ),
      );
      expect(await rpc.handleEvent(wrongKind), isFalse);
    });

    test('accessor is signer-bound and resets with bindSigner', () {
      final nips = NostrNips(
        logger: Nostr.instance.services.logger,
      );
      expect(() => nips.nip46, throwsStateError);

      nips.bindSigner(clientSigner);
      expect(nips.nip46.signer, same(clientSigner));
      expect(nips.nip46, same(nips.nip46));

      nips.bindSigner(bunkerSigner);
      expect(nips.nip46.signer, same(bunkerSigner));
    });
  });

  group('NIP-47', () {
    const connectionString =
        'nostr+walletconnect://b889ff5b1513b641e2a139f661a661364979c5beee918'
        '42f8f0ef42ab558e9d4?relay=wss%3A%2F%2Frelay.damus.io&secret=71a8c14c'
        '1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c';
    const walletPubkey =
        'b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4';
    const secret =
        '71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c';

    late NostrLocalKeySigner clientSigner;
    late NostrLocalKeySigner walletSigner;
    late NostrNip47 client;
    late NostrNip47 wallet;

    setUp(() {
      clientSigner = NostrLocalKeySigner(NostrKeyPairs.generate());
      walletSigner = NostrLocalKeySigner(NostrKeyPairs.generate());
      client = NostrNip47(signer: clientSigner);
      wallet = NostrNip47(signer: walletSigner);
    });

    test('kind constants', () {
      expect(NostrNip47.requestKind, 23194);
      expect(NostrNip47.responseKind, 23195);
      expect(NostrNip47.notificationKind, 23196);
      expect(NostrNip47.kinds, containsAll([23194, 23195, 23196, 13194]));
    });

    test('parses a connection string', () {
      final connection = NwcConnection.parse(connectionString);
      expect(connection.pubkey, walletPubkey);
      expect(connection.relay, 'wss://relay.damus.io');
      expect(connection.relays, ['wss://relay.damus.io']);
      expect(connection.secret, secret);

      const withNoSlashes =
          'nostr+walletconnect:$walletPubkey?relay=wss%3A%2F%2Fnos.lol'
          '&secret=$secret';
      expect(NwcConnection.parse(withNoSlashes).pubkey, walletPubkey);
    });

    test('connection string rejects missing parts', () {
      expect(
        () => NwcConnection.parse(
          'nostr+walletconnect:relay=wss%3A%2F%2Frelay.damus.io&secret=$secret',
        ),
        throwsFormatException,
      );
      expect(
        () => NwcConnection.parse(
          'nostr+walletconnect:$walletPubkey?secret=$secret',
        ),
        throwsFormatException,
      );
      expect(
        () => NwcConnection.parse(
          'nostr+walletconnect:$walletPubkey?relay=wss%3A%2F%2Fnos.lol',
        ),
        throwsFormatException,
      );
    });

    test('connection string roundtrips', () {
      final connection = NwcConnection.parse(connectionString);
      final again = NwcConnection.parse(connection.toConnectionString());
      expect(again.pubkey, connection.pubkey);
      expect(again.relays, connection.relays);
      expect(again.secret, connection.secret);
    });

    test('request, response and notification payloads roundtrip', () {
      const request = NwcRequest(
        method: Nip47Method.payInvoice,
        params: {'invoice': 'lnbc1'},
      );
      final decodedRequest = NwcRequest.parse(request.toJson());
      expect(decodedRequest.method, 'pay_invoice');
      expect(decodedRequest.params['invoice'], 'lnbc1');

      const response = NwcResponse(
        resultType: Nip47Method.payInvoice,
        result: {'preimage': 'ab'},
      );
      final decodedResponse = NwcResponse.parse(response.toJson());
      expect(decodedResponse.resultType, 'pay_invoice');
      expect(decodedResponse.result!['preimage'], 'ab');
      expect(decodedResponse.isError, isFalse);

      const failure = NwcResponse(
        resultType: Nip47Method.getBalance,
        error: NwcError(
          code: Nip47ErrorCode.quotaExceeded,
          message: 'budget spent',
        ),
      );
      final decodedFailure = NwcResponse.parse(failure.toJson());
      expect(decodedFailure.resultType, 'get_balance');
      expect(decodedFailure.error!.code, 'QUOTA_EXCEEDED');
      expect(decodedFailure.error!.isQuotaExceeded, isTrue);
      expect(NwcException(decodedFailure.error!).isQuotaExceeded, isTrue);

      const notification = NwcNotification(
        type: 'payment_received',
        data: {'payment_hash': 'hash'},
      );
      final decodedNotification = NwcNotification.parse(notification.toJson());
      expect(decodedNotification.type, 'payment_received');
      expect(decodedNotification.data['payment_hash'], 'hash');
    });

    test('request event is signed, tagged and NIP-44 encrypted', () async {
      final event = await client.createRequestEvent(
        walletPubkey: walletSigner.publicKey,
        method: Nip47Method.getBalance,
      );

      expect(event.kind, 23194);
      expect(event.pubkey, clientSigner.publicKey);
      expect(event.isVerified(), isTrue);
      expect(event.tags, [
        ['encryption', Nip47Encryption.nip44V2],
        ['p', walletSigner.publicKey],
      ]);
      expect(event.content, isNot(contains('get_balance')));

      final request = await wallet.decryptRequest(event);
      expect(request.method, Nip47Method.getBalance);
      expect(request.params, isEmpty);

      final responseEvent = await wallet.createResponseEvent(
        request: event,
        resultType: request.method,
        result: {'balance': 21000},
      );
      expect(responseEvent.kind, 23195);
      expect(responseEvent.tags, [
        ['p', clientSigner.publicKey],
        ['e', event.id],
      ]);

      final response = await client.decryptResponse(responseEvent);
      expect(response.resultType, Nip47Method.getBalance);
      expect(response.result!['balance'], 21000);
    });

    test('unsupported encryption is a standard error code', () {
      expect(Nip47ErrorCode.unsupportedEncryption, 'UNSUPPORTED_ENCRYPTION');
    });

    test('request encryption tag defaults to nip44 and can be nip04', () async {
      final nip44 = await client.createRequestEvent(
        walletPubkey: walletSigner.publicKey,
        method: Nip47Method.getInfo,
      );
      expect(NostrNip47.encryptionOf(nip44), Nip47Encryption.nip44V2);
      expect(
        () => client.createRequestEvent(
          walletPubkey: walletSigner.publicKey,
          method: Nip47Method.getInfo,
          encryption: 'rot13',
        ),
        throwsArgumentError,
      );

      final nip04 = await client.createRequestEvent(
        walletPubkey: walletSigner.publicKey,
        method: Nip47Method.payInvoice,
        params: {'invoice': 'lnbc1'},
        encryption: Nip47Encryption.nip04,
      );
      expect(nip04.tags, [
        ['encryption', Nip47Encryption.nip04],
        ['p', walletSigner.publicKey],
      ]);
      expect(nip04.content, contains('?iv='));

      final decrypted = await wallet.decryptRequest(nip04);
      expect(decrypted.method, Nip47Method.payInvoice);

      final reply = await wallet.createResponseEvent(
        request: nip04,
        resultType: decrypted.method,
        result: {'preimage': 'ab'},
        encryption: Nip47Encryption.nip04,
      );
      // Responses rely on the request scheme, so the client falls back to
      // NIP-04 when NIP-44 decryption fails.
      expect(
        await client.decryptResponse(reply).then((r) => r.result),
        {'preimage': 'ab'},
      );
    });

    test('forConnection signs with the connection secret, not identity',
        () async {
      final parsed = NwcConnection.parse(connectionString);
      final expectedClientPubkey = NostrKeyPairs(private: parsed.secret).public;
      final helper = NostrNip47.forConnection(parsed);
      expect(helper.signer.publicKey, expectedClientPubkey);
      expect(helper.signer.publicKey, isNot(parsed.pubkey));
      expect(helper.signer, isA<NostrLocalKeySigner>());

      // Point the connection at the fake wallet key so it can decrypt.
      final connection = NwcConnection(
        pubkey: walletSigner.publicKey,
        relays: parsed.relays,
        secret: parsed.secret,
      );
      late NostrNip47Client nwc;
      nwc = NostrNip47Client.forConnection(
        connection: connection,
        publish: (event) async {
          expect(event.pubkey, expectedClientPubkey);
          final request = await wallet.decryptRequest(event);
          final response = await wallet.createResponseEvent(
            request: event,
            resultType: request.method,
            result: {'balance': 99},
          );
          await nwc.handleEvent(response);
        },
        timeout: const Duration(seconds: 5),
      );

      expect((await nwc.getBalance())['balance'], 99);
    });

    test('payKeysend sends int TLV types', () async {
      late NostrNip47Client nwc;
      Map<String, dynamic>? seen;
      nwc = NostrNip47Client(
        nip47: NostrNip47(signer: clientSigner),
        walletPubkey: walletSigner.publicKey,
        publish: (event) async {
          seen = (await wallet.decryptRequest(event)).params;
          final response = await wallet.createResponseEvent(
            request: event,
            resultType: Nip47Method.payKeysend,
            result: {'preimage': 'cd'},
          );
          await nwc.handleEvent(response);
        },
        timeout: const Duration(seconds: 5),
      );

      await nwc.payKeysend(
        pubkey: walletSigner.publicKey,
        amount: 21,
        tlvRecords: const [
          [5482373484, '0123'],
        ],
      );

      final records = seen!['tlv_records'] as List;
      expect((records.single as Map)['type'], 5482373484);
      expect((records.single as Map)['type'], isA<int>());
    });

    test('error responses carry the error code', () async {
      final event = await client.createRequestEvent(
        walletPubkey: walletSigner.publicKey,
        method: Nip47Method.payInvoice,
        params: {'invoice': 'lnbc1'},
      );
      final responseEvent = await wallet.createErrorResponseEvent(
        request: event,
        code: Nip47ErrorCode.quotaExceeded,
        message: 'daily budget exceeded',
      );

      final response = await client.decryptResponse(responseEvent);
      expect(response.error!.code, Nip47ErrorCode.quotaExceeded);
      expect(response.error!.isQuotaExceeded, isTrue);
    });

    test('notification event roundtrip', () async {
      final event = await wallet.createNotificationEvent(
        clientPubkey: clientSigner.publicKey,
        type: 'payment_received',
        data: {'payment_hash': 'hash', 'amount': 1000},
      );

      expect(event.kind, 23196);
      final notification = await client.decryptNotification(event);
      expect(notification.type, 'payment_received');
      expect(notification.data['amount'], 1000);
    });

    test('client correlates responses over a fake relay', () async {
      final nip47 = NostrNip47(signer: clientSigner);
      late NostrNip47Client nwc;

      nwc = NostrNip47Client(
        nip47: nip47,
        walletPubkey: walletSigner.publicKey,
        publish: (event) async {
          final request = await wallet.decryptRequest(event);
          final response = await wallet.createResponseEvent(
            request: event,
            result: switch (request.method) {
              Nip47Method.getBalance => {'balance': 42000},
              Nip47Method.payInvoice => {'preimage': 'ff'},
              _ => <String, dynamic>{},
            },
          );
          await nwc.handleEvent(response);
        },
        timeout: const Duration(seconds: 5),
      );

      expect((await nwc.getBalance())['balance'], 42000);
      expect((await nwc.payInvoice('lnbc1'))['preimage'], 'ff');
    });

    test('client surfaces wallet errors and validates lookups', () async {
      final nip47 = NostrNip47(signer: clientSigner);
      late NostrNip47Client nwc;

      nwc = NostrNip47Client(
        nip47: nip47,
        walletPubkey: walletSigner.publicKey,
        publish: (event) async {
          final response = await wallet.createErrorResponseEvent(
            request: event,
            code: Nip47ErrorCode.quotaExceeded,
            message: 'budget spent',
          );
          await nwc.handleEvent(response);
        },
        timeout: const Duration(seconds: 5),
      );

      await expectLater(
        nwc.getBalance(),
        throwsA(
          isA<NwcException>().having(
            (e) => e.isQuotaExceeded,
            'isQuotaExceeded',
            isTrue,
          ),
        ),
      );

      expect(
        () => nwc.lookupInvoice(),
        throwsArgumentError,
      );
      expect(
        () => nwc.lookupInvoice(invoice: 'a', paymentHash: 'b'),
        throwsArgumentError,
      );
    });

    test('client receives notifications', () async {
      final received = <NwcNotification>[];
      final nip47 = NostrNip47(signer: clientSigner);
      final nwc = NostrNip47Client(
        nip47: nip47,
        walletPubkey: walletSigner.publicKey,
        publish: (_) async {},
        onNotification: received.add,
      );

      final event = await wallet.createNotificationEvent(
        clientPubkey: clientSigner.publicKey,
        type: 'payment_received',
        data: {'amount': 5},
      );

      expect(await nwc.handleEvent(event), isTrue);
      expect(received.single.type, 'payment_received');
      expect(received.single.data['amount'], 5);
    });

    test('accessor is signer-bound and resets with bindSigner', () {
      final nips = NostrNips(
        logger: Nostr.instance.services.logger,
      );
      expect(() => nips.nip47, throwsStateError);

      nips.bindSigner(clientSigner);
      expect(nips.nip47.signer, same(clientSigner));
      expect(nips.nip47, same(nips.nip47));

      nips.bindSigner(null);
      expect(() => nips.nip47, throwsStateError);
    });
  });
}
