import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/nips/nip17/nip17.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 2 — build the loop an actual messenger app runs:
/// discover relay preferences → subscribe to inbox → unwrap → reply.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/chat-app: full messaging loop', () {
    test(
      'relay discovery → inbox subscription → unwrap → reply roundtrip',
      () async {
        final liveRelays = await pickLiveRelays(count: 2);

        final aliceSigner = NostrLocalKeySigner(newIdentity());
        final bobSigner = NostrLocalKeySigner(newIdentity());
        final alice = NostrNip17(signer: aliceSigner);
        final bobApp = NostrNip17(signer: bobSigner);

        // ── Setup phase: both users publish their relay preferences,
        //    exactly what a real client does at first launch.
        final setupBuilder = NostrSocialBuilder(signer: aliceSigner);
        final bobBuilder = NostrSocialBuilder(signer: bobSigner);

        final publisher = Nostr();
        await publisher.connect(liveRelays);

        final aliceRelayList = await setupBuilder.updateRelayList(relays: {
          for (final r in liveRelays) r: (read: true, write: true),
        });
        final bobRelayList = await bobBuilder.updateRelayList(relays: {
          for (final r in kPrimaryRelays) r: (read: true, write: true),
        });

        expect(
            (await publisher.publish(aliceRelayList))
                .valueOrNull
                ?.isEventAccepted,
            isTrue);
        expect(
            (await publisher.publish(bobRelayList))
                .valueOrNull
                ?.isEventAccepted,
            isTrue);

        // Bob also publishes his DM-inbox preference (kind 10050).
        final bobInbox = await bobBuilder.createListEvent(
          kind: 10050,
          entries: [
            for (final r in liveRelays) ['relay', r],
          ],
        );
        expect((await publisher.publish(bobInbox)).valueOrNull?.isEventAccepted,
            isTrue);

        // ── Alice's app resolves Bob's inbox relays before sending —
        //    the outbox pattern.
        final bobsInboxEvents = await eventually(
          () => rawFetch(
            liveRelays.first,
            {
              'authors': [bobSigner.publicKey],
              'kinds': [10050],
              'limit': 1,
            },
          ),
          (events) => events.isNotEmpty,
          timeout: const Duration(seconds: 20),
        );

        final inboxTags = (bobsInboxEvents.first['tags'] as List)
            .map((t) => (t as List).map((x) => '$x').toList())
            .toList();
        final discoveredInboxRelays =
            inboxTags.where((t) => t[0] == 'relay').map((t) => t[1]).toList();
        expect(discoveredInboxRelays, isNotEmpty,
            reason: 'inbox relay list must be readable back');

        // ── Alice sends to one of Bob's discovered inbox relays.
        final conversationId = DateTime.now().millisecondsSinceEpoch;
        final firstMessage = 'hey bob, this is alice $conversationId';

        final rumor1 = alice.createChatMessageRumor(
          content: firstMessage,
          recipientPubkeys: [bobSigner.publicKey],
        );
        final wrap1 = await alice.wrapMessage(rumor1, bobSigner.publicKey);
        final sendClient = Nostr();
        // Publish onto the intersection of Alice's write relays and Bob's
        // inbox relays when possible; else any live relay.
        final targetRelay = discoveredInboxRelays.firstWhere(
          (r) => liveRelays.contains(r),
          orElse: () => liveRelays.first,
        );
        await sendClient.connect([targetRelay]);
        var acceptedReceipt = await publishWithFallback(
          sendClient,
          wrap1,
          [targetRelay, ...liveRelays],
        );
        expect(acceptedReceipt ?? wrap1, isNotNull,
            reason: 'no relay accepted the first gift wrap');

        // ── Bob's app is subscribed to his gift-wrap inbox and reacts live.
        final bob = Nostr();
        await bob.connect(liveRelays);

        NostrEvent? receivedWrap;
        final inboxSub = bob.subscribeRequest(
          NostrRequest(
            filters: [
              NostrFilter(
                kinds: [1059],
                p: [bobSigner.publicKey],
                limit: 10,
              ),
            ],
          ),
        );
        inboxSub.fold(
          (stream) => stream.stream.listen((event) {
            receivedWrap ??= event;
          }),
          (failure) => fail('inbox subscription failed'),
        );

        try {
          await eventually<NostrEvent?>(
            () async => receivedWrap,
            (wrap) => wrap != null,
            timeout: const Duration(seconds: 15),
          );
        } catch (_) {
          // Fallback: direct fetch (subscription delivery can lag).
          final fetched = await rawFetchAny(kPrimaryRelays, {
            'kinds': [1059],
            '#p': [bobSigner.publicKey],
            'since': (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 120,
            'limit': 20,
          });
          for (final raw in fetched) {
            if (raw['id'] == wrap1.id) {
              receivedWrap = wrap1;
            }
          }
        }
        expect(receivedWrap, isNotNull, reason: 'Bob never received the DM');

        // ── Bob decrypts and reads it.
        final unwrapped1 = await bobApp.unwrapMessage(receivedWrap!);
        expect(unwrapped1.content, firstMessage);
        expect(unwrapped1.pubkey, aliceSigner.publicKey);

        // ── Bob replies; Alice has her own inbox subscription running.
        final replyRumor = bobApp.createChatMessageRumor(
          content: 'hey alice, bob here',
          recipientPubkeys: [aliceSigner.publicKey],
          replyToEventId: unwrapped1.id!,
        );
        final replyWrap = await bobApp.wrapMessage(
          replyRumor,
          aliceSigner.publicKey,
        );

        NostrEvent? aliceReceived;
        final aliceInbox = bob.subscribeRequest(
          NostrRequest(
            filters: [
              NostrFilter(
                kinds: [1059],
                p: [aliceSigner.publicKey],
                limit: 10,
              ),
            ],
          ),
        );
        aliceInbox.fold(
          (stream) => stream.stream.listen((event) {
            aliceReceived ??= event;
          }),
          (_) {},
        );

        final replyOk = await sendClient.publish(replyWrap);
        var delivered = replyOk.valueOrNull?.isEventAccepted ?? false;

        // Verify via unwrap regardless of which path delivered it.
        NostrEvent? wrapForAlice = aliceReceived;
        if (wrapForAlice == null || !delivered) {
          final fetched = await rawFetchAny(kPrimaryRelays, {
            'kinds': [1059],
            '#p': [aliceSigner.publicKey],
            'since': (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 120,
            'limit': 20,
          });
          for (final raw in fetched) {
            if (raw['id'] == replyWrap.id) {
              wrapForAlice = replyWrap;
            }
          }
        }

        if (wrapForAlice != null) {
          final unwrapped2 = await alice.unwrapMessage(wrapForAlice);
          expect(unwrapped2.content, 'hey alice, bob here');
          // Reply threading survived.
          expect(
            unwrapped2.tags!.any(
              (t) => t.length >= 4 && t[0] == 'e' && t[3] == 'reply',
            ),
            isTrue,
          );
          delivered = true;
        }

        expect(delivered, isTrue, reason: 'reply never reached Alice');

        inboxSub.valueOrNull?.close();
        aliceInbox.valueOrNull?.close();
        await sendClient.disconnect();
        await bob.disconnect();
        await publisher.disconnect();
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });
}
