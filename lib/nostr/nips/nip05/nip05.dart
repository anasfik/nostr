import 'dart:convert';

import 'package:dart_nostr/nostr/core/exceptions.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:http/http.dart' as http;

/// {@template nip05}
/// NIP-05 internet identifier handling: format validation and resolving an
/// `name@domain` identifier to a public key via `/.well-known/nostr.json`.
/// {@endtemplate}
class NostrNip05 {
  /// {@macro nip05}
  NostrNip05({
    required this.logger,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  /// {@macro nostr_client_utils}
  final NostrLogger logger;

  /// Optional client. When omitted, the package-level `http.get` is used so
  /// `http.runWithClient` test overrides keep working.
  final http.Client? _httpClient;

  /// Wether the given [identifier] has a valid format.
  bool isValidNip05Identifier(String identifier) {
    final emailRegEx = RegExp(
      r'^[a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]+$',
    );

    return emailRegEx.hasMatch(identifier);
  }

  /// Verifies [internetIdentifier] against [pubKey] using NIP-05.
  Future<bool> verifyNip05({
    required String internetIdentifier,
    required String pubKey,
  }) async {
    assert(
      pubKey.length == 64 || !pubKey.startsWith('npub'),
      'pub key is invalid, it must be in hex format and not a npub(nip19) key!',
    );
    assert(
      internetIdentifier.contains('@') &&
          internetIdentifier.split('@').length == 2,
      'invalid internet identifier',
    );

    try {
      final pubKeyFromResponse = await pubKeyFromIdentifierNip05(
        internetIdentifier: internetIdentifier,
      );

      return pubKey == pubKeyFromResponse;
    } catch (e) {
      logger.log(
        'error while verifying nip05 for internet identifier: $internetIdentifier',
        e,
      );
      rethrow;
    }
  }

  /// Returns the public key published for [internetIdentifier], if any.
  Future<String?> pubKeyFromIdentifierNip05({
    required String internetIdentifier,
  }) async {
    try {
      final localPart = internetIdentifier.split('@')[0];
      final domainPart = internetIdentifier.split('@')[1];

      logger.log(
        'Attempt to fetch pubkey for $internetIdentifier from $domainPart',
      );

      final uri = Uri.parse(
        'https://$domainPart/.well-known/nostr.json?name=$localPart',
      );
      final client = _httpClient;
      final res = await (client == null ? http.get(uri) : client.get(uri));

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (decoded
          case {
            'names': final names as Map<String, dynamic>,
          }) {
        logger.log(
          'Pubkey for $localPart is ${names[localPart] ?? 'not found'} '
          'at $domainPart',
        );

        return names[localPart] as String?;
      }

      return null;
    } on Exception catch (e) {
      logger.log(
        'error while verifying nip05 for internet identifier: '
        '$internetIdentifier',
        e,
      );

      throw Nip05VerificationException(parent: e);
    }
  }
}
