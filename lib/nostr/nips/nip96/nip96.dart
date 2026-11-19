import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;

/// {@template nip96_uploader}
/// NIP-96 HTTP file storage uploader. Note: NIP-96 is deprecated in favor of
/// Blossom but remains deployed; this client covers the basic upload flow.
/// {@endtemplate}
class NostrNip96Uploader {
  /// {@macro nip96_uploader}
  NostrNip96Uploader({required this.signer, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Signer used to produce upload authorizations.
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
