import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nipb7_blob}
/// Blob descriptor returned by a Blossom server.
/// {@endtemplate}
class NostrBlobDescriptor {
  /// {@macro nipb7_blob}
  const NostrBlobDescriptor({
    required this.url,
    required this.sha256,
    required this.size,
    required this.type,
    required this.uploaded,
  });

  /// Parses a server JSON response.
  factory NostrBlobDescriptor.fromJson(Map<String, dynamic> json) {
    return NostrBlobDescriptor(
      url: json['url'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      uploaded: (json['uploaded'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Public URL of the blob.
  final String url;

  /// Hex SHA-256 of the blob.
  final String sha256;

  /// Size in bytes.
  final int size;

  /// MIME type.
  final String type;

  /// Upload timestamp in seconds.
  final int uploaded;

  /// JSON representation used by Blossom servers.
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'sha256': sha256,
      'size': size,
      'type': type,
      'uploaded': uploaded,
    };
  }
}

/// {@template nipb7_uri}
/// Parsed `blossom:` blob URI (BUD-03 style).
/// {@endtemplate}
class NostrBlossomUri {
  /// {@macro nipb7_uri}
  const NostrBlossomUri({
    required this.sha256,
    required this.ext,
    this.servers = const [],
    this.authors = const [],
    this.size,
  });

  /// Hex SHA-256 of the blob.
  final String sha256;

  /// File extension without the leading dot.
  final String ext;

  /// Preferred media servers (`xs` parameters).
  final List<String> servers;

  /// Expected author pubkeys (`as` parameters).
  final List<String> authors;

  /// Optional blob size in bytes (`sz` parameter).
  final int? size;
}

/// {@template nipb7}
/// NIP-B7 Blossom authorization helpers.
///
/// Covers the signed kind-24242 auth events, their `Nostr <base64>` header
/// form, `blossom:` URI parsing/building and the MIME/hash helpers servers
/// need. HTTP upload/download lives in the Blossom client; this file is
/// transport-free.
/// {@endtemplate}
class NostrNipB7 {
  /// {@macro nipb7}
  NostrNipB7({required this.signer});

  /// Signer used to create authorization events.
  final NostrEventSigner signer;

  /// Kind of a Blossom authorization event.
  static const int authKind = 24242;

  /// Authorization verbs accepted by Blossom servers.
  static const List<String> authTypes = [
    'upload',
    'list',
    'delete',
    'get',
    'media',
  ];

  static final RegExp _hex32 = RegExp(r'^[0-9a-f]{64}$');

  /// Whether [value] is a lowercase 64-char hex string.
  static bool isHex32(String value) => _hex32.hasMatch(value);

  /// SHA-256 of [bytes] as lowercase hex.
  static String computeBlobSha256(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Encodes [event] as `Nostr <base64(json)>`.
  static String encodeAuthorizationHeader(NostrEvent event) {
    final json = jsonEncode(event.toMap());
    return 'Nostr ${base64.encode(utf8.encode(json))}';
  }

  /// Values of every [tagName] tag in [auth].
  static List<String> getAuthTagValues(NostrEvent auth, String tagName) {
    return [
      for (final tag in auth.tags ?? const <List<String>>[])
        if (tag.length > 1 && tag.first == tagName) tag[1],
    ];
  }

  /// The `expiration` tag of [auth] as a UNIX timestamp, if present.
  static int? getAuthExpiration(NostrEvent auth) {
    for (final tag in auth.tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == 'expiration') {
        return num.tryParse(tag[1])?.toInt();
      }
    }
    return null;
  }

  /// Whether [auth] is expired at [timestamp] (seconds).
  static bool isAuthExpired(NostrEvent auth, {int? timestamp}) {
    final expiration = getAuthExpiration(auth);
    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiration != null && expiration <= now;
  }

  /// Normalizes a server URL or host to its lowercase hostname.
  static String normalizeServerTag(String server) {
    final uri = Uri.tryParse(server);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host.toLowerCase();
    }
    return server.toLowerCase();
  }

  /// Whether both server tags point at the same host.
  static bool areServersEqual(String a, String b) {
    return normalizeServerTag(a) == normalizeServerTag(b);
  }

  /// Builds and signs a kind-24242 authorization event.
  ///
  /// [type] is one of [authTypes]; [blobs] are hex SHA-256 values emitted as
  /// `x` tags; [servers] are normalized to hostnames; [expiration] is an
  /// absolute UNIX timestamp (defaults to one hour from now).
  Future<NostrEvent> createAuthEvent({
    required String type,
    List<String> blobs = const [],
    List<String> servers = const [],
    String message = '',
    int? expiration,
    DateTime? createdAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return signer.sign(
      NostrEvent(
        id: null,
        kind: authKind,
        content: message,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(now * 1000),
        tags: [
          ['t', type],
          ['expiration', '${expiration ?? now + 3600}'],
          for (final hash in blobs.toSet()) ['x', hash],
          for (final server in servers.map(normalizeServerTag).toSet())
            ['server', server],
        ],
      ),
    );
  }

  /// Authorization for uploading [blobs].
  Future<NostrEvent> createUploadAuth(
    List<String> blobs, {
    List<String> servers = const [],
    String message = 'Upload Blob',
    int? expiration,
  }) {
    return createAuthEvent(
      type: 'upload',
      blobs: blobs,
      servers: servers,
      message: message,
      expiration: expiration,
    );
  }

  /// Authorization for downloading [hash].
  Future<NostrEvent> createDownloadAuth(
    String hash, {
    String message = 'Download Blob',
  }) {
    return createAuthEvent(type: 'get', blobs: [hash], message: message);
  }

  /// Authorization for mirroring [hash] onto a server.
  Future<NostrEvent> createMirrorAuth(
    String hash, {
    String message = 'Mirror Blob',
  }) {
    return createAuthEvent(type: 'upload', blobs: [hash], message: message);
  }

  /// Authorization for listing the signer's blobs.
  Future<NostrEvent> createListAuth({String message = 'List Blobs'}) {
    return createAuthEvent(type: 'list', message: message);
  }

  /// Authorization for deleting [hash].
  Future<NostrEvent> createDeleteAuth(
    String hash, {
    String message = 'Delete Blob',
  }) {
    return createAuthEvent(type: 'delete', blobs: [hash], message: message);
  }

  /// Parses a `blossom:sha256.ext?xs=&as=&sz=` URI.
  static NostrBlossomUri parseBlossomUri(String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.scheme != 'blossom') {
      throw const FormatException('Invalid blossom URI: missing scheme');
    }

    final path = parsed.path;
    final dot = path.indexOf('.');
    if (dot == -1) {
      throw const FormatException(
        'Invalid blossom URI: missing file extension',
      );
    }

    final sha256 = path.substring(0, dot);
    final ext = path.substring(dot + 1);

    if (!isHex32(sha256)) {
      throw const FormatException(
        'Invalid blossom URI: invalid sha256 hash',
      );
    }
    if (ext.isEmpty) {
      throw const FormatException(
        'Invalid blossom URI: empty file extension',
      );
    }

    return NostrBlossomUri(
      sha256: sha256,
      ext: ext,
      servers: parsed.queryParametersAll['xs'] ?? const [],
      authors: parsed.queryParametersAll['as'] ?? const [],
      size: _parseSize(parsed.queryParameters['sz']),
    );
  }

  /// Builds a `blossom:` URI.
  static String buildBlossomUri(NostrBlossomUri uri) {
    final params = <String, List<String>>{
      if (uri.servers.isNotEmpty) 'xs': uri.servers,
      if (uri.authors.isNotEmpty) 'as': uri.authors,
      if (uri.size != null) 'sz': ['${uri.size}'],
    };

    final query = params.entries
        .expand(
          (entry) => entry.value.map(
            (value) => '${entry.key}=${Uri.encodeQueryComponent(value)}',
          ),
        )
        .join('&');

    return 'blossom:${uri.sha256}.${uri.ext}${query.isEmpty ? '' : '?$query'}';
  }

  /// Maps a MIME type to a conventional file extension.
  static String getExtension(String mimeType) {
    final normalized = mimeType.split(';').first.trim().toLowerCase();
    return _mimeExtensions[normalized] ?? '';
  }

  /// Maps a file extension to a MIME type.
  static String getMimeType(String extension) {
    var ext = extension.trim().toLowerCase();
    if (ext.isEmpty) {
      return '';
    }
    if (!ext.startsWith('.')) {
      ext = '.$ext';
    }
    return _extensionMimes[ext] ?? '';
  }

  /// Extracts base server URLs from a kind-10063 server list event.
  static List<Uri> getServersFromServerListEvent(NostrEvent event) {
    final servers = <Uri>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length < 2 || tag.first != 'server') {
        continue;
      }

      final uri = Uri.tryParse(tag[1]);
      if (uri != null && uri.host.isNotEmpty) {
        servers.add(uri.replace(path: '/'));
      }
    }

    return servers;
  }

  /// Extracts the 64-char hex hash from a blob URL, if present.
  static String? getHashFromUrl(String url) {
    final withoutFragment = url.split('#').first;
    final path = withoutFragment.split('?').first;
    final slash = path.lastIndexOf('/');
    final segment = slash == -1 ? path : path.substring(slash + 1);

    final dot = segment.indexOf('.');
    if (dot != -1 && dot != 64) {
      return null;
    }

    if (segment.length < 64) {
      return null;
    }

    final hash = segment.substring(0, 64);

    return isHex32(hash) ? hash : null;
  }

  static int? _parseSize(String? value) {
    if (value == null) {
      return null;
    }

    final size = int.tryParse(value);
    if (size == null || size <= 0) {
      throw const FormatException(
        'Invalid blossom URI: sz must be a positive integer',
      );
    }

    return size;
  }

  static const Map<String, String> _mimeExtensions = {
    'application/json': '.json',
    'application/pdf': '.pdf',
    'application/vnd.android.package-archive': '.apk',
    'application/vnd.sqlite3': '.sqlite3',
    'application/xml': '.xml',
    'audio/aac': '.aac',
    'audio/flac': '.flac',
    'audio/midi': '.midi',
    'audio/mp3': '.mp3',
    'audio/mpeg': '.mp3',
    'audio/mp4': '.m4a',
    'audio/ogg': '.ogg',
    'audio/wav': '.wav',
    'audio/webm': '.weba',
    'audio/x-aiff': '.aiff',
    'audio/x-m4a': '.m4a',
    'image/avif': '.avif',
    'image/gif': '.gif',
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/svg+xml': '.svg',
    'image/webp': '.webp',
    'text/css': '.css',
    'text/csv': '.csv',
    'text/html': '.html',
    'text/javascript': '.js',
    'text/markdown': '.md',
    'text/plain': '.txt',
    'text/xml': '.xml',
    'video/mp2t': '.ts',
    'video/mp4': '.mp4',
    'video/ogg': '.ogv',
    'video/quicktime': '.mov',
    'video/webm': '.webm',
    'video/x-matroska': '.mkv',
  };

  static const Map<String, String> _extensionMimes = {
    '.aac': 'audio/aac',
    '.aiff': 'audio/x-aiff',
    '.apk': 'application/vnd.android.package-archive',
    '.avif': 'image/avif',
    '.css': 'text/css; charset=utf-8',
    '.csv': 'text/csv; charset=utf-8',
    '.flac': 'audio/flac',
    '.gif': 'image/gif',
    '.html': 'text/html; charset=utf-8',
    '.jpeg': 'image/jpeg',
    '.jpg': 'image/jpeg',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json',
    '.m4a': 'audio/mp4',
    '.md': 'text/markdown; charset=utf-8',
    '.midi': 'audio/midi',
    '.mkv': 'video/x-matroska',
    '.mov': 'video/quicktime',
    '.mp3': 'audio/mpeg',
    '.mp4': 'video/mp4',
    '.oga': 'audio/ogg',
    '.ogg': 'audio/ogg',
    '.ogv': 'video/ogg',
    '.pdf': 'application/pdf',
    '.png': 'image/png',
    '.sqlite3': 'application/vnd.sqlite3',
    '.svg': 'image/svg+xml',
    '.ts': 'video/mp2t',
    '.txt': 'text/plain; charset=utf-8',
    '.wav': 'audio/wav',
    '.weba': 'audio/webm',
    '.webm': 'video/webm',
    '.webp': 'image/webp',
    '.xml': 'application/xml',
  };
}
