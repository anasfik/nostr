import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

import '../../fake_relay_server.dart';

void main() {
  late FakeRelayServer relay;
  late NostrEventSigner alice;
  late NostrEventSigner bob;

  setUp(() async {
    relay = FakeRelayServer();
    await relay.start();

    alice = NostrLocalKeySigner(NostrKeyPairs.generate());
    bob = NostrLocalKeySigner(NostrKeyPairs.generate());

    Nostr.instance.nips.bindSigner(alice);
    await Nostr.instance.relays.init(relaysUrl: [relay.url]);
    await relay.nextClient();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  tearDown(() async {
    await Nostr.instance.relays.disconnectFromRelays();
    Nostr.instance.nips.bindSigner(null);
    await relay.stop();
  });

  Map<String, dynamic> eventMapOf(dynamic received) {
    final decoded = jsonDecode(received as String) as List;
    if (decoded.first == 'EVENT' && decoded.length > 2) {
      return decoded[2] as Map<String, dynamic>;
    }
    return decoded[1] as Map<String, dynamic>;
  }

  group('NIP simulation over a fake relay', () {
    test(
      'NIP-17 gift wrap publishes and unwraps on the receiving side',
      () async {
        final rumor = Nostr.instance.nips.nip17.createChatMessageRumor(
          content: 'hello over the wire',
          recipientPubkeys: [bob.publicKey],
          createdAt: DateTime.now(),
        );

        final giftWrap = await Nostr.instance.nips.nip17.wrapMessage(
          rumor,
          bob.publicKey,
        );

        final ok = await Nostr.instance.relays.sendEventToRelaysAsync(
          giftWrap,
          timeout: const Duration(seconds: 3),
        );
        expect(ok.isEventAccepted, isTrue);

        final received = await relay.waitForMessage(
          (m) => '$m'.contains('"kind":1059'),
        );
        final wireEvent = NostrEvent.fromDecodedMessage(
          ['EVENT', 'sim-sub', eventMapOf(received)],
        );

        expect(wireEvent.isVerified(), isTrue);
        expect(
          wireEvent.tags!.any(
            (t) => t.length >= 2 && t.first == 'p' && t[1] == bob.publicKey,
          ),
          isTrue,
        );

        final unwrapped =
            await NostrNip17(signer: bob).unwrapMessage(wireEvent);

        expect(unwrapped.content, 'hello over the wire');
        expect(unwrapped.pubkey, alice.publicKey);
        expect(unwrapped.id, rumor.id);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'NIP-57 zap request publishes as kind 9734 with the recipient tag',
      () async {
        final zapRequest = await Nostr.instance.nips.nip57.createZapRequest(
          recipientPubkey: bob.publicKey,
          amountMillisats: 21000,
          lnurl: 'lnurl1test',
          relaysForReceipt: [relay.url],
          targetEventId: 'bb' * 32,
          zapTargetKind: '1',
        );

        final ok = await Nostr.instance.relays.sendEventToRelaysAsync(
          zapRequest,
          timeout: const Duration(seconds: 3),
        );
        expect(ok.isEventAccepted, isTrue);

        final received = await relay.waitForMessage(
          (m) => '$m'.contains('"kind":9734'),
        );
        final wireEvent = NostrEvent.fromDecodedMessage(
          ['EVENT', 'sim-sub', eventMapOf(received)],
        );

        expect(wireEvent.isVerified(), isTrue);
        expect(wireEvent.tags, isNotNull);
        expect(
          wireEvent.tags!.any(
            (t) => t.length >= 2 && t.first == 'p' && t[1] == bob.publicKey,
          ),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'NIP-94 metadata event publishes as kind 1063',
      () async {
        final metadata = await Nostr.instance.nips.nip94.createFileMetadata(
          url: 'https://media.example/cat.png',
          mimeType: 'image/png',
          sizeBytes: 42,
          sha256Hex: 'ab' * 32,
          title: 'cat',
        );

        final ok = await Nostr.instance.relays.sendEventToRelaysAsync(
          metadata,
          timeout: const Duration(seconds: 3),
        );
        expect(ok.isEventAccepted, isTrue);

        final received = await relay.waitForMessage(
          (m) => '$m'.contains('"kind":1063'),
        );
        final wireEvent = NostrEvent.fromDecodedMessage(
          ['EVENT', 'sim-sub', eventMapOf(received)],
        );

        expect(wireEvent.isVerified(), isTrue);
        expect(
          wireEvent.tags!.any(
            (t) =>
                t.length >= 2 &&
                t.first == 'url' &&
                t[1] == 'https://media.example/cat.png',
          ),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}
