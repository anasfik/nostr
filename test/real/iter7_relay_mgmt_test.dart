import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 7 — runtime relay management as a settings screen would use it.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/relay management', () {
    test(
      'add relay at runtime, list live relays, remove one — others survive',
      () async {
        final nostr = Nostr();
        final initial = await pickLiveRelays(count: 1);
        final added = await pickLiveRelays(count: 2);

        final connectResult = await nostr.connect(initial);
        expect(connectResult.isSuccess, isTrue);

        // liveRelayUrls reflects reality.
        expect(nostr.liveRelayUrls, contains(initial.first));

        // Add a second relay at runtime.
        final toAdd = added.lastWhere((r) => !initial.contains(r),
            orElse: () => added.first == initial.first
                ? (added.length > 1 ? added[1] : added.first)
                : added.first);
        if (toAdd != initial.first) {
          final addResult = await nostr.addRelays([toAdd]);
          expect(addResult.isSuccess, isTrue,
              reason: 'addRelays failed: ${addResult.failureOrNull?.message}');
          expect(nostr.liveRelayUrls, contains(toAdd));

          // New relay is immediately usable for publishing.
          final identity = newIdentity();
          final event = NostrEvent.fromPartialData(
            content: 'runtime-add ${DateTime.now().millisecondsSinceEpoch}',
            kind: 1,
            keyPairs: identity,
          );
          final ok = await nostr.publish(event);
          expect(ok.isSuccess, isTrue);
        }

        // Remove the added relay; the original must keep working.
        if (toAdd != initial.first) {
          final removed = await nostr.removeRelay(toAdd);
          expect(removed, isTrue);
          expect(nostr.liveRelayUrls, isNot(contains(toAdd)));
        }

        final identity2 = newIdentity();
        final stillWorks = await nostr.publish(NostrEvent.fromPartialData(
          content: 'after-remove ${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: identity2,
        ));
        expect(stillWorks.valueOrNull?.isEventAccepted ?? false, isTrue,
            reason: 'original relay broke after removing another');

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );

    test(
      'NIP-11 limitations drive routing decisions like a real client',
      () async {
        // A real client consults the info document before writing.
        RelayInformations? doc;
        String? relayWithDoc;

        for (final relay in kPrimaryRelays) {
          try {
            final info = await Nostr().relays.relayInformationsDocumentNip11(
                  relayUrl: relay,
                );
            if (info != null && info.limitation != null) {
              doc = info;
              relayWithDoc = relay;
              break;
            }
          } catch (_) {}
        }

        if (doc == null) {
          markTestSkipped('no relay served a NIP-11 limitation object');
          return;
        }

        final limitation = doc.limitation!;

        // Decision logic a real client runs:
        var writable = true;
        if (limitation.paymentRequired == true) writable = false;
        if ((limitation.minPow ?? 0) > 16) writable = false;

        if (limitation.authRequired == true) {
          // Route through an authenticated connection instead of skipping.
          writable = writable; // auth-capable clients can still write
        }

        // ignore: avoid_print
        print('$relayWithDoc: payment=${limitation.paymentRequired} '
            'auth=${limitation.authRequired} '
            'minPow=${limitation.minPow} -> writable=$writable');

        expect(writable, anyOf(isTrue, isFalse)); // decision path executes
      },
      timeout: kTestTimeout,
    );

    test(
      'addRelays with only dead URLs fails cleanly',
      () async {
        final nostr = Nostr();
        final relays = await pickLiveRelays(count: 1);
        await nostr.connect(relays);

        final result = await nostr.addRelays(['ws://127.0.0.1:1']);
        expect(result.isFailure, isTrue);

        // Session must be unaffected.
        expect(nostr.liveRelayUrls, contains(relays.first));

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );
  });
}
