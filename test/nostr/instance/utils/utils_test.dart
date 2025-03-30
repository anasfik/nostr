import 'dart:convert';

import 'package:dart_nostr/nostr/core/exceptions.dart';
import 'package:dart_nostr/nostr/dart_nostr.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  late http.BaseClient successfullMockHttpClient;
  late http.BaseClient errorMockHttpClient;

  setUpAll(
    () {
      /// Mock HTTP client handler which returns a nip05-compliant response
      /// containing a mapping of the internet identifier to the public key
      successfullMockHttpClient = http_testing.MockClient(
        (request) {
          return Future.value(
            http.Response(
              jsonEncode(
                {
                  'names': {
                    'localpart': 'randompubkey',
                  },
                },
              ),
              200,
            ),
          );
        },
      );

      errorMockHttpClient = http_testing.MockClient(
        (request) {
          return Future.value(
            http.Response(
              'Server error',
              500,
            ),
          );
        },
      );
    },
  );

  group(
    'nip05',
    () {
      test(
        'returns pubkey when it is found in .well-known configuration',
        () {
          http.runWithClient(
            () async {
              const internetIdentifier = 'localpart@domain';
              const expectedPubKey = 'randompubkey';

              final result =
                  await Nostr.instance.services.utils.pubKeyFromIdentifierNip05(
                internetIdentifier: internetIdentifier,
              );

              expect(result, expectedPubKey);
            },
            () => successfullMockHttpClient,
          );
        },
      );

      test(
        'returns null when pubkey is not found in .well-known configuration',
        () {
          http.runWithClient(
            () async {
              const internetIdentifier = 'nonexistentusername@domain';

              final result =
                  await Nostr.instance.services.utils.pubKeyFromIdentifierNip05(
                internetIdentifier: internetIdentifier,
              );

              expect(
                result,
                null,
              );
            },
            () => successfullMockHttpClient,
          );
        },
      );

      test('throws [Nip05VerificationException] if any exception was thrown',
          () {
        http.runWithClient(
          () async {
            const internetIdentifier = 'localpart@domain';
            await expectLater(
              () async =>
                  Nostr.instance.services.utils.pubKeyFromIdentifierNip05(
                internetIdentifier: internetIdentifier,
              ),
              throwsA(
                isA<Nip05VerificationException>(),
              ),
            );
          },
          () => errorMockHttpClient,
        );
      });
    },
  );
}
