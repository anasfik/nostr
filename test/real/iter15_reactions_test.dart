import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 15 — reaction & repost semantics: what clients compute from
/// these events is "reactions grouped by target id + emoji". Verify wild
/// reactions parse into that grouping through our models, and that our
/// builders emit shapes those groups accept.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/interop: reactions & reposts', () {
    test(
      'wild reactions group cleanly by target and emoji',
      () async {
        final reactions = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [7],
            'limit': 40
          },
          timeout: const Duration(seconds: 15),
        );
        expect(reactions.length, greaterThan(5));

        // The exact computation every client's UI does:
        final counts = <String, int>{};
        var parsed = 0;

        for (final raw in reactions) {
          final event = NostrEvent.deserialized(
            jsonEncode(['EVENT', 'iter15', raw]),
          );

          String? eTag;
          for (final t in event.tags ?? const <List<String>>[]) {
            if (t.isNotEmpty && t[0] == 'e' && t.length > 1) {
              eTag = t[1];
              break;
            }
          }

          if (eTag == null) continue; // some reactions target profiles

          final emoji =
              (event.content?.isNotEmpty ?? false) ? event.content! : '+';
          final key = '$eTag:$emoji';
          counts[key] = (counts[key] ?? 0) + 1;
          parsed++;
        }

        expect(parsed, greaterThan(3));
        // ignore: avoid_print
        print('grouped ${parsed} reactions into ${counts.length} '
            '(target,emoji) buckets');
      },
      timeout: kTestTimeout,
    );

    test(
      'our reaction shape is accepted into real reaction streams',
      () async {
        // Fetch a real recent note to react to.
        final notes = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [1],
            'limit': 3
          },
        );
        if (notes.isEmpty) return markTestSkipped('no notes found');

        final target = notes.first as Map<String, dynamic>;

        final identity = newIdentity();
        final builder =
            NostrSocialBuilder(signer: NostrLocalKeySigner(identity));
        final nostr = Nostr();

        final receipt = await publishWithFallback(
          nostr,
          await builder.createReaction(
            targetEventId: target['id'] as String,
            targetAuthorPubkey: target['pubkey'] as String,
            targetKind: '1',
          ),
          [...await pickLiveRelays(count: 2), ...kPrimaryRelays],
        );

        expect(receipt, isNotNull, reason: 'our reaction was rejected');
        expect(receipt!.isEventAccepted, isTrue);

        // Confirm it lands in the relay's reaction stream for that target.
        final stream = await eventually(
          () => rawFetchAny(kPrimaryRelays, {
            'kinds': [7],
            '#e': [target['id'] as String],
            'authors': [identity.public],
            'limit': 10,
          }),
          (events) => events.any((e) => e['id'] == receipt.eventId),
          timeout: const Duration(seconds: 20),
        );
        expect(stream, isNotEmpty);

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );
  });
}
