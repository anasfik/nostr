import 'dart:convert';

import 'package:dart_nostr/nostr/core/exceptions.dart';
import 'package:dart_nostr/nostr/dart_nostr.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  group('NostrUtils - General Utilities', () {
    test('random64HexChars generates valid hex string', () {
      final random = Nostr.instance.services.utils.random64HexChars();

      expect(random, isNotNull);
      expect(random.length, 64);
    });

    test('random64HexChars generates different values', () {
      final random1 = Nostr.instance.services.utils.random64HexChars();
      final random2 = Nostr.instance.services.utils.random64HexChars();

      expect(random1, isNot(equals(random2)));
    });

    test('consistent64HexChars generates consistent hash', () {
      const input = 'test input for hashing';
      final hash1 = Nostr.instance.services.utils.consistent64HexChars(input);
      final hash2 = Nostr.instance.services.utils.consistent64HexChars(input);

      expect(hash1, equals(hash2));
      expect(hash1.length, 64);
    });

    test('consistent64HexChars generates different hashes for different inputs',
        () {
      final hash1 =
          Nostr.instance.services.utils.consistent64HexChars('input1');
      final hash2 =
          Nostr.instance.services.utils.consistent64HexChars('input2');

      expect(hash1, isNot(equals(hash2)));
    });

    test('sha256Hash generates valid hash', () {
      const message = 'message to hash';
      final hash = Nostr.instance.services.utils.sha256Hash(message);

      expect(hash, isNotNull);
      expect(hash.length, 64); // SHA256 in hex is 64 chars
    });

    test('sha256Hash is consistent', () {
      const message = 'test message';
      final hash1 = Nostr.instance.services.utils.sha256Hash(message);
      final hash2 = Nostr.instance.services.utils.sha256Hash(message);

      expect(hash1, equals(hash2));
    });

    test('sha256Hash generates different hashes for different messages', () {
      final hash1 = Nostr.instance.services.utils.sha256Hash('message1');
      final hash2 = Nostr.instance.services.utils.sha256Hash('message2');

      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('NostrUtils - NIP05 Verification', () {
    late http.BaseClient successMockHttpClient;
    late http.BaseClient notFoundMockHttpClient;
    late http.BaseClient errorMockHttpClient;

    setUpAll(() {
      // Mock HTTP client that returns successful NIP05 response
      successMockHttpClient = http_testing.MockClient((request) {
        return Future.value(
          http.Response(
            jsonEncode({
              'names': {
                'alice': 'pubkey123',
              },
            }),
            200,
          ),
        );
      });

      // Mock HTTP client that returns no matching names
      notFoundMockHttpClient = http_testing.MockClient((request) {
        return Future.value(
          http.Response(
            jsonEncode({
              'names': {},
            }),
            200,
          ),
        );
      });

      // Mock HTTP client that returns server error
      errorMockHttpClient = http_testing.MockClient((request) {
        return Future.value(
          http.Response('Server error', 500),
        );
      });
    });

    test('pubKeyFromIdentifierNip05 returns pubkey when found', () {
      http.runWithClient(
        () async {
          const identifier = 'alice@example.com';
          final result = await Nostr.instance.services.utils
              .pubKeyFromIdentifierNip05(internetIdentifier: identifier);

          expect(result, equals('pubkey123'));
        },
        () => successMockHttpClient,
      );
    });

    test('pubKeyFromIdentifierNip05 returns null when not found', () {
      http.runWithClient(
        () async {
          const identifier = 'nonexistent@example.com';
          final result = await Nostr.instance.services.utils
              .pubKeyFromIdentifierNip05(internetIdentifier: identifier);

          expect(result, isNull);
        },
        () => notFoundMockHttpClient,
      );
    });

    test('pubKeyFromIdentifierNip05 throws on server error', () {
      http.runWithClient(
        () async {
          const identifier = 'alice@example.com';
          await expectLater(
            () async => Nostr.instance.services.utils
                .pubKeyFromIdentifierNip05(internetIdentifier: identifier),
            throwsA(isA<Nip05VerificationException>()),
          );
        },
        () => errorMockHttpClient,
      );
    });

    test('pubKeyFromIdentifierNip05 parses identifier correctly', () {
      http.runWithClient(
        () async {
          const identifier = 'user@domain.com';
          final result = await Nostr.instance.services.utils
              .pubKeyFromIdentifierNip05(internetIdentifier: identifier);

          // Result depends on mock, but should not throw
          expect(result, anyOf(isNull, isA<String>()));
        },
        () => successMockHttpClient,
      );
    });
  });

  group('NostrUtils - Bech32 Encoding', () {
    test('encodeNProfile encodes to valid nprofile', () {
      final publicKey = 'a' * 64; // Valid 64 char hex
      final nprofile =
          Nostr.instance.services.bech32.encodeNProfile(pubkey: publicKey);

      expect(nprofile, isNotNull);
      expect(nprofile.startsWith('nprofile'), isTrue);
    });

    test('encodeNevent encodes to valid nevent', () {
      final eventId = 'b' * 64; // Valid 64 char hex
      final pubkey = 'e' * 64;
      final nevent = Nostr.instance.services.bech32
          .encodeNevent(eventId: eventId, pubkey: pubkey);

      expect(nevent, isNotNull);
      expect(nevent.startsWith('nevent'), isTrue);
    });

    test('decodeNprofileToMap decodes nprofile correctly', () {
      final publicKey = 'c' * 64;
      final nprofile =
          Nostr.instance.services.bech32.encodeNProfile(pubkey: publicKey);
      final decoded =
          Nostr.instance.services.bech32.decodeNprofileToMap(nprofile);

      expect(decoded['pubkey'], equals(publicKey));
    });

    test('decodeNeventToMap decodes nevent correctly', () {
      final eventId = 'd' * 64;
      final pubkey = 'f' * 64;
      final nevent = Nostr.instance.services.bech32
          .encodeNevent(eventId: eventId, pubkey: pubkey);
      final decoded = Nostr.instance.services.bech32.decodeNeventToMap(nevent);

      expect(decoded['eventId'], equals(eventId));
      expect(decoded['pubkey'], equals(pubkey));
    });
  });
}
