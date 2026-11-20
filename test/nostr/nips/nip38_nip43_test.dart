import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

const _pubkey1 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkey2 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _relayPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _address = '30023:'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    ':post';

NostrEvent _event(
  int kind,
  List<List<String>> tags, {
  String content = '',
  String pubkey = _pubkey1,
}) {
  return NostrEvent(
    id: null,
    kind: kind,
    content: content,
    sig: null,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    tags: tags,
  );
}

void main() {
  group('NIP-38 user statuses', () {
    /// 38.md:14-28 — general status with an `r` URL.
    final generalVector = _event(
      NostrNip38.statusKind,
      [
        ['d', 'general'],
        ['r', 'https://nostr.world'],
      ],
      content: 'Sign up for nostrasia!',
    );

    /// 38.md:31-40 — music status with a `%20` link and expiration.
    final musicVector = _event(
      NostrNip38.statusKind,
      [
        ['d', 'music'],
        ['r', 'spotify:search:Intergalatic%20-%20Beastie%20Boys'],
        ['expiration', '1692845589'],
      ],
      content: 'Intergalatic - Beastie Boys',
    );

    test('constants', () {
      expect(NostrNip38.statusKind, 30315);
      expect(NostrNip38.generalStatus, 'general');
      expect(NostrNip38.musicStatus, 'music');
    });

    test('parses the spec vectors', () {
      final general = NostrNip38.parse(generalVector);

      expect(general.statusType, NostrNip38.generalStatus);
      expect(general.content, 'Sign up for nostrasia!');
      expect(general.urls, ['https://nostr.world']);
      expect(general.pubkeys, isEmpty);
      expect(general.expiresAt, isNull);
      expect(general.isExpired(), isFalse);

      final music = NostrNip38.parse(musicVector);

      expect(music.statusType, NostrNip38.musicStatus);
      expect(music.content, 'Intergalatic - Beastie Boys');
      expect(
        music.urls,
        ['spotify:search:Intergalatic%20-%20Beastie%20Boys'],
      );
      expect(
        music.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1692845589000),
      );
      expect(
        music.isExpired(
          now: DateTime.fromMillisecondsSinceEpoch(1692845590000),
        ),
        isTrue,
      );
      expect(
        NostrNip38.isExpired(musicVector, timestamp: 1692845590),
        isTrue,
      );
      expect(
        NostrNip38.isExpired(musicVector, timestamp: 1692845588),
        isFalse,
      );
      expect(NostrNip38.isExpired(generalVector, timestamp: 1), isFalse);
    });

    test('builds the spec vectors', () {
      final general = NostrNip38.generateStatusTemplate(
        statusType: 'general',
        content: 'Sign up for nostrasia!',
        urls: ['https://nostr.world'],
      );

      expect(general.kind, 30315);
      expect(general.content, 'Sign up for nostrasia!');
      expect(general.tags, generalVector.tags);

      final music = NostrNip38.generateStatusTemplate(
        statusType: 'music',
        content: 'Intergalatic - Beastie Boys',
        urls: ['spotify:search:Intergalatic%20-%20Beastie%20Boys'],
        expiresAt: 1692845589,
      );

      expect(music.tags, musicVector.tags);
    });

    test('keeps every status type and optional tag', () {
      final status = NostrNip38.parse(
        _event(
          NostrNip38.statusKind,
          [
            ['d', 'out-of-office'],
            ['p', _pubkey1],
            ['e', 'e' * 64],
            ['a', _address],
          ],
        ),
      );

      expect(status.statusType, 'out-of-office');
      expect(status.content, isEmpty);
      expect(status.pubkeys, [_pubkey1]);
      expect(status.eventIds, ['e' * 64]);
      expect(status.addresses, [_address]);
    });

    test('empty content builds a clearing status', () {
      final event = NostrNip38.generateStatusTemplate(
        statusType: 'general',
      );

      expect(event.content, isEmpty);
      expect(event.tags, [
        ['d', 'general'],
      ]);
    });

    test('rejects invalid templates', () {
      expect(
        () => NostrNip38.generateStatusTemplate(statusType: ''),
        throwsArgumentError,
      );
      expect(
        () => NostrNip38.generateStatusTemplate(
          statusType: 'general',
          expiresAt: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip38.generateStatusTemplate(
          statusType: 'general',
          pubkeys: ['not-hex'],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrNip38.generateStatusTemplate(
          statusType: 'general',
          addresses: ['nope'],
        ),
        throwsArgumentError,
      );
    });

    test('tryParse returns null for other kinds and bad d tags', () {
      expect(
          NostrNip38.tryParse(_event(1, [
            ['d', 'general']
          ])),
          isNull);
      expect(NostrNip38.tryParse(_event(NostrNip38.statusKind, [])), isNull);
      expect(
        NostrNip38.tryParse(_event(NostrNip38.statusKind, [
          ['d', '']
        ])),
        isNull,
      );
      expect(
        () => NostrNip38.parse(_event(1, [
          ['d', 'general']
        ])),
        throwsArgumentError,
      );
    });

    test('unparseable expiration is treated as absent', () {
      final event = _event(
        NostrNip38.statusKind,
        [
          ['d', 'general'],
          ['expiration', 'soon'],
        ],
      );

      expect(NostrNip38.parse(event).expiresAt, isNull);
      expect(NostrNip38.isExpired(event, timestamp: 9999999999), isFalse);
    });

    test('publish signs through the bound signer', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final nip = NostrNip38(signer: signer);

      final event = await nip.publish(statusType: 'general', content: 'Hi');

      expect(event.kind, 30315);
      expect(event.pubkey, signer.publicKey);
      expect(event.id, isNotNull);
      expect(event.sig, isNotNull);
    });
  });

  group('NIP-43 relay access metadata', () {
    const nip = NostrNip43();

    /// 43.md:29-40 — role tags.
    final roleVector = _event(
      NostrNip43.roleKind,
      [
        ['-'],
        ['d', '28b7e50f'],
        ['label', 'king'],
        ['description', 'ruler of the relay'],
        ['color', '37'],
        ['order', '1'],
      ],
      pubkey: _relayPubkey,
    );

    /// 43.md:60-68 — two members, one with a role.
    final memberListVector = _event(
      NostrNip43.memberListKind,
      [
        ['-'],
        ['member', _pubkey1],
        ['member', _pubkey2, '28b7e50f'],
      ],
      pubkey: _relayPubkey,
    );

    /// 43.md:82-90 — add user.
    final addUserVector = _event(
      NostrNip43.addUserKind,
      [
        ['-'],
        ['p', _pubkey1],
      ],
      pubkey: _relayPubkey,
    );

    /// 43.md:104-112 — remove user.
    final removeUserVector = _event(
      NostrNip43.removeUserKind,
      [
        ['-'],
        ['p', _pubkey1],
      ],
      pubkey: _relayPubkey,
    );

    /// 43.md:122-130 — join request.
    final joinVector = _event(
      NostrNip43.joinRequestKind,
      [
        ['-'],
        ['claim', 'invite-code'],
      ],
    );

    /// 43.md:152-157 — leave request.
    final leaveVector = _event(
      NostrNip43.leaveRequestKind,
      [
        ['-'],
      ],
    );

    test('constants', () {
      expect(NostrNip43.roleKind, 33534);
      expect(NostrNip43.memberListKind, 13534);
      expect(NostrNip43.addUserKind, 8000);
      expect(NostrNip43.removeUserKind, 8001);
      expect(NostrNip43.joinRequestKind, 28934);
      expect(NostrNip43.leaveRequestKind, 28936);
    });

    test('builds the spec role vector', () {
      final event = nip.generateRoleTemplate(
        roleId: '28b7e50f',
        label: 'king',
        description: 'ruler of the relay',
        color: 37,
        order: 1,
      );

      expect(event.kind, 33534);
      expect(event.tags, roleVector.tags);
      expect(event.tags!.where((tag) => tag.first == '-'), hasLength(1));
    });

    test('parses the spec role vector', () {
      final role = nip.tryParseRole(roleVector);

      expect(role, isNotNull);
      expect(role!.roleId, '28b7e50f');
      expect(role.label, 'king');
      expect(role.description, 'ruler of the relay');
      expect(role.color, 37);
      expect(role.order, 1);
      expect(role.toTag, ['d', '28b7e50f']);
    });

    test('builds and parses the spec member list vector', () {
      final event = nip.generateMemberListTemplate(
        members: const [
          NostrRelayMember(pubkey: _pubkey1),
          NostrRelayMember(pubkey: _pubkey2, roleIds: ['28b7e50f']),
        ],
      );

      expect(event.kind, 13534);
      expect(event.tags, memberListVector.tags);

      final members = nip.tryParseMemberList(memberListVector);

      expect(members, hasLength(2));
      expect(members!.first.pubkey, _pubkey1);
      expect(members.first.roleIds, isEmpty);
      expect(members.first.toTag, ['member', _pubkey1]);
      expect(members.last.pubkey, _pubkey2);
      expect(members.last.roleIds, ['28b7e50f']);
      expect(members.last.toTag, ['member', _pubkey2, '28b7e50f']);
    });

    test('builds the add and remove vectors', () {
      expect(
        nip.generateAddUserTemplate(pubkey: _pubkey1).tags,
        addUserVector.tags,
      );
      expect(
        nip.generateRemoveUserTemplate(pubkey: _pubkey1).tags,
        removeUserVector.tags,
      );
    });

    test('builds and parses the request vectors', () {
      final join = nip.generateJoinRequestTemplate(claim: 'invite-code');
      expect(join.kind, 28934);
      expect(join.tags, joinVector.tags);

      final leave = nip.generateLeaveRequestTemplate();
      expect(leave.kind, 28936);
      expect(leave.tags, leaveVector.tags);

      expect(nip.tryParseJoinRequest(joinVector)?.claim, 'invite-code');
      expect(nip.tryParseJoinRequest(leaveVector), isNull);
    });

    test('rejects invalid templates', () {
      expect(() => nip.generateRoleTemplate(roleId: ''), throwsArgumentError);
      expect(
        () => nip.generateRoleTemplate(roleId: 'r', color: 361),
        throwsArgumentError,
      );
      expect(
        () => nip.generateRoleTemplate(roleId: 'r', color: -1),
        throwsArgumentError,
      );
      expect(
        () => nip.generateMemberListTemplate(members: const []),
        throwsArgumentError,
      );
      expect(
        () => nip.generateMemberListTemplate(
          members: const [NostrRelayMember(pubkey: 'nope')],
        ),
        throwsArgumentError,
      );
      expect(
        () => nip.generateAddUserTemplate(pubkey: 'nope'),
        throwsArgumentError,
      );
      expect(
        () => nip.generateRemoveUserTemplate(pubkey: 'nope'),
        throwsArgumentError,
      );
      expect(
        () => nip.generateJoinRequestTemplate(claim: ''),
        throwsArgumentError,
      );
    });

    test('parsers are lenient and kind-checked', () {
      expect(
          nip.tryParseRole(_event(1, [
            ['d', 'r']
          ])),
          isNull);
      expect(nip.tryParseRole(_event(NostrNip43.roleKind, [])), isNull);
      expect(
        nip
            .tryParseRole(
              _event(
                NostrNip43.roleKind,
                [
                  ['d', 'r'],
                  ['color', '400'],
                  ['order', 'one'],
                ],
              ),
            )
            ?.color,
        isNull,
      );

      final members = nip.tryParseMemberList(
        _event(
          NostrNip43.memberListKind,
          [
            ['member', 'not-hex'],
            ['member', _pubkey1, 'unknown-role'],
          ],
        ),
      );

      expect(members, hasLength(1));
      expect(members!.single.pubkey, _pubkey1);
      expect(members.single.roleIds, ['unknown-role']);
      expect(nip.tryParseMemberList(_event(1, [])), isNull);

      expect(
        nip.tryParseJoinRequest(
          _event(NostrNip43.joinRequestKind, [
            ['claim', '']
          ]),
        ),
        isNull,
      );
    });

    test('templates carry exactly one NIP-70 marker', () {
      final templates = [
        nip.generateRoleTemplate(roleId: 'r'),
        nip.generateMemberListTemplate(
          members: const [NostrRelayMember(pubkey: _pubkey1)],
        ),
        nip.generateAddUserTemplate(pubkey: _pubkey1),
        nip.generateRemoveUserTemplate(pubkey: _pubkey1),
        nip.generateJoinRequestTemplate(claim: 'code'),
        nip.generateLeaveRequestTemplate(),
      ];

      for (final event in templates) {
        expect(event.tags!.first, ['-']);
        expect(event.tags!.where((tag) => tag.first == '-'), hasLength(1));
      }
    });

    test('detects relay-authored events and NIP-43 support', () {
      expect(nip.isRelayAuthored(roleVector, _relayPubkey), isTrue);
      expect(nip.isRelayAuthored(memberListVector, _relayPubkey), isTrue);
      expect(nip.isRelayAuthored(addUserVector, _relayPubkey), isTrue);
      expect(nip.isRelayAuthored(removeUserVector, _relayPubkey), isTrue);
      expect(nip.isRelayAuthored(roleVector, _pubkey2), isFalse);
      expect(nip.isRelayAuthored(joinVector, _pubkey1), isFalse);

      expect(
        nip.relaySupportsNip43(
          const RelayInformations(supportedNips: [1, 43]),
        ),
        isTrue,
      );
      expect(
        nip.relaySupportsNip43(const RelayInformations(supportedNips: [1])),
        isFalse,
      );
      expect(nip.relaySupportsNip43(const RelayInformations()), isFalse);
    });

    test('publishes join and leave requests with the user signer', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

      final join = await nip.publishJoinRequest(signer, claim: 'invite-code');
      expect(join.kind, 28934);
      expect(join.pubkey, signer.publicKey);
      expect(join.id, isNotNull);
      expect(join.tags, joinVector.tags);

      final leave = await nip.publishLeaveRequest(signer);
      expect(leave.kind, 28936);
      expect(leave.pubkey, signer.publicKey);
      expect(leave.tags, leaveVector.tags);
    });
  });
}
