import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/nips/nip67/nip67.dart';
import 'package:test/test.dart';

import '../../fake_relay_server.dart';

void main() {
  group('NIP-67 hint helpers', () {
    test('finish hint marks the result complete', () {
      // Spec example, 67.md:61-65
      final decoded = jsonDecode('["EOSE","sub2",["finish"]]') as List;

      final hints = NostrNip67.hintsOf(decoded);

      expect(hints, ['finish']);
      expect(NostrNip67.isComplete(hints), isTrue);
      expect(NostrNip67.needsPagination(hints), isFalse);
      expect(NostrNip67.needsAuth(hints), isFalse);
    });

    test('more hint asks the client to paginate', () {
      // Spec example, 67.md:69-74
      final decoded = jsonDecode('["EOSE","sub2b",["more"]]') as List;

      final hints = NostrNip67.hintsOf(decoded);

      expect(hints, ['more']);
      expect(NostrNip67.needsPagination(hints), isTrue);
      expect(NostrNip67.isComplete(hints), isFalse);
    });

    test('auth and finish hints can be sent together', () {
      // Spec example, 67.md:78-83
      final decoded = jsonDecode('["EOSE","sub4",["auth","finish"]]') as List;

      final hints = NostrNip67.hintsOf(decoded);

      expect(hints, ['auth', 'finish']);
      expect(NostrNip67.needsAuth(hints), isTrue);
      expect(NostrNip67.isComplete(hints), isTrue);
      expect(NostrNip67.needsPagination(hints), isFalse);
    });

    test('legacy two-element EOSE carries no hints', () {
      final decoded = jsonDecode('["EOSE","legacy-sub"]') as List;

      expect(NostrNip67.hintsOf(decoded), isEmpty);
      expect(NostrNip67.isComplete(const []), isFalse);
      expect(NostrNip67.needsPagination(const []), isFalse);
      expect(NostrNip67.needsAuth(const []), isFalse);
    });

    test('empty hint array is tolerated', () {
      final decoded = jsonDecode('["EOSE","sub",[]]') as List;

      expect(NostrNip67.hintsOf(decoded), isEmpty);
    });

    test('unknown hints are ignored without error', () {
      final decoded =
          jsonDecode('["EOSE","sub",["future-hint",42,null,"finish"]]') as List;

      final hints = NostrNip67.hintsOf(decoded);

      expect(hints, ['finish']);
      expect(NostrNip67.isComplete(hints), isTrue);
    });

    test('non-list third element is treated as absent', () {
      final decoded = jsonDecode('["EOSE","sub","finish"]') as List;

      expect(NostrNip67.hintsOf(decoded), isEmpty);
    });
  });

  group('EOSE message models', () {
    test('NostrRequestEoseCommand exposes hints and the right sub id', () {
      final decoded = jsonDecode('["EOSE","sub4",["auth","finish"]]') as List;

      final command = NostrRequestEoseCommand.fromDecodedMessage(decoded);

      expect(command.subscriptionId, 'sub4');
      expect(command.hints, ['auth', 'finish']);
    });

    test('NostrRequestEoseCommand parses legacy EOSE', () {
      final decoded = jsonDecode('["EOSE","legacy-sub"]') as List;

      final command = NostrRequestEoseCommand.fromDecodedMessage(decoded);

      expect(command.subscriptionId, 'legacy-sub');
      expect(command.hints, isEmpty);
    });

    test('NostrEOSE no longer throws or misreads the sub id on 3 elements', () {
      const message = '["EOSE","sub2",["finish"]]';

      final eose = const NostrEOSE(subscriptionId: 'placeholder')
          .fromRelayMessage(message);

      expect(eose.subscriptionId, 'sub2');
      expect(eose.hints, ['finish']);
    });
  });

  group('3-element EOSE reaches the relay callback', () {
    late FakeRelayServer relay;

    setUp(() async {
      relay = FakeRelayServer();
      await relay.start();
    });

    tearDown(() async {
      await Nostr.instance.relays.disconnectFromRelays();
      await relay.stop();
    });

    test(
      'does not throw and delivers hints through onEose',
      () async {
        await Nostr.instance.relays.init(relaysUrl: [relay.url]);
        await relay.nextClient();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final received = Completer<NostrRequestEoseCommand>();
        final subscription = Nostr.instance.relays.startEventsSubscription(
          request: NostrRequest(
            subscriptionId: 'nip67-sub',
            filters: const [
              NostrFilter(kinds: [1], limit: 10),
            ],
          ),
          onEose: (relayUrl, eose) {
            if (eose.hints.isNotEmpty && !received.isCompleted) {
              received.complete(eose);
            }
          },
        );

        // Let the subscription register its EOSE callback before pushing.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        relay.broadcast('["EOSE","nip67-sub",["more"]]');

        final eose = await received.future.timeout(const Duration(seconds: 5));

        expect(eose.subscriptionId, 'nip67-sub');
        expect(eose.hints, ['more']);
        expect(NostrNip67.needsPagination(eose.hints), isTrue);

        subscription.close();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}
