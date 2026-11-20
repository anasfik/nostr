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
      expect(nips.nip24, same(nips.nip24));
      expect(nips.nip35, same(nips.nip35));
      expect(nips.nip36, same(nips.nip36));
      expect(nips.nip48, same(nips.nip48));
      expect(nips.nip5a, same(nips.nip5a));
      expect(nips.nip7d, same(nips.nip7d));
      expect(nips.nipc7, same(nips.nipc7));
      expect(nips.nipa3, same(nips.nipa3));
      expect(nips.nipc0, same(nips.nipc0));
      expect(nips.nip73, same(nips.nip73));
      expect(nips.nip66, same(nips.nip66));
      expect(const NostrNip24(), same(const NostrNip24()));
      expect(const NostrNip35(), same(const NostrNip35()));
      expect(const NostrNip36(), same(const NostrNip36()));
      expect(const NostrNip48(), same(const NostrNip48()));
      expect(const NostrNip5a(), same(const NostrNip5a()));
      expect(const NostrNip7d(), same(const NostrNip7d()));
      expect(const NostrNipC7(), same(const NostrNipC7()));
      expect(const NostrNipA3(), same(const NostrNipA3()));
      expect(const NostrNipC0(), same(const NostrNipC0()));
      expect(const NostrNip73(), same(const NostrNip73()));
      expect(const NostrNip66(), same(const NostrNip66()));

      final npub = nips.nip19.encodePublicKeyToNpub('a' * 64);
      expect(nips.nip19.decodeNpubKeyToPublicKey(npub), 'a' * 64);
      expect(nips.nip21.parse('nostr:$npub')['hrp'], 'npub');
      expect(nips.nip05.isValidNip05Identifier('name@example.com'), isTrue);
      expect(
        NostrNip73.tagsFor('isbn:9780765382030'),
        const [
          ['i', 'isbn:9780765382030'],
          ['k', 'isbn'],
        ],
      );
      expect(nips.nip42, same(nips.nip42));
      expect(nips.nip45, same(nips.nip45));
      expect(nips.nip43, same(nips.nip43));
      expect(const NostrNip43(), same(const NostrNip43()));

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
      expect(() => nips.nip37, throwsStateError);
      expect(() => nips.nip38, throwsStateError);
      expect(() => nips.nip52, throwsStateError);
      expect(() => nips.nip53, throwsStateError);
      expect(() => nips.nip60, throwsStateError);
      expect(() => nips.nip61, throwsStateError);
      expect(() => nips.nip62, throwsStateError);
      expect(() => nips.nip64, throwsStateError);
      expect(() => nips.nip68, throwsStateError);
      expect(() => nips.nip71, throwsStateError);
      expect(() => nips.nip85, throwsStateError);
      expect(() => nips.nip89, throwsStateError);
      expect(() => nips.nipa4, throwsStateError);
      expect(() => nips.nip69, throwsStateError);
      expect(() => nips.nip87, throwsStateError);
      expect(() => nips.nipB0, throwsStateError);
      expect(() => nips.nipCC, throwsStateError);
      expect(() => nips.nip34, throwsStateError);
      expect(() => nips.nip86, throwsStateError);
      expect(() => nips.nipa0, throwsStateError);
      expect(() => nips.nipcd, throwsStateError);
      expect(() => nips.nipf4, throwsStateError);
      expect(nips.signer, isNull);

      final first = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(first);

      expect(nips.nip17.signer, same(first));
      expect(nips.nip32, same(nips.nip32));
      expect(nips.nip32.signer, same(first));
      expect(nips.nip37, same(nips.nip37));
      expect(nips.nip37.signer, same(first));
      expect(nips.nip38, same(nips.nip38));
      expect(nips.nip38.signer, same(first));
      expect(nips.nip56, same(nips.nip56));
      expect(nips.nip56.signer, same(first));
      expect(nips.nip60, same(nips.nip60));
      expect(nips.nip60.signer, same(first));
      expect(nips.nip61, same(nips.nip61));
      expect(nips.nip61.signer, same(first));
      expect(nips.nip62, same(nips.nip62));
      expect(nips.nip62.signer, same(first));
      expect(nips.nip64, same(nips.nip64));
      expect(nips.nip64.signer, same(first));
      expect(nips.nip68, same(nips.nip68));
      expect(nips.nip68.signer, same(first));
      expect(nips.nip89, same(nips.nip89));
      expect(nips.nip89.signer, same(first));
      expect(nips.nip52, same(nips.nip52));
      expect(nips.nip52.signer, same(first));
      expect(nips.nip53, same(nips.nip53));
      expect(nips.nip53.signer, same(first));
      expect(nips.nip71, same(nips.nip71));
      expect(nips.nip71.signer, same(first));
      expect(nips.nip85, same(nips.nip85));
      expect(nips.nip85.signer, same(first));
      expect(nips.nip17, same(nips.nip17));
      expect(nips.nip57, same(nips.nip57));
      expect(nips.nip57.signer, same(first));
      expect(nips.nip94, same(nips.nip94));
      expect(nips.nip94.signer, same(first));
      expect(nips.nip96, same(nips.nip96));
      expect(nips.nip96.signer, same(first));
      expect(nips.blossom, same(nips.blossom));
      expect(nips.nipa4, same(nips.nipa4));
      expect(nips.nipa4.signer, same(first));
      expect(nips.social, same(nips.social));
      expect(nips.nip69, same(nips.nip69));
      expect(nips.nip69.signer, same(first));
      expect(nips.nip87, same(nips.nip87));
      expect(nips.nip87.signer, same(first));
      expect(nips.nipB0, same(nips.nipB0));
      expect(nips.nipB0.signer, same(first));
      expect(nips.nipCC, same(nips.nipCC));
      expect(nips.nipCC.signer, same(first));
      expect(nips.nipCC.bech32, same(nips.nip19));
      expect(nips.nip34, same(nips.nip34));
      expect(nips.nip34.signer, same(first));
      expect(nips.nip86, same(nips.nip86));
      expect(nips.nip86.signer, same(first));
      expect(nips.nipa0, same(nips.nipa0));
      expect(nips.nipa0.signer, same(first));
      expect(nips.nipcd, same(nips.nipcd));
      expect(nips.nipcd.signer, same(first));
      expect(nips.nipcd.bech32, same(nips.nip19));
      expect(nips.nipf4, same(nips.nipf4));
      expect(nips.nipf4.signer, same(first));

      final second = NostrLocalKeySigner(NostrKeyPairs.generate());
      nips.bindSigner(second);
      expect(nips.nip17.signer, same(second));
      expect(nips.nip37.signer, same(second));
      expect(nips.nip38.signer, same(second));
      expect(nips.nip52.signer, same(second));
      expect(nips.nip53.signer, same(second));
      expect(nips.nip60.signer, same(second));
      expect(nips.nip61.signer, same(second));
      expect(nips.nip64.signer, same(second));
      expect(nips.nip68.signer, same(second));
      expect(nips.nip71.signer, same(second));
      expect(nips.nip85.signer, same(second));
      expect(nips.nip89.signer, same(second));
      expect(nips.nipa4.signer, same(second));
      expect(nips.nip69.signer, same(second));
      expect(nips.nip87.signer, same(second));
      expect(nips.nipB0.signer, same(second));
      expect(nips.nipCC.signer, same(second));
      expect(nips.nip34.signer, same(second));
      expect(nips.nip86.signer, same(second));
      expect(nips.nipa0.signer, same(second));
      expect(nips.nipcd.signer, same(second));
      expect(nips.nipf4.signer, same(second));

      nips.bindSigner(null);
      expect(() => nips.blossom, throwsStateError);
      expect(() => nips.nip38, throwsStateError);
      expect(() => nips.nip52, throwsStateError);
      expect(() => nips.nip53, throwsStateError);
      expect(() => nips.nip60, throwsStateError);
      expect(() => nips.nip61, throwsStateError);
      expect(() => nips.nip62, throwsStateError);
      expect(() => nips.nip64, throwsStateError);
      expect(() => nips.nip68, throwsStateError);
      expect(() => nips.nip71, throwsStateError);
      expect(() => nips.nip85, throwsStateError);
      expect(() => nips.nip89, throwsStateError);
      expect(() => nips.nipa4, throwsStateError);
      expect(() => nips.nip69, throwsStateError);
      expect(() => nips.nip87, throwsStateError);
      expect(() => nips.nipB0, throwsStateError);
      expect(() => nips.nipCC, throwsStateError);
      expect(() => nips.nip34, throwsStateError);
      expect(() => nips.nip86, throwsStateError);
      expect(() => nips.nipa0, throwsStateError);
      expect(() => nips.nipcd, throwsStateError);
      expect(() => nips.nipf4, throwsStateError);
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
