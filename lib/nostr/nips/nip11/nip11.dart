import 'dart:convert';

import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/nips/nip11/relay_informations.dart';
import 'package:http/http.dart' as http;

export 'relay_informations.dart';

/// {@template nip11}
/// NIP-11 relay information document fetching and parsing.
/// {@endtemplate}
class NostrNip11 {
  /// {@macro nip11}
  NostrNip11({
    required this.logger,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  /// {@macro nostr_client_utils}
  final NostrLogger logger;

  /// Optional client. When omitted, the package-level `http.get` is used so
  /// `http.runWithClient` test overrides keep working.
  final http.Client? _httpClient;

  /// Converts a `ws://`/`wss://` relay URL to its HTTP counterpart.
  static Uri httpUri(String relayUrl) {
    final normalized = relayUrl.trim();

    if (!normalized.startsWith('ws://') && !normalized.startsWith('wss://')) {
      throw ArgumentError.value(
        relayUrl,
        'relayUrl',
        'invalid relay url, expected ws:// or wss:// scheme',
      );
    }

    var httpUrl = normalized.replaceFirst('ws://', 'http://');
    httpUrl = httpUrl.replaceFirst('wss://', 'https://');
    return Uri.parse(httpUrl);
  }

  /// Fetches and parses the relay information document for [relayUrl].
  ///
  /// Returns `null` on failure when [throwExceptionIfExists] is `false`.
  Future<RelayInformations?> fetch({
    required String relayUrl,
    bool throwExceptionIfExists = true,
  }) async {
    try {
      final uri = httpUri(relayUrl);

      final client = _httpClient;
      const headers = {'Accept': 'application/nostr+json'};
      final res = await (client == null
          ? http.get(uri, headers: headers)
          : client.get(uri, headers: headers));
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;

      return RelayInformations.fromNip11Response(decoded);
    } catch (e) {
      logger.log(
        'error while getting relay informations from nip11 for relay url: $relayUrl',
        e,
      );

      if (throwExceptionIfExists) {
        rethrow;
      }
    }
    return null;
  }
}
