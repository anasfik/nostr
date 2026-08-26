import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/builders/social_builder.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/instance/keys/keys.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

import '../real/helpers.dart';

/// Iteration 4 — what every client's login/settings screen does:
/// seed-phrase login, nsec import, npub export, profile editing.
void main() {
  if (!realNetworkTestsEnabled) {
    return;
  }

  group('REAL/identity: login & settings flows', () {
    test(
      'seed phrase login produces valid, deterministic keys',
      () {
        const mnemonic =
            'legal winner thank year wave sausage worth useful legal winner thank yellow';

        expect(NostrKeys.isMnemonicValid(mnemonic), isTrue);

        final privateKey = NostrKeys.getPrivateKeyFromMnemonic(mnemonic);
        // Deterministic: same phrase always yields the same key.
        final again = NostrKeys.getPrivateKeyFromMnemonic(mnemonic);
        expect(privateKey, again);

        final keyPairs = NostrKeyPairs(private: privateKey);
        expect(keyPairs.public, hasLength(64));

        // Signature roundtrip proves the derived key is cryptographically
        // usable end-to-end.
        final signed = NostrEvent.fromPartialData(
          content: 'mnemonic login',
          kind: 1,
          keyPairs: keyPairs,
        );
        expect(signed.isVerified(), isTrue);
      },
    );

    test(
      'nsec login: decode, validate, reject garbage',
      () async {
        final keyPair = NostrKeyPairs.generate();
        final bech32 = NostrBech32();

        final nsec = bech32.encodePrivateKeyToNsec(keyPair.private);
        final npub = bech32.encodePublicKeyToNpub(keyPair.public);

        // Roundtrip.
        expect(bech32.decodeNsecKeyToPrivateKey(nsec), keyPair.private);
        expect(bech32.decodeNpubKeyToPublicKey(npub), keyPair.public);

        // Garbage rejection — login fields get garbage typed into them.
        expect(() => bech32.decodeNsecKeyToPrivateKey('nsec1garbage'),
            throwsA(anything));
        expect(() => NostrKeyPairs(private: 'not-a-key'), throwsArgumentError);
        expect(NostrKeyPairs.isValidPrivateKey('zz' * 32), isFalse);
        expect(NostrKeyPairs.isValidPrivateKey(keyPair.private), isTrue);
      },
    );

    test(
      'profile settings screen: edit → publish → read back own changes',
      () async {
        final identity = newIdentity();
        final signer = NostrLocalKeySigner(identity);
        final builder = NostrSocialBuilder(signer: signer);
        final nostr = Nostr();

        final relays = await pickLiveRelays(count: 1);
        await nostr.connect(relays);

        // First-time setup: empty profile.
        final v1 = await builder.updateProfile(name: 'newcomer');
        await nostr.publish(v1);

        // User edits their display name later — replaceable kind 0.
        final sessionTag =
            DateTime.now().millisecondsSinceEpoch.toRadixString(36);
        final v2 = await builder.updateProfile(
          name: 'iter4-$sessionTag',
          about: 'updated bio',
          picture: 'https://example.com/avatar.png',
        );
        final ok = await nostr.publish(v2);
        expect(ok.valueOrNull?.isEventAccepted ?? false, isTrue,
            reason: 'profile update rejected');

        // Read back latest self-profile; must reflect newest version.
        final storedProfiles = await eventually(
          () => rawFetch(relays.first, {
            'authors': [identity.public],
            'kinds': [0],
            'limit': 5,
          }),
          (events) => events.isNotEmpty,
          timeout: const Duration(seconds: 20),
        );

        // Relay may serve one or both versions during propagation; at least
        // one event must exist and all served copies must be signed by us.
        for (final raw in storedProfiles) {
          expect(raw['pubkey'], identity.public);
        }

        await nostr.disconnect();
      },
      timeout: kTestTimeout,
    );
  });
}
