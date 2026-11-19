import 'dart:convert';

import 'package:dart_nostr/nostr/core/exceptions.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';
import 'package:dart_nostr/nostr/nips/nip05/nip05.dart';
import 'package:dart_nostr/nostr/nips/nip06/nip06.dart';
import 'package:dart_nostr/nostr/nips/nip11/nip11.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  late NostrLogger logger;

  setUp(() {
    logger = NostrLogger(passedDebugOptions: NostrDebugOptions.general())
      ..disableLogs();
  });

  group('NIP-05 internet identifiers', () {
    late NostrNip05 nip05;

    test('validates identifier format', () {
      nip05 = NostrNip05(logger: logger);
      expect(nip05.isValidNip05Identifier('name@example.com'), isTrue);
      expect(nip05.isValidNip05Identifier('first.last@sub.example.io'), isTrue);
      expect(nip05.isValidNip05Identifier('_name-1@example.com'), isTrue);
      expect(nip05.isValidNip05Identifier('name'), isFalse);
      expect(nip05.isValidNip05Identifier('@example.com'), isFalse);
      expect(nip05.isValidNip05Identifier('name@'), isFalse);
      expect(nip05.isValidNip05Identifier('a b@example.com'), isFalse);
    });

    test('resolves a pubkey from the well-known document', () async {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final client = http_testing.MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.com/.well-known/nostr.json?name=alice',
        );
        return http.Response(
          jsonEncode({
            'names': {'alice': pubkey, 'bob': 'bb' * 32},
          }),
          200,
        );
      });
      nip05 = NostrNip05(logger: logger, httpClient: client);

      expect(
        await nip05.pubKeyFromIdentifierNip05(
          internetIdentifier: 'alice@example.com',
        ),
        pubkey,
      );
    });

    test('returns null when the local part is absent', () async {
      final client = http_testing.MockClient(
        (_) async =>
            http.Response(jsonEncode({'names': <String, dynamic>{}}), 200),
      );
      nip05 = NostrNip05(logger: logger, httpClient: client);

      expect(
        await nip05.pubKeyFromIdentifierNip05(
          internetIdentifier: 'nobody@example.com',
        ),
        isNull,
      );
    });

    test('verifyNip05 compares the fetched pubkey', () async {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final client = http_testing.MockClient(
        (_) async => http.Response(
          jsonEncode({
            'names': {'alice': pubkey},
          }),
          200,
        ),
      );
      nip05 = NostrNip05(logger: logger, httpClient: client);

      expect(
        await nip05.verifyNip05(
          internetIdentifier: 'alice@example.com',
          pubKey: pubkey,
        ),
        isTrue,
      );
      expect(
        await nip05.verifyNip05(
          internetIdentifier: 'alice@example.com',
          pubKey: 'ff' * 32,
        ),
        isFalse,
      );
    });

    test('wraps transport failures in Nip05VerificationException', () async {
      final client = http_testing.MockClient(
        (_) async => throw http.ClientException('boom'),
      );
      nip05 = NostrNip05(logger: logger, httpClient: client);

      expect(
        () => nip05.pubKeyFromIdentifierNip05(
          internetIdentifier: 'alice@example.com',
        ),
        throwsA(isA<Nip05VerificationException>()),
      );
    });

    test('rejects a document without a names map', () async {
      final client = http_testing.MockClient(
        (_) async => http.Response(jsonEncode({'other': 1}), 200),
      );
      nip05 = NostrNip05(logger: logger, httpClient: client);

      expect(
        await nip05.pubKeyFromIdentifierNip05(
          internetIdentifier: 'alice@example.com',
        ),
        isNull,
      );
    });
  });

  group('NIP-06 mnemonic derivation', () {
    const nip06 = NostrNip06();

    // Official NIP-06 test vector.
    const mnemonic =
        'leader monkey parrot ring guide accident before fence cannon height '
        'naive bean';
    const expectedPrivateKey =
        '7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a';

    test('validates BIP-39 mnemonics', () {
      expect(nip06.isMnemonicValid(mnemonic), isTrue);
      expect(nip06.isMnemonicValid('not a mnemonic at all'), isFalse);
    });

    test('derives the official NIP-06 vector key', () {
      final privateKey = nip06.privateKeyFromMnemonic(mnemonic);

      expect(privateKey, expectedPrivateKey);
      expect(privateKey, hasLength(64));
    });

    test('derivation is deterministic', () {
      expect(
        nip06.privateKeyFromMnemonic(mnemonic),
        nip06.privateKeyFromMnemonic(mnemonic),
      );
    });
  });

  group('NIP-11 relay information', () {
    test('httpUri maps ws/wss to http/https', () {
      expect(
        NostrNip11.httpUri('ws://relay.example').toString(),
        'http://relay.example',
      );
      expect(
        NostrNip11.httpUri('wss://relay.example/path').toString(),
        'https://relay.example/path',
      );
      expect(
        () => NostrNip11.httpUri('https://relay.example'),
        throwsArgumentError,
      );
    });

    test('fetch sends the NIP-11 Accept header and parses the document',
        () async {
      final client = http_testing.MockClient((request) async {
        expect(request.headers['Accept'], 'application/nostr+json');
        expect(request.url.toString(), 'https://relay.example');
        return http.Response(
          jsonEncode({
            'name': 'Test Relay',
            'description': 'a relay',
            'pubkey': 'ab' * 32,
            'supported_nips': [1, 11, 42],
            'software': 'strfry',
            'version': '1.0.0',
            'limitation': {
              'max_message_length': 16384,
              'max_subscriptions': 20,
              'max_filters': 100,
              'max_limit': 5000,
            },
            'retention': [
              {
                'kinds': [0, 1],
                'time': 3600,
              },
            ],
          }),
          200,
        );
      });
      final nip11 = NostrNip11(logger: logger, httpClient: client);

      final info = await nip11.fetch(relayUrl: 'wss://relay.example');

      expect(info, isNotNull);
      expect(info!.name, 'Test Relay');
      expect(info.supportedNips, [1, 11, 42]);
      expect(info.supportsNip(42), isTrue);
      expect(info.supportsNip(50), isFalse);
      expect(info.limitation?.maxMessageLength, 16384);
      expect(info.retention.single.kinds, [0, 1]);
    });

    test('fetch rethrows or returns null depending on the flag', () async {
      final client = http_testing.MockClient(
        (_) async => http.Response('not json', 500),
      );
      final nip11 = NostrNip11(logger: logger, httpClient: client);

      await expectLater(
        nip11.fetch(relayUrl: 'wss://relay.example'),
        throwsA(anything),
      );
      expect(
        await nip11.fetch(
          relayUrl: 'wss://relay.example',
          throwExceptionIfExists: false,
        ),
        isNull,
      );
    });
  });
}
