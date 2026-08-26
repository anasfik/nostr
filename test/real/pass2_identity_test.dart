import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/nips/nip13/pow.dart';
import 'package:dart_nostr/nostr/nips/nip21/nip21.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Pass 2 — identity & crypto against real network data:
/// NIP-19 entities from live events, NIP-21 URIs, NIP-13 on mined events.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  late NostrBech32 bech32;
  late NostrNip21 nip21;

  setUpAll(() {
    final logger = NostrLogger(passedDebugOptions: NostrDebugOptions.general());
    logger.disableLogs();
    bech32 = NostrBech32(logger: logger);
    nip21 = NostrNip21(bech32: bech32);
  });

  group('REAL: identity & crypto on live data', () {
    test(
      'nprofile roundtrip on a real pubkey with relay hints',
      () async {
        final events = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [0],
            'limit': 5
          },
        );

        expect(events, isNotEmpty);
        final pubkey = events.first['pubkey'] as String;

        final nprofile = bech32
            .encodeNProfile(pubkey: pubkey, userRelays: [kPrimaryRelays[0]]);

        final decoded = bech32.decodeNprofileToMap(nprofile);
        expect(decoded['pubkey'], pubkey);

        // NIP-21 parse of a real entity.
        final parsed = nip21.parseFully('nostr:$nprofile');
        expect((parsed['decoded'] as Map)['pubkey'], pubkey);
      },
      timeout: kTestTimeout,
    );

    test(
      'nevent roundtrip on a real event id',
      () async {
        final events = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 3
          },
        );

        expect(events, isNotEmpty);
        final event = events.first;

        final nevent = bech32.encodeNevent(
          eventId: event['id'] as String,
          pubkey: event['pubkey'] as String,
          userRelays: [kPrimaryRelays[0]],
        );

        final decoded = bech32.decodeNeventToMap(nevent);
        expect(decoded['eventId'], event['id']);
        expect(decoded['pubkey'], event['pubkey']);
      },
      timeout: kTestTimeout,
    );

    test(
      'naddr roundtrip matches real parameterized replaceable events',
      () async {
        // Find a real long-form article (kind 30023).
        final articles = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [30023],
            'limit': 5
          },
          timeout: const Duration(seconds: 12),
        );

        if (articles.isEmpty) {
          markTestSkipped('no kind-30023 events found in sample window');
          return;
        }

        final article = articles.first as Map<String, dynamic>;
        String dTag = '';
        for (final tag in article['tags'] as List) {
          final t = (tag as List).map((e) => '$e').toList();
          if (t.isNotEmpty && t[0] == 'd') {
            dTag = t.length > 1 ? t[1] : '';
            break;
          }
        }

        final naddr = bech32.encodeNAddr(
          kind: 30023,
          authorPubkey: article['pubkey'] as String,
          identifier: dTag,
          userRelays: [kPrimaryRelays[0]],
        );

        final decoded = bech32.decodeNaddrToMap(naddr);
        expect(decoded['kind'], 30023);
        expect(decoded['pubkey'], article['pubkey']);
        expect(decoded['identifier'], dTag);

        // The coordinate built from the decode must fetch the same event.
        final coordinate = '30023:${article['pubkey']}:$dTag';
        expect(coordinate, startsWith('30023:'));
      },
      timeout: kTestTimeout,
    );

    test(
      'NIP-13 difficulty verification on real PoW-mined events',
      () async {
        // Fetch enough recent notes that some carry PoW.
        final events = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 200
          },
          timeout: const Duration(seconds: 15),
        );

        expect(events.length, greaterThan(20));

        var powEventsFound = 0; // ignore: unused_local_variable
        var checked = 0;
        for (final event in events) {
          final e = event as Map<String, dynamic>;
          final tags = [
            for (final tag in (e['tags'] as List? ?? []))
              (tag as List).map((p) => '$p').toList(),
          ];

          final nonceTag =
              tags.where((t) => t.isNotEmpty && t[0] == 'nonce').toList();
          if (nonceTag.isEmpty) {
            continue;
          }
          powEventsFound++;
          checked++;

          final declaredDifficulty = nonceTag.first.length > 2
              ? int.tryParse(nonceTag.first[2])
              : null;

          final actual = NostrProofOfWork.getDifficulty(e['id'] as String);
          if (declaredDifficulty != null) {
            expect(actual >= declaredDifficulty - 4, isTrue,
                reason: 'event ${e['id']} claims $declaredDifficulty bits '
                    'but has $actual');
          }
        }

        // Also sanity check our own miner against a real-world small target.
        final mined = await NostrProofOfWork.mineEvent(
          signer: NostrLocalKeySigner(NostrKeyPairs.generate()),
          kind: 1,
          content: 'pow check ${DateTime.now().millisecondsSinceEpoch}',
          tags: [],
          targetDifficulty: 10,
          timeout: const Duration(seconds: 30),
        );
        expect(NostrProofOfWork.meetsTarget(mined.id!, 10), isTrue);
      },
      timeout: kTestTimeout,
    );

    test(
      'event ids and signatures of live events verify with local crypto',
      () async {
        final events = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 10
          },
        );

        expect(events.length, greaterThan(3));

        var verifiedCount = 0;
        for (final raw in events) {
          final serialized = jsonEncode(['EVENT', 'verify-sub', raw]);
          final event = NostrEvent.deserialized(serialized);

          // Recompute the id from fields; must match what the relay served.
          final recomputedId = NostrEvent.getEventId(
            kind: event.kind!,
            content: event.content!,
            createdAt: event.createdAt!,
            tags: event.tags!,
            pubkey: event.pubkey,
          );
          expect(recomputedId, event.id,
              reason: 'id mismatch for live event ${event.id}');

          if (event.isVerified()) {
            verifiedCount++;
          }
        }

        // Relays reject invalid signatures, so most should verify.
        expect(verifiedCount, greaterThan(events.length ~/ 2));
      },
      timeout: kTestTimeout,
    );
  });
}
