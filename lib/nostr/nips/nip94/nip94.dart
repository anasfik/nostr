import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip94_file_metadata}
/// NIP-94 file metadata event builder (kind 1063). Complements uploads by
/// publishing discoverable metadata about a hosted file.
/// {@endtemplate}
class NostrNip94FileMetadata {
  /// {@macro nip94_file_metadata}
  NostrNip94FileMetadata({required this.signer});

  /// Signer used to sign the metadata event.
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
