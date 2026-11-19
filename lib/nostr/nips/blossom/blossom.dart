import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;

export '../nip94/nip94.dart';
export '../nip96/nip96.dart';

/// {@template blossom_client}
/// Blossom media server client (BUD-01/BUD-02): fetch blobs, check
/// availability, and upload with authorization events.
///
/// Blossom servers authorize uploads via a NIP-98-ish signed `upload` event
/// (kind 24242) carrying sha256 of the payload, expiration and verb tags.
/// {@endtemplate}
class NostrBlossomClient {
  /// {@macro blossom_client}
  NostrBlossomClient({
    required this.signer,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Signer used to produce upload authorizations.
  final NostrEventSigner signer;

  final http.Client _httpClient;

  static const int _uploadAuthKind = 24242;

  /// HEAD /<sha256> — checks whether a blob exists on [serverUrl].
  ///
  /// Returns content type and size when present, `null` otherwise.
  Future<({String? contentType, int? size})?> headBlob(
    String serverUrl,
    String sha256,
  ) async {
    final response = await _httpClient.head(_blobUri(serverUrl, sha256));

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw http.ClientException('unexpected status ${response.statusCode}');
    }

    return (
      contentType: response.headers['content-type'],
      size: int.tryParse(response.headers['content-length'] ?? ''),
    );
  }

  /// GET /<sha256> — downloads a blob from [serverUrl].
  Future<Uint8List> getBlob(String serverUrl, String sha256) async {
    final response = await _httpClient.get(_blobUri(serverUrl, sha256));

    if (response.statusCode != 200) {
      throw http.ClientException(
        'failed to fetch blob: ${response.statusCode}',
      );
    }

    return response.bodyBytes;
  }

  /// PUT /upload — uploads [bytes] to [serverUrl], producing the signed
  /// authorization event internally.
  ///
  /// Returns the blob descriptor JSON returned by the server (typically
  /// containing `url`, `sha256`, `size`, `type`).
  Future<Map<String, dynamic>> uploadBlob({
    required String serverUrl,
    required Uint8List bytes,
    required String sha256Hex,
    String contentType = 'application/octet-stream',
    Duration validFor = const Duration(hours: 1),
  }) async {
    final normalizedServer = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    final auth = await signer.sign(
      NostrEvent(
        id: null,
        kind: _uploadAuthKind,
        content: 'Upload',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: DateTime.now(),
        tags: [
          ['t', 'upload'],
          ['x', sha256Hex],
          [
            'expiration',
            '${(DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000)}',
          ],
        ],
      ),
    );

    final response = await _httpClient.put(
      Uri.parse('$normalizedServer/upload'),
      headers: {
        'authorization':
            'Nostr ${base64Encode(utf8.encode(auth.serialized()))}',
        'content-type': contentType,
      },
      body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw http.ClientException(
        'blossom upload failed (${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Lists blobs for the signer's pubkey (GET /list/<pubkey>).
  Future<List<dynamic>> listBlobs(
    String serverUrl,
    String pubkey,
  ) async {
    final response = await _httpClient
        .get(Uri.parse('${_normalize(serverUrl)}/list/$pubkey'));

    if (response.statusCode != 200) {
      throw http.ClientException(
        'failed to list blobs: ${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  Uri _blobUri(String serverUrl, String sha256) =>
      Uri.parse('${_normalize(serverUrl)}/$sha256');

  String _normalize(String serverUrl) => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;
}
