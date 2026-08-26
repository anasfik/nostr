import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;

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
    final response = await http.head(_blobUri(serverUrl, sha256));

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
    final response = await http.get(_blobUri(serverUrl, sha256));

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
    final response =
        await http.get(Uri.parse('${_normalize(serverUrl)}/list/$pubkey'));

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

/// {@template nip94_file_metadata}
/// NIP-94 file metadata event builder (kind 1063). Complements uploads by
/// publishing discoverable metadata about a hosted file.
/// {@endtemplate}
class NostrNip94FileMetadata {
  /// {@macro nip94_file_metadata}
  NostrNip94FileMetadata({required this.signer});

  final NostrEventSigner signer;

  /// Creates a kind-1063 file metadata event.
  Future<NostrEvent> createFileMetadata({
    required String url,
    required String mimeType,
    required int sizeBytes,
    required String sha256Hex,
    String? originalHash,
    List<String> dimensions = const [],
    String? magnetUri,
    List<String> torrentInfoHashes = const [],
    String? blurhash,
    String? title,
    String? description,
    DateTime? createdAt,
  }) async {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: 1063,
        content: description ?? '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['url', url],
          ['m', mimeType],
          ['size', '$sizeBytes'],
          ['x', sha256Hex],
          if (originalHash != null) ['ox', originalHash],
          if (dimensions.isNotEmpty) ['dim', dimensions.join('x')],
          if (magnetUri != null) ['magnet', magnetUri],
          for (final hash in torrentInfoHashes) ['i', hash],
          if (blurhash != null) ['blurhash', blurhash],
          if (title != null) ['title', title],
        ],
      ),
    );
  }
}

/// {@template nip96_uploader}
/// NIP-96 HTTP file storage uploader. Note: NIP-96 is deprecated in favor of
/// Blossom but remains deployed; this client covers the basic upload flow.
/// {@endtemplate}
class NostrNip96Uploader {
  /// {@macro nip96_uploader}
  NostrNip96Uploader({required this.signer, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final NostrEventSigner signer;

  final http.Client _httpClient;

  /// Resolves the API URL advertised in a relay/media server's NIP-96
  /// information document (`api_url` field).
  Future<String?> resolveApiUrl(String serverRootUrl) async {
    final doc = await http.get(
      Uri.parse(serverRootUrl),
      headers: {'accept': 'application/nostr+json'},
    );

    if (doc.statusCode != 200) {
      return null;
    }

    try {
      return (jsonDecode(doc.body) as Map<String, dynamic>)['api_url']
          as String?;
    } catch (_) {
      return null;
    }
  }

  /// Uploads a file via multipart form-data POST with a NIP-98-style
  /// authorization header.
  Future<String> upload({
    required String apiUrl,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    Duration validFor = const Duration(hours: 1),
  }) async {
    final auth = await signer.sign(
      NostrEvent(
        id: null,
        kind: 24242,
        content: '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: DateTime.now(),
        tags: [
          ['t', 'upload'],
          [
            'expiration',
            '${(DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000)}'
          ],
        ],
      ),
    );

    final request = http.MultipartRequest('POST', Uri.parse(apiUrl))
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      )
      ..headers['authorization'] =
          'Nostr ${base64Encode(utf8.encode(auth.serialized()))}';

    final streamed = await _httpClient.send(request);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw http.ClientException(
        'nip96 upload failed (${streamed.statusCode}): $body',
      );
    }

    try {
      return ((jsonDecode(body) as Map<String, dynamic>)['nip94_event']
          as Map<String, dynamic>)['tags'][0][1] as String;
    } catch (_) {
      // Fall back to returning the raw body when the shape differs.
      return body;
    }
  }
}
