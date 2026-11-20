import 'package:dart_nostr/nostr/model/event/event.dart';

/// {@template nostr_tags}
/// Read-only helpers for Nostr tag lists.
///
/// Every helper accepts a nullable tag list so callers can pass
/// `event.tags` directly. Tag names are matched exactly and case-sensitively.
/// {@endtemplate}
class NostrTags {
  const NostrTags._();

  /// First value of the first tag named [name], or `null`.
  ///
  /// Tags without a value (such as `['-']`) return `null`; use [has] to check
  /// presence regardless of values.
  static String? first(List<List<String>>? tags, String name) {
    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == name) {
        return tag[1];
      }
    }

    return null;
  }

  /// First value of every tag named [name], in event order.
  ///
  /// Values after the first are ignored, so an `option` tag
  /// `['option', 'id', 'label']` contributes only `id`.
  static List<String> all(List<List<String>>? tags, String name) {
    final values = <String>[];

    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == name) {
        values.add(tag[1]);
      }
    }

    return values;
  }

  /// Whether any tag is named [name], even without a value.
  static bool has(List<List<String>>? tags, String name) {
    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.isNotEmpty && tag.first == name) {
        return true;
      }
    }

    return false;
  }

  /// Values of every tag named [name].
  ///
  /// Throws a [StateError] when no such tag exists. Tags named [name] without
  /// values (such as `['-']`) return an empty list.
  static List<String> require(List<List<String>>? tags, String name) {
    if (!has(tags, name)) {
      throw StateError('Missing required "$name" tag');
    }

    return all(tags, name);
  }

  /// Whether any tag named [name] has [value] in its first value slot.
  static bool containsValue(
    List<List<String>>? tags,
    String name,
    String value,
  ) {
    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == name && tag[1] == value) {
        return true;
      }
    }

    return false;
  }

  /// First tag named [name], including every slot, or `null`.
  ///
  /// Unlike [first], this keeps the optional slots at index 2 and beyond, so
  /// `['e', id, relay, 'root']` is returned whole. Tags without a value (such
  /// as `['-']`) are returned as-is.
  static List<String>? tag(List<List<String>>? tags, String name) {
    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.isNotEmpty && tag.first == name) {
        return tag;
      }
    }

    return null;
  }

  /// Slot at [index] of [tag], or `null` when out of range.
  static String? at(List<String>? tag, int index) {
    if (tag == null || index < 0 || index >= tag.length) {
      return null;
    }

    return tag[index];
  }

  /// Whether [tags] contains exactly [count] tags named [name].
  static bool hasExactly(List<List<String>>? tags, String name, int count) {
    var found = 0;

    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.isNotEmpty && tag.first == name) {
        found++;
      }
    }

    return found == count;
  }

  /// Value slots after the name, in order (NIP-01 tag shape).
  ///
  /// `['e', id, relay]` yields `[id, relay]`; a name-only tag yields `[]`.
  static List<String> tail(List<String> tag) {
    if (tag.length <= 1) {
      return const <String>[];
    }

    return tag.sublist(1);
  }

  /// Every tag named [name] whose first value starts with [prefix].
  ///
  /// Useful for NIP-10/NIP-73 prefixed references such as `["r", "https://…"]`.
  /// Returns whole tags, and skips tags without a value.
  static List<List<String>> withPrefix(
    List<List<String>>? tags,
    String name,
    String prefix,
  ) {
    final matches = <List<String>>[];

    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == name && tag[1].startsWith(prefix)) {
        matches.add(tag);
      }
    }

    return matches;
  }

  /// Map of tag name to its first value slot, in event order (NIP-01).
  ///
  /// The first occurrence of a name wins; names without a value map to `''`.
  static Map<String, List<String>> toTagMap(List<List<String>> tags) {
    final map = <String, List<String>>{};

    for (final tag in tags) {
      if (tag.isEmpty || map.containsKey(tag.first)) {
        continue;
      }

      map[tag.first] = [if (tag.length > 1) tag[1] else ''];
    }

    return map;
  }

  /// Copy of [event] with [tag] present once, replacing tags of the same name.
  ///
  /// The replacement keeps the position of the first same-named tag, so tag
  /// order stays stable. Adding a tag changes the canonical serialization, so
  /// `id` and `sig` are always cleared; sign the result before publishing.
  static NostrEvent withTag(NostrEvent event, List<String> tag) {
    if (tag.isEmpty) {
      throw ArgumentError.value(tag, 'tag', 'Tag must have a name');
    }

    final name = tag.first;
    final tags = <List<String>>[];
    var added = false;

    for (final existing in event.tags ?? const <List<String>>[]) {
      if (existing.isNotEmpty && existing.first == name) {
        if (!added) {
          tags.add(tag);
          added = true;
        }
        continue;
      }

      tags.add(existing);
    }

    if (!added) {
      tags.add(tag);
    }

    return _copyWithTags(event, tags);
  }

  /// Copy of [event] without any tag named after [tag]'s first slot.
  ///
  /// Every same-named tag is removed. `id` and `sig` are cleared because the
  /// canonical serialization changed.
  static NostrEvent withoutTag(NostrEvent event, List<String> tag) {
    if (tag.isEmpty) {
      throw ArgumentError.value(tag, 'tag', 'Tag must have a name');
    }

    final name = tag.first;
    final tags = [
      for (final existing in event.tags ?? const <List<String>>[])
        if (existing.isEmpty || existing.first != name) existing,
    ];

    return _copyWithTags(event, tags);
  }

  static NostrEvent _copyWithTags(NostrEvent event, List<List<String>> tags) {
    return NostrEvent(
      id: null,
      kind: event.kind,
      content: event.content,
      sig: null,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      tags: tags,
      subscriptionId: event.subscriptionId,
      ots: event.ots,
    );
  }
}

/// {@template nostr_event_address}
/// NIP-01 `a` tag address: `kind:pubkey:d`.
///
/// Addressable kinds (30000–39999) require a non-empty identifier. Other
/// kinds use an empty identifier by convention; parsing stays lenient there.
/// {@endtemplate}
class NostrEventAddress {
  /// {@macro nostr_event_address}
  const NostrEventAddress({
    required this.kind,
    required this.pubkey,
    this.identifier = '',
  });

  /// Event kind encoded in the address.
  final int kind;

  /// 64-character lowercase hex author public key.
  final String pubkey;

  /// `d` tag identifier; empty for non-addressable kinds.
  final String identifier;

  /// Whether [kind] is addressable (30000–39999).
  static bool isAddressableKind(int kind) => kind >= 30000 && kind < 40000;

  /// Whether this address points at an addressable event.
  bool get isAddressable => isAddressableKind(kind);

  /// Parses `kind:pubkey:d`, keeping any `:` inside the identifier.
  ///
  /// Returns `null` when [address] is malformed, the kind is not a number,
  /// the pubkey is not 64 lowercase hex characters, or an addressable kind
  /// has an empty identifier.
  static NostrEventAddress? tryParse(String? address) {
    if (address == null) {
      return null;
    }

    final firstSeparator = address.indexOf(':');
    if (firstSeparator <= 0) {
      return null;
    }

    final secondSeparator = address.indexOf(':', firstSeparator + 1);
    if (secondSeparator < 0) {
      return null;
    }

    final kind = int.tryParse(address.substring(0, firstSeparator));
    final pubkey = address.substring(firstSeparator + 1, secondSeparator);
    final identifier = address.substring(secondSeparator + 1);

    if (kind == null || kind < 0 || !NostrValidators.isHex64(pubkey)) {
      return null;
    }

    if (isAddressableKind(kind) && identifier.isEmpty) {
      return null;
    }

    return NostrEventAddress(
      kind: kind,
      pubkey: pubkey,
      identifier: identifier,
    );
  }

  /// Parses `kind:pubkey:d`, throwing [FormatException] when invalid.
  static NostrEventAddress parse(String address) {
    final parsed = tryParse(address);

    if (parsed == null) {
      throw FormatException('Invalid event address: $address');
    }

    return parsed;
  }

  /// Builds `kind:pubkey:d`.
  ///
  /// Throws [ArgumentError] for a malformed pubkey or an addressable kind
  /// without an identifier.
  static String build({
    required int kind,
    required String pubkey,
    String identifier = '',
  }) {
    if (kind < 0) {
      throw ArgumentError.value(kind, 'kind', 'Kind must not be negative');
    }

    if (!NostrValidators.isHex64(pubkey)) {
      throw ArgumentError.value(
        pubkey,
        'pubkey',
        'Expected 64 lowercase hex characters',
      );
    }

    if (isAddressableKind(kind) && identifier.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Addressable kinds require a non-empty d tag',
      );
    }

    return '$kind:$pubkey:$identifier';
  }

  /// This address serialized as `kind:pubkey:d`.
  String get address => '$kind:$pubkey:$identifier';

  @override
  String toString() => address;
}

/// {@template nostr_validators}
/// Small validators shared by newer NIP implementations.
/// {@endtemplate}
class NostrValidators {
  const NostrValidators._();

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Whether [value] is exactly 64 lowercase hex characters.
  static bool isHex64(String? value) => value != null && _hex64.hasMatch(value);

  /// Parses a non-negative UNIX timestamp in seconds from an [int] or string.
  static int? tryUnixSeconds(Object? value) {
    final parsed = switch (value) {
      final int seconds => seconds,
      final String text => int.tryParse(text.trim()),
      _ => null,
    };

    if (parsed == null || parsed < 0) {
      return null;
    }

    return parsed;
  }

  /// Parses an ISO-8601 date string, returning `null` for anything else.
  static DateTime? tryIsoDate(Object? value) {
    if (value is! String) {
      return null;
    }

    return DateTime.tryParse(value.trim());
  }

  /// Parses an [int] or numeric string within the optional [min]/[max], or
  /// `null`.
  static int? tryInt(Object? value, {int? min, int? max}) {
    final parsed = switch (value) {
      final int number => number,
      final String text => int.tryParse(text.trim()),
      _ => null,
    };

    if (parsed == null) {
      return null;
    }

    if (min != null && parsed < min) {
      return null;
    }

    if (max != null && parsed > max) {
      return null;
    }

    return parsed;
  }

  /// Whether [value] equals its own lowercase form.
  static bool isLowercase(String value) => value == value.toLowerCase();

  /// Parses an absolute `http`/`https` URL with a host (NIP-23/NIP-73 links).
  static Uri? tryHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    return uri;
  }

  /// Canonical form of an `http`/`https` URL (NIP-23/NIP-73 deduplication).
  ///
  /// Lowercases scheme and host, drops default ports and the fragment, keeps
  /// path and query. Returns `null` for anything that is not an http(s) URL.
  static String? normalizeUrl(String value) {
    final uri = tryHttpUrl(value);

    if (uri == null) {
      return null;
    }

    final normalized = uri.replace(fragment: '').toString();

    return normalized.endsWith('#')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  /// Whether [value] is a `ws`/`wss` relay URL with a host (NIP-01/NIP-65).
  static bool isRelayUrl(String value) {
    final uri = Uri.tryParse(value.trim());

    return uri != null &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'ws' || uri.scheme == 'wss');
  }

  static final RegExp _geohash = RegExp(r'^[0-9bcdefghjkmnpqrstuvwxyz]{1,12}$');

  /// Normalized lowercase geohash, or `null` (NIP-52 calendar locations).
  ///
  /// Accepts 1–12 characters from the geohash base32 alphabet; `a`, `i`, `l`
  /// and `o` are not part of it and are rejected.
  static String? tryGeohash(String value) {
    final normalized = value.trim().toLowerCase();

    return _geohash.hasMatch(normalized) ? normalized : null;
  }

  /// Day number for [unixSeconds], floored so negative values stay ordered.
  static int dayIndex(int unixSeconds) => (unixSeconds / 86400).floor();
}
