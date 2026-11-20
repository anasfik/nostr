import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';

/// {@template nostr_imeta}
/// Parsed NIP-92 `imeta` tag.
///
/// Entries are stored in event order, so repeatable keys such as `fallback`
/// and `image` keep every value. Each raw entry is split on its first space
/// only, letting values contain spaces (`alt`, URLs with query strings).
///
/// See [NostrNip92] for event-level helpers.
/// {@endtemplate}
class NostrImeta {
  NostrImeta._(this._entries);

  /// Parses an `imeta` [tag], with or without its leading `imeta` name.
  ///
  /// Never throws: malformed entries are kept as-is and reported invalid by
  /// the `isValid` getter. Use [tryParse] to reject invalid tags directly.
  factory NostrImeta.parse(List<String> tag) {
    final entries = <MapEntry<String, String>>[];
    final start = tag.isNotEmpty && tag.first == NostrNip92.tagName ? 1 : 0;

    for (final raw in tag.skip(start)) {
      if (raw.isEmpty) {
        continue;
      }

      final separator = raw.indexOf(' ');
      if (separator < 0) {
        entries.add(MapEntry(raw, ''));
        continue;
      }

      entries.add(
        MapEntry(
          raw.substring(0, separator),
          raw.substring(separator + 1),
        ),
      );
    }

    return NostrImeta._(List<MapEntry<String, String>>.unmodifiable(entries));
  }

  /// Like [NostrImeta.parse], but returns `null` for tags that fail validation.
  static NostrImeta? tryParse(List<String> tag) {
    final parsed = NostrImeta.parse(tag);

    return parsed.isValid ? parsed : null;
  }

  /// Typed keys with dedicated getters; everything else lands in [extras].
  static const Set<String> typedKeys = {
    'url',
    'm',
    'x',
    'dim',
    'alt',
    'blurhash',
    'service',
    'fallback',
    'image',
  };

  final List<MapEntry<String, String>> _entries;

  /// Ordered key/value entries, including duplicates.
  List<MapEntry<String, String>> get entries => _entries;

  /// First value for [key], or `null`.
  String? operator [](String key) {
    for (final entry in _entries) {
      if (entry.key == key) {
        return entry.value;
      }
    }

    return null;
  }

  /// Every value for [key], in event order.
  List<String> getAll(String key) => [
        for (final entry in _entries)
          if (entry.key == key) entry.value,
      ];

  /// Primary media URL.
  String? get url => this['url'];

  /// MIME type (`m`).
  String? get m => this['m'];

  /// SHA-256 hash (`x`).
  String? get x => this['x'];

  /// Raw dimensions such as `3024x4032` (`dim`).
  String? get dim => this['dim'];

  /// Accessibility description (`alt`).
  String? get alt => this['alt'];

  /// Blurhash placeholder (`blurhash`).
  String? get blurhash => this['blurhash'];

  /// Service that hosts the media (`service`).
  String? get service => this['service'];

  /// Fallback URLs, in preference order.
  List<String> get fallback => getAll('fallback');

  /// Alternative image URLs, in preference order.
  List<String> get image => getAll('image');

  /// Unrecognised keys, preserving repeats.
  Map<String, List<String>> get extras {
    final result = <String, List<String>>{};

    for (final entry in _entries) {
      if (typedKeys.contains(entry.key)) {
        continue;
      }

      (result[entry.key] ??= <String>[]).add(entry.value);
    }

    return result;
  }

  /// Whether the tag has a non-empty `url` and at least one other field with a
  /// non-empty value, as required by NIP-92.
  bool get isValid {
    final mediaUrl = url;

    return mediaUrl != null &&
        mediaUrl.isNotEmpty &&
        _entries.any(
          (entry) =>
              entry.key.isNotEmpty &&
              entry.key != 'url' &&
              entry.value.isNotEmpty,
        );
  }

  /// Serializes back to a tag list, including the leading `imeta` name.
  List<String> toTag() => [
        NostrNip92.tagName,
        for (final entry in _entries)
          entry.value.isEmpty ? entry.key : '${entry.key} ${entry.value}',
      ];
}

/// {@template nip92}
/// NIP-92 media attachment metadata (`imeta` tags).
///
/// Stateless: parse tags from an event, match them against event content, or
/// resolve profile `picture`/`banner` metadata.
/// {@endtemplate}
class NostrNip92 {
  /// {@macro nip92}
  const NostrNip92();

  /// Tag name used for inline media metadata.
  static const String tagName = 'imeta';

  /// Every valid `imeta` tag on [event], in order.
  static List<NostrImeta> parseAll(NostrEvent event) => parseTags(event.tags);

  /// Every valid `imeta` tag in [tags], skipping malformed ones.
  static List<NostrImeta> parseTags(List<List<String>>? tags) {
    final result = <NostrImeta>[];

    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.isEmpty || tag.first != tagName) {
        continue;
      }

      final imeta = NostrImeta.tryParse(tag);
      if (imeta != null) {
        result.add(imeta);
      }
    }

    return result;
  }

  /// Whether [imeta] describes exactly [url].
  static bool matchesUrl(NostrImeta imeta, String? url) =>
      url != null && url.isNotEmpty && imeta.url == url;

  /// `imeta` tag describing the profile [field] (`picture` or `banner`).
  ///
  /// Reads the stringified JSON [NostrEvent.content] of a kind-0 event and
  /// returns the first tag whose `url` equals the field value, per NIP-92.
  /// Returns `null` for malformed content or when no tag matches.
  static NostrImeta? forProfileField(NostrEvent event, String field) {
    final content = event.content;
    if (content == null || content.isEmpty) {
      return null;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return null;
    }

    if (decoded is! Map) {
      return null;
    }

    final fieldValue = decoded[field];
    if (fieldValue is! String || fieldValue.isEmpty) {
      return null;
    }

    for (final imeta in parseAll(event)) {
      if (matchesUrl(imeta, fieldValue)) {
        return imeta;
      }
    }

    return null;
  }
}
