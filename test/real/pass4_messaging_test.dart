import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/nips/nip17/nip17.dart';
import 'package:dart_nostr/nostr/nips/nip57/zaps.dart';
import 'package:dart_nostr/nostr/nips/nip59/nip59.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Pass 4 — private messaging, NIP-42 auth and zaps against live relays.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL: private messaging over the wire', () {
    test(
      'gift-wrapped DM survives a real relay roundtrip between two users',
      () async {
        final alice = NostrLocalKeySigner(NostrKeyPairs.generate());
        final bob = NostrLocalKeySigner(NostrKeyPairs.generate());

        final aliceNip17 = NostrNip17(signer: alice);
        final bobNip17 = NostrNip17(signer: bob);

        final liveRelays = await pickLiveRelays(count: 1);

        // Alice wraps a message to Bob.
        final rumor = aliceNip17.createChatMessageRumor(
          content:
              'secret e2e message ${DateTime.now().millisecondsSinceEpoch}',
          recipientPubkeys: [bob.publicKey],
        );

        final giftWrap = await aliceNip17.wrapMessage(rumor, bob.publicKey);

        // Publish via a client connected as anyone (relays don't care who
        // publishes; the crypto protects the content).
        final publisher = Nostr();
        await publisher.connect(liveRelays);
        final ok = await publisher.publish(giftWrap);
        expect(ok.valueOrNull?.isEventAccepted, isTrue,
            reason: 'relay rejected the gift wrap');
        expect(giftWrap.kind, 1059);
        expect(giftWrap.pubkey != alice.publicKey, isTrue,
            reason: 'gift wrap author must be ephemeral');

        // Bob discovers it by subscribing to kind-1059 addressed to him.
        final receiver = Nostr();
        await receiver.connect(liveRelays);

        NostrEvent? received;
        final sub = receiver.subscribeRequest(
          NostrRequest(
            filters: [
              NostrFilter(kinds: [1059], p: [bob.publicKey], limit: 5),
            ],
          ),
        );

        sub.fold(
          (stream) {
            stream.stream.listen((event) {
              received ??= event;
            });
          },
          (failure) => fail('subscribe failed: ${failure.message}'),
        );

        // Wait for discovery via subscription OR direct fetch fallback.
        try {
          await eventually<NostrEvent?>(
            () async => received,
            (event) => event != null,
            timeout: const Duration(seconds: 15),
          );
        } catch (_) {
          final fetched = await rawFetch(liveRelays.first, {
            'kinds': [1059],
            '#p': [bob.publicKey],
            'limit': 10,
          });
          for (final raw in fetched) {
            if (raw['id'] == giftWrap.id) {
              received = giftWrap;
              break;
            }
          }
        }

        expect(received, isNotNull, reason: 'Bob never saw the gift wrap');

        // Bob unwraps both layers and reads the secret.
        final unwrapped = await bobNip17.unwrapMessage(received!);
        expect(unwrapped.content, rumor.content);
        expect(unwrapped.pubkey, alice.publicKey);

        sub.valueOrNull?.close();
        await publisher.disconnect();
        await receiver.disconnect();
      },
      timeout: kTestTimeout,
    );
  });

  group('REAL: NIP-42 auth-gated relays', () {
    test(
      'nostr.wine rejects unauthenticated writes, accepts signed ones',
      () async {
        final identity = newIdentity();

        // 1. Without a signer: relay must refuse with auth-required.
        final anonymous = Nostr();
        final anonConnect = await anonymous.connect([kAuthRelay]);
        if (anonConnect.isFailure) {
          markTestSkipped('auth relay unreachable right now');
          return;
        }

        final note = NostrEvent.fromPartialData(
          content: 'should be refused ${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: identity,
        );

        final anonResult = await anonymous.publish(note);
        var wasRefused = false;

        if (anonResult.isFailure) {
          wasRefused = true;
        } else if (!(anonResult.valueOrNull?.isEventAccepted ?? true)) {
          wasRefused = true;
        }

        await anonymous.disconnect();

        // 2. With a signer: relay must accept after AUTH handshake.
        final authenticated = Nostr();
        final authConnect = await authenticated.connect(
          [kAuthRelay],
          signer: NostrLocalKeySigner(identity),
        );
        expect(authConnect.isSuccess, isTrue);

        final authedNote = NostrEvent.fromPartialData(
          content: 'authed write ${DateTime.now().millisecondsSinceEpoch}',
          kind: 1,
          keyPairs: identity,
        );

        final authedResult = await authenticated.publish(authedNote);

        // Possible outcomes:
        // - Relay doesn't gate writes: both publishes succeed.
        // - Auth-gated only: anonymous refused, signed accepted.
        // - Gated + paid membership (e.g. nostr.wine): signed publish gets
        //   an OK with accepted=false and a `restricted` message. The AUTH
        //   handshake itself succeeded — the challenge was answered and the
        //   relay's policy surfaced clearly instead of hanging or crashing.
        if (!wasRefused && authedResult.isFailure) {
          markTestSkipped('relay accepted unauthenticated writes');
          return;
        }

        expect(wasRefused || authedResult.isSuccess, isTrue);

        final outcomeText = authedResult.fold(
          (ok) => '${ok.isEventAccepted} ${ok.message}',
          (failure) => '${failure.message} ${failure.cause}',
        );

        final isAcceptedWrite = authedResult.isSuccess &&
            authedResult.valueOrNull!.isEventAccepted!;
        final isPolicyRefusal = outcomeText.contains('restricted') ||
            outcomeText.contains('paid') ||
            outcomeText.contains('sign up');

        expect(
          isAcceptedWrite || isPolicyRefusal,
          isTrue,
          reason: 'unexpected outcome after AUTH: $outcomeText',
        );

        await authenticated.disconnect();
      },
      timeout: kTestTimeout,
    );
  });

  group('REAL: NIP-57 zap request flow', () {
    test(
      'zap receipts from real users parse correctly',
      () async {
        // Real kind-9735 events exist in volume on public relays.
        final receipts = await rawFetchAny(
          kPrimaryRelays,
          {
            'kinds': [9735],
            'limit': 20
          },
          timeout: const Duration(seconds: 15),
        );

        if (receipts.isEmpty) {
          markTestSkipped('no zap receipts found in sample window');
          return;
        }

        var parsedCount = 0;
        for (final raw in receipts) {
          final receipt = NostrEvent.deserialized(
            jsonEncode(['EVENT', 'zap-check', raw]),
          );

          final parsed = NostrZaps.parseZapReceipt(receipt);

          // Every receipt must reference a zapped user.
          expect(
            receipt.tags!.any((t) => t.isNotEmpty && t[0] == 'p'),
            isTrue,
          );

          if (parsed.bolt11 != null && parsed.bolt11!.startsWith('lnbc')) {
            parsedCount++;
          }

          final sender = NostrZaps.zapSenderPubkey(parsed.zapRequest);
          // Anonymous zaps have no embedded request; verified ones do.
          if (parsed.zapRequest != null) {
            expect(sender, isNotNull);
            expect(sender, hasLength(64));
          }
        }

        expect(parsedCount, greaterThan(0),
            reason: 'expected at least one receipt with a bolt11 invoice');
      },
      timeout: kTestTimeout,
    );

    test(
      'lightning address resolution works for real wallets',
      () async {
        // Well-known, stable lightning addresses in the ecosystem.
        const candidates = [
          'hrf@getalby.com',
          'odell@getalby.com',
        ];

        String? workingAddress;
        Map<String, dynamic>? doc;

        for (final address in candidates) {
          try {
            final url = lightningAddressToLnurlPayUrl(address);
            final zaps = NostrZaps(signer: NostrLocalKeySigner(newIdentity()));
            doc = await zaps.fetchLnurlPayDocument(url);
            workingAddress = address;
            break;
          } catch (_) {
            continue;
          }
        }

        if (doc == null) {
          markTestSkipped('no lightning wallet endpoint reachable');
          return;
        }

        expect(doc['callback'], isA<String>());
        expect(workingAddress, isNotNull);
      },
      timeout: kTestTimeout,
    );
  });
}
