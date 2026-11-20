import 'dart:convert';

import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nostr_metadata_birthday}
/// NIP-24 `birthday` metadata object.
///
/// Each field is optional (`24.md:19`), so a profile may publish only a month
/// and day.
/// {@endtemplate}
class NostrMetadataBirthday {
  /// {@macro nostr_metadata_birthday}
  const NostrMetadataBirthday({this.year, this.month, this.day});

  /// Birth year, when known.
  final int? year;

  /// Birth month (1–12), when known.
  final int? month;

  /// Birth day (1–31), when known.
  final int? day;

  /// Whether no field is set.
  bool get isEmpty => year == null && month == null && day == null;

  /// JSON object with only the fields that are set.
  Map<String, int> toJson() => {
        if (year != null) 'year': year!,
        if (month != null) 'month': month!,
        if (day != null) 'day': day!,
      };

  /// Parses a `birthday` object from a [Map] or JSON string.
  ///
  /// Never throws. Returns `null` when [value] is not an object, when every
  /// field is absent, or when a present field is not an integer in range.
  static NostrMetadataBirthday? tryParse(Object? value) {
    var decoded = value;

    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }

    if (decoded is! Map) {
      return null;
    }

    final year = NostrValidators.tryInt(decoded['year'], min: 1);
    final month = NostrValidators.tryInt(decoded['month'], min: 1, max: 12);
    final day = NostrValidators.tryInt(decoded['day'], min: 1, max: 31);

    if (decoded.containsKey('year') && year == null) {
      return null;
    }

    if (decoded.containsKey('month') && month == null) {
      return null;
    }

    if (decoded.containsKey('day') && day == null) {
      return null;
    }

    final birthday = NostrMetadataBirthday(
      year: year,
      month: month,
      day: day,
    );

    return birthday.isEmpty ? null : birthday;
  }
}

/// {@template nostr_metadata_extras}
/// NIP-24 fields read from a kind-0 metadata object.
///
/// Wraps the decoded JSON so callers can inspect [bot], [birthday] and the
/// deprecated field names without re-decoding. Raw access stays available via
/// [fields].
/// {@endtemplate}
class NostrMetadataExtras {
  const NostrMetadataExtras._(this.fields);

  /// Parses already-decoded kind-0 content.
  ///
  /// Total for any map: unknown fields are kept and queried through [fields].
  factory NostrMetadataExtras.parse(Map<String, dynamic> json) =>
      NostrMetadataExtras._(Map<String, dynamic>.unmodifiable(json));

  /// Parses kind-0 [content] (stringified JSON or a decoded map).
  ///
  /// Never throws: malformed JSON and non-object values return `null`.
  static NostrMetadataExtras? tryParse(Object? content) {
    var decoded = content;

    if (content is String) {
      try {
        decoded = jsonDecode(content);
      } on FormatException {
        return null;
      }
    }

    if (decoded is! Map) {
      return null;
    }

    final fields = <String, dynamic>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        return null;
      }
      fields[entry.key as String] = entry.value;
    }

    return NostrMetadataExtras._(Map<String, dynamic>.unmodifiable(fields));
  }

  /// Decoded metadata object.
  final Map<String, dynamic> fields;

  /// NIP-24 `bot` flag, or `null` when absent or not a boolean.
  bool? get bot {
    final value = fields['bot'];

    return value is bool ? value : null;
  }

  /// NIP-24 `birthday`, or `null` when absent or malformed.
  NostrMetadataBirthday? get birthday =>
      NostrMetadataBirthday.tryParse(fields['birthday']);

  /// Deprecated field names present in the metadata, in spec order.
  List<String> get deprecatedFields => [
        for (final field in NostrNip24.deprecatedMetadataFields)
          if (fields.containsKey(field)) field,
      ];
}

/// {@template nip24}
/// NIP-24 extra metadata fields and tags.
///
/// Stateless helpers for the kind-0 extras (`display_name`, `website`,
/// `banner`, `bot`, `birthday`), deprecated-field cleanup and the shared
/// `r`/`i`/`title`/`t` tag names. The `t` value MUST be lowercase
/// (`24.md:43`).
/// {@endtemplate}
class NostrNip24 {
  /// {@macro nip24}
  const NostrNip24();

  /// Kind-0 fields replaced by newer names (`24.md:21-26`).
  static const Set<String> deprecatedMetadataFields = {
    'displayName',
    'username',
  };

  /// `r` tag: web URL the event refers to.
  static const String r = 'r';

  /// `i` tag: external id the event refers to (NIP-73).
  static const String i = 'i';

  /// `title` tag: name of a set, calendar event, live event or listing.
  static const String title = 'title';

  /// `t` tag: hashtag. The value MUST be lowercase (`24.md:43`).
  static const String t = 't';

  /// Metadata JSON without the deprecated [deprecatedMetadataFields].
  ///
  /// Accepts kind-0 content as a JSON string or a decoded map and returns the
  /// re-encoded object. Returns `null` when the input is not a JSON object or
  /// contains values JSON cannot encode (such as a [DateTime]).
  static String? normalizeMetadataJson(Object? content) {
    var decoded = content;

    if (content is String) {
      try {
        decoded = jsonDecode(content);
      } on FormatException {
        return null;
      }
    }

    if (decoded is! Map) {
      return null;
    }

    final normalized = <String, dynamic>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        return null;
      }
      if (deprecatedMetadataFields.contains(entry.key)) {
        continue;
      }
      normalized[entry.key as String] = entry.value;
    }

    try {
      return jsonEncode(normalized);
      // Non-encodable values (e.g. DateTime) surface as an Error.
      // ignore: avoid_catching_errors
    } on JsonUnsupportedObjectError {
      return null;
    }
  }

  /// Whether [value] is a non-empty lowercase hashtag (`24.md:43`).
  static bool isValidHashtag(String value) =>
      value.isNotEmpty && NostrValidators.isLowercase(value);

  /// `['t', hashtag]` with the value lowercased.
  ///
  /// Throws [ArgumentError] when the lowercased value is empty or only
  /// whitespace, i.e. when the input cannot be a hashtag.
  static List<String> hashtagTag(String hashtag) {
    final normalized = hashtag.toLowerCase();

    if (normalized.trim().isEmpty) {
      throw ArgumentError.value(
        hashtag,
        'hashtag',
        'Hashtags must be non-empty',
      );
    }

    return [t, normalized];
  }
}
