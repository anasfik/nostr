import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/nips/blossom/blossom.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  group('NostrBlossomClient HTTP client injection', () {
    late NostrEventSigner signer;

    setUp(() {
      signer = NostrLocalKeySigner(NostrKeyPairs.generate());
    });

    test('headBlob uses the injected client', () async {
      final client = NostrBlossomClient(
        signer: signer,
        httpClient: http_testing.MockClient((request) async {
          expect(request.method, 'HEAD');
          return http.Response(
            '',
            200,
            headers: {
              'content-type': 'image/png',
              'content-length': '42',
            },
          );
        }),
      );

      final result = await client.headBlob('https://blossom.example', 'abc');

      expect(result?.contentType, 'image/png');
      expect(result?.size, 42);
    });

    test('headBlob returns null on 404', () async {
      final client = NostrBlossomClient(
        signer: signer,
        httpClient: http_testing.MockClient((request) async {
          return http.Response('', 404);
        }),
      );

      expect(await client.headBlob('https://blossom.example', 'abc'), isNull);
    });

    test('getBlob uses the injected client', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final client = NostrBlossomClient(
        signer: signer,
        httpClient: http_testing.MockClient((request) async {
          expect(request.url.path, '/abc');
          return http.Response.bytes(bytes, 200);
        }),
      );

      expect(await client.getBlob('https://blossom.example', 'abc'), bytes);
    });

    test('listBlobs uses the injected client', () async {
      final client = NostrBlossomClient(
        signer: signer,
        httpClient: http_testing.MockClient((request) async {
          expect(request.url.path, '/list/pubkey1');
          return http.Response(
            jsonEncode([
              {'sha256': 'abc'},
            ]),
            200,
          );
        }),
      );

      final blobs =
          await client.listBlobs('https://blossom.example', 'pubkey1');

      expect(blobs, [
        {'sha256': 'abc'},
      ]);
    });
  });
}
