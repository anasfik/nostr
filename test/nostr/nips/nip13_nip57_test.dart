import 'dart:convert';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip13/pow.dart';
import 'package:dart_nostr/nostr/nips/nip57/zaps.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

void main() {
  late NostrEventSigner signer;

  setUp(() {
    signer = NostrLocalKeySigner(NostrKeyPairs.generate());
  });

  group('NIP-13 proof of work', () {
    test('getDifficulty counts leading zero bits', () {
      expect(NostrProofOfWork.getDifficulty('f' * 64), 0);
      expect(NostrProofOfWork.getDifficulty('0' * 64), 256);
      // 0x8 = binary 1000 -> MSB set -> 0 leading zero bits
      expect(NostrProofOfWork.getDifficulty('8${'f' * 63}'), 0);
      // 0x7 = binary 0111 -> 1 leading zero bit
      expect(NostrProofOfWork.getDifficulty('7${'f' * 63}'), 1);
      // 0xB = 1011 -> 0 bits; 0x4 = 0100 -> 1 bit
      expect(NostrProofOfWork.getDifficulty('b${'f' * 63}'), 0);
      expect(NostrProofOfWork.getDifficulty('4${'f' * 63}'), 1);
      // 0x3 = 0011 -> 2 bits; 0x1 -> 3 bits; 0x0 nibble -> 4 bits
      expect(NostrProofOfWork.getDifficulty('3${'f' * 63}'), 2);
      expect(NostrProofOfWork.getDifficulty('1${'f' * 63}'), 3);
      expect(NostrProofOfWork.getDifficulty('0f${'f' * 62}'), 4);
      expect(NostrProofOfWork.getDifficulty('00f${'f' * 61}'), 8);
    });

    test('meetsTarget', () {
      expect(NostrProofOfWork.meetsTarget('0000abc', 16), isTrue);
      expect(NostrProofOfWork.meetsTarget('0001abc', 16), isFalse);
    });

    test('mineEvent produces an id meeting a small target', () async {
      final mined = await NostrProofOfWork.mineEvent(
        signer: signer,
        kind: 1,
        content: 'pow note',
        tags: [],
        targetDifficulty: 12,
        timeout: const Duration(seconds: 30),
      );

      expect(mined.isVerified(), isTrue);
      expect(
        NostrProofOfWork.meetsTarget(mined.id!, 12),
        isTrue,
        reason: 'id ${mined.id} should have >= 12 difficulty',
      );
    });
  });

  group('NIP-57 zaps', () {
    test('createZapRequest builds kind-9734 with required tags', () async {
      final req = await NostrZaps(signer: signer).createZapRequest(
        recipientPubkey: 'aa' * 32,
        amountMillisats: 21000,
        lnurl:
            'lnurl1dp68gurn8ghj7um5v93kketj9ehx2amn9uh8wetvdskkkmn0wahzqmr8335kg',
        relaysForReceipt: ['wss://relay.example'],
        targetEventId: 'bb' * 32,
        zapTargetKind: '1',
      );

      expect(req.kind, 9734);
      expect(req.isVerified(), isTrue);

      bool hasTag(String a, String b) =>
          req.tags!.any((t) => t.length >= 2 && t[0] == a && t[1] == b);

      expect(hasTag('p', 'aa' * 32), isTrue);
      expect(hasTag('e', 'bb' * 32), isTrue);
      expect(hasTag('amount', '21000'), isTrue);
      expect(req.tags!.any((t) => t[0] == 'relays'), isTrue);
    });

    test('parseZapReceipt extracts bolt11, preimage, request', () {
      final receipt = NostrEvent(
        id: 'cc' * 32,
        kind: 9735,
        content: '',
        sig: null,
        pubkey: 'dd' * 32,
        createdAt: DateTime.now(),
        tags: [
          const ['bolt11', 'lnbc210n1...'],
          const ['preimage', 'aa11'],
          [
            'description',
            jsonEncode({'pubkey': 'ee' * 32, 'kind': 9734}),
          ],
          ['p', 'ff' * 32],
        ],
      );

      final parsed = NostrZaps.parseZapReceipt(receipt);

      expect(parsed.bolt11, 'lnbc210n1...');
      expect(parsed.preimage, 'aa11');
      expect(NostrZaps.zapSenderPubkey(parsed.zapRequest), 'ee' * 32);
    });

    test('parseZapReceipt rejects non-zap kinds', () {
      final notAZap = NostrEvent(
        id: 'cc' * 32,
        kind: 1,
        content: '',
        sig: null,
        pubkey: 'dd' * 32,
        createdAt: DateTime.now(),
        tags: const [],
      );

      expect(() => NostrZaps.parseZapReceipt(notAZap), throwsArgumentError);
    });

    test('validateZapRequest enforces spec rules', () async {
      final zaps = NostrZaps(signer: signer);

      // Valid request.
      final valid = await zaps.createZapRequest(
        recipientPubkey: 'aa' * 32,
        amountMillisats: 1000,
        lnurl: 'lnurl1xyz',
        relaysForReceipt: ['wss://relay.example'],
      );
      expect(NostrZaps.validateZapRequest(valid), isEmpty);

      // Missing relays tag + two p tags.
      final broken = await signer.sign(
        NostrEvent(
          id: null,
          kind: 9734,
          content: '',
          sig: null,
          pubkey: signer.publicKey,
          createdAt: DateTime.now(),
          tags: [
            ['p', 'aa' * 32],
            ['p', 'bb' * 32],
            ['amount', '-5'],
          ],
        ),
      );

      final problems = NostrZaps.validateZapRequest(broken);
      expect(problems.any((p) => p.contains('exactly one p tag')), isTrue);
      expect(problems.any((p) => p.contains('relays tag')), isTrue);
      expect(problems.any((p) => p.contains('amount')), isTrue);
    });

    test('tampered zap request fails validation', () async {
      final zaps = NostrZaps(signer: signer);
      final valid = await zaps.createZapRequest(
        recipientPubkey: 'aa' * 32,
        amountMillisats: 1000,
        lnurl: 'lnurl1x',
        relaysForReceipt: ['wss://r.example'],
      );

      // Tamper with the content after signing.
      final tampered = NostrEvent(
        id: valid.id,
        kind: valid.kind,
        content: 'injected',
        sig: valid.sig,
        pubkey: valid.pubkey,
        createdAt: valid.createdAt,
        tags: valid.tags,
      );

      final problems = NostrZaps.validateZapRequest(tampered);
      expect(problems, isNotEmpty, reason: 'tampered request must be detected');
    });

    test('verifyReceiptMatchesRequest compares canonical serialization',
        () async {
      final zaps = NostrZaps(signer: signer);
      final req = await zaps.createZapRequest(
        recipientPubkey: 'aa' * 32,
        amountMillisats: 5000,
        lnurl: 'lnurl1x',
        relaysForReceipt: ['wss://r.example'],
      );

      final canonical = jsonEncode(req.toMap());
      expect(
        NostrZaps.verifyReceiptMatchesRequest(
          bolt11DescriptionField: canonical,
          zapRequest: req,
        ),
        isTrue,
      );
      expect(
        NostrZaps.verifyReceiptMatchesRequest(
          bolt11DescriptionField: '{\"tampered\": true}',
          zapRequest: req,
        ),
        isFalse,
      );
    });

    test('lightningAddressToLnurlPayUrl', () {
      expect(
        lightningAddressToLnurlPayUrl('satoshi@zap.example.com'),
        'https://zap.example.com/.well-known/lnurlp/satoshi',
      );

      expect(
        () => lightningAddressToLnurlPayUrl('no-at-sign'),
        throwsArgumentError,
      );
    });

    test('invoice url embeds nostr parameter', () async {
      final zaps = NostrZaps(signer: signer);
      final req = await zaps.createZapRequest(
        recipientPubkey: 'aa' * 32,
        amountMillisats: 5000,
        lnurl: 'lnurl1xyz',
      );

      final url = zaps.buildInvoiceRequestUrl(
        lnurlPayDocument: {'callback': 'https://wallet.example/callback'},
        zapRequest: req,
        amountMillisats: 5000,
      );

      expect(url.host, 'wallet.example');
      expect(url.queryParameters['amount'], '5000');
      expect(url.queryParameters['nostr'], contains('"kind":9734'));
    });
  });
}
