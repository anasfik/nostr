import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nostr_external_content_id}
/// Parsed NIP-73 external content id.
///
/// [id] is the `i` tag value, [kind] its `k` tag kind and [urlHint] the
/// optional redirect URL stored as the second `i` tag value.
/// {@endtemplate}
class NostrExternalContentId {
  const NostrExternalContentId._({
    required this.id,
    required this.kind,
    this.urlHint,
  });

  /// `i` tag value.
  final String id;

  /// `k` tag value, such as `web`, `isbn`, `geo` or `bitcoin:tx`.
  final String kind;

  /// Optional URL hint for clients that do not understand [id].
  final String? urlHint;

  static final RegExp _geohash = RegExp(r'^[0-9bcdefghjkmnpqrstuvwxyz]{1,12}$');
  static final RegExp _isbn = RegExp(r'^(?:\d{13}|\d{9}[\dX])$');
  static final RegExp _isan = RegExp(
    r'^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-'
    r'[0-9A-Fa-f]$',
  );
  static final RegExp _doi = RegExp(r'^10\.\d{4,9}/\S+$');
  static final RegExp _iso3166 = RegExp(r'^[A-Z]{2}(?:-[A-Z0-9]{1,3})?$');
  static final RegExp _osm = RegExp(r'^osm:(?:node|way|relation):\d+$');
  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _evmAddress = RegExp(r'^0x[0-9a-f]{40}$');
  static final RegExp _blockchain = RegExp(
    r'^([a-z][a-z0-9]*):(?:(\d+):)?(tx|address):(.+)$',
  );

  /// Parses an `i` tag value, throwing [ArgumentError] when unsupported.
  static NostrExternalContentId parse(String value, {String? urlHint}) {
    final id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, 'i', 'External content id is empty');
    }

    if (urlHint != null && urlHint.trim().isEmpty) {
      throw ArgumentError.value(urlHint, 'urlHint', 'URL hint is empty');
    }

    final kind = _kindFor(id);
    if (kind == null) {
      throw ArgumentError.value(
        value,
        'i',
        'Unsupported external content id',
      );
    }

    return NostrExternalContentId._(
      id: kind == 'web' ? _normalizeUrl(id)! : id,
      kind: kind,
      urlHint: urlHint,
    );
  }

  /// Like [parse], returning `null` for unsupported values.
  static NostrExternalContentId? tryParse(String value, {String? urlHint}) {
    try {
      return parse(value, urlHint: urlHint);
    } on ArgumentError {
      return null;
    }
  }

  /// Derives the `k` kind for [value], or `null` when unsupported.
  static String? kindFor(String value) => _kindFor(value.trim());

  /// `['i', id, urlHint?]`.
  List<String> toITag() => [
        'i',
        id,
        if (urlHint != null) urlHint!,
      ];

  /// `['k', kind]`.
  List<String> toKTag() => ['k', kind];

  /// `[i, k]` tags for an event.
  List<List<String>> toTags() => [toITag(), toKTag()];

  static String? _kindFor(String value) {
    final lower = value.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return _normalizeUrl(value) == null ? null : 'web';
    }

    if (value.startsWith('#')) {
      final topic = value.substring(1);

      return topic.isNotEmpty &&
              !topic.contains(RegExp(r'\s')) &&
              topic == topic.toLowerCase()
          ? '#'
          : null;
    }

    if (lower.startsWith('isbn:')) {
      return _isbn.hasMatch(value.substring(5)) ? 'isbn' : null;
    }

    if (lower.startsWith('geo:')) {
      final geohash = value.substring(4);

      return _geohash.hasMatch(geohash) ? 'geo' : null;
    }

    if (lower.startsWith('osm:')) {
      return _osm.hasMatch(value) ? 'osm' : null;
    }

    if (lower.startsWith('iso3166:')) {
      return _iso3166.hasMatch(value.substring(8)) ? 'iso3166' : null;
    }

    if (lower.startsWith('isan:')) {
      return _isan.hasMatch(value.substring(5)) ? 'isan' : null;
    }

    if (lower.startsWith('doi:')) {
      final doi = value.substring(4);

      return _doi.hasMatch(doi) && doi == doi.toLowerCase() ? 'doi' : null;
    }

    for (final prefix in const [
      'podcast:item:guid:',
      'podcast:publisher:guid:',
      'podcast:guid:',
    ]) {
      if (lower.startsWith(prefix)) {
        final guid = value.substring(prefix.length);

        return guid.isNotEmpty && !guid.contains(RegExp(r'\s'))
            ? prefix.substring(0, prefix.length - 1)
            : null;
      }
    }

    final blockchain = _blockchain.firstMatch(value);
    if (blockchain == null) {
      return null;
    }

    final chain = blockchain.group(1)!;
    final type = blockchain.group(3)!;
    final reference = blockchain.group(4)!;

    if (reference.contains(RegExp(r'\s'))) {
      return null;
    }

    if (type == 'tx' && !_isValidTx(chain, reference)) {
      return null;
    }

    if (type == 'address' &&
        chain == 'ethereum' &&
        !_evmAddress.hasMatch(reference)) {
      return null;
    }

    return '$chain:$type';
  }

  static bool _isValidTx(String chain, String txid) {
    if (txid != txid.toLowerCase()) {
      return false;
    }

    return switch (chain) {
      'bitcoin' => _hex64.hasMatch(txid),
      'ethereum' => RegExp(r'^0x[0-9a-f]{64}$').hasMatch(txid),
      _ => txid.isNotEmpty,
    };
  }

  /// Drops the fragment and validates an absolute HTTP(S) URL.
  static String? _normalizeUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return null;
    }

    return uri.removeFragment().toString();
  }

  @override
  String toString() => id;
}

/// {@template nip73}
/// NIP-73 external content ids.
///
/// Stateless: parse or build the `i`/`k` tag pair for URLs, ISBNs, geohashes,
/// OpenStreetMap objects, ISO 3166 codes, ISANs, DOIs, hashtags, podcast GUIDs
/// and blockchain transactions/addresses, and build `#i`/`#k` filters.
/// {@endtemplate}
class NostrNip73 {
  /// {@macro nip73}
  const NostrNip73();

  /// Referenced-content tag name.
  static const String iTag = 'i';

  /// Referenced-content kind tag name.
  static const String kTag = 'k';

  /// Parses an `i` value into a [NostrExternalContentId].
  static NostrExternalContentId parse(String value, {String? urlHint}) =>
      NostrExternalContentId.parse(value, urlHint: urlHint);

  /// Like [parse], returning `null` for unsupported values.
  static NostrExternalContentId? tryParse(String value, {String? urlHint}) =>
      NostrExternalContentId.tryParse(value, urlHint: urlHint);

  /// `k` kind for [value], or `null` when unsupported.
  static String? kindFor(String value) => NostrExternalContentId.kindFor(value);

  /// `[i, k]` tags for [value].
  static List<List<String>> tagsFor(String value, {String? urlHint}) =>
      parse(value, urlHint: urlHint).toTags();

  /// Every supported `i` tag on [event], in order.
  ///
  /// Unsupported ids are skipped; `k` tags are derived from each id instead of
  /// trusting the event's own `k` tags.
  static List<NostrExternalContentId> parseEvent(NostrEvent event) {
    final result = <NostrExternalContentId>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length < 2 || tag.first != iTag) {
        continue;
      }

      final parsed = tryParse(tag[1], urlHint: NostrTags.at(tag, 2));
      if (parsed != null) {
        result.add(parsed);
      }
    }

    return result;
  }

  /// Builds a `#i` / `#k` filter, as used by clients to query references.
  ///
  /// Throws [ArgumentError] when both [ids] and [kinds] are empty or any id is
  /// unsupported.
  static NostrFilter buildFilter({
    List<String> ids = const [],
    List<String> kinds = const [],
    List<String>? authors,
    int? limit,
  }) {
    if (ids.isEmpty && kinds.isEmpty) {
      throw ArgumentError('Provide at least one external content id or kind');
    }

    for (final id in ids) {
      if (tryParse(id) == null) {
        throw ArgumentError.value(id, 'ids', 'Unsupported external content id');
      }
    }

    return NostrFilter(
      authors: authors,
      limit: limit,
      additionalFilters: {
        if (ids.isNotEmpty) '#i': ids,
        if (kinds.isNotEmpty) '#k': kinds,
      },
    );
  }
}
