import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  final logger = Nostr.instance.services.logger;

  group('NostrNips accessor', () {
    test('is exposed by Nostr.instance and NostrServices', () {
      expect(Nostr.instance.nips, isA<NostrNips>());
      expect(Nostr.instance.nips, same(Nostr.instance.services.nips));
      expect(Nostr.instance.nips, same(Nostr.instance.nips));
      // Wiring: the NIP-19 surface is the same instance as services.bech32.
      expect(Nostr.instance.nips.nip19, same(Nostr.instance.services.bech32));
    });

    test('stateless NIP accessors are cached and functional', () {
      final nips = NostrNips(logger: logger);

      expect(nips.nip19, same(nips.nip19));
      expect(nips.nip21, same(nips.nip21));
      expect(nips.nip05, same(nips.nip05));
      expect(nips.nip06, same(nips.nip06));
      expect(nips.nip11, same(nips.nip11));

      final npub = nips.nip19.encodePublicKeyToNpub('a' * 64);
      expect(nips.nip19.decodeNpubKeyToPublicKey(npub), 'a' * 64);
      expect(nips.nip21.parse('nostr:$npub')['hrp'], 'npub');
      expect(nips.nip05.isValidNip05Identifier('name@example.com'), isTrue);
      expect(nips.nip42, same(nips.nip42));
      expect(nips.nip45, same(nips.nip45));

      final countEvent =
          nips.nip45.countEventFor(const NostrFilter(kinds: [1]));
      expect(countEvent.serialized(), contains('"COUNT"'));
      expect(
        nips.nip45.parseResponse('["COUNT","sub",{"count":7}]').count,
        7,
      );
      expect(NostrNip45, isNotNull);
      expect(NostrNip42.authKind, 22242);
    });

    test('static-only NIP APIs stay on their classes', () {
      expect(NostrProofOfWork.getDifficulty('0' * 64), 256);
      expect(
        NostrNip11.httpUri('wss://relay.example').toString(),
        'https://relay.example',
      );
      expect(Nip44, isNotNull);
      expect(NostrNip49, isNotNull);
      expect(Nip59, isNotNull);
    });

    test('signer-bound accessors require and cache a signer', () {
      final nips = NostrNips(logger: logger);

      expect(() => nips.nip17, throwsStateError);
      expect(nips.signer, isNull);

      final first = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(first);

      expect(nips.nip17.signer, same(first));
      expect(nips.nip17, same(nips.nip17));
      expect(nips.nip57, same(nips.nip57));
      expect(nips.nip57.signer, same(first));
      expect(nips.nip94, same(nips.nip94));
      expect(nips.nip94.signer, same(first));
      expect(nips.nip96, same(nips.nip96));
      expect(nips.nip96.signer, same(first));
      expect(nips.blossom, same(nips.blossom));
      expect(nips.social, same(nips.social));

      final second = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(second);
      expect(nips.nip17.signer, same(second));

      nips.bindSigner(null);
      expect(() => nips.blossom, throwsStateError);
    });

    test('connect/addRelays bind the signer without a live relay', () async {
      final nostr = Nostr();
      final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

      await nostr.connect(const [], signer: signer);
      expect(nostr.nips.signer, same(signer));

      final other = NostrLocalKeySigner(NostrKeyPairs.generate());
      await nostr.addRelays(const [], signer: other);
      expect(nostr.nips.signer, same(other));

      // Documented behavior: disconnect does not clear the bound NIP signer.
      // Call nips.bindSigner(null) explicitly to revoke it.
      await nostr.disconnect();
      expect(nostr.nips.signer, same(other));

      nostr.disableLogs();
    });
  });
}
