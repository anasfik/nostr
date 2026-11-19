import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

/// A pubkey that is not derived from any local key in these tests.
final String _remotePubkey = 'ab' * 32;

/// Author pubkey used for NIP-29 state events.
final String _authorPubkey = 'cc' * 32;

/// Admin/member pubkey used for NIP-29 state events.
final String _memberPubkey = 'cd' * 32;

/// Signer that holds no local key material, like a NIP-46 remote signer.
class _RemoteSigner implements NostrEventSigner {
  @override
  String get publicKey => _remotePubkey;

  @override
  Future<NostrEvent> sign(NostrEvent event) async => event;

  @override
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey) =>
      throw UnimplementedError();

  @override
  Future<String> nip44Decrypt(String payload, String senderPublicKey) =>
      throw UnimplementedError();
}

void main() {
  final logger = Nostr.instance.services.logger;

  group('NIP-04 legacy DMs', () {
    const sk1 =
        '91ba716fa9e7ea2fcbad360cf4f8e0d312f73984da63d90f524ad61a6a1e7dbe';
    const sk2 =
        '96f6fa197aa07477ab88f6981118466ae3a982faab8ad5db9d5426870c73d220';
    final pk1 = NostrSecp256k1.derivePublicKey(sk1);

    test('decrypts a go-nostr payload', () {
      final nip04 = NostrNip04(privateKeyHex: sk2);

      expect(
        nip04.decrypt(
          'zJxfaJ32rN5Dg1ODjOlEew==?iv=EV5bUjcc4OX2Km/zPp4ndQ==',
          pk1,
        ),
        'nanana',
      );
    });

    test('roundtrips with random IV and PKCS7 padding', () {
      final alice = NostrNip04(privateKeyHex: sk1);
      final bob = NostrNip04(privateKeyHex: sk2);
      final plaintext = 'z' * 800;

      final first = alice.encrypt(plaintext, bob.publicKey);
      final second = alice.encrypt(plaintext, bob.publicKey);

      expect(first, isNot(second), reason: 'IV must be random');
      expect(first, contains('?iv='));
      expect(bob.decrypt(first, alice.publicKey), plaintext);
      expect(bob.decrypt(second, alice.publicKey), plaintext);
    });

    test('accepts x-only recipient public keys', () {
      final alice = NostrNip04(privateKeyHex: sk1);
      final bob = NostrNip04(privateKeyHex: sk2);
      final bobXOnly = NostrSecp256k1.derivePublicKey(sk2).substring(2);

      final payload = alice.encrypt('hi', bobXOnly);
      expect(payload, contains('?iv='));
      expect(bob.decrypt(payload, alice.publicKey), 'hi');
    });

    test('creates a verified kind-4 event with a p tag', () {
      final alice = NostrNip04(privateKeyHex: sk1);
      final bob = NostrNip04(privateKeyHex: sk2);

      final event = alice.createDirectMessage(
        plaintext: 'secret',
        recipientPublicKey: bob.publicKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(event.kind, 4);
      expect(event.pubkey, alice.publicKey);
      expect(event.tags, [
        ['p', bob.publicKey],
      ]);
      expect(event.isVerified(), isTrue);
      expect(bob.decrypt(event.content!, alice.publicKey), 'secret');
    });

    test('roundtrips an empty plaintext as one padded block', () {
      final alice = NostrNip04(privateKeyHex: sk1);
      final bob = NostrNip04(privateKeyHex: sk2);

      final payload = alice.encrypt('', bob.publicKey);
      final ctB64 = payload.substring(0, payload.indexOf('?iv='));

      expect(base64.decode(ctB64), hasLength(16));
      expect(bob.decrypt(payload, alice.publicKey), '');
    });

    test('rejects payloads without ?iv=', () {
      final nip04 = NostrNip04(privateKeyHex: sk2);

      expect(
        () => nip04.decrypt('bm90LWEtcGF5bG9hZA==', pk1),
        throwsArgumentError,
      );
    });

    test('fromSigner only accepts local key material', () {
      expect(
        () => NostrNip04.fromSigner(_RemoteSigner()),
        throwsArgumentError,
      );
    });
  });

  group('NIP-28 public channels', () {
    late NostrEventSigner signer;
    late NostrNip28 nip28;

    setUp(() {
      signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      nip28 = NostrNip28(signer: signer);
    });

    test('creates a kind-40 channel with JSON metadata', () async {
      final event = await nip28.createChannel(
        metadata: {'name': 'Dart', 'about': 'Dart chat'},
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(event.kind, 40);
      expect(jsonDecode(event.content!), {
        'name': 'Dart',
        'about': 'Dart chat',
      });
      expect(event.tags, isEmpty);
      expect(event.isVerified(), isTrue);
    });

    test('creates a kind-41 metadata update with an e tag', () async {
      final event = await nip28.updateChannelMetadata(
        channelId: 'channel-id',
        metadata: {'name': 'renamed'},
      );

      expect(event.kind, 41);
      expect(event.tags, [
        ['e', 'channel-id'],
      ]);
      expect(jsonDecode(event.content!), {'name': 'renamed'});
      expect(event.isVerified(), isTrue);
    });

    test('creates kind-42 root and reply tags', () async {
      final root = await nip28.sendChannelMessage(
        channelId: 'channel-id',
        relayUrl: 'wss://relay.example',
        content: 'hello',
      );
      final reply = await nip28.sendChannelMessage(
        channelId: 'channel-id',
        relayUrl: 'wss://relay.example',
        content: 'hi back',
        replyToEventId: root.id,
      );

      expect(root.kind, 42);
      expect(root.tags, [
        ['e', 'channel-id', 'wss://relay.example', 'root'],
      ]);
      expect(reply.tags, [
        ['e', 'channel-id', 'wss://relay.example', 'root'],
        ['e', root.id, 'wss://relay.example', 'reply'],
      ]);
      expect(reply.isVerified(), isTrue);
    });

    test('creates kind-43 and kind-44 moderation events', () async {
      final hidden = await nip28.hideChannelMessage(
        messageEventId: 'msg-id',
        reason: 'spam',
      );
      final muted = await nip28.muteChannelUser(
        pubkey: _memberPubkey,
        reason: 'abuse',
      );

      expect(hidden.kind, 43);
      expect(hidden.tags, [
        ['e', 'msg-id'],
      ]);
      expect(jsonDecode(hidden.content!), {'reason': 'spam'});

      expect(muted.kind, 44);
      expect(muted.tags, [
        ['p', 'cd' * 32],
      ]);
      expect(jsonDecode(muted.content!), {'reason': 'abuse'});
    });
  });

  group('NIP-29 relay groups', () {
    final nip29 = NostrNip29(bech32: NostrBech32(logger: logger));

    test('builds a kind-39000 metadata template and parses it back', () {
      const metadata = GroupMetadata(
        id: 'dart',
        name: 'Dart',
        about: 'Dart chat',
        picture: 'https://example.com/p.png',
        isPrivate: true,
        supportedKinds: ['9', '11'],
        children: ['child-a'],
      );

      final template = nip29.createGroupMetadataEvent(metadata);

      expect(template.kind, 39000);
      expect(template.id, isNull);
      expect(template.sig, isNull);
      expect(template.tags, [
        ['d', 'dart'],
        ['name', 'Dart'],
        ['picture', 'https://example.com/p.png'],
        ['about', 'Dart chat'],
        ['private'],
        ['supported_kinds', '9', '11'],
        ['child', 'child-a'],
      ]);
      expect(
        nip29.validateGroupMetadataEvent(template),
        isFalse,
        reason: 'templates have no pubkey',
      );

      final signed = NostrEvent(
        id: 'aa' * 32,
        kind: 39000,
        content: '',
        sig: 'bb' * 64,
        pubkey: _authorPubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        tags: template.tags,
      );

      expect(nip29.validateGroupMetadataEvent(signed), isTrue);
      final parsed = nip29.parseGroupMetadataEvent(signed);
      expect(parsed.id, 'dart');
      expect(parsed.pubkey, 'cc' * 32);
      expect(parsed.name, 'Dart');
      expect(parsed.isPrivate, isTrue);
      expect(parsed.supportedKinds, ['9', '11']);
      expect(parsed.children, ['child-a']);
    });

    test('builds and parses kind-39001 admins with permissions', () {
      final template = nip29.createGroupAdminsEvent(
        groupId: 'dart',
        admins: [
          GroupAdmin(
            pubkey: _memberPubkey,
            label: 'mod',
            permissions: [
              GroupAdminPermission.putUser,
              GroupAdminPermission.deleteEvent,
            ],
          ),
        ],
      );

      expect(template.tags, [
        ['d', 'dart'],
        ['p', _memberPubkey, 'mod', 'put-user', 'delete-event'],
      ]);

      final signed = _withPubkey(template, _authorPubkey);
      expect(nip29.validateGroupAdminsEvent(signed), isTrue);
      final admins = nip29.parseGroupAdminsEvent(signed);
      expect(admins, hasLength(1));
      expect(admins.single.pubkey, 'cd' * 32);
      expect(admins.single.label, 'mod');
      expect(admins.single.permissions, [
        GroupAdminPermission.putUser,
        GroupAdminPermission.deleteEvent,
      ]);

      final invalidTags = <List<String>>[
        ['d', 'dart'],
        ['p', _memberPubkey, '', 'not-a-permission'],
      ];
      final invalid = _withPubkey(
        NostrEvent(
          id: null,
          kind: 39001,
          content: '',
          sig: null,
          pubkey: _authorPubkey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          tags: invalidTags,
        ),
        _authorPubkey,
      );
      expect(nip29.validateGroupAdminsEvent(invalid), isFalse);
    });

    test('builds and parses kind-39002 members', () {
      final template = nip29.createGroupMembersEvent(
        groupId: 'dart',
        members: [
          GroupMember(pubkey: 'cd' * 32),
          GroupMember(pubkey: 'ef' * 32, label: 'friend'),
        ],
      );

      expect(template.tags, [
        ['d', 'dart'],
        ['p', 'cd' * 32, ''],
        ['p', 'ef' * 32, 'friend'],
      ]);

      final signed = _withPubkey(template, _authorPubkey);
      expect(nip29.validateGroupMembersEvent(signed), isTrue);
      final members = nip29.parseGroupMembersEvent(signed);
      expect(members, hasLength(2));
      expect(members.first.label, isNull);
      expect(members.last.label, 'friend');
    });

    test('builds moderation templates with h/previous tags', () {
      expect(
        nip29
            .createPutUserEvent(
              groupId: 'dart',
              pubkey: _memberPubkey,
              roles: ['mod'],
              reason: 'promote',
              previous: ['event-1', 'event-2'],
            )
            .tags,
        [
          ['h', 'dart'],
          ['p', 'cd' * 32, 'mod'],
          ['previous', 'event-1', 'event-2'],
        ],
      );
      expect(
        nip29.createRemoveUserEvent(groupId: 'dart', pubkey: 'cd' * 32).tags,
        [
          ['h', 'dart'],
          ['p', 'cd' * 32],
        ],
      );
      expect(
        nip29.createDeleteEventEvent(groupId: 'dart', eventId: 'evt').tags,
        [
          ['h', 'dart'],
          ['e', 'evt'],
        ],
      );
      expect(nip29.createCreateGroupEvent(groupId: 'fresh').kind, 9007);
      expect(nip29.createDeleteGroupEvent(groupId: 'dart').kind, 9008);
      expect(
        nip29.createCreateInviteEvent(groupId: 'dart', code: 'abc').tags,
        [
          ['h', 'dart'],
          ['code', 'abc'],
        ],
      );
      expect(
        nip29
            .createEditGroupMetadataEvent(
              metadata: const GroupMetadata(id: 'dart', name: 'Dart'),
            )
            .tags,
        [
          ['h', 'dart'],
          ['name', 'Dart'],
        ],
      );
    });

    test('encodes and parses both group reference forms', () {
      const reference = GroupReference(
        host: 'wss://relay.example',
        id: 'dart',
      );

      expect(reference.encode(), "relay.example'dart");
      expect(nip29.encodeGroupReference(reference), "relay.example'dart");

      final parsed = nip29.parseGroupReference("relay.example'dart");
      expect(parsed?.host, 'relay.example');
      expect(parsed?.id, 'dart');

      final naddr = NostrBech32(logger: logger).encodeNAddr(
        kind: 39000,
        authorPubkey: 'cc' * 32,
        identifier: 'dart',
        userRelays: ['wss://relay.example'],
      );
      final fromNaddr = nip29.parseGroupReference(naddr);
      expect(fromNaddr?.host, 'relay.example');
      expect(fromNaddr?.id, 'dart');

      expect(nip29.parseGroupReference('not-a-group'), isNull);
    });
  });

  group('NIP-98 HTTP auth', () {
    late NostrEventSigner signer;
    late NostrNip98 nip98;

    setUp(() {
      signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      nip98 = NostrNip98(signer: signer);
    });

    test('creates and validates a token without the scheme', () async {
      final token = await nip98.getToken(
        url: 'https://example.com/login',
        method: 'POST',
      );

      expect(token.startsWith('Nostr '), isFalse);

      final event = NostrNip98.unpackEventFromToken(token);
      expect(event.kind, 27235);
      expect(event.content, '');
      expect(event.pubkey, signer.publicKey);
      expect(event.isVerified(), isTrue);
      expect(event.tags, [
        ['u', 'https://example.com/login'],
        ['method', 'POST'],
      ]);

      expect(
        nip98.validateToken(
          token,
          url: 'https://example.com/login',
          method: 'post',
        ),
        isTrue,
      );
    });

    test('prefixes the authorization scheme on request', () async {
      final token = await nip98.getToken(
        url: 'https://example.com/login',
        method: 'GET',
        includeAuthorizationScheme: true,
      );

      expect(token, startsWith(NostrNip98.authorizationScheme));
      expect(
        nip98.validateToken(
          token,
          url: 'https://example.com/login',
          method: 'GET',
        ),
        isTrue,
      );
    });

    test('binds the SHA-256 payload hash', () async {
      final token = await nip98.getToken(
        url: 'https://example.com/login',
        method: 'POST',
        payload: {'test': 'payload'},
      );

      final event = NostrNip98.unpackEventFromToken(token);
      expect(
        event.tags!.any(
          (tag) =>
              tag.length == 2 &&
              tag[0] == 'payload' &&
              tag[1] == NostrNip98.hashPayload({'test': 'payload'}),
        ),
        isTrue,
      );

      expect(
        nip98.validateToken(
          token,
          url: 'https://example.com/login',
          method: 'POST',
          payload: {'test': 'payload'},
        ),
        isTrue,
      );
      expect(
        () => nip98.validateToken(
          token,
          url: 'https://example.com/login',
          method: 'POST',
          payload: {'test': 'other'},
        ),
        throwsFormatException,
      );
    });

    test('rejects wrong url, method and kind', () async {
      final token = await nip98.getToken(
        url: 'https://example.com/login',
        method: 'POST',
      );

      expect(
        () => nip98.validateToken(
          token,
          url: 'https://example.com/other',
          method: 'POST',
        ),
        throwsFormatException,
      );
      expect(
        () => nip98.validateToken(
          token,
          url: 'https://example.com/login',
          method: 'DELETE',
        ),
        throwsFormatException,
      );

      final wrongKind = await signer.sign(
        NostrEvent(
          id: null,
          kind: 1,
          content: '',
          sig: null,
          pubkey: signer.publicKey,
          createdAt: DateTime.now(),
          tags: const [
            ['u', 'https://example.com/login'],
            ['method', 'POST'],
          ],
        ),
      );
      expect(nip98.validateEventKind(wrongKind), isFalse);
      expect(
        () => nip98.validateEvent(
          wrongKind,
          url: 'https://example.com/login',
          method: 'POST',
        ),
        throwsFormatException,
      );
    });

    test('rejects an event whose tags were rewritten after signing', () async {
      final token = await nip98.getToken(
        url: 'https://example.com/login',
        method: 'POST',
      );
      final event = NostrNip98.unpackEventFromToken(token);

      final tampered = NostrEvent(
        id: event.id,
        kind: event.kind,
        content: event.content,
        sig: event.sig,
        pubkey: event.pubkey,
        createdAt: event.createdAt,
        tags: const [
          ['u', 'https://evil.example/steal'],
          ['method', 'DELETE'],
        ],
      );
      final tamperedToken = base64.encode(
        utf8.encode(jsonEncode(tampered.toMap())),
      );

      expect(tampered.isVerified(), isTrue, reason: 'sig covers claimed id');
      expect(
        () => nip98.validateToken(
          tamperedToken,
          url: 'https://evil.example/steal',
          method: 'DELETE',
        ),
        throwsFormatException,
      );
      expect(
        () => nip98.validateEvent(
          tampered,
          url: 'https://evil.example/steal',
          method: 'DELETE',
        ),
        throwsFormatException,
      );
    });

    test('rejects non-object and wrongly typed token payloads', () {
      final tokens = [
        base64.encode(utf8.encode('[1,2]')),
        base64.encode(utf8.encode('{"id":1}')),
        base64.encode(utf8.encode('{"kind":"27235"}')),
        base64.encode(utf8.encode('{"tags":[["u",1]]}')),
      ];

      for (final token in tokens) {
        expect(
          () => NostrNip98.unpackEventFromToken(token),
          throwsFormatException,
          reason: token,
        );
      }
    });

    test('rejects stale and invalid tokens', () async {
      final stale = await signer.sign(
        NostrEvent(
          id: null,
          kind: 27235,
          content: '',
          sig: null,
          pubkey: signer.publicKey,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          tags: const [
            ['u', 'https://example.com/login'],
            ['method', 'POST'],
          ],
        ),
      );

      expect(nip98.validateEventTimestamp(stale), isFalse);
      expect(
        () => nip98.validateEvent(
          stale,
          url: 'https://example.com/login',
          method: 'POST',
        ),
        throwsFormatException,
      );

      expect(
        () => NostrNip98.unpackEventFromToken(''),
        throwsFormatException,
      );
      expect(
        () => NostrNip98.unpackEventFromToken('bm90LWpzb24='),
        throwsFormatException,
      );
    });
  });

  group('NostrNips accessor wiring', () {
    test('nip29 is stateless, cached and functional', () {
      final nips = NostrNips(logger: logger);

      expect(nips.nip29, same(nips.nip29));
      expect(nips.nip29.createCreateGroupEvent(groupId: 'g').kind, 9007);
    });

    test('signer-bound accessors require a signer', () {
      final nips = NostrNips(logger: logger);

      expect(() => nips.nip04, throwsStateError);
      expect(() => nips.nip28, throwsStateError);
      expect(() => nips.nip98, throwsStateError);
    });

    test('local signer wires nip04/nip28/nip98 and rebinding resets', () {
      final nips = NostrNips(logger: logger);
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

      nips.bindSigner(signer);

      expect(nips.nip04.publicKey, signer.keyPairs.public);
      expect(nips.nip28.signer, same(signer));
      expect(nips.nip98.signer, same(signer));
      expect(nips.nip04, same(nips.nip04));
      expect(nips.nip28, same(nips.nip28));
      expect(nips.nip98, same(nips.nip98));

      nips.bindSigner(NostrLocalKeySigner(NostrKeyPairs.generate()));
      expect(nips.nip28.signer, isNot(same(signer)));
    });

    test('remote signer cannot use nip04', () {
      final nips = NostrNips(logger: logger)..bindSigner(_RemoteSigner());

      expect(() => nips.nip04, throwsArgumentError);
      expect(nips.nip28.signer.publicKey, 'ab' * 32);
      expect(nips.nip98.signer.publicKey, 'ab' * 32);
    });
  });
}

/// Returns [template] with a pubkey so validation helpers accept it.
NostrEvent _withPubkey(NostrEvent template, String pubkey) {
  return NostrEvent(
    id: template.id,
    kind: template.kind,
    content: template.content,
    sig: template.sig,
    pubkey: pubkey,
    createdAt: template.createdAt,
    tags: template.tags,
  );
}
