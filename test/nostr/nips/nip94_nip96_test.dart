import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/nips/nip94/nip94.dart';
import 'package:dart_nostr/nostr/nips/nip96/nip96.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  late NostrEventSigner signer;

  setUp(() {
    signer = NostrLocalKeySigner(NostrKeyPairs.generate());
  });

  group('NIP-94 file metadata', () {
    test('builds a signed kind-1063 event with every tag', () async {
      final builder = NostrNip94FileMetadata(signer: signer);
      final event = await builder.createFileMetadata(
        url: 'https://media.example/cat.png',
        mimeType: 'image/png',
        sizeBytes: 12345,
        sha256Hex: 'ab' * 32,
        originalHash: 'cd' * 32,
        dimensions: ['800', '600'],
        magnetUri: 'magnet:?xt=urn:btih:abc',
        torrentInfoHashes: ['hash1', 'hash2'],
        blurhash: 'LEHV6nWB2yk8',
        title: 'A cat',
        description: 'a cat picture',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(event.kind, 1063);
      expect(event.pubkey, signer.publicKey);
      expect(event.content, 'a cat picture');
      expect(event.isVerified(), isTrue);

      bool hasTag(List<String> tag) => event.tags!.any(
            (t) =>
                t.length == tag.length &&
                List.generate(tag.length, (i) => t[i] == tag[i])
                    .every((m) => m),
          );

      expect(hasTag(['url', 'https://media.example/cat.png']), isTrue);
      expect(hasTag(['m', 'image/png']), isTrue);
      expect(hasTag(['size', '12345']), isTrue);
      expect(hasTag(['x', 'ab' * 32]), isTrue);
      expect(hasTag(['ox', 'cd' * 32]), isTrue);
      expect(hasTag(['dim', '800x600']), isTrue);
      expect(hasTag(['magnet', 'magnet:?xt=urn:btih:abc']), isTrue);
      expect(hasTag(['i', 'hash1']), isTrue);
      expect(hasTag(['i', 'hash2']), isTrue);
      expect(hasTag(['blurhash', 'LEHV6nWB2yk8']), isTrue);
      expect(hasTag(['title', 'A cat']), isTrue);
    });

    test('omits optional tags when not supplied', () async {
      final builder = NostrNip94FileMetadata(signer: signer);
      final event = await builder.createFileMetadata(
        url: 'https://media.example/file.bin',
        mimeType: 'application/octet-stream',
        sizeBytes: 1,
        sha256Hex: '00' * 32,
      );

      expect(event.content, '');
      expect(event.tags!.map((t) => t.first), ['url', 'm', 'size', 'x']);
    });
  });

  group('NIP-96 uploader', () {
    test('uploads with a signed authorization header and returns the URL',
        () async {
      late http.Request captured;
      final client = http_testing.MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'nip94_event': {
              'tags': [
                ['url', 'https://cdn.example/uploaded.png'],
                ['x', 'ab' * 32],
              ],
            },
          }),
          201,
        );
      });
      final uploader = NostrNip96Uploader(signer: signer, httpClient: client);

      final url = await uploader.upload(
        apiUrl: 'https://cdn.example/upload',
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'file.png',
        contentType: 'image/png',
      );

      expect(url, 'https://cdn.example/uploaded.png');
      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://cdn.example/upload');

      final authHeader = captured.headers['authorization'];
      expect(authHeader, startsWith('Nostr '));

      final authMessage = jsonDecode(
        utf8.decode(base64Decode(authHeader!.substring('Nostr '.length))),
      ) as List;
      expect(authMessage.first, 'EVENT');
      final authEvent = authMessage[1] as Map<String, dynamic>;
      expect(authEvent['kind'], 24242);
      expect(authEvent['pubkey'], signer.publicKey);
      expect(
        (authEvent['tags'] as List).any(
          (t) =>
              t is List && t.isNotEmpty && t.first == 't' && t[1] == 'upload',
        ),
        isTrue,
      );
      expect(
        (authEvent['tags'] as List).any(
          (t) => t is List && t.isNotEmpty && t.first == 'expiration',
        ),
        isTrue,
      );
    });

    test('returns the raw body when the response shape differs', () async {
      final client = http_testing.MockClient(
        (_) async => http.Response('plain-upload-body', 200),
      );
      final uploader = NostrNip96Uploader(signer: signer, httpClient: client);

      expect(
        await uploader.upload(
          apiUrl: 'https://cdn.example/upload',
          bytes: Uint8List.fromList([1]),
          fileName: 'f.bin',
          contentType: 'application/octet-stream',
        ),
        'plain-upload-body',
      );
    });

    test('throws on non-2xx responses', () async {
      final client = http_testing.MockClient(
        (_) async => http.Response('nope', 413),
      );
      final uploader = NostrNip96Uploader(signer: signer, httpClient: client);

      expect(
        () => uploader.upload(
          apiUrl: 'https://cdn.example/upload',
          bytes: Uint8List.fromList([1]),
          fileName: 'f.bin',
          contentType: 'application/octet-stream',
        ),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
