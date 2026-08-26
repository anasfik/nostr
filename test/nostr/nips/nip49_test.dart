import 'package:dart_nostr/nostr/nips/nip49/nip49.dart';
import 'package:test/test.dart';

void main() {
  group('NostrNip49', () {
    test('decrypts the official spec vector', () {
      const encrypted =
          'ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p';

      final key = NostrNip49.decryptKey(
        ncryptsec: encrypted,
        password: 'nostr',
        expectedLogNFold: 16,
      );

      expect(
        key,
        '3501454135014541350145413501453fefb02227e449e57cf4d3a3ce05378683',
      );
    });

    test('wrong password fails', () {
      const encrypted =
          'ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p';

      // Wrong password must fail (MAC check) rather than return garbage.
      expect(
        () => NostrNip49.decryptKey(ncryptsec: encrypted, password: 'nostr1'),
        throwsArgumentError,
      );
    });

    test(
      'encrypt/decrypt roundtrip',
      timeout: const Timeout(Duration(minutes: 5)),
      () {
        const originalKey =
            '3501454135014541350145413501453fefb02227e449e57cf4d3a3ce05378683';

        final encrypted = NostrNip49.encryptKey(
          privateKeyHex: originalKey,
          password: 'correct horse battery staple',
          logNFold: 10, // low cost for tests only
        );

        expect(encrypted, startsWith('ncryptsec'));

        final decrypted = NostrNip49.decryptKey(
          ncryptsec: encrypted,
          password: 'correct horse battery staple',
        );

        expect(decrypted, originalKey);
      },
    );

    test('rejects invalid private keys', () {
      expect(
        () => NostrNip49.encryptKey(
          privateKeyHex: 'tooshort',
          password: 'x',
          logNFold: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects wrong hrp payloads', () {
      expect(
        () => NostrNip49.decryptKey(
          ncryptsec:
              'npub1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p',
          password: 'nostr',
        ),
        throwsArgumentError,
      );
    });
  });
}
