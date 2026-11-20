import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// Spec vectors, verbatim from NIP-35, NIP-48 and NIP-62.
const Map<String, dynamic> _specTorrent = {
  'kind': 2003,
  'content': '<long-description-pre-formatted>',
  'tags': [
    ['title', '<torrent-title>'],
    ['x', '<bittorrent-info-hash>'],
    ['file', '<file-name>', '<file-size-in-bytes>'],
    ['file', '<file-name>', '<file-size-in-bytes>'],
    ['tracker', 'udp://mytacker.com:1337'],
    ['tracker', 'http://1337-tracker.net/announce'],
    ['i', 'tcat:video,movie,4k'],
    ['i', 'newznab:2045'],
    ['i', 'imdb:tt15239678'],
    ['i', 'tmdb:movie:693134'],
    ['i', 'ttvdb:movie:290272'],
    ['t', 'movie'],
    ['t', '4k'],
  ],
};

/// 48.md:39-55 — ActivityPub bridged note.
const Map<String, dynamic> _specBridgedNote = {
  'kind': 1,
  'content': 'I\'m vegan btw',
  'tags': [
    [
      'proxy',
      'https://gleasonator.com/objects/8f6fac53-4f66-4c6e-ac7d-92e5e78c3e79',
      'activitypub',
    ],
  ],
  'pubkey': '79c2cae114ea28a981e7559b4fe7854a473521a8d22a66bbab9fa248eb820ff6',
  'created_at': 1691091365,
  'id': '55920b758b9c7b17854b6e3d44e6a02a83d1cb49e1227e75a30426dea94d4cb2',
  'sig': 'a72f12c08f18e85d98fb92ae89e2fe63e48b8864c5e10fbdd5335f3c9f936397a6'
      'b0a7350efe251f8168b1601d7012d4a6d0ee6eec958067cf22a14f5a5ea579',
};

/// 62.md:15-25 — vanish this relay.
const Map<String, dynamic> _specVanish = {
  'kind': 62,
  'pubkey': _pubkey,
  'tags': [
    ['relay', '<relay url>'],
  ],
  'content': '<reason or note>',
};

/// 62.md:49-58 — vanish every relay.
const Map<String, dynamic> _specGlobalVanish = {
  'kind': 62,
  'pubkey': _pubkey,
  'tags': [
    ['relay', 'ALL_RELAYS'],
  ],
  'content': '<reason>',
};

NostrEvent _event(
  Map<String, dynamic> json, {
  String pubkey = _pubkey,
}) {
  return NostrEvent(
    id: json['id'] as String?,
    kind: json['kind'] as int?,
    content: json['content'] as String?,
    sig: json['sig'] as String?,
    pubkey: (json['pubkey'] as String?) ?? pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((json['created_at'] as int?) ?? 0) * 1000,
    ),
    tags: [
      for (final tag in (json['tags'] as List?) ?? const [])
        List<String>.from(tag as List),
    ],
  );
}

/// Signer that cannot encrypt to its own key, like a restricted remote signer.
class _NoSelfCryptoSigner implements NostrEventSigner {
  _NoSelfCryptoSigner(this._local);

  final NostrLocalKeySigner _local;

  @override
  String get publicKey => _local.publicKey;

  @override
  Future<NostrEvent> sign(NostrEvent event) => _local.sign(event);

  @override
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey) =>
      Future.error(UnsupportedError('nip44_encrypt unavailable'));

  @override
  Future<String> nip44Decrypt(String payload, String senderPublicKey) =>
      Future.error(UnsupportedError('nip44_decrypt unavailable'));
}

void main() {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

  group('NIP-35 torrents', () {
    test('constants', () {
      expect(NostrNip35.torrentKind, 2003);
      expect(NostrNip35.commentKind, 2004);
    });

    test('parses the spec torrent vector', () {
      final event = _event(_specTorrent);
      final torrent = NostrNip35.parse(event);

      expect(NostrNip35.isTorrent(event), isTrue);
      expect(NostrNip35.isComment(event), isFalse);
      expect(torrent.title, '<torrent-title>');
      expect(torrent.infoHash, '<bittorrent-info-hash>');
      expect(torrent.content, '<long-description-pre-formatted>');
      expect(torrent.files, hasLength(2));
      expect(torrent.files.first.name, '<file-name>');
      expect(torrent.files.first.size, '<file-size-in-bytes>');
      expect(torrent.files.first.toTag(), _specTorrent['tags']![2]);
      expect(
        torrent.trackers,
        ['udp://mytacker.com:1337', 'http://1337-tracker.net/announce'],
      );
      expect(torrent.references, [
        'tcat:video,movie,4k',
        'newznab:2045',
        'imdb:tt15239678',
        'tmdb:movie:693134',
        'ttvdb:movie:290272',
      ]);
      expect(torrent.categories, ['movie', '4k']);
      expect(torrent.pubkey, _pubkey);
    });

    test('builds the spec torrent tags exactly', () {
      final event = NostrNip35.generateTorrentTemplate(
        title: '<torrent-title>',
        infoHash: '<bittorrent-info-hash>',
        content: '<long-description-pre-formatted>',
        files: const [
          NostrTorrentFile(
            name: '<file-name>',
            size: '<file-size-in-bytes>',
          ),
          NostrTorrentFile(
            name: '<file-name>',
            size: '<file-size-in-bytes>',
          ),
        ],
        trackers: const [
          'udp://mytacker.com:1337',
          'http://1337-tracker.net/announce',
        ],
        references: const [
          'tcat:video,movie,4k',
          'newznab:2045',
          'imdb:tt15239678',
          'tmdb:movie:693134',
          'ttvdb:movie:290272',
        ],
        categories: const ['movie', '4k'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 2003);
      expect(event.content, _specTorrent['content']);
      expect(event.tags, _specTorrent['tags']);
      expect(event.id, isNull);
      expect(event.sig, isNull);
      expect(event.pubkey, isEmpty);
    });

    test('title is optional and extraTags cannot duplicate emitted tags', () {
      final event = NostrNip35.generateTorrentTemplate(
        infoHash: 'b' * 40,
        extraTags: [
          ['title', 'imposter'],
          ['x', 'other'],
          ['t', 'movie'],
          ['client', 'dart-nostr'],
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.tags, [
        ['x', 'b' * 40],
        ['client', 'dart-nostr'],
      ]);
      expect(event.tags!.where((tag) => tag.first == 'title'), isEmpty);
    });

    test('rejects invalid templates', () {
      expect(
        () => NostrNip35.generateTorrentTemplate(infoHash: ''),
        throwsArgumentError,
      );
      expect(
        () => NostrNip35.generateTorrentTemplate(
          infoHash: 'hash',
          files: const [NostrTorrentFile(name: '', size: '1')],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip35.generateTorrentTemplate(
          infoHash: 'hash',
          files: const [NostrTorrentFile(name: 'a.txt', size: '')],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip35.generateTorrentTemplate(
          infoHash: 'hash',
          trackers: const [''],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip35.generateTorrentTemplate(
          infoHash: 'hash',
          references: const [''],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip35.generateTorrentTemplate(
          infoHash: 'hash',
          categories: const [''],
        ),
        throwsArgumentError,
      );
    });

    test('tryParse returns null and parse throws for invalid events', () {
      expect(
        NostrNip35.tryParse(_event({'kind': 1, 'tags': <List<String>>[]})),
        isNull,
      );
      expect(
        NostrNip35.tryParse(_event({'kind': 2003, 'tags': <List<String>>[]})),
        isNull,
      );
      expect(
        NostrNip35.tryParse(
          _event({
            'kind': 2003,
            'tags': [
              ['x', ''],
            ],
          }),
        ),
        isNull,
      );
      expect(() => NostrNip35.parse(_event({'kind': 1})), throwsArgumentError);

      // Malformed file tags are skipped, not fatal.
      expect(
        NostrNip35.parse(
          _event({
            'kind': 2003,
            'tags': [
              ['x', 'hash'],
              ['file'],
              ['file', 'a.txt'],
              ['file', 'b.txt', '2'],
            ],
          }),
        ).files.single.name,
        'b.txt',
      );
      expect(NostrTorrentFile.tryParse(const ['file']), isNull);
    });

    test('a kind 2004 comment is not a torrent index', () {
      final comment = _event({
        'kind': 2004,
        'content': 'nice',
        'tags': [
          ['e', 'c' * 64],
        ],
      });

      expect(NostrNip35.isComment(comment), isTrue);
      expect(NostrNip35.tryParse(comment), isNull);
    });
  });

  group('NIP-37 draft wraps', () {
    const draft = {'kind': 1, 'content': 'GM', 'tags': <String>[]};
    const createdAtUnix = 1700000000;

    test('constants', () {
      expect(NostrNip37.draftKind, 31234);
      expect(NostrNip37.checkpointKind, 1234);
      expect(NostrNip37.relayListKind, 10013);
    });

    test('builds the 37.md:16-25 wrap tags exactly', () {
      final event = NostrNip37.generateDraftWrapTemplate(
        identifier: 'note-1',
        draftKind: 1,
        encryptedContent: 'ciphertext',
        expiresAt: createdAtUnix + 90 * 24 * 60 * 60,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 31234);
      expect(event.content, 'ciphertext');
      expect(event.tags, [
        ['d', 'note-1'],
        ['k', '1'],
        ['expiration', '${createdAtUnix + 90 * 24 * 60 * 60}'],
      ]);
    });

    test('builds the 37.md:38-44 checkpoint tags exactly', () {
      final address = NostrEventAddress.build(
        kind: NostrNip37.draftKind,
        pubkey: _pubkey,
        identifier: 'note-1',
      );
      final event = NostrNip37.generateCheckpointTemplate(
        address: address,
        encryptedContent: 'ciphertext',
        extraTags: const [
          ['a', 'imposter'],
          ['t', 'nostr'],
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 1234);
      expect(event.content, 'ciphertext');
      expect(event.tags, [
        ['a', '31234:$_pubkey:note-1'],
        ['t', 'nostr'],
      ]);
    });

    test('relay list template keeps the relay list encrypted', () {
      final event = NostrNip37.generateRelayListTemplate(
        encryptedContent: 'ciphertext',
        extraTags: const [
          ['relay', 'wss://leaked.example'],
          ['t', 'nostr'],
        ],
      );

      expect(event.kind, 10013);
      expect(event.tags, [
        ['t', 'nostr'],
      ]);
    });

    test('createDraftWrap encrypts, signs and round-trips', () async {
      final nip = NostrNip37(signer: signer);
      final event = await nip.createDraftWrap(
        identifier: 'note-1',
        draftKind: 1,
        draft: draft,
        expiresAt: createdAtUnix,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 31234);
      expect(event.pubkey, signer.publicKey);
      expect(event.id, isNotNull);
      expect(event.sig, isNotNull);
      expect(event.tags, [
        ['d', 'note-1'],
        ['k', '1'],
        ['expiration', '$createdAtUnix'],
      ]);

      final wrap = NostrNip37.parseDraftWrap(event);
      expect(wrap.identifier, 'note-1');
      expect(wrap.draftKind, 1);
      expect(wrap.content, isNotEmpty);
      expect(wrap.isDeleted, isFalse);
      expect(
          wrap.expiresAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(wrap.pubkey, signer.publicKey);
      expect(await nip.decryptDraft(event), draft);
      expect(await nip.tryDecryptDraft(event), draft);
    });

    test('createDraftDeletion blanks content (37.md:28)', () async {
      final nip = NostrNip37(signer: signer);
      final event = await nip.createDraftDeletion(
        identifier: 'note-1',
        draftKind: 1,
      );

      expect(event.content, isEmpty);
      expect(NostrNip37.parseDraftWrap(event).isDeleted, isTrue);
      expect(await nip.tryDecryptDraft(event), isNull);
    });

    test('createCheckpoint points at the signer parent wrap', () async {
      final nip = NostrNip37(signer: signer);
      final event = await nip.createCheckpoint(
        identifier: 'note-1',
        draft: draft,
      );

      expect(event.kind, 1234);
      expect(event.tags, [
        ['a', '31234:${signer.publicKey}:note-1'],
      ]);

      final parent = NostrNip37.parseCheckpoint(event);
      expect(parent.kind, 31234);
      expect(parent.pubkey, signer.publicKey);
      expect(parent.identifier, 'note-1');
      expect(await nip.decryptDraft(event), draft);
    });

    test('createRelayList and parseRelayList round-trip', () async {
      final nip = NostrNip37(signer: signer);
      final event = await nip.createRelayList(
        relays: const ['wss://relay.one', 'wss://relay.two'],
      );

      expect(event.kind, 10013);
      expect(event.tags, isEmpty);
      expect(
        await nip.parseRelayList(event),
        ['wss://relay.one', 'wss://relay.two'],
      );
      expect(
        await nip.tryParseRelayList(event),
        ['wss://relay.one', 'wss://relay.two'],
      );
    });

    test('rejects invalid templates and relay URLs', () async {
      expect(
        () => NostrNip37.generateDraftWrapTemplate(
          identifier: ' ',
          draftKind: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip37.generateDraftWrapTemplate(
          identifier: 'id',
          draftKind: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip37.generateDraftWrapTemplate(
          identifier: 'id',
          draftKind: 1,
          expiresAt: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip37.generateCheckpointTemplate(address: 'nope'),
        throwsArgumentError,
      );
      expect(
        () => NostrNip37.generateCheckpointTemplate(
          address: '30023:$_pubkey:post',
        ),
        throwsArgumentError,
      );

      final nip = NostrNip37(signer: signer);
      expect(
        () => nip.createRelayList(relays: const []),
        throwsArgumentError,
      );
      expect(
        () => nip.createRelayList(relays: const ['https://relay.one']),
        throwsArgumentError,
      );
      expect(
        () => nip.createCheckpoint(identifier: '', draft: const {}),
        throwsArgumentError,
      );
    });

    test('tryParse returns null and parse throws for invalid events', () async {
      expect(
        NostrNip37.tryParseDraftWrap(
          _event({'kind': 1, 'tags': <List<String>>[]}),
        ),
        isNull,
      );
      expect(
        NostrNip37.tryParseDraftWrap(
          _event({'kind': 31234, 'tags': <List<String>>[]}),
        ),
        isNull,
      );
      expect(
        NostrNip37.tryParseDraftWrap(
          _event({
            'kind': 31234,
            'tags': [
              ['d', ''],
              ['k', '1'],
            ],
          }),
        ),
        isNull,
      );
      expect(
        NostrNip37.tryParseDraftWrap(
          _event({
            'kind': 31234,
            'tags': [
              ['d', 'note-1'],
              ['k', 'one'],
            ],
          }),
        ),
        isNull,
      );
      expect(
        () => NostrNip37.parseDraftWrap(_event({'kind': 1})),
        throwsArgumentError,
      );

      expect(NostrNip37.tryParseCheckpoint(_event({'kind': 1234})), isNull);
      expect(
        NostrNip37.tryParseCheckpoint(
          _event({
            'kind': 1234,
            'tags': [
              ['a', '30023:$_pubkey:post'],
            ],
          }),
        ),
        isNull,
      );
      expect(
        () => NostrNip37.parseCheckpoint(_event({'kind': 1234})),
        throwsArgumentError,
      );

      final nip = NostrNip37(signer: signer);
      expect(await nip.tryParseRelayList(_event({'kind': 1})), isNull);
      expect(
        () => nip.parseRelayList(_event({'kind': 1})),
        throwsArgumentError,
      );
      expect(await nip.tryDecryptDraft(_event({'kind': 1})), isNull);
      expect(
        () => nip.decryptDraft(_event({'kind': 1})),
        throwsArgumentError,
      );
    });

    test('unparseable expiration is treated as absent', () {
      expect(
        NostrNip37.parseDraftWrap(
          _event({
            'kind': 31234,
            'tags': [
              ['d', 'note-1'],
              ['k', '1'],
              ['expiration', 'soon'],
            ],
          }),
        ).expiresAt,
        isNull,
      );
    });

    test('a signer without self NIP-44 support raises StateError', () async {
      final nip = NostrNip37(signer: _NoSelfCryptoSigner(signer));

      expect(
        () => nip.createDraftWrap(
          identifier: 'note-1',
          draftKind: 1,
          draft: draft,
        ),
        throwsStateError,
      );
    });
  });

  group('NIP-48 bridged events', () {
    test('constants', () {
      expect(NostrNip48.tagName, 'proxy');
      expect(NostrNip48.supportedProtocols, {
        'activitypub',
        'atproto',
        'rss',
        'web',
      });
    });

    test('parses the spec bridged note', () {
      final event = _event(_specBridgedNote);
      final reference = NostrNip48.parse(event);

      expect(NostrNip48.isBridged(event), isTrue);
      expect(
        reference.id,
        'https://gleasonator.com/objects/8f6fac53-4f66-4c6e-ac7d-92e5e78c3e79',
      );
      expect(reference.protocol, NostrNip48.activityPub);
      expect(reference.toTag(), _specBridgedNote['tags']![0]);
    });

    test('builds the spec proxy tag exactly', () {
      expect(
        NostrNip48.tag(
          id: 'https://gleasonator.com/objects/'
              '8f6fac53-4f66-4c6e-ac7d-92e5e78c3e79',
          protocol: 'activitypub',
        ),
        _specBridgedNote['tags']![0],
      );
    });

    test('withProxy replaces tags and clears id and sig', () {
      final note = _event({
        'kind': 1,
        'content': 'hello',
        'id': 'a' * 64,
        'sig': 'b' * 128,
        'tags': [
          ['t', 'nostr'],
          ['proxy', 'at://old', 'atproto'],
        ],
      });

      final bridged = NostrNip48.withProxy(
        note,
        id: 'https://twitter.com/jack/status/20',
        protocol: NostrNip48.web,
      );

      expect(bridged.tags, [
        ['t', 'nostr'],
        ['proxy', 'https://twitter.com/jack/status/20', 'web'],
      ]);
      expect(bridged.id, isNull);
      expect(bridged.sig, isNull);
      expect(NostrNip48.parse(bridged).protocol, 'web');
    });

    test('withoutProxy removes every proxy tag', () {
      final note = NostrNip48.withoutProxy(
        _event({
          'kind': 1,
          'tags': [
            ['proxy', 'a', 'activitypub'],
            ['proxy', 'b', 'rss'],
            ['t', 'nostr'],
          ],
        }),
      );

      expect(note.tags, [
        ['t', 'nostr'],
      ]);
      expect(NostrNip48.isBridged(note), isFalse);
    });

    test('parses every proxy tag and skips malformed ones', () {
      final event = _event({
        'kind': 30023,
        'tags': [
          ['proxy'],
          ['proxy', 'only-id'],
          ['proxy', '', 'web'],
          ['proxy', 'https://a.example', 'web'],
          ['proxy', 'https://b.example', 'rss'],
        ],
      });

      final references = NostrNip48.parseAll(event);
      expect(references, hasLength(2));
      expect(references.first.id, 'https://a.example');
      expect(references.last.protocol, 'rss');
      expect(NostrNip48.tryParse(event)?.id, 'https://a.example');
    });

    test('non-bridged events return null and parse throws', () {
      final note = _event({'kind': 1, 'tags': <List<String>>[]});

      expect(NostrNip48.tryParse(note), isNull);
      expect(NostrNip48.isBridged(note), isFalse);
      expect(() => NostrNip48.parse(note), throwsArgumentError);
      expect(NostrProxyReference.tryParse(const ['proxy']), isNull);
    });

    test('rejects blank proxy ids and protocols', () {
      expect(
        () => NostrNip48.tag(id: '', protocol: 'web'),
        throwsArgumentError,
      );
      expect(
        () => NostrNip48.tag(id: 'https://a.example', protocol: ' '),
        throwsArgumentError,
      );
    });
  });

  group('NIP-62 request to vanish', () {
    test('constants', () {
      expect(NostrNip62.vanishKind, 62);
      expect(NostrNip62.allRelays, 'ALL_RELAYS');
    });

    test('parses the spec vanish vector', () {
      final event = _event(_specVanish);
      final request = NostrNip62.parse(event);

      expect(request.relays, ['<relay url>']);
      expect(request.content, '<reason or note>');
      expect(request.pubkey, _pubkey);
      expect(request.isGlobal, isFalse);
    });

    test('parses the spec global vanish vector', () {
      final request = NostrNip62.parse(_event(_specGlobalVanish));

      expect(request.relays, ['ALL_RELAYS']);
      expect(request.isGlobal, isTrue);
      expect(request.content, '<reason>');
    });

    test('builds the spec vanish tags exactly', () {
      final event = NostrNip62.generateVanishTemplate(
        relays: const ['<relay url>'],
        content: '<reason or note>',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(event.kind, 62);
      expect(event.content, _specVanish['content']);
      expect(event.tags, _specVanish['tags']);
      expect(event.pubkey, isEmpty);

      final global = NostrNip62.generateVanishTemplate(
        relays: const [NostrNip62.allRelays],
        content: '<reason>',
      );
      expect(global.tags, _specGlobalVanish['tags']);
    });

    test('extraTags cannot duplicate the relay tags', () {
      final event = NostrNip62.generateVanishTemplate(
        relays: const ['wss://relay.one'],
        extraTags: const [
          ['relay', 'wss://imposter'],
          ['t', 'nostr'],
        ],
      );

      expect(event.tags, [
        ['relay', 'wss://relay.one'],
        ['t', 'nostr'],
      ]);
    });

    test('rejects an empty relay list or blank relays', () {
      expect(
        () => NostrNip62.generateVanishTemplate(relays: const []),
        throwsArgumentError,
      );
      expect(
        () => NostrNip62.generateVanishTemplate(relays: const ['']),
        throwsArgumentError,
      );
      expect(
        () => NostrNip62.generateVanishTemplate(relays: const [' ']),
        throwsArgumentError,
      );
    });

    test('publish signs through the bound signer', () async {
      final nip = NostrNip62(signer: signer);
      final event = await nip.publish(
        relays: const ['wss://relay.one', 'wss://relay.two'],
        content: 'GDPR erasure request',
      );

      expect(event.kind, 62);
      expect(event.pubkey, signer.publicKey);
      expect(event.id, isNotNull);
      expect(event.sig, isNotNull);
      expect(event.tags, [
        ['relay', 'wss://relay.one'],
        ['relay', 'wss://relay.two'],
      ]);
      expect(NostrNip62.parse(event).relays, hasLength(2));
    });

    test('tryParse returns null and parse throws for invalid events', () {
      expect(
        NostrNip62.tryParse(_event({'kind': 5, 'tags': <List<String>>[]})),
        isNull,
      );
      expect(
        NostrNip62.tryParse(_event({'kind': 62, 'tags': <List<String>>[]})),
        isNull,
      );
      expect(
        NostrNip62.tryParse(
          _event({
            'kind': 62,
            'tags': [
              ['relay', ''],
            ],
          }),
        ),
        isNull,
      );
      expect(() => NostrNip62.parse(_event({'kind': 62})), throwsArgumentError);
    });
  });

  group('wiring', () {
    test('accessors are cached and typed on NostrNips', () {
      final nips = NostrNips(logger: Nostr.instance.services.logger);

      expect(nips.nip35, same(nips.nip35));
      expect(nips.nip48, same(nips.nip48));
      expect(nips.nip35, isA<NostrNip35>());
      expect(nips.nip48, isA<NostrNip48>());
      expect(const NostrNip35(), same(const NostrNip35()));
      expect(const NostrNip48(), same(const NostrNip48()));
      expect(Nostr.instance.nips.nip35, same(Nostr.instance.nips.nip35));
      expect(Nostr.instance.nips.nip48, same(Nostr.instance.nips.nip48));
    });

    test('signer-bound accessors throw StateError when unbound', () {
      final nips = NostrNips(logger: Nostr.instance.services.logger);

      expect(() => nips.nip37, throwsStateError);
      expect(() => nips.nip62, throwsStateError);

      final first = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(first);
      expect(nips.nip37.signer, same(first));
      expect(nips.nip62.signer, same(first));
      expect(nips.nip37, same(nips.nip37));
      expect(nips.nip62, same(nips.nip62));

      final second = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(second);
      expect(nips.nip37.signer, same(second));
      expect(nips.nip62.signer, same(second));

      nips.bindSigner(null);
      expect(() => nips.nip37, throwsStateError);
      expect(() => nips.nip62, throwsStateError);
    });
  });
}
