import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrKeys Service', () {
    test('derivePublicKey from private key', () {
      final privateKey = '1'.padRight(64, '0'); // Valid 64 char hex
      final publicKey =
          Nostr.instance.services.keys.derivePublicKey(privateKey: privateKey);

      expect(publicKey, isNotNull);
      expect(publicKey.length, 64);
    });

    test('generateKeyPair creates valid pair', () {
      final keyPair = Nostr.instance.services.keys.generateKeyPair();

      expect(keyPair.private, isNotNull);
      expect(keyPair.public, isNotNull);
      expect(keyPair.private.length, 64);
      expect(keyPair.public.length, 64);
    });

    test('generatePrivateKey creates valid key', () {
      final privateKey = Nostr.instance.services.keys.generatePrivateKey();

      expect(privateKey, isNotNull);
      expect(privateKey.length, 64);
    });

    test('generateKeyPairFromExistingPrivateKey creates pair', () {
      final privateKey = '2'.padRight(64, '0');
      final keyPair = Nostr.instance.services.keys
          .generateKeyPairFromExistingPrivateKey(privateKey);

      expect(keyPair.private, equals(privateKey));
      expect(keyPair.public.length, 64);
    });

    test('sign and verify message', () {
      final privateKey = '3'.padRight(64, '0');
      const message = 'test message to sign';
      final publicKey =
          Nostr.instance.services.keys.derivePublicKey(privateKey: privateKey);

      final signature = Nostr.instance.services.keys
          .sign(privateKey: privateKey, message: message);

      expect(signature, isNotNull);
      expect(signature.length, 128);

      final isVerified = Nostr.instance.services.keys.verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      );

      expect(isVerified, isTrue);
    });

    test('verify fails with wrong message', () {
      final privateKey = '4'.padRight(64, '0');
      const message = 'original message';
      const wrongMessage = 'different message';
      final publicKey =
          Nostr.instance.services.keys.derivePublicKey(privateKey: privateKey);

      final signature = Nostr.instance.services.keys
          .sign(privateKey: privateKey, message: message);

      final isVerified = Nostr.instance.services.keys.verify(
        publicKey: publicKey,
        message: wrongMessage,
        signature: signature,
      );

      expect(isVerified, isFalse);
    });

    test('isValidPrivateKey returns true for valid key', () {
      final validKey = 'f' * 64;
      expect(
        Nostr.instance.services.keys.isValidPrivateKey(validKey),
        isTrue,
      );
    });

    test('isValidPrivateKey returns false for invalid key', () {
      expect(
        Nostr.instance.services.keys.isValidPrivateKey('tooshort'),
        isFalse,
      );
      expect(
        Nostr.instance.services.keys.isValidPrivateKey('a' * 63),
        isFalse,
      );
    });

    test('key caching works', () {
      final privateKey = '6'.padRight(64, '0');
      final keyPair1 = Nostr.instance.services.keys
          .generateKeyPairFromExistingPrivateKey(privateKey);
      final keyPair2 = Nostr.instance.services.keys
          .generateKeyPairFromExistingPrivateKey(privateKey);

      expect(keyPair1.public, equals(keyPair2.public));
    });

    test('multiple key pairs are independent', () {
      final keyPair1 = Nostr.instance.services.keys.generateKeyPair();
      final keyPair2 = Nostr.instance.services.keys.generateKeyPair();

      expect(keyPair1.private, isNot(equals(keyPair2.private)));
      expect(keyPair1.public, isNot(equals(keyPair2.public)));
    });

    test('derived public key matches key pair public key', () {
      final privateKey = '7'.padRight(64, '0');
      final keyPair = Nostr.instance.services.keys
          .generateKeyPairFromExistingPrivateKey(privateKey);
      final derivedPublicKey =
          Nostr.instance.services.keys.derivePublicKey(privateKey: privateKey);

      expect(keyPair.public, equals(derivedPublicKey));
    });
  });
}
