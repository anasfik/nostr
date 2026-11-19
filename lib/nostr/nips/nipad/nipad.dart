import 'dart:convert';

import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:http/http.dart' as http;

/// {@template nipad_pointer}
/// Pointer returned by a NIP-AD `.well-known/nostr.json` lookup.
///
/// [filter] selects the events mirrored at the web address and [relays] lists
/// where to find them.
/// {@endtemplate}
class NostrWebAddressPointer {
  /// {@macro nipad_pointer}
  const NostrWebAddressPointer({required this.filter, this.relays});

  /// Filter for the events behind the web address.
  final NostrFilter filter;

  /// Relays hosting those events.
  final List<String>? relays;
}

/// {@template nipad}
/// NIP-AD web address pointers.
///
/// Resolves a web URL to a Nostr filter by querying
/// `https://<domain>/.well-known/nostr.json?path=<path>`. The document maps
/// each path to `{ "filter": {...}, "relays": [...] }`.
///
/// Missing or malformed documents, non-200 responses and network errors all
/// produce `null` rather than throwing, matching `nostr-tools`.
/// {@endtemplate}
class NostrNipAD {
  /// {@macro nipad}
  NostrNipAD({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Matches an optional scheme, a domain and an optional path.
  static final RegExp webAddressRegex = RegExp(
    r'^(?:https?:\/\/)?((?:[\w-]+\.)+[\w-]+)(\/[^\s]*)?$',
  );

  /// Whether [value] looks like a web address.
  static bool isWebAddress(String? value) {
    return value != null && webAddressRegex.hasMatch(value);
  }

  /// Looks up the Nostr pointer for [url].
  ///
  /// Returns `null` when the URL is not a web address, the document is
  /// missing, the path has no entry, the response is not valid JSON, or the
  /// request exceeds [timeout].
  Future<NostrWebAddressPointer?> queryWebAddress(
    String url, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final match = webAddressRegex.firstMatch(url);
    if (match == null) {
      return null;
    }

    final domain = match.group(1)!;
    final path = match.group(2) ?? '/';

    try {
      final uri = Uri.https(
        domain,
        '/.well-known/nostr.json',
        {'path': path},
      );
      final response = await _httpClient.get(uri).timeout(timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final document = jsonDecode(response.body);
      if (document is! Map<String, dynamic>) {
        return null;
      }

      final entry = document[path];
      if (entry is! Map<String, dynamic>) {
        return null;
      }

      final filter = entry['filter'];
      if (filter is! Map<String, dynamic>) {
        return null;
      }

      final relays = entry['relays'];

      return NostrWebAddressPointer(
        filter: NostrFilter.fromJson(filter),
        relays: relays is List ? List<String>.from(relays) : null,
      );
    } on Exception catch (_) {
      return null;
    }
  }

  /// Closes the underlying HTTP client.
  ///
  /// Call this when the instance is no longer used; an injected client is
  /// closed too, so pass an owned client only.
  void close() => _httpClient.close();
}
