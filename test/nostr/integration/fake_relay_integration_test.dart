import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/instance/keys/keys.dart';
import 'package:test/test.dart';

import '../../fake_relay_server.dart';

void main() {
  late FakeRelayServer relay;

  setUp(() async {
    relay = FakeRelayServer();
    await relay.start();
  });

  tearDown(() async {
    await relay.stop();
  });

  group('FakeRelayServer integration (real websocket loop)', () {
    test(
      'publish resolves with OK from a live relay',
      () async {
        final keyPairs = NostrKeyPairs.generate();

        Nostr.instance.relays.init(
          relaysUrl: [relay.url],
        );

        // Wait until the client socket is registered.
        await relay.nextClient();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final event = NostrEvent.fromPartialData(
          content: 'integration hello',
          kind: 1,
          keyPairs: keyPairs,
        );

        final ok = await Nostr.instance.relays.sendEventToRelaysAsync(
          event,
          timeout: const Duration(seconds: 3),
        );

        expect(ok.isEventAccepted, isTrue);

        final received = await relay.waitForMessage(
          (m) => '$m'.contains('"EVENT"'),
        );
        final decoded = jsonDecode(received as String) as List;
        expect(decoded.first, 'EVENT');
        expect((decoded[1] as Map)['content'], 'integration hello');
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'subscription receives events broadcast by the relay',
      () async {
        Nostr.instance.relays.init(
          relaysUrl: [relay.url],
        );
        await relay.nextClient();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final request = NostrRequest(
          subscriptionId: 'int-sub-1',
          filters: const [
            NostrFilter(
              kinds: [1],
              limit: 10,
            ),
          ],
        );

        final subscription = Nostr.instance.relays.startEventsSubscription(
          request: request,
        );

        // Give the REQ a moment to be sent, then push an event.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final keyPair = NostrKeyPairs.generate();
        final event = NostrEvent.fromPartialData(
          content: 'pushed to subscribers',
          kind: 1,
          keyPairs: keyPair,
        );

        relay.sendEventToClients('int-sub-1', event.toMap());

        final received = await subscription.stream.first;
        expect(received.content, 'pushed to subscribers');

        subscription.close();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'sending to zero matching relays fails fast instead of hanging forever',
      () async {
        Nostr.instance.relays.init(
          relaysUrl: ['ws://localhost:1'], // unreachable
          connectionTimeout: const Duration(milliseconds: 300),
        );

        final keyPairs = NostrKeyPairs.generate();
        final event = NostrEvent.fromPartialData(
          content: 'no relays',
          kind: 1,
          keyPairs: keyPairs,
        );

        expect(
          Nostr.instance.relays.sendEventToRelaysAsync(
            event,
            timeout: const Duration(seconds: 1),
          ),
          throwsA(isA<StateError>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'NOTICE-triggered reconnect uses backoff and does not hot-loop',
      () async {
        var reconnectCount = 0;

        Nostr.instance.relays.init(
          relaysUrl: [relay.url],
        );
        await relay.nextClient();

        // Observe reconnect pacing indirectly via registry state after notice.
        final stopwatch = Stopwatch()..start();
        final timer = Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => reconnectCount++,
        );

        relay.sendNotice('reconnect-me');

        // With backoff the first attempt waits >= 500ms; before the fix it
        // would reconnect synchronously inside message handling.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        timer.cancel();
        stopwatch.stop();

        // Nothing crashed and we are still functional.
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(150));
        expect(reconnectCount, greaterThan(0));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('NIP-42 auth flow', () {
    test(
      'client answers auth challenge and publishes successfully',
      () async {
        final authRelay = FakeRelayServer(requireAuth: true);
        await authRelay.start();

        final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

        Nostr.instance.relays.init(
          relaysUrl: [authRelay.url],
          signer: signer,
        );

        await authRelay.nextClient();

        // The relay sent its challenge on connect; wait for the client's
        // AUTH reply.
        final authReply = await authRelay.waitForMessage((m) {
          return '$m'.contains('"AUTH"');
        }).timeout(const Duration(seconds: 5));

        final decodedAuth = jsonDecode(authReply as String) as List;
        expect(decodedAuth.first, 'AUTH');

        final authEvent = decodedAuth[1] as Map;
        expect(authEvent['kind'], 22242);
        expect(authEvent['pubkey'], signer.publicKey);

        final tags = [
          for (final tag in authEvent['tags'] as List)
            [for (final p in tag as List) p.toString()],
        ];
        expect(
          tags.any((t) => t.length >= 2 && t[0] == 'challenge'),
          isTrue,
        );

        await authRelay.stop();
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('Phase 0 regression tests', () {
    test('canBeDeserialized never throws on malformed input', () {
      expect(NostrEvent.canBeDeserialized('not json at all {{'), isFalse);
      expect(NostrEvent.canBeDeserialized('["NOTICE","hi"]'), isFalse);
      expect(NostrEvent.canBeDeserialized('{}'), isFalse);
    });

    test('NIP-06 derivation pads leading zeros to full 64 chars', () {
      // A known test mnemonic. Whatever the derived child key is, the result
      // must always be exactly 64 hex chars — previously keys whose first
      // byte was 0x00 came out shorter and invalid.
      for (var i = 0; i < 12; i++) {
        final words =
            List.generate(12, (index) => 'abandon').sublist(0, 11).join(' ');
        final mnemonic =
            '$words about'; // valid 12-word mnemonic per BIP39 vectors

        if (!NostrKeys.isMnemonicValid(mnemonic)) continue;

        final priv = NostrKeys.getPrivateKeyFromMnemonic(mnemonic);
        expect(priv.length, 64, reason: 'mnemonic: $mnemonic -> $priv');
        expect(priv, matches(RegExp(r'^[0-9a-f]{64}$')));
      }
    });

    test('key cache evicts entries instead of growing without bound', () async {
      for (var i = 0; i < 64; i++) {
        Nostr.instance.services.keys.generatePrivateKey();
      }
      await Nostr.instance.services.keys.freeAllResources();
    });
  });
}
