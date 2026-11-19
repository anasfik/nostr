import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';

/// {@template nip55_capable}
/// Android NIP-55 signer surface.
///
/// A NIP-55 signer app answers `ContentResolver.call` requests. This package
/// cannot bind Android intents, so an application supplies an implementation
/// over its own platform channel and the helpers below build/parse the URIs
/// exchanged with the signer app.
/// {@endtemplate}
abstract interface class NostrNip55Capable {
  /// Requests the signer's public key.
  Future<String> getPublicKey();

  /// Signs an event template (`sign_event`), returning the signed event map.
  Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event);

  /// `nip04_encrypt`.
  Future<String> encryptNip04({
    required String pubKey,
    required String plaintext,
  });

  /// `nip04_decrypt`.
  Future<String> decryptNip04({
    required String pubKey,
    required String ciphertext,
  });

  /// `nip44_encrypt`.
  Future<String> encryptNip44({
    required String pubKey,
    required String plaintext,
  });

  /// `nip44_decrypt`.
  Future<String> decryptNip44({
    required String pubKey,
    required String ciphertext,
  });

  /// `decrypt_zap_event`: decrypts the embedded zap request.
  Future<Map<String, dynamic>> decryptZapEvent(Map<String, dynamic> event);
}

/// {@template nip55_result}
/// Parsed response returned by a NIP-55 signer app.
///
/// The signer answers with `nostrsigner:` (or the supplied `callbackUrl`)
/// carrying `result`/`event`, `package`, `id`, `current_user` and `rejected`
/// query parameters.
/// {@endtemplate}
class NostrNip55Result {
  /// {@macro nip55_result}
  const NostrNip55Result({
    this.result,
    this.event,
    this.package,
    this.id,
    this.currentUser,
    this.rejected = false,
  });

  /// Signature or plain result, used when `returnType=signature`.
  final String? result;

  /// Signed event, used when `returnType=event`.
  final Map<String, dynamic>? event;

  /// Package name of the signer app.
  final String? package;

  /// Request id echoed by the signer.
  final String? id;

  /// `current_user` echoed by the signer.
  final String? currentUser;

  /// Whether the user rejected the request.
  final bool rejected;
}

/// {@template nip55}
/// NIP-55 Android signer intent helpers.
///
/// Builds `nostrsigner:` URIs (`get_public_key`, `sign_event`,
/// `nip04_encrypt/decrypt`, `nip44_encrypt/decrypt`, `decrypt_zap_event`) and
/// parses the signer's response. No `Intent`, `ContentResolver` or activity
/// result plumbing is included; see [NostrNip55Capable] for the execution
/// side.
/// {@endtemplate}
class NostrNip55 {
  /// {@macro nip55}
  const NostrNip55();

  /// URI scheme used by NIP-55 signer apps.
  static const String scheme = 'nostrsigner:';

  /// Default response type: only the signature is returned.
  static const String returnTypeSignature = 'signature';

  /// Response type returning the full signed event.
  static const String returnTypeEvent = 'event';

  /// Builds a `get_public_key` request.
  static String getPublicKeyUri({
    List<Map<String, Object>> permissions = const [],
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? appName,
  }) {
    return _buildUri(
      base: scheme,
      type: 'get_public_key',
      permissions: permissions,
      callbackUrl: callbackUrl,
      returnType: returnType,
      compressionType: compressionType,
      id: id,
      currentUser: currentUser,
      appName: appName,
    );
  }

  /// Builds a `sign_event` request for [event].
  static String signEventUri({
    required NostrEvent event,
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? appName,
  }) {
    return _buildUri(
      base: '$scheme${Uri.encodeComponent(jsonEncode(event.toMap()))}',
      type: 'sign_event',
      callbackUrl: callbackUrl,
      returnType: returnType,
      compressionType: compressionType,
      id: id,
      currentUser: currentUser,
      appName: appName,
    );
  }

  /// Builds a `nip04_encrypt` request.
  static String encryptNip04Uri({
    required String pubKey,
    required String content,
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? appName,
  }) {
    return _buildUri(
      base: scheme,
      type: 'nip04_encrypt',
      pubKey: pubKey,
      plainText: content,
      callbackUrl: callbackUrl,
      returnType: returnType,
      compressionType: compressionType,
      id: id,
      currentUser: currentUser,
      appName: appName,
    );
  }

  /// Builds a `nip04_decrypt` request.
  static String decryptNip04Uri({
    required String pubKey,
    required String content,
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? appName,
  }) {
    return _buildUri(
      base: scheme,
      type: 'nip04_decrypt',
      pubKey: pubKey,
      encryptedText: content,
      callbackUrl: callbackUrl,
      returnType: returnType,
      compressionType: compressionType,
      id: id,
      currentUser: currentUser,
      appName: appName,
    );
  }

  /// Builds a `nip44_encrypt` request.
  static String encryptNip44Uri({
    required String pubKey,
    required String content,
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? appName,
  }) {
    return _buildUri(
      base: scheme,
      type: 'nip44_encrypt',
      pubKey: pubKey,
      plainText: content,
      callbackUrl: callbackUrl,
      returnType: returnType,
      compressionType: compressionType,
      id: id,
      currentUser: currentUser,
      appName: appName,
    );
  }

  /// Builds a `nip44_decrypt` request.
  static String decryptNip44Uri({
    required String pubKey,
    required String content,
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? appName,
  }) {
    return _buildUri(
      base: scheme,
      type: 'nip44_decrypt',
      pubKey: pubKey,
      encryptedText: content,
      callbackUrl: callbackUrl,
      returnType: returnType,
      compressionType: compressionType,
      id: id,
      currentUser: currentUser,
      appName: appName,
    );
  }

  /// Builds a `decrypt_zap_event` request for [event].
  static String decryptZapEventUri({
    required NostrEvent event,
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? appName,
  }) {
    return _buildUri(
      base: '$scheme${Uri.encodeComponent(jsonEncode(event.toMap()))}',
      type: 'decrypt_zap_event',
      callbackUrl: callbackUrl,
      returnType: returnType,
      compressionType: compressionType,
      id: id,
      currentUser: currentUser,
      appName: appName,
    );
  }

  /// Parses a signer response URI (either `nostrsigner:` or a callback URL).
  static NostrNip55Result parseResultUri(String uri) {
    final params = Uri.parse(uri).queryParameters;
    final rawEvent = params['event'];

    Map<String, dynamic>? event;
    if (rawEvent != null && rawEvent.isNotEmpty) {
      final decoded = jsonDecode(rawEvent);
      if (decoded is Map<String, dynamic>) {
        event = decoded;
      }
    }

    return NostrNip55Result(
      result: params['result'],
      event: event,
      package: params['package'],
      id: params['id'],
      currentUser: params['current_user'],
      rejected: params['rejected'] == 'true',
    );
  }

  static String _buildUri({
    required String base,
    required String type,
    List<Map<String, Object>>? permissions,
    String? callbackUrl,
    String returnType = returnTypeSignature,
    String compressionType = 'none',
    String? id,
    String? currentUser,
    String? pubKey,
    String? plainText,
    String? encryptedText,
    String? appName,
  }) {
    final params = <String, String>{
      'type': type,
      'compressionType': compressionType,
      'returnType': returnType,
      if (callbackUrl != null) 'callbackUrl': callbackUrl,
      if (id != null) 'id': id,
      if (currentUser != null) 'current_user': currentUser,
      if (permissions != null && permissions.isNotEmpty)
        'permissions': Uri.encodeComponent(jsonEncode(permissions)),
      if (pubKey != null) 'pubKey': pubKey,
      if (plainText != null) 'plainText': plainText,
      if (encryptedText != null) 'encryptedText': encryptedText,
      if (appName != null) 'appName': appName,
    };

    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');

    return '$base?$query';
  }
}
