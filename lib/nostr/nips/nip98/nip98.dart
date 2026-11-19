import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip98}
/// NIP-98 HTTP authentication (kind 27235).
///
/// A client signs a short-lived kind-27235 event binding a URL, an HTTP
/// method and (optionally) a payload hash. The base64-encoded event is sent
/// in the `Authorization` header, with the `Nostr ` scheme by default at the
/// HTTP layer.
///
/// Usage:
/// ```dart
/// final nip98 = NostrNip98(signer: signer);
/// final token = await nip98.getToken(
///   url: 'https://example.com/login',
///   method: 'POST',
///   includeAuthorizationScheme: true,
/// );
/// // header: Authorization: $token
/// ```
/// {@endtemplate}
class NostrNip98 {
  /// {@macro nip98}
  NostrNip98({required this.signer});

  /// Signer used to sign the authentication event.
  final NostrEventSigner signer;

  /// Authorization scheme prefix used by NIP-98.
  static const String authorizationScheme = 'Nostr ';

  /// Kind of the NIP-98 authentication event.
  static const int kind = 27235;

  /// Maximum allowed clock skew, in seconds, for [validateEventTimestamp].
  static const int timestampToleranceSeconds = 60;

  /// Builds and signs a NIP-98 token for [url] and [method].
  ///
  /// [payload] is hashed with SHA-256 and added as a `payload` tag when
  /// provided. Set [includeAuthorizationScheme] to prefix the token with
  /// `Nostr `.
  Future<String> getToken({
    required String url,
    required String method,
    bool includeAuthorizationScheme = false,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
  }) async {
    final event = await signer.sign(
      NostrEvent(
        id: null,
        kind: kind,
        content: '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['u', url],
          ['method', method],
          if (payload != null) ['payload', hashPayload(payload)],
        ],
      ),
    );

    final encoded = base64.encode(utf8.encode(jsonEncode(event.toMap())));
    return includeAuthorizationScheme
        ? '$authorizationScheme$encoded'
        : encoded;
  }

  /// Unpacks the event carried by a NIP-98 [token].
  ///
  /// Throws [FormatException] when the token is empty, not base64 or not a
  /// JSON event object.
  static NostrEvent unpackEventFromToken(String token) {
    if (token.isEmpty) {
      throw const FormatException('Missing token');
    }

    final raw = token.replaceFirst(authorizationScheme, '');

    final String json;
    try {
      json = utf8.decode(base64.decode(raw));
    } on FormatException {
      throw const FormatException('Invalid token');
    }

    if (json.isEmpty || !json.startsWith('{')) {
      throw const FormatException('Invalid token');
    }

    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid token');
    }

    final createdAt = _optional<int>(decoded, 'created_at');

    return NostrEvent(
      id: _optional<String>(decoded, 'id'),
      kind: _optional<int>(decoded, 'kind'),
      content: _optional<String>(decoded, 'content') ?? '',
      sig: _optional<String>(decoded, 'sig'),
      pubkey: _optional<String>(decoded, 'pubkey') ?? '',
      createdAt: createdAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      tags: _stringTags(decoded['tags']),
    );
  }

  /// Validates a NIP-98 token against [url], [method] and optional [payload].
  ///
  /// Returns `true` when valid; throws [FormatException] describing the first
  /// failed check otherwise.
  bool validateToken(
    String token, {
    required String url,
    required String method,
    Map<String, dynamic>? payload,
  }) {
    final event = unpackEventFromToken(token);

    return validateEvent(event, url: url, method: method, payload: payload);
  }

  /// Validates every NIP-98 rule for [event].
  ///
  /// Throws [FormatException] describing the first failed check.
  bool validateEvent(
    NostrEvent event, {
    required String url,
    required String method,
    Map<String, dynamic>? payload,
  }) {
    final recomputedId = _recomputedId(event);
    if (recomputedId == null || recomputedId != event.id) {
      throw const FormatException(
        'Invalid nostr event, id does not match its content',
      );
    }
    if (!event.isVerified()) {
      throw const FormatException('Invalid nostr event, signature invalid');
    }
    if (!validateEventKind(event)) {
      throw const FormatException('Invalid nostr event, kind invalid');
    }
    if (!validateEventTimestamp(event)) {
      throw const FormatException(
        'Invalid nostr event, created_at timestamp invalid',
      );
    }
    if (!validateEventUrlTag(event, url)) {
      throw const FormatException('Invalid nostr event, url tag invalid');
    }
    if (!validateEventMethodTag(event, method)) {
      throw const FormatException('Invalid nostr event, method tag invalid');
    }
    if (payload != null &&
        payload.isNotEmpty &&
        !validateEventPayloadTag(event, payload)) {
      throw const FormatException(
        'Invalid nostr event, payload tag does not match request body hash',
      );
    }

    return true;
  }

  /// Whether [event] has a `created_at` within
  /// [timestampToleranceSeconds] of now (past or future).
  bool validateEventTimestamp(NostrEvent event) {
    final createdAt = event.createdAt;
    if (createdAt == null) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final eventSeconds = createdAt.millisecondsSinceEpoch ~/ 1000;

    return (now - eventSeconds).abs() < timestampToleranceSeconds;
  }

  /// Whether [event] is a kind-27235 event.
  bool validateEventKind(NostrEvent event) => event.kind == kind;

  /// Whether the first `u` tag of [event] equals [url].
  bool validateEventUrlTag(NostrEvent event, String url) {
    final tag = _firstTag(event, 'u');
    return tag != null && tag.length > 1 && tag[1] == url;
  }

  /// Whether the first `method` tag of [event] matches [method], ignoring
  /// case.
  bool validateEventMethodTag(NostrEvent event, String method) {
    final tag = _firstTag(event, 'method');
    return tag != null &&
        tag.length > 1 &&
        tag[1].toLowerCase() == method.toLowerCase();
  }

  /// Whether the first `payload` tag of [event] equals the SHA-256 hash of
  /// [payload].
  bool validateEventPayloadTag(
    NostrEvent event,
    Map<String, dynamic> payload,
  ) {
    final tag = _firstTag(event, 'payload');
    return tag != null && tag.length > 1 && tag[1] == hashPayload(payload);
  }

  /// SHA-256 (hex) of the JSON encoding of [payload].
  static String hashPayload(Object payload) {
    final bytes = utf8.encode(jsonEncode(payload));
    return sha256.convert(bytes).toString();
  }

  static T? _optional<T>(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is! T) {
      throw FormatException('Invalid token, "$key" has wrong type');
    }
    return value;
  }

  static List<List<String>> _stringTags(Object? raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List) {
      throw const FormatException('Invalid token, "tags" has wrong type');
    }

    final tags = <List<String>>[];
    for (final tag in raw) {
      if (tag is! List) {
        throw const FormatException('Invalid token, tag has wrong type');
      }
      final values = <String>[];
      for (final value in tag) {
        if (value is! String) {
          throw const FormatException(
            'Invalid token, tag value has wrong type',
          );
        }
        values.add(value);
      }
      tags.add(values);
    }
    return tags;
  }

  static List<String>? _firstTag(NostrEvent event, String name) {
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isNotEmpty && tag.first == name) {
        return tag;
      }
    }
    return null;
  }

  /// Recomputes the event id from its fields, or `null` when a field needed
  /// for serialization is missing.
  static String? _recomputedId(NostrEvent event) {
    final kind = event.kind;
    final createdAt = event.createdAt;
    if (kind == null || createdAt == null) {
      return null;
    }

    return NostrEvent.getEventId(
      kind: kind,
      content: event.content ?? '',
      createdAt: createdAt,
      tags: event.tags ?? const [],
      pubkey: event.pubkey,
    );
  }
}
