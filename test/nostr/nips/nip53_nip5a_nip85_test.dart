import 'package:dart_nostr/nostr/core/crypto_utils.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip53/nip53.dart';
import 'package:dart_nostr/nostr/nips/nip5a/nip5a.dart';
import 'package:dart_nostr/nostr/nips/nip85/nip85.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

const String _pubkey =
    '1597246ac22f7d1375041054f2a4986bd971d8d196d7997e48973263ac9879ec';
const String _eventId =
    'e88a691e98d9987c964521dff60025f60700378a4879180dcbbb4a5027850411';
const String _servicePubkey =
    '4fd5e210530e4f6b2cb083795834bfe5108324f1ed9f00ab73b9e8fcfe5f12fe';
const String _indexHash =
    '186ea5fd14e88fd1ac49351759e7ab906fa94892002b60bf7f5a428f28ca1c99';
const String _aboutHash =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
const String _faviconHash =
    'fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321';
const String _postHash =
    'b1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';

NostrEvent _event(
  List<List<String>> tags, {
  int kind = 30311,
  String content = '',
  String pubkey = _pubkey,
  DateTime? createdAt,
}) {
  return NostrEvent(
    id: null,
    kind: kind,
    content: content,
    sig: null,
    pubkey: pubkey,
    createdAt: createdAt ?? DateTime.utc(2024),
    tags: tags,
  );
}

/// Asserts the spec's `id` and `sig` for a fully specified vector event.
void _expectSpecEvent(
  NostrEvent event, {
  required String id,
  required String sig,
  bool checkId = true,
}) {
  if (checkId) {
    expect(
      NostrEvent.getEventId(
        kind: event.kind!,
        content: event.content ?? '',
        createdAt: event.createdAt!,
        tags: event.tags ?? const [],
        pubkey: event.pubkey,
      ),
      id,
    );
  }

  final signed = NostrEvent(
    id: id,
    kind: event.kind,
    content: event.content,
    sig: sig,
    pubkey: event.pubkey,
    createdAt: event.createdAt,
    tags: event.tags,
  );
  expect(signed.isVerified(), isTrue);
}

void main() {
  group('NIP-53 live activities', () {
    test('kind constants and predicates', () {
      expect(NostrLiveKind.liveEvent, 30311);
      expect(NostrLiveKind.chatMessage, 1311);
      expect(NostrLiveKind.room, 30312);
      expect(NostrLiveKind.meeting, 30313);
      expect(NostrLiveKind.presence, 10312);
      expect(NostrLiveKind.isLiveKind(30311), isTrue);
      expect(NostrLiveKind.isLiveKind(10312), isTrue);
      expect(NostrLiveKind.isLiveKind(1), isFalse);
      expect(NostrNip53.liveEventKind, 30311);
      expect(NostrNip53.roomKind, 30312);
    });

    test('spec live streaming vector 53.md:91-110', () {
      const tags = [
        ['d', 'demo-cf-stream'],
        ['title', 'Adult Swim Metalocalypse'],
        ['summary', 'Live stream from IPTV-ORG collection'],
        [
          'streaming',
          'https://adultswim-vodlive.cdn.turner.com/live/metalocalypse/'
              'stream.m3u8',
        ],
        ['starts', '1687182672'],
        ['status', 'live'],
        ['t', 'animation'],
        ['t', 'iptv'],
        ['image', 'https://i.imgur.com/CaKq6Mt.png'],
      ];
      final event = _event(
        tags,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1687182672 * 1000),
      );

      // The spec sample id does not hash to its tags: recomputing the id from
      // this vector yields 6c1338a7..., so the signature is verified against
      // the published id while the id derivation is skipped.
      _expectSpecEvent(
        event,
        id: '57f28dbc264990e2c61e80a883862f7c114019804208b14da0bff81371e484d2',
        sig: '5bc7a60f5688effa5287244a24768cbe0dcd854436090abc3bef172f7f5d'
            'b1410af4277508dbafc4f70a754a891c90ce3b966a7bc47e7c1eb71ff5764'
            '0f3d389',
        checkId: false,
      );

      final parsed = NostrLiveEvent.parse(event);
      expect(parsed.dTag, 'demo-cf-stream');
      expect(parsed.title, 'Adult Swim Metalocalypse');
      expect(parsed.summary, 'Live stream from IPTV-ORG collection');
      expect(parsed.status, 'live');
      expect(parsed.isLive, isTrue);
      expect(parsed.starts, 1687182672);
      expect(parsed.ends, isNull);
      expect(parsed.hashtags, ['animation', 'iptv']);
      expect(parsed.image, 'https://i.imgur.com/CaKq6Mt.png');
      expect(
        parsed.streamingUrl,
        'https://adultswim-vodlive.cdn.turner.com/live/metalocalypse/'
        'stream.m3u8',
      );
      expect(
        parsed.address,
        '30311:$_pubkey:demo-cf-stream',
      );
      expect(NostrLiveEvent.validate(event), isTrue);
    });

    test('participant roles, relay hints and optional proofs', () {
      final keys = NostrKeyPairs.generate();
      const coordinate = '30311:$_pubkey:demo-cf-stream';
      final proof = keys.sign(NostrCryptoUtils.sha256Hash(coordinate));

      final event = _event([
        ['d', 'demo-cf-stream'],
        ['title', 'Stream'],
        ['p', _pubkey, 'wss://provider1.com/', 'Host', proof],
        ['p', keys.public, 'wss://provider2.com/', 'Speaker'],
        ['p', '14aeb..8dad4', '', 'Participant'],
        ['relays', 'wss://one.com', 'wss://two.com'],
        ['pinned', _eventId],
      ]);
      final parsed = NostrLiveEvent.parse(event);

      expect(parsed.participants, hasLength(3));
      expect(parsed.participants.first.relay, 'wss://provider1.com/');
      expect(parsed.participants.first.role, 'Host');
      expect(parsed.participants.first.isHost, isTrue);
      expect(parsed.participants[1].proof, isNull);
      expect(parsed.participants[2].relay, isNull);
      expect(parsed.participants[2].role, 'Participant');
      expect(parsed.relays, ['wss://one.com', 'wss://two.com']);
      expect(parsed.pinned, [_eventId]);

      final hostKeys = keys;
      final document = _event(
        [
          ['d', 'demo-cf-stream'],
          ['p', hostKeys.public, 'wss://provider1.com/', 'Host', proof],
        ],
        pubkey: _pubkey,
      );
      final documentParsed = NostrLiveEvent.parse(document);
      expect(
        documentParsed
            .verifyParticipantProof(documentParsed.participants.first),
        isTrue,
      );

      const badProof = NostrLiveParticipant(
        pubkey: '14aeb..8dad4',
        role: 'Host',
        proof: 'junk',
      );
      expect(badProof.verifyProof(coordinate: coordinate), isFalse);
      expect(
        const NostrLiveParticipant(pubkey: '14aeb..8dad4')
            .verifyProof(coordinate: coordinate),
        isFalse,
      );
      // Parsing never gates on the proof.
      expect(NostrLiveEvent.tryParse(document), isNotNull);
    });

    test('spec chat message vector 53.md:115-126', () {
      const activity = '30311:$_pubkey:demo-cf-stream';
      final event = _event(
        [
          ['a', activity, '', 'root'],
        ],
        kind: 1311,
        content: 'Zaps to live streams is beautiful.',
        pubkey:
            '3f770d65d3a764a9c5cb503ae123e62ec7598ad035d836e2a810f3877a745b24',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1687286726 * 1000),
      );

      _expectSpecEvent(
        event,
        id: '97aa81798ee6c5637f7b21a411f89e10244e195aa91cb341bf49f718e36c8188',
        sig: '997f62ddfc0827c121043074d50cfce7a528e978c575722748629a4137c45b'
            '75bdbc84170bedc723ef0a5a4c3daebf1fef2e93f5e2ddb98e5d685d022c3'
            '0b622',
      );

      final parsed = NostrLiveChatMessage.parse(event);
      expect(parsed.activityAddress, activity);
      expect(parsed.activityRelay, isNull);
      expect(parsed.activityMarker, 'root');
      expect(parsed.parentEventId, isNull);
      expect(parsed.quotes, isEmpty);
      expect(parsed.content, 'Zaps to live streams is beautiful.');

      final built = NostrLiveChatMessage.build(
        activityAddress: activity,
        parentEventId: _eventId,
        quotes: [_eventId],
        content: 'hi',
      );
      final builtParsed = NostrLiveChatMessage.parse(built);
      expect(builtParsed.parentEventId, _eventId);
      expect(builtParsed.quotes, [_eventId]);

      final marked = NostrLiveChatMessage.build(
        activityAddress: activity,
        activityMarker: 'root',
      );
      expect(NostrTags.tag(marked.tags, 'a'), ['a', activity, '', 'root']);
      expect(NostrLiveChatMessage.parse(marked).activityMarker, 'root');

      final relayed = NostrLiveChatMessage.build(
        activityAddress: activity,
        activityRelay: 'wss://relay.example',
        activityMarker: 'root',
      );
      expect(
        NostrTags.tag(relayed.tags, 'a'),
        ['a', activity, 'wss://relay.example', 'root'],
      );
      expect(
        NostrLiveChatMessage.parse(relayed).activityRelay,
        'wss://relay.example',
      );

      expect(
        NostrLiveChatMessage.tryParse(
          _event([
            ['e', _eventId]
          ], kind: 1311),
        ),
        isNull,
        reason: 'the a tag is mandatory',
      );
    });

    test('spec room vector 53.md:209-226', () {
      final event = _event(
        [
          ['d', 'main-conference-room'],
          ['room', 'Main Conference Hall'],
          ['summary', 'Our primary conference space'],
          ['image', 'https://example.com/room.jpg'],
          ['status', 'open'],
          ['service', 'https://meet.example.com/room'],
          ['endpoint', 'https://api.example.com/room'],
          ['t', 'conference'],
          [
            'p',
            'f7234bd4c1394dda46d09f35bd384dd30cc552ad5541990f98844fb06676e9ca',
            'wss://nostr.example.com/',
            'Owner',
          ],
          ['p', '14aeb..8dad4', 'wss://provider2.com/', 'Moderator'],
          ['relays', 'wss://relay1.com', 'wss://relay2.com'],
        ],
        kind: 30312,
      );

      final parsed = NostrLiveRoom.parse(event);
      expect(parsed.dTag, 'main-conference-room');
      expect(parsed.roomName, 'Main Conference Hall');
      expect(parsed.status, 'open');
      expect(parsed.serviceUrl, 'https://meet.example.com/room');
      expect(parsed.endpointUrl, 'https://api.example.com/room');
      expect(parsed.hashtags, ['conference']);
      expect(parsed.participants, hasLength(2));
      expect(parsed.participants[1].role, 'Moderator');
      expect(parsed.relays, ['wss://relay1.com', 'wss://relay2.com']);
      // The spec example labels its provider "Owner"; role names stay free-form.
      expect(parsed.hasHost, isFalse);

      final built = NostrLiveRoom.build(
        dTag: 'main-conference-room',
        roomName: 'Main Conference Hall',
        status: 'open',
        serviceUrl: 'https://meet.example.com/room',
        participants: const [
          NostrLiveParticipant(pubkey: _pubkey, role: 'Host'),
        ],
      );
      expect(NostrLiveRoom.validate(built), isTrue);
      expect(
        NostrTags.tag(built.tags, 'room'),
        ['room', 'Main Conference Hall'],
      );
      expect(() {
        NostrLiveRoom.build(
          dTag: 'room',
          roomName: 'Room',
          status: 'open',
          serviceUrl: 'https://meet.example.com/room',
          participants: const [
            NostrLiveParticipant(pubkey: _pubkey, role: 'Speaker'),
          ],
        );
      }, throwsArgumentError);

      // `room` is required by the spec (53.md:142): the builder enforces it,
      // while parsing stays tolerant for events already on relays.
      expect(
        () => NostrLiveRoom.build(
          dTag: 'room',
          roomName: '  ',
          status: 'open',
          serviceUrl: 'https://meet.example.com/room',
          participants: const [
            NostrLiveParticipant(pubkey: _pubkey, role: 'Host'),
          ],
        ),
        throwsArgumentError,
      );
      final legacy = _event(
        [
          ['d', 'room'],
          ['status', 'open'],
          ['service', 'https://meet.example.com/room'],
          ['p', _pubkey, '', 'Host'],
        ],
        kind: 30312,
      );
      expect(NostrLiveRoom.tryParse(legacy), isNotNull);
      expect(NostrLiveRoom.tryParse(legacy)!.roomName, isNull);
      expect(
        NostrLiveRoom.validate(legacy),
        isFalse,
        reason: 'validate enforces the spec-required room tag',
      );

      // validate matches the builder: no Host provider and unknown status fail
      // even though the event still parses (53.md:157,160).
      final noHost = _event(
        [
          ['d', 'room'],
          ['room', 'Room'],
          ['status', 'open'],
          ['service', 'https://meet.example.com/room'],
          ['p', _pubkey, '', 'Speaker'],
        ],
        kind: 30312,
      );
      expect(NostrLiveRoom.tryParse(noHost), isNotNull);
      expect(
        NostrLiveRoom.validate(noHost),
        isFalse,
        reason: 'rooms require at least one Host provider (53.md:160)',
      );

      final unknownStatus = _event(
        [
          ['d', 'room'],
          ['room', 'Room'],
          ['status', 'paused'],
          ['service', 'https://meet.example.com/room'],
          ['p', _pubkey, '', 'Host'],
        ],
        kind: 30312,
      );
      expect(NostrLiveRoom.tryParse(unknownStatus), isNotNull);
      expect(
        NostrLiveRoom.validate(unknownStatus),
        isFalse,
        reason: 'validate rejects status values outside open|private|closed',
      );
    });

    test('spec meeting vector 53.md:229-248', () {
      final event = _event(
        [
          ['d', 'annual-meeting-2025'],
          [
            'a',
            '30312:f7234bd4c1394dda46d09f35bd384dd30cc552ad5541990f98844fb06676e9ca:main-conference-room',
            'wss://nostr.example.com',
          ],
          ['title', 'Annual Company Meeting 2025'],
          ['summary', 'Yearly company-wide meeting'],
          ['image', 'https://example.com/meeting.jpg'],
          ['starts', '1676262123'],
          ['ends', '1676269323'],
          ['status', 'live'],
          ['total_participants', '180'],
          ['current_participants', '175'],
          ['p', '91cf9..4e5ca', 'wss://provider1.com/', 'Speaker'],
        ],
        kind: 30313,
      );

      final parsed = NostrLiveMeeting.parse(event);
      expect(parsed.title, 'Annual Company Meeting 2025');
      expect(parsed.roomAddress, contains(':main-conference-room'));
      expect(parsed.roomRelay, 'wss://nostr.example.com');
      expect(parsed.starts, 1676262123);
      expect(parsed.ends, 1676269323);
      expect(parsed.status, 'live');
      expect(parsed.totalParticipants, 180);
      expect(parsed.currentParticipants, 175);
      expect(parsed.participants.single.role, 'Speaker');

      final built = NostrLiveMeeting.build(
        dTag: 'annual-meeting-2025',
        roomAddress: '30312:$_pubkey:main-conference-room',
        title: 'Annual Company Meeting 2025',
        starts: 1676262123,
        ends: 1676269323,
        status: 'live',
      );
      expect(NostrLiveMeeting.validate(built), isTrue);

      final wrongRoom = _event(
        [
          ['d', 'meeting'],
          ['a', '30311:$_pubkey:stream'],
          ['title', 'Bad'],
          ['starts', '1'],
          ['status', 'live'],
        ],
        kind: 30313,
      );
      expect(NostrLiveMeeting.tryParse(wrongRoom), isNull);

      // Inverted windows are kept as data: the spec states no ordering MUST.
      final inverted = _event(
        [
          ['d', 'meeting'],
          ['a', '30312:$_pubkey:room'],
          ['title', 'Inverted window'],
          ['starts', '10'],
          ['ends', '5'],
          ['status', 'live'],
        ],
        kind: 30313,
      );
      expect(NostrLiveMeeting.parse(inverted).ends, 5);
    });

    test('presence points at exactly one room', () {
      final roomAddress = '30312:$_pubkey:main-conference-room';
      final built = NostrPresence.build(
        roomAddress: roomAddress,
        roomRelay: 'wss://relay.example',
        handRaised: true,
      );

      final parsed = NostrPresence.parse(built);
      expect(parsed.roomAddress, roomAddress);
      expect(parsed.roomRelay, 'wss://relay.example');
      expect(parsed.handRaised, isTrue);
      expect(
        NostrTags.tag(built.tags, 'a'),
        ['a', roomAddress, 'wss://relay.example', 'root'],
      );

      final lowered = NostrPresence.build(roomAddress: roomAddress);
      expect(
        NostrTags.tag(lowered.tags, 'a'),
        ['a', roomAddress, '', 'root'],
      );
      expect(NostrPresence.parse(lowered).handRaised, isFalse);
      expect(
        NostrPresence.parse(lowered).roomRelay,
        isNull,
        reason: 'the empty relay slot must not be read as the marker',
      );

      final duplicate = _event(
        [
          ['a', roomAddress, '', 'root'],
          ['a', '30312:$_pubkey:other', '', 'root'],
        ],
        kind: 10312,
      );
      expect(NostrPresence.tryParse(duplicate), isNull);

      final wrongKind = _event([
        ['a', '30311:$_pubkey:stream']
      ], kind: 10312);
      expect(NostrPresence.tryParse(wrongKind), isNull);
    });

    test('signer-bound generation, parsing and publishing', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final nips = NostrNip53(signer: signer);

      final template = nips.generateLiveEvent(
        dTag: 'stream',
        title: 'Live',
        status: 'live',
        participants: const [
          NostrLiveParticipant(pubkey: _pubkey, role: 'Host'),
        ],
      );
      expect(template.sig, isNull);
      expect(nips.tryParseLiveEvent(template), isNotNull);

      final signed = await nips.publish(template);
      expect(signed.isVerified(), isTrue);
      expect(nips.parseLiveEvent(signed).title, 'Live');

      expect(
        nips.tryParseLiveEvent(_event([
          ['d', 'x']
        ], kind: 1311)),
        isNull,
      );
      expect(
        nips.tryParseChatMessage(
          nips.generateChatMessage(
            activityAddress: '30311:${signer.publicKey}:stream',
            content: 'hello',
          ),
        ),
        isNotNull,
      );
      expect(
        nips.tryParsePresence(
          nips.generatePresence(
            roomAddress: '30312:${signer.publicKey}:room',
          ),
        ),
        isNotNull,
      );
    });

    test('invalid numeric tags are rejected and statuses stay tolerant', () {
      expect(
        NostrLiveEvent.tryParse(
          _event([
            ['d', 'x'],
            ['starts', 'not-a-number'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrLiveEvent.tryParse(_event([
          ['title', 'no d']
        ])),
        isNull,
      );

      // Unknown statuses keep the event parseable; only the typed value is
      // dropped and the raw tag survives.
      final unknownEvent = _event([
        ['d', 'x'],
        ['status', 'soon'],
      ]);
      final unknown = NostrLiveEvent.parse(unknownEvent);
      expect(unknown.status, isNull);
      expect(unknown.rawStatus, 'soon');
      expect(unknown.isLive, isFalse);
      expect(
        NostrLiveEvent.validate(unknownEvent),
        isFalse,
        reason: 'validate rejects status values outside planned|live|ended',
      );

      final room = NostrLiveRoom.parse(
        _event(
          [
            ['d', 'room'],
            ['room', 'Room'],
            ['status', 'paused'],
            ['service', 'https://meet.example.com/room'],
            ['p', _pubkey, '', 'Host'],
          ],
          kind: 30312,
        ),
      );
      expect(room.status, isNull);
      expect(room.rawStatus, 'paused');

      final meeting = NostrLiveMeeting.parse(
        _event(
          [
            ['d', 'meeting'],
            ['a', '30312:$_pubkey:room'],
            ['title', 'Meeting'],
            ['starts', '10'],
            ['status', 'paused'],
          ],
          kind: 30313,
        ),
      );
      expect(meeting.status, isNull);
      expect(meeting.rawStatus, 'paused');

      // Builders stay strict even though parsers tolerate unknown statuses.
      expect(
        () => NostrLiveEvent.build(dTag: 'x', status: 'soon'),
        throwsArgumentError,
      );
      expect(
        () => NostrLiveRoom.build(
          dTag: 'room',
          roomName: 'Room',
          status: 'paused',
          serviceUrl: 'https://meet.example.com/room',
          participants: const [
            NostrLiveParticipant(pubkey: _pubkey, role: 'Host'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrLiveMeeting.build(
          dTag: 'meeting',
          roomAddress: '30312:$_pubkey:room',
          title: 'Meeting',
          starts: 10,
          status: 'paused',
        ),
        throwsArgumentError,
      );

      final unknownMeeting = _event(
        [
          ['d', 'meeting'],
          ['a', '30312:$_pubkey:room'],
          ['title', 'Meeting'],
          ['starts', '10'],
          ['status', 'paused'],
        ],
        kind: 30313,
      );
      expect(NostrLiveMeeting.tryParse(unknownMeeting), isNotNull);
      expect(
        NostrLiveMeeting.validate(unknownMeeting),
        isFalse,
        reason: 'validate rejects status values outside planned|live|ended',
      );
    });
  });

  group('NIP-5A static websites', () {
    const rootPaths = {
      '/index.html': _indexHash,
      '/about.html': _aboutHash,
      '/favicon.ico': _faviconHash,
    };

    test('aggregate hash matches the spec vector 5A.md:90-101', () {
      const tags = [
        ['path', '/index.html', _indexHash],
        ['path', '/about.html', _aboutHash],
        ['path', '/favicon.ico', _faviconHash],
      ];

      expect(
        NostrSiteManifest.computeAggregateHash(tags),
        '89acc6381f045bae6f7985b8ff8e70ca50bb20f693d938dc59e0f8d2e4567cb2',
      );

      // Order independent and unaware of non-path tags.
      expect(
        NostrSiteManifest.computeAggregateHash([
          ['title', 'ignored'],
          ['path', '/favicon.ico', _faviconHash],
          [
            'x',
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            'aggregate'
          ],
          ['path', '/index.html', _indexHash],
          ['path', '/about.html', _aboutHash],
        ]),
        '89acc6381f045bae6f7985b8ff8e70ca50bb20f693d938dc59e0f8d2e4567cb2',
      );

      // Only exactly-three-slot path tags count, matching parse (5A.md:45).
      expect(
        NostrSiteManifest.computeAggregateHash([
          ['path', '/index.html', _indexHash],
          ['path', '/about.html', _aboutHash, 'extra'],
        ]),
        NostrSiteManifest.computeAggregateHash([
          ['path', '/index.html', _indexHash],
        ]),
      );

      const named = [
        ['path', '/index.html', _indexHash],
        ['path', '/post.html', _aboutHash],
      ];
      expect(
        NostrSiteManifest.computeAggregateHash(named),
        '0f59b49f9f40c14656ea47eb9c429ec086b8e5b8ebf060f970d5f5736a3dfcf9',
      );

      const copied = [
        ['path', '/index.html', _indexHash],
        ['path', '/post.html', _postHash],
      ];
      expect(
        NostrSiteManifest.computeAggregateHash(copied),
        'c3168e6b20996ae211a76e9aceff0a993d3c4bb6fe60b8980550ec1c34342f54',
      );

      expect(const NostrNip5a().computeAggregateHash(copied), hasLength(64));
    });

    test('spec root manifest vector 5A.md:200-223', () {
      final window = DateTime.fromMillisecondsSinceEpoch(1727373475 * 1000);
      final event = NostrSiteManifest.build(
        kind: NostrSiteKind.root,
        paths: rootPaths,
        servers: const ['https://blossom.example.com'],
        title: 'My Nostr Site',
        description: 'A static website hosted on Nostr',
        source: 'https://github.com/example/my-nostr-site',
        apps: const [
          NostrSiteApp(
            address:
                '31990:266815e0c9210dfa324c6cba3573b14bee49da4209a9456f9484e5106cd408a5:my-app',
            relay: 'wss://relay.example.com',
          ),
          NostrSiteApp(
            address:
                '32267:266815e0c9210dfa324c6cba3573b14bee49da4209a9456f9484e5106cd408a5:com.example.webapp',
            relay: 'wss://relay.example.com',
          ),
        ],
        createdAt: window,
      );

      final parsed = NostrSiteManifest.parse(event);
      expect(parsed.isRoot, isTrue);
      expect(parsed.dTag, isNull);
      expect(parsed.paths, rootPaths);
      expect(
        parsed.aggregateHash,
        '89acc6381f045bae6f7985b8ff8e70ca50bb20f693d938dc59e0f8d2e4567cb2',
      );
      expect(NostrSiteManifest.verifyAggregateHash(event.tags!), isTrue);
      expect(parsed.servers, ['https://blossom.example.com']);
      expect(parsed.title, 'My Nostr Site');
      expect(parsed.description, 'A static website hosted on Nostr');
      expect(parsed.source, 'https://github.com/example/my-nostr-site');
      expect(parsed.apps, hasLength(2));
      expect(parsed.apps.first.parsedAddress?.kind, 31990);
      expect(parsed.apps.last.relay, 'wss://relay.example.com');
      expect(parsed.isCopy, isFalse);

      // The same path set must get its hash from the manifest, not a tag.
      expect(parsed.hashForPath('/'), _indexHash);
      expect(parsed.hashForPath('/about.html'), _aboutHash);
      expect(parsed.hashForPath('/missing.html'), isNull);
    });

    test('spec named manifest vector 5A.md:225-248', () {
      final event = NostrSiteManifest.build(
        kind: NostrSiteKind.named,
        dTag: 'blog',
        paths: const {
          '/index.html': _indexHash,
          '/post.html': _aboutHash,
        },
        servers: const ['https://blossom.example.com'],
        title: 'My Blog',
        description: 'A blog hosted on Nostr',
        source: 'https://github.com/example/my-nostr-blog',
      );

      final parsed = NostrSiteManifest.parse(event);
      expect(parsed.isNamed, isTrue);
      expect(parsed.dTag, 'blog');
      expect(
        parsed.aggregateHash,
        '0f59b49f9f40c14656ea47eb9c429ec086b8e5b8ebf060f970d5f5736a3dfcf9',
      );

      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['d', 'bad-tag-'],
              ['path', '/index.html', _indexHash],
            ],
            kind: 35128,
          ),
        ),
        isNull,
      );
      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['d', 'fourteen-chars'],
              ['path', '/index.html', _indexHash],
            ],
            kind: 35128,
          ),
        ),
        isNull,
      );
      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['d', 'Uppercase'],
              ['path', '/index.html', _indexHash],
            ],
            kind: 35128,
          ),
        ),
        isNull,
      );
      expect(
        NostrSiteManifest.build(
          kind: NostrSiteKind.named,
          dTag: 'a-1',
          paths: rootPaths,
        ).kind,
        35128,
      );
    });

    test('root manifests reject d tags', () {
      final event = _event(
        [
          ['d', 'blog'],
          ['path', '/index.html', _indexHash],
        ],
        kind: 15128,
      );

      expect(NostrSiteManifest.tryParse(event), isNull);
    });

    test('root site coordinates are valid copy and snapshot refs', () {
      const rootAddress =
          '15128:266815e0c9210dfa324c6cba3573b14bee49da4209a9456f9484e5106cd408a5:';
      const paths = {'/index.html': _indexHash};

      final snapshot = NostrSiteManifest.build(
        kind: NostrSiteKind.snapshot,
        parentAddress: rootAddress,
        paths: paths,
      );
      final parsedSnapshot = NostrSiteManifest.parse(snapshot);
      expect(parsedSnapshot.parentAddress, rootAddress);
      expect(parsedSnapshot.originAddress, isNull);

      final copy = NostrSiteManifest.build(
        kind: NostrSiteKind.named,
        dTag: 'root-copy',
        parentAddress: rootAddress,
        originAddress: rootAddress,
        paths: paths,
      );
      final parsedCopy = NostrSiteManifest.parse(copy);
      expect(parsedCopy.parentAddress, rootAddress);
      expect(parsedCopy.originAddress, rootAddress);

      // Garbage kinds and pubkeys stay rejected.
      expect(
        () => NostrSiteManifest.build(
          kind: NostrSiteKind.snapshot,
          parentAddress: '1:$_pubkey:',
          paths: paths,
        ),
        throwsArgumentError,
      );
      expect(
        () => NostrSiteManifest.build(
          kind: NostrSiteKind.snapshot,
          parentAddress: '15128:not-a-pubkey:',
          paths: paths,
        ),
        throwsArgumentError,
      );
    });

    test('copied manifest lineage 5A.md:250-298', () {
      const parent =
          '35128:266815e0c9210dfa324c6cba3573b14bee49da4209a9456f9484e5106cd408a5:blog';
      const origin = parent;

      final event = NostrSiteManifest.build(
        kind: NostrSiteKind.named,
        dTag: 'blog',
        parentAddress: parent,
        originAddress: origin,
        paths: const {
          '/index.html': _indexHash,
          '/post.html': _postHash,
        },
        title: 'My Copied Blog',
        description: 'A copy of another named nsite',
      );

      final parsed = NostrSiteManifest.parse(event);
      expect(parsed.isCopy, isTrue);
      expect(parsed.parentAddress, parent);
      expect(parsed.originAddress, origin);
      expect(
        parsed.aggregateHash,
        'c3168e6b20996ae211a76e9aceff0a993d3c4bb6fe60b8980550ec1c34342f54',
      );

      final loneParent = NostrSiteManifest.tryParse(
        _event(
          [
            ['d', 'blog'],
            ['path', '/index.html', _indexHash],
            ['a', parent],
          ],
          kind: 35128,
        ),
      );
      expect(
        loneParent,
        isNotNull,
        reason: 'a lone a is SHOULD-NOT, not MUST-NOT (5A.md:126)',
      );
      expect(loneParent!.parentAddress, parent);
      expect(loneParent.originAddress, isNull);
      expect(loneParent.isCopy, isTrue);

      final loneOrigin = NostrSiteManifest.tryParse(
        _event(
          [
            ['d', 'blog'],
            ['path', '/index.html', _indexHash],
            ['A', origin],
          ],
          kind: 35128,
        ),
      );
      expect(loneOrigin?.originAddress, origin);
      expect(loneOrigin?.parentAddress, isNull);

      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', _indexHash],
              ['a', 'not-an-address'],
              ['A', origin],
            ],
            kind: 35128,
          ),
        ),
        isNull,
      );
    });

    test('manifest snapshot aggregate x tag 5A.md:300-322', () {
      const parent =
          '35128:266815e0c9210dfa324c6cba3573b14bee49da4209a9456f9484e5106cd408a5:blog';
      final event = NostrSiteManifest.build(
        kind: NostrSiteKind.snapshot,
        parentAddress: parent,
        paths: const {
          '/index.html': _indexHash,
          '/post.html': _postHash,
        },
        servers: const ['https://blossom.example.com'],
        title: 'My Blog v1',
        description: 'An immutable snapshot of a blog hosted on Nostr',
      );

      final parsed = NostrSiteManifest.parse(event);
      expect(parsed.isSnapshot, isTrue);
      expect(parsed.dTag, isNull);
      expect(parsed.parentAddress, parent);
      expect(parsed.originAddress, isNull);
      expect(
        parsed.aggregateHash,
        'c3168e6b20996ae211a76e9aceff0a993d3c4bb6fe60b8980550ec1c34342f54',
      );
      expect(NostrTags.hasExactly(parsed.tags, 'x', 1), isTrue);

      // Only kind 15128 forbids `d`; a snapshot may carry one (5A.md:17,300).
      final versioned = NostrSiteManifest.build(
        kind: NostrSiteKind.snapshot,
        dTag: 'v1',
        parentAddress: parent,
        paths: const {'/index.html': _indexHash},
      );
      expect(NostrSiteManifest.parse(versioned).dTag, 'v1');

      final missingX = _event(
        [
          ['a', parent],
          ['path', '/index.html', _indexHash],
        ],
        kind: 5128,
      );
      expect(NostrSiteManifest.tryParse(missingX), isNull);

      final wrongX = _event(
        [
          ['a', parent],
          ['path', '/index.html', _indexHash],
          [
            'x',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'aggregate'
          ],
        ],
        kind: 5128,
      );
      expect(NostrSiteManifest.tryParse(wrongX), isNull);

      final noParent = _event(
        [
          ['path', '/index.html', _indexHash],
          [
            'x',
            NostrSiteManifest.computeAggregateHash([
              ['path', '/index.html', _indexHash],
            ]),
            'aggregate'
          ],
        ],
        kind: 5128,
      );
      expect(NostrSiteManifest.tryParse(noParent), isNull);
    });

    test('path resolution falls back to index.html', () {
      const nip = NostrNip5a();

      expect(nip.resolvePath('/'), '/index.html');
      expect(nip.resolvePath('/blog/'), '/blog/index.html');
      expect(NostrSiteManifest.resolvePath('/dir/'), '/dir/index.html');
      expect(NostrSiteManifest.resolvePath('/file.html'), '/file.html');
      expect(NostrSiteManifest.resolvePath('file.html'), '/file.html');
      expect(
        NostrSiteManifest.computeAggregateHash(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('source, app and path validation stays strict', () {
      final base = {
        '/index.html': _indexHash,
      };

      expect(
        NostrSiteManifest.tryParse(
          NostrSiteManifest.build(
            kind: NostrSiteKind.root,
            paths: base,
            source: 'nostr://git.example.com/example/site',
          ),
        ),
        isNotNull,
      );
      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', _indexHash],
              ['source', 'http://insecure.example.com/site'],
            ],
            kind: 15128,
          ),
        ),
        isNull,
      );
      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', _indexHash],
              ['app', 'not-an-address'],
            ],
            kind: 15128,
          ),
        ),
        isNull,
      );
      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', 'relative.html', _indexHash],
            ],
            kind: 15128,
          ),
        ),
        isNull,
      );
      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', 'not-a-hash'],
            ],
            kind: 15128,
          ),
        ),
        isNull,
      );
      expect(
        NostrSiteManifest.tryParse(_event(const [], kind: 15128)),
        isNull,
      );
    });

    test('app tags always carry three slots', () {
      const app =
          '31990:266815e0c9210dfa324c6cba3573b14bee49da4209a9456f9484e5106cd408a5:my-app';

      final built = NostrSiteManifest.build(
        kind: NostrSiteKind.root,
        paths: const {'/index.html': _indexHash},
        apps: const [NostrSiteApp(address: app)],
      );
      expect(NostrTags.tag(built.tags, 'app'), ['app', app, '']);

      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', _indexHash],
              ['app', app],
            ],
            kind: 15128,
          ),
        ),
        isNull,
        reason: 'the app tag requires the relay slot (5A.md:106)',
      );

      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', _indexHash],
              ['app', app, 'wss://relay.example', 'extra'],
            ],
            kind: 15128,
          ),
        ),
        isNull,
        reason: 'four slots are not the spec app tag (5A.md:106)',
      );
    });

    test('copy lineage rejects duplicate and non-site addresses', () {
      const siteAddress = '35128:$_pubkey:blog';
      const rootAddress = '15128:$_pubkey:';

      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', _indexHash],
              ['d', 'blog'],
              ['a', siteAddress],
              ['a', rootAddress],
            ],
            kind: 35128,
          ),
        ),
        isNull,
        reason: 'copied sites allow one a tag',
      );

      expect(
        NostrSiteManifest.tryParse(
          _event(
            [
              ['path', '/index.html', _indexHash],
              ['d', 'blog'],
              ['A', siteAddress],
              ['A', rootAddress],
            ],
            kind: 35128,
          ),
        ),
        isNull,
        reason: 'copied sites allow one A tag',
      );

      for (final source in ['30000', '5128']) {
        expect(
          NostrSiteManifest.tryParse(
            _event(
              [
                ['path', '/index.html', _indexHash],
                ['d', 'blog'],
                ['a', '$source:$_pubkey:'],
              ],
              kind: 35128,
            ),
          ),
          isNull,
          reason: 'lineage must reference a 15128 or 35128 site',
        );
      }
    });

    test('stateless generation and publishing', () async {
      const nip = NostrNip5a();
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

      final root = nip.generateRootManifest(paths: rootPaths);
      final named = nip.generateNamedManifest(dTag: 'blog', paths: rootPaths);
      final snapshot = nip.generateSnapshot(
        parentAddress: '35128:$_pubkey:blog',
        paths: rootPaths,
        originAddress: '35128:$_pubkey:blog',
      );

      expect(root.kind, 15128);
      expect(nip.parseManifest(named).dTag, 'blog');
      expect(nip.parseManifest(snapshot).isSnapshot, isTrue);
      expect(nip.tryParseManifest(root), isNotNull);

      final signed = await nip.publish(root, signer);
      expect(signed.isVerified(), isTrue);
      expect(signed.pubkey, signer.publicKey);
    });
  });

  group('NIP-85 trusted assertions', () {
    test('kind helpers', () {
      expect(NostrAssertionKind.user, 30382);
      expect(NostrAssertionKind.event, 30383);
      expect(NostrAssertionKind.addressable, 30384);
      expect(NostrAssertionKind.identifier, 30385);
      expect(NostrAssertionKind.providerRecommendation, 10040);
      expect(NostrAssertionKind.isAssertion(30382), isTrue);
      expect(NostrAssertionKind.isAssertion(10040), isFalse);
      expect(NostrAssertionKind.isAssertionKind(10040), isTrue);
      expect(NostrNip85.userAssertionKind, 30382);
      expect(NostrNip85.providerRecommendationKind, 10040);
    });

    test('spec user assertion vector 85.md:24-37', () {
      final event = _event(
        [
          ['d', _eventId],
          ['rank', '89'],
        ],
        kind: 30382,
        pubkey: _servicePubkey,
      );

      final parsed = NostrUserAssertion.parse(event);
      expect(parsed.subject, _eventId);
      expect(parsed.rank, 89);
      expect(parsed.pubkey, _servicePubkey);
      expect(parsed.followers, isNull);
      expect(NostrUserAssertion.validate(event), isTrue);
    });

    test('user assertion covers every declared result tag', () {
      final event = NostrUserAssertion.build(
        subject: _eventId,
        rank: 75,
        followers: 10,
        firstCreatedAt: 1600000000,
        postCount: 20,
        replyCount: 5,
        reactionsCount: 30,
        zapAmountReceived: 4000,
        zapAmountSent: 3000,
        zapCountReceived: 40,
        zapCountSent: 35,
        zapAvgAmountDayReceived: 50,
        zapAvgAmountDaySent: 45,
        reportsCountReceived: 2,
        reportsCountSent: 1,
        topics: const ['nostr', 'dart'],
        activeHoursStart: 8,
        activeHoursEnd: 22,
      );

      final parsed = NostrUserAssertion.parse(event);
      expect(parsed.rank, 75);
      expect(parsed.followers, 10);
      expect(parsed.firstCreatedAt, 1600000000);
      expect(parsed.postCount, 20);
      expect(parsed.replyCount, 5);
      expect(parsed.reactionsCount, 30);
      expect(parsed.zapAmountReceived, 4000);
      expect(parsed.zapAmountSent, 3000);
      expect(parsed.zapCountReceived, 40);
      expect(parsed.zapCountSent, 35);
      expect(parsed.zapAvgAmountDayReceived, 50);
      expect(parsed.zapAvgAmountDaySent, 45);
      expect(parsed.reportsCountReceived, 2);
      expect(parsed.reportsCountSent, 1);
      expect(parsed.topics, ['nostr', 'dart']);
      expect(parsed.activeHoursStart, 8);
      expect(parsed.activeHoursEnd, 22);

      final tagNames = event.tags!.map((tag) => tag.first).toSet();
      expect(
        tagNames,
        containsAll([
          'd',
          'rank',
          'followers',
          'first_created_at',
          'post_cnt',
          'reply_cnt',
          'reactions_cnt',
          'zap_amt_recd',
          'zap_amt_sent',
          'zap_cnt_recd',
          'zap_cnt_sent',
          'zap_avg_amt_day_recd',
          'zap_avg_amt_day_sent',
          'reports_cnt_recd',
          'reports_cnt_sent',
          't',
          'active_hours_start',
          'active_hours_end',
        ]),
      );
    });

    test('numeric result tags parse tolerantly', () {
      final event = _event(
        [
          ['d', _eventId],
          ['rank', 'not-a-number'],
          ['followers', '12'],
          ['zap_amt_recd', '-3'],
          ['zap_amt_sent', '0'],
        ],
        kind: 30382,
      );

      final parsed = NostrUserAssertion.parse(event);
      expect(parsed.rank, isNull);
      expect(parsed.followers, 12);
      // Negative values become null, matching the builder's non-negative rule.
      expect(parsed.zapAmountReceived, isNull);
      // Zero is a real count and stays zero.
      expect(parsed.zapAmountSent, 0);
      expect(NostrUserAssertion.tryParse(event), isNotNull);
    });

    test('event, address and identifier assertions', () {
      final eventAssertion = NostrEventAssertion.build(
        subject: _eventId,
        rank: 90,
        commentCount: 4,
        quoteCount: 3,
        repostCount: 2,
        reactionCount: 10,
        zapCount: 6,
        zapAmount: 2100,
      );
      final parsedEvent = NostrEventAssertion.parse(eventAssertion);
      expect(parsedEvent.subject, _eventId);
      expect(parsedEvent.rank, 90);
      expect(parsedEvent.commentCount, 4);
      expect(parsedEvent.quoteCount, 3);
      expect(parsedEvent.repostCount, 2);
      expect(parsedEvent.reactionCount, 10);
      expect(parsedEvent.zapCount, 6);
      expect(parsedEvent.zapAmount, 2100);
      expect(NostrEventAssertion.validate(eventAssertion), isTrue);

      const address =
          '31990:266815e0c9210dfa324c6cba3573b14bee49da4209a9456f9484e5106cd408a5:my-app';
      final addressAssertion = NostrAddressAssertion.build(
        subject: address,
        rank: 60,
        zapAmount: 900,
      );
      final parsedAddress = NostrAddressAssertion.parse(addressAssertion);
      expect(parsedAddress.subject, address);
      expect(parsedAddress.rank, 60);
      expect(parsedAddress.zapAmount, 900);

      final identifierAssertion = NostrIdentifierAssertion.build(
        subject: 'isbn:978-3-16-148410-0',
        rank: 88,
        commentCount: 7,
        reactionCount: 11,
        kTags: const ['isbn', 'book'],
      );
      final parsedIdentifier =
          NostrIdentifierAssertion.parse(identifierAssertion);
      expect(parsedIdentifier.subject, 'isbn:978-3-16-148410-0');
      expect(parsedIdentifier.rank, 88);
      expect(parsedIdentifier.commentCount, 7);
      expect(parsedIdentifier.reactionCount, 11);
      expect(parsedIdentifier.kTags, ['isbn', 'book']);

      expect(
        NostrUserAssertion.tryParse(eventAssertion),
        isNull,
        reason: 'kind 30383 is not a user assertion',
      );
      expect(
        NostrAddressAssertion.tryParse(
          _event(
            [
              ['d', '31990:$_pubkey'],
            ],
            kind: 30384,
          ),
        ),
        isNull,
      );
      expect(
        NostrIdentifierAssertion.tryParse(
          _event([
            ['rank', '1']
          ], kind: 30385),
        ),
        isNull,
      );
    });

    test('provider recommendations and NIP-44 private fallback', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final nips = NostrNip85(signer: signer);
      const publicRank = NostrProviderRecommendation(
        kindTag: '30382:rank',
        servicePubkey: _servicePubkey,
        relay: 'wss://nip85.nostr.band',
      );
      const privateRank = NostrProviderRecommendation(
        kindTag: '30383:rank',
        servicePubkey: _eventId,
        relay: 'wss://nostr.wine',
      );

      final template = await nips.generateProviderRecommendation(
        recommendations: const [publicRank],
        privateRecommendations: const [privateRank],
      );
      expect(template.kind, 10040);
      expect(template.tags, [
        ['30382:rank', _servicePubkey, 'wss://nip85.nostr.band'],
      ]);
      expect(template.content, isNotEmpty);

      final signed = await nips.publish(template);
      final resolved = await nips.resolveProviderRecommendations(signed);
      expect(
        resolved.map((item) => item.kindTag),
        ['30382:rank', '30383:rank'],
      );
      expect(resolved.last.servicePubkey, _eventId);

      // Private content is deduplicated against public entries.
      final duplicated = await nips.generateProviderRecommendation(
        recommendations: const [publicRank],
        privateRecommendations: const [publicRank],
      );
      final duplicatedResolved = await nips.resolveProviderRecommendations(
        await nips.publish(duplicated),
      );
      expect(duplicatedResolved, hasLength(1));

      // Malformed encrypted content falls back to the public tags.
      final broken = _event(
        [
          ['30382:rank', _servicePubkey, 'wss://nip85.nostr.band'],
        ],
        kind: 10040,
        content: 'not-a-nip44-payload',
      );
      final fallback = await nips.resolveProviderRecommendations(broken);
      expect(fallback, hasLength(1));
      expect(fallback.single.kindTag, '30382:rank');
      expect(NostrProviderRecommendation.parseEvent(broken), hasLength(1));

      expect(
        await nips.resolveProviderRecommendations(
          _event(const [], kind: 10040),
        ),
        isEmpty,
      );
    });

    test('provider recommendation parsing is tolerant', () {
      final event = _event(
        [
          ['30382:rank', _servicePubkey, 'wss://nip85.nostr.band'],
          ['30382:followers', 'not-a-pubkey', 'wss://bad.example'],
          ['not-a-selector', _eventId, 'wss://bad.example'],
          ['30383:rank', _eventId],
        ],
        kind: 10040,
      );

      final parsed = NostrProviderRecommendation.parseEvent(event);
      expect(parsed, hasLength(2));
      expect(parsed.first.kind, 30382);
      expect(parsed.first.resultTag, 'rank');
      expect(parsed.last.kindTag, '30383:rank');
      expect(parsed.last.relay, isNull);

      expect(
        NostrProviderRecommendation.parseList(
          '[["30384:rank","$_eventId","wss://relay.example"]]',
        ),
        hasLength(1),
      );
      expect(NostrProviderRecommendation.parseList('not-json'), isEmpty);
      expect(NostrProviderRecommendation.parseList({'a': 1}), isEmpty);
      expect(
        NostrProviderRecommendation.isValidKindTag('30382:rank'),
        isTrue,
      );
      expect(
        NostrProviderRecommendation.isValidKindTag('rank'),
        isFalse,
      );
    });

    test('signer-bound generation, parsing and publishing', () async {
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());
      final nips = NostrNip85(signer: signer);

      final template = nips.generateUserAssertion(
        subject: _eventId,
        rank: 89,
      );
      expect(nips.tryParseUserAssertion(template)?.rank, 89);
      expect(
        nips.tryParseEventAssertion(
          nips.generateEventAssertion(subject: _eventId, rank: 1),
        ),
        isNotNull,
      );
      expect(
        nips.tryParseAddressAssertion(
          nips.generateAddressAssertion(
            subject: '31990:$_pubkey:app',
            rank: 1,
          ),
        ),
        isNotNull,
      );
      expect(
        nips.tryParseIdentifierAssertion(
          nips.generateIdentifierAssertion(
            subject: 'isbn:123',
            kTags: const ['isbn'],
          ),
        ),
        isNotNull,
      );

      final signed = await nips.publish(template);
      expect(signed.isVerified(), isTrue);
      expect(nips.parseUserAssertion(signed).subject, _eventId);
    });
  });
}
