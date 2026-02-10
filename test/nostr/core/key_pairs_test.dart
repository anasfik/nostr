import 'package:dart_nostr/dart_nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NostrKeyPairs', () {
    test('generateKeyPair creates valid key pair', () {
      final keyPair = NostrKeyPairs.generate();

      expect(keyPair.private, isNotNull);
      expect(keyPair.public, isNotNull);
      expect(keyPair.private.length, 64);
      expect(keyPair.public.length, 64);
    });

    test('private and public keys are different', () {
      final keyPair = NostrKeyPairs.generate();
      expect(keyPair.private, isNot(equals(keyPair.public)));
    });

    test('same private key generates same public key', () {
      final privateKey = 'a'.padRight(64, '0'); // Valid 64 char hex string
      final keyPair1 = NostrKeyPairs(private: privateKey);
      final keyPair2 = NostrKeyPairs(private: privateKey);

      expect(keyPair1.public, equals(keyPair2.public));
    });

    test('sign and verify message works correctly', () {
      final keyPair = NostrKeyPairs.generate();
      final message =
          Nostr.instance.services.utils.sha256Hash('test message for signing');

      final signature = keyPair.sign(message);

      expect(signature, isNotNull);
      expect(signature.length, 128); // BIP340 signature is 128 hex chars

      final isVerified =
          NostrKeyPairs.verify(keyPair.public, message, signature);
      expect(isVerified, isTrue);
    });

    test('isValidPrivateKey validates correct format', () {
      final validPrivateKey = 'a' * 64; // Valid hex string, 64 chars
      expect(NostrKeyPairs.isValidPrivateKey(validPrivateKey), isTrue);
    });

    test('isValidPrivateKey rejects invalid format', () {
      expect(NostrKeyPairs.isValidPrivateKey('tooshort'), isFalse);
      expect(NostrKeyPairs.isValidPrivateKey('a' * 63), isFalse);
      expect(NostrKeyPairs.isValidPrivateKey('a' * 65), isFalse);
    });

    test('factory with invalid private key throws assertion error', () {
      expect(
        () => NostrKeyPairs(private: 'invalid'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equatable comparison works correctly', () {
      final privateKey = 'b' * 64;
      final keyPair1 = NostrKeyPairs(private: privateKey);
      final keyPair2 = NostrKeyPairs(private: privateKey);
      final keyPair3 = NostrKeyPairs.generate();

      expect(keyPair1, equals(keyPair2));
      expect(keyPair1, isNot(equals(keyPair3)));
    });
  });
}
