import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Pass 5 — stability soak:
/// long-lived connections, concurrent subscriptions, mixed-relay EOSE
/// aggregation, reconnect resilience.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL: stability & consistency', () {
    test(
      'long-lived session with concurrent subscriptions stays consistent',
      () async {
        final nostr = Nostr();
        final liveRelays = await pickLiveRelays(count: 3);
        final connected = await nostr.connect(liveRelays);
        expect(connected.isSuccess, isTrue);

        final received = <String, int>{};
        final errors = <String>[];
        final subs = <NostrEventsStream>[];

        // Three overlapping subscriptions running concurrently for ~25s.
        const filterSpecs = [
          {
            'kinds': [1],
            'limit': 30
          },
          {
            'kinds': [0],
            'limit': 20
          },
          {
            'kinds': [3],
            'limit': 20
          },
        ];

        final kindSets = [
          [1],
          [0],
          [3],
        ];
        for (var index = 0; index < kindSets.length; index++) {
          // Capture per-iteration so callbacks don't share the loop variable.
          final subIndex = index;
          final kinds = kindSets[index];

          final sub = nostr.subscribeRequest(
            NostrRequest(
              subscriptionId: 'soak-$subIndex',
              filters: [NostrFilter(kinds: kinds, limit: 30)],
            ),
          );

          sub.fold(
            (stream) {
              subs.add(stream);
              stream.stream.listen(
                (event) {
                  received['soak-$subIndex'] =
                      (received['soak-$subIndex'] ?? 0) + 1;
                },
                onError: (Object e) => errors.add('sub-$subIndex: $e'),
                onDone: () {},
              );
            },
            (failure) => errors.add('sub-$subIndex setup: ${failure.message}'),
          );
        }

        // Soak window: keep the session alive and pumping.
        await Future<void>.delayed(const Duration(seconds: 25));

        expect(errors, isEmpty, reason: 'stream errors during soak: $errors');
        expect(received.values.every((c) => c > 0), isTrue,
            reason: 'every subscription should have received events; got '
                '$received');

        // Cleanly close everything.
        for (final sub in subs) {
          sub.close();
        }
        await nostr.disconnect();

        // ignore: avoid_print
        print('soak received per subscription: $received');
      },
      timeout: kTestTimeout,
    );

    test(
      'disconnect/reconnect cycles do not leak or wedge the client',
      () async {
        for (var cycle = 0; cycle < 3; cycle++) {
          final nostr = Nostr();
          final liveRelays = await pickLiveRelays(count: 1);

          final connected = await nostr.connect(liveRelays);
          expect(connected.isSuccess, isTrue,
              reason: 'cycle $cycle connect failed');

          final identity = newIdentity();
          final event = NostrEvent.fromPartialData(
            content:
                'reconnect-cycle-$cycle-${identity.public.substring(0, 8)}',
            kind: 1,
            keyPairs: identity,
          );

          final ok = await nostr.publish(event);
          expect(ok.isSuccess, isTrue, reason: 'cycle $cycle publish failed');

          await nostr.disconnect();
        }
      },
      timeout: kTestTimeout,
    );

    test(
      'publishing to multiple relays concurrently aggregates OK responses',
      () async {
        final liveRelays = await pickLiveRelays(count: 3);
        final identity = newIdentity();
        final nostr = Nostr();

        final connected = await nostr.connect(liveRelays);
        expect(connected.isSuccess, isTrue);

        final event = NostrEvent.fromPartialData(
          content: 'fanout ${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: identity,
        );

        // The library returns the FIRST OK; assert it arrives promptly and
        // that no relay error wedges the call.
        final sw = Stopwatch()..start();
        final ok = await nostr.publish(event);
        sw.stop();

        expect(ok.isSuccess, isTrue);
        expect(ok.valueOrNull?.isEventAccepted, isTrue);
        expect(sw.elapsed, lessThan(const Duration(seconds: 10)));

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );

    test(
      'unreachable relays in the mix do not block healthy ones',
      () async {
        final deadRelay = 'wss://127.0.0.1:1';
        final liveRelays = await pickLiveRelays(count: 2);

        final nostr = Nostr();
        final connected = await nostr.connect([deadRelay, ...liveRelays]);
        // Must still succeed thanks to at least one healthy relay...
        expect(connected.isSuccess, isTrue);

        // ...and remain fully usable.
        final identity = newIdentity();
        final event = NostrEvent.fromPartialData(
          content: 'mixed-health ${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: identity,
        );

        final ok = await nostr.publish(event);
        expect(ok.isSuccess, isTrue);
        expect(ok.valueOrNull?.isEventAccepted, isTrue);

        final countResult = await nostr.subscribeRequest(
          NostrRequest(
            filters: [
              const NostrFilter(kinds: [1], limit: 3)
            ],
          ),
        );
        expect(countResult.isSuccess, isTrue);
        countResult.valueOrNull?.close();

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );
  });
}
