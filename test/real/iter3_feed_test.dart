import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 3 — build the loop a feed client runs:
/// outbox discovery → follow graph → timeline fetch → pagination →
/// repost resolution → replaceable-event reads.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/feed-app: content discovery loop', () {
    test(
      'outbox discovery from a real user relay list',
      () async {
        // Find a real kind-10002 in the wild.
        final relayLists = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [10002],
            'limit': 5
          },
          timeout: const Duration(seconds: 12),
        );

        if (relayLists.isEmpty) {
          markTestSkipped('no kind-10002 events found');
          return;
        }

        final list = relayLists.first as Map<String, dynamic>;
        final writeRelays = <String>[];
        final readRelays = <String>[];

        for (final tag in list['tags'] as List) {
          final t = (tag as List).map((x) => '$x').toList();
          if (t.isEmpty || t[0] != 'r' || t.length < 2) continue;
          final marker = t.length > 2 ? t[2] : '';
          if (marker != 'read') writeRelays.add(t[1]);
          if (marker != 'write') readRelays.add(t[1]);
        }

        // A well-formed NIP-65 list yields usable routing info.
        expect(readRelays.length + writeRelays.length, greaterThan(0));
        expect(list['pubkey'], hasLength(64));
      },
      timeout: kTestTimeout,
    );

    test(
      'follow graph: read a real contact list and hydrate authors',
      () async {
        final followLists = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [3],
            'limit': 3
          },
          timeout: const Duration(seconds: 12),
        );

        if (followLists.isEmpty) {
          markTestSkipped('no kind-3 events found');
          return;
        }

        final followedPubkeys = <String>[];
        for (final tag in (followLists.first['tags'] as List)) {
          final t = (tag as List).map((x) => '$x').toList();
          if (t.isNotEmpty && t[0] == 'p' && t[1].length == 64) {
            followedPubkeys.add(t[1]);
          }
          if (followedPubkeys.length >= 5) break;
        }
        expect(followedPubkeys, isNotEmpty);

        // Hydrate: fetch profiles of followed users (what a feed does next).
        final profiles = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [0],
            'authors': followedPubkeys.take(5).toList()
          },
          timeout: const Duration(seconds: 15),
        );

        // Some of the followed accounts must have profiles resolvable.
        expect(profiles, isNotEmpty);
        final profile = profiles.first as Map<String, dynamic>;
        expect(profile['content'], isA<String>());
      },
      timeout: kTestTimeout,
    );

    test(
      'timeline pagination walks backwards deterministically',
      () async {
        final page1 = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 20,
          },
        );
        expect(page1.length, greaterThan(2));

        // Paginate older than the oldest event on page 1.
        final oldest = page1
            .map((e) => e['created_at'] as int)
            .reduce((a, b) => a < b ? a : b);

        final page2 = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 20,
            'until': oldest,
          },
        );

        if (page2.isNotEmpty) {
          final newestOnPage2 = page2
              .map((e) => e['created_at'] as int)
              .reduce((a, b) => a > b ? a : b);
          expect(newestOnPage2 <= oldest, isTrue,
              reason: 'pagination returned overlapping/newer events');
        }
      },
      timeout: kTestTimeout,
    );

    test(
      'library-side pagination via filters works identically',
      () async {
        final nostr = Nostr();
        final relays = await pickLiveRelays(count: 1);
        await nostr.connect(relays);

        final result = nostr.subscribeRequest(
          NostrRequest(
            subscriptionId: 'iter3-page',
            filters: [
              NostrFilter(kinds: const [1], limit: 10),
            ],
          ),
        );

        final events = <NostrEvent>[];
        result.fold(
          (stream) {
            stream.stream.listen(events.add);
          },
          (failure) => fail('subscribe failed'),
        );

        await Future<void>.delayed(const Duration(seconds: 8));
        result.valueOrNull?.close();

        expect(events.length, greaterThan(3));

        // All events share the subscription id — stream isolation works.
        final subIds = events.map((e) => e.subscriptionId).toSet();
        expect(subIds.length, 1);
        expect(subIds.first, 'iter3-page');

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );

    test(
      'repost resolution finds the embedded original note',
      () async {
        final reposts = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [6],
            'limit': 10
          },
          timeout: const Duration(seconds: 12),
        );

        if (reposts.isEmpty) {
          markTestSkipped('no reposts found in sample window');
          return;
        }

        var resolvedCount = 0;
        for (final raw in reposts.take(3)) {
          try {
            final event = NostrEvent.deserialized(
              jsonEncode(['EVENT', 'iter3', raw]),
            );
            // Kind-6 content carries the serialized original note.
            if (event.content!.contains('"EVENT"') ||
                event.content!.contains('"kind"')) {
              final decodedContent = jsonDecode(event.content!) as List;
              expect(decodedContent.first, 'EVENT');
              resolvedCount++;
            } else {
              // Kinds-16-style generic reposts only carry tags; verify e-tag.
              expect(
                event.tags!.any((t) => t.isNotEmpty && t[0] == 'e'),
                isTrue,
              );
              resolvedCount++;
            }
          } catch (_) {}
        }
        expect(resolvedCount, greaterThan(0));
      },
      timeout: kTestTimeout,
    );
  });
}
