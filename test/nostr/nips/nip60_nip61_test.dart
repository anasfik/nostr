import 'dart:convert';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip60/nip60.dart';
import 'package:dart_nostr/nostr/nips/nip61/nip61.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

const String _mint1 = 'https://mint1';
const String _mint2 = 'https://mint2';
const String _eventId1 =
    '1111111111111111111111111111111111111111111111111111111111111111';
const String _eventId2 =
    '2222222222222222222222222222222222222222222222222222222222222222';

NostrCashuProof _proof(int amount, String id) {
  return NostrCashuProof(
    id: 'keyset-$id',
    amount: amount,
    secret: 'secret-$id',
    C: '02${id.padLeft(64, '0')}',
  );
}

/// Builds a NUT-11 P2PK secret locked to [key].
String _p2pkSecret(String key, {Map<String, dynamic> extra = const {}}) {
  return jsonEncode([
    'P2PK',
    {'data': key, 'nonce': 'test-nonce', ...extra},
  ]);
}

/// A proof whose secret is P2PK-locked to [key].
NostrCashuProof _lockedProof(int amount, String id, String key) {
  return NostrCashuProof(
    id: 'keyset-$id',
    amount: amount,
    secret: _p2pkSecret(key),
    C: '02${id.padLeft(64, '0')}',
  );
}

bool _hasTag(List<List<String>>? tags, List<String> expected) {
  for (final tag in tags ?? const <List<String>>[]) {
    if (tag.length != expected.length) {
      continue;
    }

    var matches = true;
    for (var index = 0; index < tag.length; index++) {
      if (tag[index] != expected[index]) {
        matches = false;
        break;
      }
    }

    if (matches) {
      return true;
    }
  }

  return false;
}

NostrEvent _event({
  required int kind,
  required String pubkey,
  String content = '',
  List<List<String>> tags = const [],
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

class _NoSelfEncryptionSigner implements NostrEventSigner {
  _NoSelfEncryptionSigner(this.publicKey);

  @override
  final String publicKey;

  @override
  Future<NostrEvent> sign(NostrEvent event) {
    throw UnimplementedError();
  }

  @override
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey) {
    throw UnsupportedError('remote signer has no self encryption');
  }

  @override
  Future<String> nip44Decrypt(String payload, String senderPublicKey) {
    throw UnsupportedError('remote signer has no self decryption');
  }
}

class _BrokenDecryptSigner implements NostrEventSigner {
  _BrokenDecryptSigner(this.publicKey);

  @override
  final String publicKey;

  @override
  Future<NostrEvent> sign(NostrEvent event) {
    throw UnimplementedError();
  }

  @override
  Future<String> nip44Encrypt(String plaintext, String recipientPublicKey) {
    throw UnsupportedError('broken signer');
  }

  @override
  Future<String> nip44Decrypt(String payload, String senderPublicKey) {
    throw Exception('signer exploded');
  }
}

void main() {
  late NostrLocalKeySigner signer;
  late NostrNip60 nip60;
  late NostrNip61 nip61;

  setUp(() {
    signer = NostrLocalKeySigner(NostrKeyPairs.generate());
    nip60 = NostrNip60(signer: signer);
    nip61 = NostrNip61(signer: signer);
  });

  group('NIP-60', () {
    test('kind constants cover wallet, token, history and quote', () {
      expect(NostrNip60.walletKind, 17375);
      expect(NostrNip60.tokenKind, 7375);
      expect(NostrNip60.historyKind, 7376);
      expect(NostrNip60.quoteKind, 7374);
      expect(NostrNip60.deleteKind, 5);
      expect(
        NostrNip60.kinds,
        [17375, 7375, 7376, 7374],
      );
    });

    test('proof JSON roundtrips and tolerates loose fields', () {
      const proof = NostrCashuProof(
        id: '005c2502034d4f12',
        amount: 1,
        secret: 'z+zyxAVLRqN9lEjxuNPSyRJzEstbl69Jc1vtimvtkPg=',
        C: '0241d98a8197ef238a192d47edf191a9de78b657308937b4f7dd0aa53beae72c46',
        unblindedSignature: 'unblinded',
        dleq: {'e': 'e', 's': 's', 'r': 'r'},
      );

      final json = proof.toJson();
      expect(json['C'], proof.C);
      expect(json['amount'], 1);

      final parsed = NostrCashuProof.fromJson(json);
      expect(parsed.id, proof.id);
      expect(parsed.amount, 1);
      expect(parsed.secret, proof.secret);
      expect(parsed.C, proof.C);
      expect(parsed.c, proof.C);
      expect(parsed.unblindedSignature, 'unblinded');
      expect(parsed.dleq, {'e': 'e', 's': 's', 'r': 'r'});

      final loose = NostrCashuProof.fromJson({
        'amount': '7',
        'secret': 's',
        'C': 'c',
        'unknown': true,
      });
      expect(loose.id, isEmpty);
      expect(loose.amount, 7);
      expect(loose.C, 'c');
    });

    test('proof fromJson jsonEncodes an array secret', () {
      const secret = [
        'P2PK',
        {'data': '02aa', 'nonce': 'n'},
      ];
      final proof = NostrCashuProof.fromJson({
        'id': 'keyset',
        'amount': 1,
        'secret': secret,
        'C': '02aa',
      });

      expect(proof.secret, jsonEncode(secret));
      expect(jsonDecode(proof.secret), secret);
    });

    test('wallet event is encrypted, parses back and keeps tag pairs',
        () async {
      final wallet = NostrCashuWallet(
        privateKey: NostrKeyPairs.generate().private,
        mints: const [_mint1, _mint2],
      );

      final event = await nip60.createWalletEvent(wallet: wallet);

      expect(event.kind, NostrNip60.walletKind);
      expect(event.tags, isEmpty);
      expect(event.isVerified(), isTrue);
      expect(event.content, isNot(contains('privkey')));
      expect(event.content, isNot(contains(wallet.privateKey)));

      final parsed = await nip60.parseWalletEvent(event);
      expect(parsed.privateKey, wallet.privateKey);
      expect(parsed.mints, [_mint1, _mint2]);
      expect(await nip60.tryParseWalletEvent(event), isNotNull);
    });

    test('wallet parse rejects the wrong kind and missing mints', () async {
      final wallet = NostrCashuWallet(
        privateKey: NostrKeyPairs.generate().private,
        mints: const [_mint1],
      );

      expect(
        () => nip60.parseWalletEvent(
          _event(kind: 1, pubkey: signer.publicKey),
        ),
        throwsArgumentError,
      );

      // Missing mint tags in an otherwise valid encrypted payload.
      final content = await signer.nip44Encrypt(
        jsonEncode([
          ['privkey', wallet.privateKey],
        ]),
        signer.publicKey,
      );
      final malformed = await signer.sign(
        _event(
          kind: NostrNip60.walletKind,
          pubkey: signer.publicKey,
          content: content,
        ),
      );

      await expectLater(
        nip60.parseWalletEvent(malformed),
        throwsFormatException,
      );
      expect(await nip60.tryParseWalletEvent(malformed), isNull);
      expect(
        await nip60.tryParseWalletEvent(
          _event(kind: 1, pubkey: signer.publicKey),
        ),
        isNull,
      );

      expect(
        () => nip60.createWalletEvent(
          wallet: NostrCashuWallet(
            privateKey: wallet.privateKey,
            mints: const [],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('token event encrypts mint, unit, proofs and del', () async {
      final token = NostrCashuTokenEvent(
        mint: _mint1,
        proofs: [_proof(1, '1'), _proof(2, '2')],
        del: const [_eventId2],
      );

      final event = await nip60.createTokenEvent(token: token);
      expect(event.kind, NostrNip60.tokenKind);
      expect(event.tags, isEmpty);

      final raw = jsonDecode(
        await signer.nip44Decrypt(event.content!, signer.publicKey),
      ) as Map<String, dynamic>;
      expect(raw['mint'], _mint1);
      expect(raw['unit'], 'sat');
      expect(raw['proofs'] as List, hasLength(2));
      expect(raw['del'], [_eventId2]);

      final parsed = await nip60.parseTokenEvent(event);
      expect(parsed.mint, _mint1);
      expect(parsed.unit, 'sat');
      expect(parsed.proofs.map((proof) => proof.amount), [1, 2]);
      expect(parsed.del, [_eventId2]);
      expect(parsed.proofs.first.toJson()['C'], isNotEmpty);
    });

    test('token parse defaults an omitted unit to sat', () async {
      final content = await signer.nip44Encrypt(
        jsonEncode({
          'mint': _mint1,
          'proofs': [_proof(3, '3').toJson()],
        }),
        signer.publicKey,
      );
      final event = await signer.sign(
        _event(
          kind: NostrNip60.tokenKind,
          pubkey: signer.publicKey,
          content: content,
        ),
      );

      final parsed = await nip60.parseTokenEvent(event);
      expect(parsed.unit, 'sat');
      expect(parsed.del, isEmpty);
    });

    test('token event rejects proofs without a secret', () async {
      await expectLater(
        nip60.createTokenEvent(
          token: const NostrCashuTokenEvent(
            mint: _mint1,
            proofs: [
              NostrCashuProof(id: 'keyset', amount: 1, secret: '', C: '02aa'),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('history event encrypts tuples without mirroring outer e tags',
        () async {
      final entries = [
        const NostrCashuHistoryEntry(
          direction: NostrCashuHistoryEntry.outgoing,
          amount: 4,
          eventId: _eventId1,
          kind: NostrCashuHistoryEntry.destroyed,
        ),
        const NostrCashuHistoryEntry(
          direction: NostrCashuHistoryEntry.outgoing,
          amount: 4,
          eventId: _eventId2,
          kind: NostrCashuHistoryEntry.created,
        ),
      ];

      final event = await nip60.createHistoryEvent(entries: entries);

      expect(event.kind, NostrNip60.historyKind);
      // 60.md:106-108 restricts outer tags to redemptions; created/destroyed
      // markers live only in the encrypted content.
      expect(event.tags, isEmpty);

      // 60.md content shape is tag pairs, with one shared block per spend.
      final raw = jsonDecode(
        await signer.nip44Decrypt(event.content!, signer.publicKey),
      );
      expect(raw, [
        ['direction', 'out'],
        ['amount', '4'],
        ['unit', 'sat'],
        ['e', _eventId1, '', 'destroyed'],
        ['e', _eventId2, '', 'created'],
      ]);

      final parsed = await nip60.parseHistoryEvent(event);
      expect(parsed, hasLength(2));
      expect(parsed.first.direction, 'out');
      expect(parsed.first.amount, 4);
      expect(parsed.first.unit, 'sat');
      expect(parsed.first.eventId, _eventId1);
      expect(parsed.first.kind, 'destroyed');
      expect(parsed.last.kind, 'created');
    });

    test('history parse accepts the legacy flat tuple content', () async {
      final content = await signer.nip44Encrypt(
        jsonEncode([
          ['out', '4', 'sat', _eventId1, '', 'destroyed'],
          ['in', '1', 'usd', _eventId2, '', 'created'],
        ]),
        signer.publicKey,
      );
      final event = _event(
        kind: NostrNip60.historyKind,
        pubkey: signer.publicKey,
        content: content,
      );

      final parsed = await nip60.parseHistoryEvent(event);
      expect(parsed, hasLength(2));
      expect(parsed.first.direction, 'out');
      expect(parsed.first.amount, 4);
      expect(parsed.first.unit, 'sat');
      expect(parsed.first.eventId, _eventId1);
      expect(parsed.first.kind, 'destroyed');
      expect(parsed.last.direction, 'in');
      expect(parsed.last.unit, 'usd');
      expect(parsed.last.eventId, _eventId2);
      expect(parsed.last.kind, 'created');
    });

    test('history event rejects entries without a token event id', () async {
      await expectLater(
        nip60.createHistoryEvent(
          entries: const [
            NostrCashuHistoryEntry(
              direction: NostrCashuHistoryEntry.incoming,
              amount: 1,
              eventId: '',
              kind: NostrCashuHistoryEntry.created,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('history event accepts redeemed nutzap tags', () async {
      final redemptionTags = NostrNip61.buildRedemptionHistoryTags(
        nutzapEventId: _eventId1,
        senderPubkey: signer.publicKey,
      );

      final event = await nip60.createHistoryEvent(
        entries: [
          const NostrCashuHistoryEntry(
            direction: NostrCashuHistoryEntry.incoming,
            amount: 1,
            eventId: _eventId2,
            kind: NostrCashuHistoryEntry.created,
          ),
        ],
        extraTags: redemptionTags,
      );

      expect(
        _hasTag(event.tags, ['e', _eventId1, '', 'redeemed']),
        isTrue,
      );
      expect(_hasTag(event.tags, ['p', signer.publicKey]), isTrue);
      // Only the redemption tags are public; the created entry stays encrypted.
      expect(event.tags, hasLength(2));
      expect(
        event.tags!.any((tag) => tag.length >= 4 && tag[3] == 'created'),
        isFalse,
      );

      final parsed = await nip60.parseHistoryEvent(event);
      expect(parsed, hasLength(1));
      expect(parsed.first.eventId, _eventId2);
      expect(parsed.outerTags, event.tags);
      expect(parsed.redemptions, [_eventId1]);

      final plain = await nip60.createHistoryEvent(entries: parsed);
      expect((await nip60.parseHistoryEvent(plain)).redemptions, isEmpty);
    });

    test('delete template is kind 5 with e ids and k 7375', () {
      final template = NostrNip60.createDeleteTemplate(
        tokenEventIds: const [_eventId1, _eventId2],
      );

      expect(template.kind, 5);
      expect(_hasTag(template.tags, ['e', _eventId1]), isTrue);
      expect(_hasTag(template.tags, ['e', _eventId2]), isTrue);
      expect(_hasTag(template.tags, ['k', '7375']), isTrue);
      expect(template.tags!.any((tag) => tag.first == 'a'), isFalse);
      expect(
        () => NostrNip60.createDeleteTemplate(tokenEventIds: const []),
        throwsArgumentError,
      );
    });

    test('planSpend prefers an exact proof and reports change', () {
      final proofs = [
        _proof(1, '1'),
        _proof(2, '2'),
        _proof(4, '3'),
        _proof(8, '4'),
      ];

      // 60.md spending example: spend 4 from {1, 2, 4, 8}.
      final plan = NostrNip60.planSpend(proofs: proofs, amount: 4);
      expect(plan.insufficient, isFalse);
      expect(plan.sufficient, isTrue);
      expect(plan.spent.map((proof) => proof.amount), [4]);
      expect(plan.change.map((proof) => proof.amount), [1, 2, 8]);

      final greedy = NostrNip60.planSpend(proofs: proofs, amount: 10);
      expect(greedy.spent.map((proof) => proof.amount), [4, 8]);
      expect(greedy.change.map((proof) => proof.amount), [1, 2]);

      final zero = NostrNip60.planSpend(proofs: proofs, amount: 0);
      expect(zero.spent, isEmpty);
      expect(zero.change, hasLength(4));

      expect(
        () => NostrNip60.planSpend(proofs: proofs, amount: -1),
        throwsArgumentError,
      );
    });

    test('planSpend reports insufficient funds without losing proofs', () {
      final plan = NostrNip60.planSpend(
        proofs: [_proof(1, '1'), _proof(2, '2')],
        amount: 5,
      );

      expect(plan.insufficient, isTrue);
      expect(plan.sufficient, isFalse);
      expect(plan.spent, isEmpty);
      expect(plan.change.map((proof) => proof.amount), [1, 2]);
    });

    test('rollover keeps unspent proofs and records del', () async {
      final token = NostrCashuTokenEvent(
        mint: _mint1,
        proofs: [
          _proof(1, '1'),
          _proof(2, '2'),
          _proof(4, '3'),
          _proof(8, '4'),
        ],
      );

      final rolled = await nip60.rolloverTokenEvent(
        previousEventId: _eventId1,
        token: token,
        spentProofs: [_proof(4, '3')],
      );

      expect(rolled.kind, NostrNip60.tokenKind);
      expect(rolled.isVerified(), isTrue);

      final parsed = await nip60.parseTokenEvent(rolled);
      expect(parsed.mint, _mint1);
      expect(parsed.proofs.map((proof) => proof.amount), [1, 2, 8]);
      expect(parsed.del, [_eventId1]);

      await expectLater(
        nip60.rolloverTokenEvent(
          previousEventId: _eventId1,
          token: token,
          spentProofs: token.proofs,
        ),
        throwsArgumentError,
      );
    });

    test('quote event encrypts the quote id and keeps expiration', () async {
      final expiresAt = DateTime.utc(2024, 1, 15);
      final event = await nip60.createQuoteEvent(
        quoteId: 'quote-id',
        mintUrl: _mint1,
        expiresAt: expiresAt,
      );

      expect(event.kind, NostrNip60.quoteKind);
      expect(_hasTag(event.tags, ['mint', _mint1]), isTrue);
      expect(
        _hasTag(
          event.tags,
          ['expiration', '${expiresAt.millisecondsSinceEpoch ~/ 1000}'],
        ),
        isTrue,
      );
      expect(event.content, isNot(contains('quote-id')));

      final parsed = await nip60.parseQuoteEvent(event);
      expect(parsed.quoteId, 'quote-id');
      expect(parsed.mintUrl, _mint1);
      expect(parsed.expiresAt, expiresAt);
      expect(await nip60.tryParseQuoteEvent(event), isNotNull);
      expect(
        await nip60.tryParseQuoteEvent(
          _event(kind: 1, pubkey: signer.publicKey),
        ),
        isNull,
      );
    });

    test('signer that cannot self-encrypt fails with StateError', () async {
      final remote = _NoSelfEncryptionSigner(signer.publicKey);
      final remoteNip60 = NostrNip60(signer: remote);
      final wallet = NostrCashuWallet(
        privateKey: NostrKeyPairs.generate().private,
        mints: const [_mint1],
      );

      await expectLater(
        remoteNip60.createWalletEvent(wallet: wallet),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('NIP-44 encrypt'),
          ),
        ),
      );

      final encrypted = await nip60.createWalletEvent(wallet: wallet);
      await expectLater(
        remoteNip60.parseWalletEvent(encrypted),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('NIP-44 decrypt'),
          ),
        ),
      );
      await expectLater(
        remoteNip60.tryParseWalletEvent(encrypted),
        throwsA(isA<StateError>()),
      );
    });

    test('a throwing signer stays a StateError, not a null parse', () async {
      final broken = NostrNip60(signer: _BrokenDecryptSigner(signer.publicKey));
      final encrypted = await nip60.createTokenEvent(
        token: NostrCashuTokenEvent(
          mint: _mint1,
          proofs: [_proof(1, '1')],
        ),
      );

      await expectLater(
        broken.parseTokenEvent(encrypted),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        broken.tryParseTokenEvent(encrypted),
        throwsA(isA<StateError>()),
      );
    });

    test('malformed NIP-44 payloads parse to null instead of throwing',
        () async {
      // Well-framed but garbage bytes: passes the version/size check and is
      // rejected by the signer as an invalid MAC.
      final garbage =
          List<int>.generate(128, (index) => (index * 31 + 5) & 0xff)
            ..[0] = 0x02;
      // Version 0x03 is not a NIP-44 v2 payload.
      final wrongVersion = List<int>.generate(128, (index) => index & 0xff)
        ..[0] = 0x03;
      // Shorter than the minimum 132 base64 characters.
      final truncated = List<int>.filled(20, 0x02);

      final payloads = {
        'random base64': base64Encode(garbage),
        'wrong version byte': base64Encode(wrongVersion),
        'truncated payload': base64Encode(truncated),
        'invalid base64': '!' * 140,
      };

      for (final entry in payloads.entries) {
        final walletEvent = _event(
          kind: NostrNip60.walletKind,
          pubkey: signer.publicKey,
          content: entry.value,
        );
        final tokenEvent = _event(
          kind: NostrNip60.tokenKind,
          pubkey: signer.publicKey,
          content: entry.value,
        );
        final historyEvent = _event(
          kind: NostrNip60.historyKind,
          pubkey: signer.publicKey,
          content: entry.value,
        );
        final quoteEvent = _event(
          kind: NostrNip60.quoteKind,
          pubkey: signer.publicKey,
          content: entry.value,
          tags: [
            ['mint', _mint1],
            ['expiration', '1700000000'],
          ],
        );

        expect(
          await nip60.tryParseWalletEvent(walletEvent),
          isNull,
          reason: '${entry.key} wallet',
        );
        expect(
          await nip60.tryParseTokenEvent(tokenEvent),
          isNull,
          reason: '${entry.key} token',
        );
        expect(
          await nip60.tryParseHistoryEvent(historyEvent),
          isNull,
          reason: '${entry.key} history',
        );
        expect(
          await nip60.tryParseQuoteEvent(quoteEvent),
          isNull,
          reason: '${entry.key} quote',
        );

        // Strict parsers report bad content as FormatException.
        await expectLater(
          nip60.parseWalletEvent(walletEvent),
          throwsFormatException,
        );
        await expectLater(
          nip60.parseTokenEvent(tokenEvent),
          throwsFormatException,
        );
        await expectLater(
          nip60.parseHistoryEvent(historyEvent),
          throwsFormatException,
        );
        await expectLater(
          nip60.parseQuoteEvent(quoteEvent),
          throwsFormatException,
        );
      }
    });
  });

  group('NIP-61', () {
    final p2pkKey = '02${NostrKeyPairs.generate().public}';

    test('kind constants cover recommendations and nutzaps', () {
      expect(NostrNip61.mintRecommendationKind, 10019);
      expect(NostrNip61.nutzapKind, 9321);
      expect(NostrNip61.kinds, [10019, 9321]);
    });

    test('mint recommendation roundtrips relay, mints and P2PK key', () async {
      expect(p2pkKey, hasLength(66));
      expect(RegExp(r'^02[0-9a-f]{64}$').hasMatch(p2pkKey), isTrue);

      final event = await nip61.createMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [
          NostrMintRef(url: _mint1, units: ['sat', 'usd']),
          NostrMintRef(url: _mint2),
        ],
        p2pkPubkey: p2pkKey,
      );

      expect(event.kind, NostrNip61.mintRecommendationKind);
      expect(_hasTag(event.tags, ['relay', 'wss://relay1']), isTrue);
      expect(_hasTag(event.tags, ['mint', _mint1, 'sat', 'usd']), isTrue);
      expect(_hasTag(event.tags, ['mint', _mint2]), isTrue);
      expect(_hasTag(event.tags, ['pubkey', p2pkKey]), isTrue);
      expect(event.isVerified(), isTrue);

      final parsed = NostrNip61.parseMintRecommendation(event);
      expect(parsed.relayUrl, 'wss://relay1');
      expect(parsed.p2pkPubkey, p2pkKey);
      expect(parsed.author, signer.publicKey);
      expect(parsed.mints.map((mint) => mint.url), [_mint1, _mint2]);
      expect(parsed.mints.first.units, ['sat', 'usd']);
    });

    test('mint recommendation defaults to a 02-prefixed P2PK key', () async {
      final expectedKey = '02${signer.publicKey}';

      final event = await nip61.createMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [NostrMintRef(url: _mint1)],
      );

      expect(_hasTag(event.tags, ['pubkey', expectedKey]), isTrue);

      final parsed = NostrNip61.parseMintRecommendation(event);
      expect(parsed.p2pkPubkey, expectedKey);
      expect(parsed.p2pkPubkey, startsWith('02'));
      expect(parsed.p2pkPubkey, hasLength(66));
      expect(
        RegExp(r'^02[0-9a-f]{64}$').hasMatch(parsed.p2pkPubkey),
        isTrue,
      );
      expect(parsed.author, signer.publicKey);
    });

    test('default recommendation verifies a nutzap locked to its key',
        () async {
      final recommendationEvent = await nip61.createMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [
          NostrMintRef(url: _mint1, units: ['sat']),
        ],
      );
      final recommendation = NostrNip61.parseMintRecommendation(
        recommendationEvent,
      );

      final nutzapEvent = await nip61.createNutzap(
        recipient: signer.publicKey,
        mintUrl: _mint1,
        proofs: [_lockedProof(1, '1', recommendation.p2pkPubkey)],
        p2pkKey: recommendation.p2pkPubkey,
      );
      final nutzap = NostrNip61.parseNutzap(nutzapEvent);

      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: nutzap,
        recommendation: recommendation,
      );

      expect(verification.valid, isTrue);
      expect(verification.problems, isEmpty);
    });

    test('mint recommendation rejects non-02 or malformed P2PK keys', () async {
      final invalidKeys = [
        '03${signer.publicKey}',
        'aa${'a' * 62}',
        signer.publicKey,
        '02${'z' * 64}',
      ];

      for (final invalidKey in invalidKeys) {
        await expectLater(
          nip61.createMintRecommendation(
            relayUrl: 'wss://relay1',
            mints: const [NostrMintRef(url: _mint1)],
            p2pkPubkey: invalidKey,
          ),
          throwsArgumentError,
        );
      }
    });

    test('mint recommendation parse skips invalid mint URLs', () {
      final event = _event(
        kind: NostrNip61.mintRecommendationKind,
        pubkey: signer.publicKey,
        tags: [
          ['relay', 'wss://relay1'],
          ['mint', 'not a mint url'],
          ['mint', 'ftp://mint.example'],
          ['mint', _mint1, 'sat'],
          ['pubkey', p2pkKey],
        ],
      );

      final parsed = NostrNip61.parseMintRecommendation(event);
      expect(parsed.mints.map((mint) => mint.url), [_mint1]);
      expect(parsed.mints.single.units, ['sat']);
      expect(parsed.relayUrl, 'wss://relay1');

      expect(
        () => NostrNip61.parseMintRecommendation(
          _event(kind: 1, pubkey: signer.publicKey),
        ),
        throwsArgumentError,
      );
      expect(
        NostrNip61.tryParseMintRecommendation(
          _event(kind: 1, pubkey: signer.publicKey),
        ),
        isNull,
      );
    });

    test('nutzap roundtrips proofs, mint, recipient and event reference',
        () async {
      final recipient = NostrKeyPairs.generate().public;
      final proofs = [
        _lockedProof(1, '1', p2pkKey),
        _lockedProof(2, '2', p2pkKey),
      ];

      final event = await nip61.createNutzap(
        recipient: recipient,
        mintUrl: _mint1,
        proofs: proofs,
        comment: 'Thanks for this great idea.',
        eventId: _eventId1,
        kind: 1,
        p2pkKey: p2pkKey,
      );

      expect(event.kind, NostrNip61.nutzapKind);
      expect(event.content, 'Thanks for this great idea.');
      expect(_hasTag(event.tags, ['u', _mint1]), isTrue);
      expect(_hasTag(event.tags, ['p', recipient]), isTrue);
      expect(_hasTag(event.tags, ['e', _eventId1]), isTrue);
      expect(_hasTag(event.tags, ['k', '1']), isTrue);
      expect(_hasTag(event.tags, ['unit', 'sat']), isTrue);
      expect(
        event.tags!.where((tag) => tag.first == 'proof'),
        hasLength(2),
      );
      expect(event.isVerified(), isTrue);

      final parsed = NostrNip61.parseNutzap(event);
      expect(parsed.proofs.map((proof) => proof.amount), [1, 2]);
      expect(parsed.unit, 'sat');
      expect(parsed.mintUrl, _mint1);
      expect(parsed.recipient, recipient);
      expect(parsed.eventId, _eventId1);
      expect(parsed.kind, 1);
      expect(parsed.comment, 'Thanks for this great idea.');
    });

    test('nutzap requires a 02-prefixed P2PK key', () async {
      await expectLater(
        nip61.createNutzap(
          recipient: signer.publicKey,
          mintUrl: _mint1,
          proofs: [_lockedProof(1, '1', p2pkKey)],
          p2pkKey: p2pkKey.substring(2),
        ),
        throwsArgumentError,
      );
    });

    test('nutzap rejects proofs not locked to the advertised P2PK key',
        () async {
      final attackerKey = '02${NostrKeyPairs.generate().public}';

      expect(NostrNip61.p2pkLockForProof(_proof(1, '1')), isNull);
      expect(
        NostrNip61.p2pkLockForProof(_lockedProof(1, '1', p2pkKey)),
        p2pkKey.substring(2),
      );

      // Missing lock.
      await expectLater(
        nip61.createNutzap(
          recipient: signer.publicKey,
          mintUrl: _mint1,
          proofs: [_lockedProof(1, '1', p2pkKey), _proof(2, '2')],
          p2pkKey: p2pkKey,
        ),
        throwsArgumentError,
      );

      // Locked to a different key.
      await expectLater(
        nip61.createNutzap(
          recipient: signer.publicKey,
          mintUrl: _mint1,
          proofs: [_lockedProof(1, '1', attackerKey)],
          p2pkKey: p2pkKey,
        ),
        throwsArgumentError,
      );

      // Matching lock in x-only form normalizes and is accepted.
      final event = await nip61.createNutzap(
        recipient: signer.publicKey,
        mintUrl: _mint1,
        proofs: [_lockedProof(1, '1', p2pkKey.substring(2))],
        p2pkKey: p2pkKey,
      );
      expect(event.kind, NostrNip61.nutzapKind);
      expect(event.isVerified(), isTrue);
    });

    test('nutzap rejects malformed P2PK keys and an empty unit', () async {
      for (final invalidKey in [
        '02zz',
        '02${'z' * 64}',
        '03${signer.publicKey}',
      ]) {
        await expectLater(
          nip61.createNutzap(
            recipient: signer.publicKey,
            mintUrl: _mint1,
            proofs: [_proof(1, '1')],
            p2pkKey: invalidKey,
          ),
          throwsArgumentError,
          reason: invalidKey,
        );
      }

      await expectLater(
        nip61.createNutzap(
          recipient: signer.publicKey,
          mintUrl: _mint1,
          proofs: [_lockedProof(1, '1', p2pkKey)],
          p2pkKey: p2pkKey,
          unit: '',
        ),
        throwsArgumentError,
      );
    });

    test('nutzap parse skips malformed proofs and defaults the unit', () {
      final recipient = signer.publicKey;
      final event = _event(
        kind: NostrNip61.nutzapKind,
        pubkey: signer.publicKey,
        content: 'hi',
        tags: [
          ['proof', 'not json'],
          ['proof', jsonEncode(_proof(1, '1').toJson())],
          ['u', _mint1],
          ['p', recipient],
        ],
      );

      final parsed = NostrNip61.parseNutzap(event);
      expect(parsed.proofs, hasLength(1));
      expect(parsed.unit, 'sat');
      expect(parsed.eventId, isNull);
      expect(parsed.kind, isNull);

      expect(
        () => NostrNip61.parseNutzap(_event(kind: 1, pubkey: recipient)),
        throwsArgumentError,
      );
      expect(
        NostrNip61.tryParseNutzap(_event(kind: 1, pubkey: recipient)),
        isNull,
      );
    });

    test('structural verification accepts a matching recommendation', () async {
      final recipientSigner = NostrLocalKeySigner(NostrKeyPairs.generate());
      final recipientKey = '02${recipientSigner.publicKey}';

      final recommendationEvent = await NostrNip61(
        signer: recipientSigner,
      ).createMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [
          NostrMintRef(url: _mint1, units: ['sat']),
        ],
        p2pkPubkey: recipientKey,
      );
      final recommendation = NostrNip61.parseMintRecommendation(
        recommendationEvent,
      );

      final nutzapEvent = await nip61.createNutzap(
        recipient: recipientSigner.publicKey,
        mintUrl: _mint1,
        proofs: [_lockedProof(1, '1', recipientKey)],
        p2pkKey: recipientKey,
      );
      final nutzap = NostrNip61.parseNutzap(nutzapEvent);

      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: nutzap,
        recommendation: recommendation,
      );

      expect(verification.valid, isTrue);
      expect(verification.problems, isEmpty);
    });

    test('structural verification rejects a proof locked to an attacker key',
        () {
      final recipientKey = '02${NostrKeyPairs.generate().public}';
      final attackerKey = '02${NostrKeyPairs.generate().public}';
      final recommendation = NostrMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [NostrMintRef(url: _mint1)],
        p2pkPubkey: recipientKey,
        author: signer.publicKey,
      );

      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: NostrNutzap(
          proofs: [_lockedProof(1, '1', attackerKey)],
          mintUrl: _mint1,
          recipient: signer.publicKey,
        ),
        recommendation: recommendation,
      );

      expect(verification.valid, isFalse);
      expect(verification.problems, contains(contains('is locked to')));
      expect(
        verification.problems,
        contains(contains('not to the recommendation P2PK key')),
      );
    });

    test('structural verification normalizes x-only and compressed keys', () {
      final xOnly = NostrKeyPairs.generate().public;
      final recommendation = NostrMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [NostrMintRef(url: _mint1)],
        p2pkPubkey: '02$xOnly',
        author: signer.publicKey,
      );

      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: NostrNutzap(
          proofs: [
            // x-only secret with extra NUT-11 condition keys.
            NostrCashuProof(
              id: 'keyset-1',
              amount: 1,
              secret: _p2pkSecret(
                xOnly,
                extra: {
                  'tags': [
                    ['sigflag', 'SIG_ALL'],
                  ],
                },
              ),
              C: '02$xOnly',
            ),
            // Compressed secret matches the recommendation form directly.
            NostrCashuProof(
              id: 'keyset-2',
              amount: 2,
              secret: _p2pkSecret('02$xOnly'),
              C: '02$xOnly',
            ),
          ],
          mintUrl: _mint1,
          recipient: signer.publicKey,
        ),
        recommendation: recommendation,
      );

      expect(verification.valid, isTrue);
      expect(verification.problems, isEmpty);
    });

    test('structural verification reports missing or malformed secrets', () {
      final recipientKey = '02${NostrKeyPairs.generate().public}';
      final recommendation = NostrMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [NostrMintRef(url: _mint1)],
        p2pkPubkey: recipientKey,
        author: signer.publicKey,
      );

      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: NostrNutzap(
          proofs: const [
            // Plain cashu secret: not P2PK-locked at all.
            NostrCashuProof(id: 'a', amount: 1, secret: 'plain', C: '02aa'),
            // Empty secret.
            NostrCashuProof(id: 'b', amount: 1, secret: '', C: '02bb'),
            // Truncated JSON.
            NostrCashuProof(id: 'c', amount: 1, secret: '["P2PK",', C: '02cc'),
            // P2PK without a usable data field.
            NostrCashuProof(
              id: 'd',
              amount: 1,
              secret: '["P2PK", {"nonce": "n"}]',
              C: '02dd',
            ),
          ],
          mintUrl: _mint1,
          recipient: signer.publicKey,
        ),
        recommendation: recommendation,
      );

      expect(verification.valid, isFalse);
      expect(
        verification.problems,
        contains(contains('proof 2 is missing a P2PK secret')),
      );
      expect(
        verification.problems
            .where((problem) => problem.contains('malformed P2PK secret')),
        hasLength(3),
      );
    });

    test('structural verification skips the key check without an author', () {
      final p2pkKey = '02${NostrKeyPairs.generate().public}';

      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: NostrNutzap(
          proofs: [_lockedProof(1, '1', p2pkKey)],
          mintUrl: _mint1,
          // Identity recipient differs from the dedicated P2PK key; without a
          // known author there is nothing to compare it against (61.md).
          recipient: _eventId1,
        ),
        recommendation: NostrMintRecommendation(
          relayUrl: 'wss://relay1',
          mints: const [NostrMintRef(url: _mint1)],
          p2pkPubkey: p2pkKey,
        ),
      );

      expect(verification.valid, isTrue);
      expect(verification.problems, isEmpty);
    });

    test('structural verification reports every problem', () {
      final recommendation = NostrMintRecommendation(
        relayUrl: 'wss://relay1',
        mints: const [
          NostrMintRef(url: _mint1, units: ['usd']),
        ],
        p2pkPubkey: 'aa${'a' * 62}',
        author: _eventId2,
      );
      final nutzap = NostrNutzap(
        proofs: [_proof(1, '1')],
        mintUrl: _mint2,
        recipient: 'not-hex',
      );

      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: nutzap,
        recommendation: recommendation,
      );

      expect(verification.valid, isFalse);
      expect(
        verification.problems,
        contains(contains('does not match recommendation author')),
      );
      expect(verification.problems, contains(contains('is not 02-prefixed')));
      expect(verification.problems, contains(contains('is not listed')));
      expect(
        verification.problems,
        contains(contains('is not a valid p tag')),
      );

      final wrongUnit = NostrNip61.verifyNutzapStructure(
        nutzap: NostrNutzap(
          proofs: [_proof(1, '1')],
          mintUrl: _mint1,
          recipient: _eventId2,
        ),
        recommendation: NostrMintRecommendation(
          relayUrl: 'wss://relay1',
          mints: const [
            NostrMintRef(url: _mint1, units: ['usd']),
          ],
          p2pkPubkey: p2pkKey,
          author: _eventId2,
        ),
      );
      expect(wrongUnit.problems, contains(contains('unit sat is not')));
    });

    test('structural verification never accepts a malformed recommendation key',
        () {
      for (final malformedKey in ['02', '02zz', '02${'z' * 64}']) {
        final verification = NostrNip61.verifyNutzapStructure(
          nutzap: NostrNutzap(
            proofs: [_lockedProof(1, '1', p2pkKey)],
            mintUrl: _mint1,
            recipient: signer.publicKey,
          ),
          recommendation: NostrMintRecommendation(
            relayUrl: 'wss://relay1',
            mints: const [NostrMintRef(url: _mint1)],
            p2pkPubkey: malformedKey,
            author: signer.publicKey,
          ),
        );

        expect(verification.valid, isFalse, reason: malformedKey);
        expect(
          verification.problems,
          contains(contains('is not a valid 02-prefixed')),
          reason: malformedKey,
        );
      }
    });

    test('structural verification rejects a nutzap without proofs', () {
      final verification = NostrNip61.verifyNutzapStructure(
        nutzap: const NostrNutzap(
          proofs: [],
          mintUrl: _mint1,
          recipient: _eventId2,
        ),
        recommendation: NostrMintRecommendation(
          relayUrl: 'wss://relay1',
          mints: const [NostrMintRef(url: _mint1)],
          p2pkPubkey: p2pkKey,
          author: _eventId2,
        ),
      );

      expect(verification.valid, isFalse);
      expect(verification.problems, contains(contains('no proofs')));
    });

    test('redemption history tags carry redeemed marker and sender', () {
      final tags = NostrNip61.buildRedemptionHistoryTags(
        nutzapEventId: _eventId2,
        senderPubkey: _eventId1,
      );

      expect(tags, [
        ['e', _eventId2, '', 'redeemed'],
        ['p', _eventId1],
      ]);
    });
  });
}
