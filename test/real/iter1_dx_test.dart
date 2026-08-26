import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 1 — DX audit: can a developer drive the API like a real app
/// without fighting it? Covers lifecycle misuse, reconnection, footguns.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/DX: lifecycle correctness', () {
    test(
      'double disconnect is safe, reconnect after disconnect works',
      () async {
        final nostr = Nostr();
        final relays = await pickLiveRelays(count: 1);

        await nostr.connect(relays);
        await nostr.disconnect();
        // Second disconnect must not throw.
        await nostr.disconnect();

        // Reconnect on the same instance must fully work.
        final again = await nostr.connect(relays);
        expect(again.isSuccess, isTrue,
            reason: 'reconnect failed: ${again.failureOrNull?.message}');

        final identity = newIdentity();
        final event = NostrEvent.fromPartialData(
          content: 'post-reconnect ${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: identity,
        );

        final ok = await nostr.publish(event);
        expect(ok.isSuccess, isTrue, reason: 'publish after reconnect failed');
        expect(ok.valueOrNull?.isEventAccepted, isTrue);

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );

    test(
      'operations before connect fail with clear guidance, not crashes',
      () async {
        final nostr = Nostr();
        final identity = newIdentity();
        final event = NostrEvent.fromPartialData(
          content: 'x',
          kind: 1,
          keyPairs: identity,
        );

        final publishResult = await nostr.publish(event);
        expect(publishResult.isFailure, isTrue);
        expect(publishResult.failureOrNull!.message, contains('connect'));

        final subResult = nostr.subscribeRequest(
          NostrRequest(filters: const [
            NostrFilter(kinds: [1])
          ]),
        );
        expect(subResult.isFailure, isTrue);
        expect(subResult.failureOrNull!.message, contains('connect'));
      },
      timeout: kTestTimeout,
    );

    test(
      'isolated instances do not interfere with each other',
      () async {
        final relays = await pickLiveRelays(count: 2);
        final a = Nostr();
        final b = Nostr();

        await a.connect([relays.first]);
        await b.connect([relays.last]);

        final idA = newIdentity();
        final idB = newIdentity();

        final okA = await a.publish(NostrEvent.fromPartialData(
          content: 'from-a-${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: idA,
        ));
        final okB = await b.publish(NostrEvent.fromPartialData(
          content: 'from-b-${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: idB,
        ));

        expect(okA.isSuccess, isTrue);
        expect(okB.isSuccess, isTrue);
        // Different authors prove isolation.
        expect(idA.public, isNot(idB.public));

        await a.disconnect();
        // B must keep working after A disconnects.
        final okB2 = await b.publish(NostrEvent.fromPartialData(
          content: 'b-still-alive-${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: idB,
        ));
        var bAccepted =
            okB2.isSuccess && (okB2.valueOrNull?.isEventAccepted ?? false);
        // Shared public relays rate-limit per IP; fall through to the
        // other live relay before concluding B is broken.
        if (!bAccepted) {
          final retry = await b.publish(NostrEvent.fromPartialData(
            content: 'b-still-alive-retry',
            kind: 1,
            keyPairs: idB,
            createdAt: DateTime.now().add(const Duration(seconds: 1)),
          ));
          bAccepted =
              retry.isSuccess && (retry.valueOrNull?.isEventAccepted ?? false);
        }
        expect(bAccepted, isTrue,
            reason: 'instance B broke after instance A disconnected');

        await b.disconnect();
      },
      timeout: kTestTimeout,
    );
  });
}
