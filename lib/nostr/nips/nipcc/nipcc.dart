import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_geocache_verification_ref}
/// NIP-CC composite `a` value: `<finder-pubkey-hex>:<geocache-naddr>`.
///
/// This is the only place NIP-CC departs from `kind:pubkey:d` addresses, so
/// the parser is local instead of reusing [NostrEventAddress]. It validates the
/// finder as 64 lowercase hex characters and the second half as a bech32
/// `naddr` shape; it does not decode the naddr checksum.
/// {@endtemplate}
class NostrGeocacheVerificationRef {
  /// {@macro nostr_geocache_verification_ref}
  const NostrGeocacheVerificationRef({
    required this.finderPubkey,
    required this.naddr,
  });

  static final RegExp _naddr = RegExp(
    r'^naddr1[02-9ac-hj-np-z]+$',
  );

  /// Finder public key, 64 lowercase hex characters.
  final String finderPubkey;

  /// Bech32 `naddr` of the geocache listing.
  final String naddr;

  /// `<finder-pubkey-hex>:<naddr>`.
  String get value => '$finderPubkey:$naddr';

  /// Parses a composite value, or returns `null` when malformed.
  static NostrGeocacheVerificationRef? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    final separator = value.indexOf(':');
    if (separator <= 0) {
      return null;
    }

    final finder = value.substring(0, separator);
    final naddr = value.substring(separator + 1);

    if (!NostrValidators.isHex64(finder) || !_naddr.hasMatch(naddr)) {
      return null;
    }

    return NostrGeocacheVerificationRef(
      finderPubkey: finder,
      naddr: naddr,
    );
  }

  /// Parses a composite value, throwing [ArgumentError] when malformed.
  static NostrGeocacheVerificationRef parse(String value) {
    final parsed = tryParse(value);

    if (parsed == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Expected <64-hex-pubkey>:<naddr>',
      );
    }

    return parsed;
  }

  @override
  String toString() => value;
}

/// {@template nostr_geocache_verification}
/// Parsed NIP-CC verification event (kind 7517).
///
/// The event is signed by the cache's verification key and proves physical
/// presence. [finderPubkey] and [naddr] come from the composite `a` tag;
/// [content] must be exactly `Geocache verification for <finder-npub>`.
/// {@endtemplate}
class NostrGeocacheVerification {
  /// {@macro nostr_geocache_verification}
  const NostrGeocacheVerification({
    this.id,
    required this.pubkey,
    required this.finderPubkey,
    required this.naddr,
    required this.content,
    this.createdAt,
    this.sig,
    this.tags = const [],
  });

  /// Static content prefix required by CC.md.
  static const String contentPrefix = 'Geocache verification for ';

  static final RegExp _npub = RegExp(r'^npub1[02-9ac-hj-np-z]+$');

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key: the cache verification key.
  final String pubkey;

  /// Finder public key from the composite `a` tag.
  final String finderPubkey;

  /// Geocache `naddr` from the composite `a` tag.
  final String naddr;

  /// Verification content.
  final String content;

  /// Event creation time.
  final DateTime? createdAt;

  /// Event signature.
  final String? sig;

  /// Raw tag list.
  final List<List<String>> tags;

  /// `<finder-pubkey-hex>:<naddr>`.
  String get reference => '$finderPubkey:$naddr';

  /// Builds the exact content string for [finderNpub].
  static String contentFor(String finderNpub) => '$contentPrefix$finderNpub';

  /// Whether [content] has the static format with a bech32 npub.
  static bool isVerificationContent(String content) =>
      npubFromContent(content) != null;

  /// Finder npub from [content], or `null` when it does not match the format.
  static String? npubFromContent(String content) {
    if (!content.startsWith(contentPrefix)) {
      return null;
    }

    final npub = content.substring(contentPrefix.length);

    return _npub.hasMatch(npub) ? npub : null;
  }

  /// Parses a kind-7517 event, throwing [ArgumentError] when invalid.
  static NostrGeocacheVerification parse(NostrEvent event) {
    final parsed = tryParseEvent(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-CC verification event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrGeocacheVerification? tryParseEvent(NostrEvent event) {
    if (event.kind != NostrNipCC.verificationKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final reference = NostrGeocacheVerificationRef.tryParse(
      NostrTags.first(tags, 'a'),
    );

    if (reference == null) {
      return null;
    }

    if (!isVerificationContent(event.content ?? '')) {
      return null;
    }

    return NostrGeocacheVerification(
      id: event.id,
      pubkey: event.pubkey,
      finderPubkey: reference.finderPubkey,
      naddr: reference.naddr,
      content: event.content ?? '',
      createdAt: event.createdAt,
      sig: event.sig,
      tags: tags,
    );
  }
}

/// {@template nostr_geocache}
/// Parsed NIP-CC geocache listing (kind 37516).
///
/// [geohashes] keeps every `g` tag, [difficulty]/[terrain] the `D`/`T`
/// scores, [size] the `S` value and [type] the first non-`archived` `t` value
/// with `traditional` as the documented default. [modifiers] lists the `n`
/// type modifiers with extras dropped (first per category wins) and
/// [firstToFind] the locked-in `F` winner.
///
/// The listing does not infer lifecycle state from logs; only the explicit
/// `t`/`F` tags are reflected.
/// {@endtemplate}
class NostrGeocache {
  /// {@macro nostr_geocache}
  const NostrGeocache({
    this.id,
    required this.pubkey,
    required this.dTag,
    required this.name,
    required this.geohashes,
    required this.difficulty,
    required this.terrain,
    required this.size,
    this.type = 'traditional',
    this.types = const [],
    this.modifiers = const [],
    this.hint,
    this.mission,
    this.images = const [],
    this.relays = const [],
    this.verificationPubkey,
    this.firstToFind,
    this.content = '',
    this.createdAt,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Cache owner public key.
  final String pubkey;

  /// `d` tag: cache identifier.
  final String dTag;

  /// `name` tag.
  final String name;

  /// `g` tags, in event order.
  final List<String> geohashes;

  /// `D` tag: 1-5 finding difficulty.
  final int difficulty;

  /// `T` tag: 1-5 terrain difficulty.
  final int terrain;

  /// `S` tag: `micro`, `small`, `regular`, `large` or `other`.
  final String size;

  /// Cache type, `traditional` when no non-`archived` `t` tag is present.
  final String type;

  /// Every `t` tag value, in event order.
  final List<String> types;

  /// `n` type modifiers, in event order.
  final List<String> modifiers;

  /// `hint` tag.
  final String? hint;

  /// First `mission` tag, when present.
  final String? mission;

  /// `image` tag values.
  final List<String> images;

  /// `r` tag values: preferred log relays.
  final List<String> relays;

  /// `verification` tag: hex verification public key.
  final String? verificationPubkey;

  /// `F` tag: locked-in first-to-find winner public key.
  final String? firstToFind;

  /// Cache description.
  final String content;

  /// Event creation time.
  final DateTime? createdAt;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether the `first-to-find` claim modifier is present.
  bool get isFirstToFind => modifiers.contains('first-to-find');

  /// Whether the cache is a physical artwork (`art` modifier).
  bool get isArt => modifiers.contains('art');

  /// Whether the listing carries the explicit `archived` type tag.
  bool get isArchived => types.contains('archived');

  /// Whether finds can be cryptographically verified.
  bool get requiresVerification => verificationPubkey != null;

  /// Parses a kind-37516 event, throwing [ArgumentError] when invalid.
  static NostrGeocache parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-CC geocache listing event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrGeocache? tryParse(NostrEvent event) {
    if (event.kind != NostrNipCC.cacheKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    final name = NostrTags.first(tags, 'name');

    if (dTag == null || dTag.isEmpty || name == null || name.isEmpty) {
      return null;
    }

    final geohashes = NostrTags.all(tags, 'g');
    if (!NostrNipCC.areCacheGeohashes(geohashes)) {
      return null;
    }

    final difficulty = NostrValidators.tryInt(
      NostrTags.first(tags, 'D'),
      min: 1,
      max: 5,
    );
    final terrain = NostrValidators.tryInt(
      NostrTags.first(tags, 'T'),
      min: 1,
      max: 5,
    );
    final size = NostrTags.first(tags, 'S');

    if (difficulty == null ||
        terrain == null ||
        !NostrNipCC.sizes.contains(size)) {
      return null;
    }

    final types = NostrTags.all(tags, 't');
    final type = NostrNipCC.cacheTypeOf(types);
    final rawModifiers = NostrTags.all(tags, 'n');
    if (!NostrNipCC.areModifiersValid(rawModifiers)) {
      return null;
    }
    final modifiers = NostrNipCC.normalizeModifiers(rawModifiers);

    final verificationPubkey = NostrTags.first(tags, 'verification');
    if (verificationPubkey != null &&
        !NostrValidators.isHex64(verificationPubkey)) {
      return null;
    }

    final firstToFind = NostrTags.first(tags, 'F');
    if (firstToFind != null && !NostrValidators.isHex64(firstToFind)) {
      return null;
    }

    if (firstToFind != null &&
        (!modifiers.contains('first-to-find') || verificationPubkey == null)) {
      return null;
    }

    return NostrGeocache(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      name: name,
      geohashes: List<String>.unmodifiable(geohashes),
      difficulty: difficulty,
      terrain: terrain,
      size: size!,
      type: type,
      types: List<String>.unmodifiable(types),
      modifiers: List<String>.unmodifiable(modifiers),
      hint: NostrTags.first(tags, 'hint'),
      mission: NostrTags.first(tags, 'mission'),
      images: NostrTags.all(tags, 'image'),
      relays: NostrTags.all(tags, 'r'),
      verificationPubkey: verificationPubkey,
      firstToFind: firstToFind,
      content: event.content ?? '',
      createdAt: event.createdAt,
      tags: tags,
    );
  }
}

/// {@template nostr_geocache_found_log}
/// Parsed NIP-CC found log (kind 7516).
///
/// [address] is the `a` tag pointing at the kind-37516 cache. [verification]
/// is the optional embedded kind-7517 event and [proof] its parsed form;
/// [isVerified] is structural, while [isVerifiedFor] also checks the cache
/// verification key.
/// {@endtemplate}
class NostrGeocacheFoundLog {
  /// {@macro nostr_geocache_found_log}
  const NostrGeocacheFoundLog({
    this.id,
    required this.pubkey,
    required this.address,
    this.content = '',
    this.images = const [],
    this.verification,
    this.createdAt,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Finder public key.
  final String pubkey;

  /// `a` tag: cache coordinate.
  final NostrEventAddress address;

  /// Log message; may contain JSON.
  final String content;

  /// `image` tag values.
  final List<String> images;

  /// Embedded kind-7517 verification event.
  final NostrEvent? verification;

  /// Event creation time.
  final DateTime? createdAt;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether a structurally valid embedded verification event is present.
  ///
  /// This checks the event shape only; a proof signed by another key still
  /// counts. Use [isVerifiedFor] or [NostrNipCC.validateVerifiedFind] before
  /// treating a log as a verified find.
  bool get isVerified => proof != null;

  /// Whether the embedded proof parses and is authored by [cache]'s
  /// verification key.
  ///
  /// This is the cache-aware check used by the first-to-find winner path. The
  /// event signature itself is not validated here; call
  /// `NostrEvent.isVerified()` when cryptographic authenticity is required.
  bool isVerifiedFor(NostrGeocache cache) {
    final key = cache.verificationPubkey;
    final verification = proof;

    return key != null && verification != null && verification.pubkey == key;
  }

  /// Parsed embedded verification event, when valid.
  NostrGeocacheVerification? get proof {
    final event = verification;

    return event == null
        ? null
        : NostrGeocacheVerification.tryParseEvent(event);
  }

  /// Parses a kind-7516 event, throwing [ArgumentError] when invalid.
  static NostrGeocacheFoundLog parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-CC found log event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrGeocacheFoundLog? tryParse(NostrEvent event) {
    if (event.kind != NostrNipCC.foundLogKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final address = NostrEventAddress.tryParse(NostrTags.first(tags, 'a'));
    if (address == null || address.kind != NostrNipCC.cacheKind) {
      return null;
    }

    final rawVerification = NostrTags.first(tags, 'verification');
    NostrEvent? verification;
    if (rawVerification != null) {
      verification = NostrNipCC.decodeEventJson(rawVerification);
      if (verification == null) {
        return null;
      }
    }

    return NostrGeocacheFoundLog(
      id: event.id,
      pubkey: event.pubkey,
      address: address,
      content: event.content ?? '',
      images: NostrTags.all(tags, 'image'),
      verification: verification,
      createdAt: event.createdAt,
      tags: tags,
    );
  }
}

/// {@template nostr_geocache_comment}
/// Parsed NIP-CC comment log (kind 1111).
///
/// For top-level cache logs the root `A`/`K`/`P` tags and parent `a`/`k`/`p`
/// tags are identical. [logType] is the `t` value, `note` when absent.
/// {@endtemplate}
class NostrGeocacheComment {
  /// {@macro nostr_geocache_comment}
  const NostrGeocacheComment({
    this.id,
    required this.pubkey,
    required this.address,
    this.logType = 'note',
    this.content = '',
    this.images = const [],
    this.createdAt,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Log author public key.
  final String pubkey;

  /// Cache coordinate shared by the root and parent tags.
  final NostrEventAddress address;

  /// `t` tag: `dnf`, `note`, `maintenance` or `archived`.
  final String logType;

  /// Log message.
  final String content;

  /// `image` tag values.
  final List<String> images;

  /// Event creation time.
  final DateTime? createdAt;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses a kind-1111 geocache log, throwing [ArgumentError] when invalid.
  static NostrGeocacheComment parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-CC comment log event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrGeocacheComment? tryParse(NostrEvent event) {
    if (event.kind != NostrNipCC.commentKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final root = NostrEventAddress.tryParse(NostrTags.first(tags, 'A'));
    final parent = NostrEventAddress.tryParse(NostrTags.first(tags, 'a'));

    if (root == null ||
        parent == null ||
        root.kind != NostrNipCC.cacheKind ||
        root.address != parent.address) {
      return null;
    }

    if (NostrTags.first(tags, 'K') != '${NostrNipCC.cacheKind}' ||
        NostrTags.first(tags, 'k') != '${NostrNipCC.cacheKind}') {
      return null;
    }

    final owner = NostrTags.first(tags, 'P');
    if (!NostrValidators.isHex64(owner) ||
        NostrTags.first(tags, 'p') != owner) {
      return null;
    }

    return NostrGeocacheComment(
      id: event.id,
      pubkey: event.pubkey,
      address: root,
      logType: NostrTags.first(tags, 't') ?? 'note',
      content: event.content ?? '',
      images: NostrTags.all(tags, 'image'),
      createdAt: event.createdAt,
      tags: tags,
    );
  }
}

/// {@template nostr_geocache_curation}
/// Parsed NIP-CC curation list (kind 37517).
///
/// [geocaches] preserves the `a` tag order, which CC.md marks as meaningful.
/// [theme] and [mapStyle] carry the optional display defaults.
/// {@endtemplate}
class NostrGeocacheCuration {
  /// {@macro nostr_geocache_curation}
  const NostrGeocacheCuration({
    this.id,
    required this.pubkey,
    required this.dTag,
    required this.title,
    required this.geocaches,
    this.description,
    this.image,
    this.geohashes = const [],
    this.theme,
    this.mapStyle,
    this.content = '',
    this.createdAt,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// List author public key.
  final String pubkey;

  /// `d` tag: list identifier.
  final String dTag;

  /// `title` tag.
  final String title;

  /// `a` tags referencing kind-37516/37515 geocaches, in order.
  final List<NostrEventAddress> geocaches;

  /// `description` tag.
  final String? description;

  /// `image` tag.
  final String? image;

  /// `g` tag values.
  final List<String> geohashes;

  /// `theme` tag: `adventure` or `mojave`.
  final String? theme;

  /// `map` tag: `original`, `dark`, `satellite` or `adventure`.
  final String? mapStyle;

  /// List description.
  final String content;

  /// Event creation time.
  final DateTime? createdAt;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses a kind-37517 event, throwing [ArgumentError] when invalid.
  static NostrGeocacheCuration parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-CC curation list event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrGeocacheCuration? tryParse(NostrEvent event) {
    if (event.kind != NostrNipCC.curationKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    final title = NostrTags.first(tags, 'title');

    if (dTag == null || dTag.isEmpty || title == null || title.isEmpty) {
      return null;
    }

    final geohashes = NostrTags.all(tags, 'g');
    if (!NostrNipCC.areCurationGeohashes(geohashes)) {
      return null;
    }

    final geocaches = <NostrEventAddress>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'a') {
        continue;
      }

      final address = NostrEventAddress.tryParse(NostrTags.at(tag, 1));
      if (address == null || !NostrNipCC.isGeocacheReference(address)) {
        return null;
      }
      geocaches.add(address);
    }

    if (geocaches.isEmpty) {
      return null;
    }

    final theme = NostrTags.first(tags, 'theme');
    final mapStyle = NostrTags.first(tags, 'map');

    if (theme != null && !NostrNipCC.themes.contains(theme)) {
      return null;
    }

    if (mapStyle != null && !NostrNipCC.mapStyles.contains(mapStyle)) {
      return null;
    }

    return NostrGeocacheCuration(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      title: title,
      geocaches: List<NostrEventAddress>.unmodifiable(geocaches),
      description: NostrTags.first(tags, 'description'),
      image: NostrTags.first(tags, 'image'),
      geohashes: List<String>.unmodifiable(geohashes),
      theme: theme,
      mapStyle: mapStyle,
      content: event.content ?? '',
      createdAt: event.createdAt,
      tags: tags,
    );
  }
}

/// {@template nostr_geocache_validation}
/// Structural validation result for a NIP-CC verified find.
///
/// [valid] is `true` only when [problems] is empty. Signature verification is
/// deliberately out of scope; call `NostrEvent.isVerified()` on the
/// verification event when authenticity matters.
/// {@endtemplate}
class NostrGeocacheValidation {
  /// {@macro nostr_geocache_validation}
  const NostrGeocacheValidation({required this.problems});

  /// Human-readable problems. Empty when [valid].
  final List<String> problems;

  /// Whether no problem was found.
  bool get valid => problems.isEmpty;
}

/// {@template nipcc}
/// NIP-CC geocaching events.
///
/// - kind 37516: cache listing (`d`, `name`, repeatable `g`, `D`/`T` 1-5,
///   `S`, optional `t`/`n`/`hint`/`mission`/`image`/`r`/`verification`/`F`).
/// - kind 7516: found log with an optional embedded kind-7517 proof.
/// - kind 1111: DNF/note/maintenance/archived comment with root and parent
///   tags both pointing at the cache.
/// - kind 7517: verification event signed by the cache verification key.
/// - kind 37517: curation list.
///
/// The `F` winner and first-to-find ordering follow CC.md: the earliest
/// verified found log wins (ties by ascending event id) until the listing
/// locks a winner with `F`. A log counts as verified only when its embedded
/// kind-7517 proof is authored by the listing's `verification` key; proof-less
/// or foreign-key proofs are unverified.
/// {@endtemplate}
class NostrNipCC {
  /// {@macro nipcc}
  NostrNipCC({required this.signer, NostrBech32? bech32})
      : bech32 = bech32 ?? NostrBech32();

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// NIP-19 encoder used to build npub/naddr values for verification events.
  final NostrBech32 bech32;

  /// Cache listing kind.
  static const int cacheKind = 37516;

  /// Found log kind.
  static const int foundLogKind = 7516;

  /// Comment log kind (NIP-22).
  static const int commentKind = 1111;

  /// Verification event kind.
  static const int verificationKind = 7517;

  /// Curation list kind.
  static const int curationKind = 37517;

  /// Kinds this NIP defines.
  static const List<int> kinds = [
    cacheKind,
    foundLogKind,
    commentKind,
    verificationKind,
    curationKind,
  ];

  /// Cache sizes allowed by the `S` tag.
  static const Set<String> sizes = {
    'micro',
    'small',
    'regular',
    'large',
    'other',
  };

  /// Claim modifiers: at most one `n` value per category.
  static const Map<String, Set<String>> modifierCategories = {
    'claim': {'first-to-find'},
    'prize': {'art'},
  };

  /// Comment log types defined by CC.md.
  static const Set<String> logTypes = {
    'dnf',
    'note',
    'maintenance',
    'archived',
  };

  /// Supported `theme` values.
  static const Set<String> themes = {'adventure', 'mojave'};

  /// Supported `map` values.
  static const Set<String> mapStyles = {
    'original',
    'dark',
    'satellite',
    'adventure',
  };

  /// Whether [address] points at a cache listing or another curation list.
  static bool isGeocacheReference(NostrEventAddress address) =>
      address.kind == cacheKind || address.kind == 37515;

  /// Whether [geohashes] are all 3-9 character cache geohashes.
  static bool areCacheGeohashes(List<String> geohashes) =>
      geohashes.isNotEmpty && geohashes.every(_isCacheGeohash);

  /// Whether [geohashes] are all 3-6 character curation geohashes.
  static bool areCurationGeohashes(List<String> geohashes) =>
      geohashes.every(_isCurationGeohash);

  /// `t` value to use as the cache type, `traditional` when none applies.
  static String cacheTypeOf(List<String> types) {
    for (final type in types) {
      if (type != 'archived') {
        return type;
      }
    }

    return 'traditional';
  }

  /// Whether every modifier value is non-blank.
  ///
  /// Duplicates are not an error: CC.md tells clients to use the first value
  /// per category and ignore the rest, which [normalizeModifiers] does.
  static bool areModifiersValid(List<String> modifiers) =>
      modifiers.every((modifier) => modifier.trim().isNotEmpty);

  /// First occurrence of each modifier, at most one per known category.
  ///
  /// Unknown modifiers are kept once; repeated values are ignored.
  static List<String> normalizeModifiers(List<String> modifiers) {
    final seen = <String>{};
    final categories = <String>{};
    final normalized = <String>[];

    for (final modifier in modifiers) {
      final value = modifier.trim();
      if (value.isEmpty || !seen.add(value)) {
        continue;
      }

      String? category;
      for (final entry in modifierCategories.entries) {
        if (entry.value.contains(value)) {
          category = entry.key;
          break;
        }
      }

      if (category != null && !categories.add(category)) {
        continue;
      }

      normalized.add(value);
    }

    return normalized;
  }

  /// Decodes an embedded verification event JSON object, or `null`.
  static NostrEvent? decodeEventJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final kind = decoded['kind'];
      final pubkey = decoded['pubkey'];
      if (kind is! int || pubkey is! String) {
        return null;
      }

      final rawTags = decoded['tags'];
      final tags = <List<String>>[];
      if (rawTags is List) {
        for (final tag in rawTags) {
          if (tag is List) {
            tags.add([for (final item in tag) '$item']);
          }
        }
      }

      final createdAt = decoded['created_at'];

      return NostrEvent(
        id: decoded['id'] as String?,
        kind: kind,
        content:
            decoded['content'] is String ? decoded['content'] as String : '',
        sig: decoded['sig'] as String?,
        pubkey: pubkey,
        createdAt: createdAt is int
            ? DateTime.fromMillisecondsSinceEpoch(createdAt * 1000)
            : null,
        tags: tags,
      );
    } on FormatException {
      return null;
    }
  }

  /// Serializes an embedded verification event in the CC.md key order.
  ///
  /// The event `id` is omitted by design: CC.md lists only `kind`, `content`,
  /// `tags`, `pubkey`, `created_at` and `sig` for the embedded form.
  static String encodeEventJson(NostrEvent event) {
    return jsonEncode({
      'kind': event.kind,
      'content': event.content ?? '',
      'tags': event.tags ?? const <List<String>>[],
      'pubkey': event.pubkey,
      'created_at': (event.createdAt?.millisecondsSinceEpoch ?? 0) ~/ 1000,
      if (event.sig != null) 'sig': event.sig,
    });
  }

  /// Builds an unsigned kind-37516 cache listing.
  ///
  /// Tags follow the CC.md listing order. `F` requires both the
  /// `first-to-find` modifier and a `verification` key, as the spec states.
  ///
  /// Throws [ArgumentError] for invalid scores, sizes, geohashes, keys, blank
  /// modifiers or an `F` tag without its prerequisites. Duplicate modifiers
  /// are collapsed to the first occurrence per category instead of thrown.
  static NostrEvent generateCacheTemplate({
    required String dTag,
    required String name,
    required List<String> geohashes,
    required int difficulty,
    required int terrain,
    required String size,
    String type = 'traditional',
    List<String> modifiers = const [],
    String? hint,
    String? mission,
    List<String> images = const [],
    List<String> relays = const [],
    String? verificationPubkey,
    String? firstToFind,
    String content = '',
    DateTime? createdAt,
  }) {
    if (dTag.trim().isEmpty) {
      throw ArgumentError.value(dTag, 'dTag', 'Cache id is empty');
    }

    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Cache name is empty');
    }

    if (!areCacheGeohashes(geohashes)) {
      throw ArgumentError.value(
        geohashes,
        'geohashes',
        'Cache geohashes must be 3-9 characters from the geohash alphabet',
      );
    }

    _checkScore(difficulty, 'difficulty');
    _checkScore(terrain, 'terrain');

    if (!sizes.contains(size)) {
      throw ArgumentError.value(size, 'size', 'Unknown cache size');
    }

    if (type.trim().isEmpty) {
      throw ArgumentError.value(type, 'type', 'Cache type is empty');
    }

    if (!areModifiersValid(modifiers)) {
      throw ArgumentError.value(
        modifiers,
        'modifiers',
        'Modifiers must not be blank',
      );
    }
    final normalizedModifiers = normalizeModifiers(modifiers);

    _checkImages(images);

    for (final relay in relays) {
      if (!NostrValidators.isRelayUrl(relay)) {
        throw ArgumentError.value(relay, 'relays', 'Expected a relay URL');
      }
    }

    if (verificationPubkey != null &&
        !NostrValidators.isHex64(verificationPubkey)) {
      throw ArgumentError.value(
        verificationPubkey,
        'verificationPubkey',
        'Expected a 64 lowercase hex public key',
      );
    }

    if (firstToFind != null) {
      if (!NostrValidators.isHex64(firstToFind)) {
        throw ArgumentError.value(
          firstToFind,
          'firstToFind',
          'Expected a 64 lowercase hex public key',
        );
      }

      if (!normalizedModifiers.contains('first-to-find') ||
          verificationPubkey == null) {
        throw ArgumentError.value(
          firstToFind,
          'firstToFind',
          'An F winner requires the first-to-find modifier and a verification '
              'key',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: cacheKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        ['name', name],
        for (final geohash in geohashes) ['g', geohash],
        ['D', '$difficulty'],
        ['T', '$terrain'],
        ['S', size],
        ['t', type],
        for (final modifier in normalizedModifiers) ['n', modifier],
        if (hint != null) ['hint', hint],
        if (mission != null) ['mission', mission],
        for (final image in images) ['image', image],
        for (final relay in relays) ['r', relay],
        if (verificationPubkey != null) ['verification', verificationPubkey],
        if (firstToFind != null) ['F', firstToFind],
      ],
    );
  }

  /// Builds an unsigned kind-7516 found log.
  ///
  /// [cache] must be a kind-37516 coordinate. [verification] must be a
  /// kind-7517 event when supplied.
  static NostrEvent generateFoundLogTemplate({
    required NostrEventAddress cache,
    String content = '',
    List<String> images = const [],
    NostrEvent? verification,
    DateTime? createdAt,
  }) {
    _requireCacheAddress(cache, 'cache');

    if (verification != null && verification.kind != verificationKind) {
      throw ArgumentError.value(
        verification.kind,
        'verification',
        'Embedded verification must be a kind 7517 event',
      );
    }

    _checkImages(images);

    return NostrEvent(
      id: null,
      kind: foundLogKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['a', cache.address],
        for (final image in images) ['image', image],
        if (verification != null)
          ['verification', encodeEventJson(verification)],
      ],
    );
  }

  /// Builds an unsigned kind-1111 comment log.
  ///
  /// Root `A`/`K`/`P` and parent `a`/`k`/`p` all point at [cache], because
  /// CC.md treats the listing as both root and parent for top-level logs.
  static NostrEvent generateCommentTemplate({
    required NostrEventAddress cache,
    required String content,
    String logType = 'note',
    List<String> images = const [],
    DateTime? createdAt,
  }) {
    _requireCacheAddress(cache, 'cache');

    if (!logTypes.contains(logType)) {
      throw ArgumentError.value(logType, 'logType', 'Unknown comment log type');
    }

    _checkImages(images);

    final owner = cache.pubkey;

    return NostrEvent(
      id: null,
      kind: commentKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['A', cache.address],
        ['K', '$cacheKind'],
        ['P', owner],
        ['a', cache.address],
        ['k', '$cacheKind'],
        ['p', owner],
        ['t', logType],
        for (final image in images) ['image', image],
      ],
    );
  }

  /// Builds an unsigned kind-7517 verification event.
  ///
  /// The event must be signed by the cache verification key, which is not
  /// necessarily the user signer, so callers publish it with
  /// [publishVerification] or another signer.
  static NostrEvent generateVerificationTemplate({
    required String finderPubkey,
    required NostrEventAddress cache,
    NostrBech32? bech32,
    DateTime? createdAt,
  }) {
    if (!NostrValidators.isHex64(finderPubkey)) {
      throw ArgumentError.value(
        finderPubkey,
        'finderPubkey',
        'Expected a 64 lowercase hex public key',
      );
    }

    _requireCacheAddress(cache, 'cache');
    final encoder = bech32 ?? NostrBech32();
    final naddr = encoder.encodeNAddr(
      kind: cache.kind,
      authorPubkey: cache.pubkey,
      identifier: cache.identifier,
    );

    return NostrEvent(
      id: null,
      kind: verificationKind,
      content: NostrGeocacheVerification.contentFor(
        encoder.encodePublicKeyToNpub(finderPubkey),
      ),
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['a', '$finderPubkey:$naddr'],
      ],
    );
  }

  /// Builds an unsigned kind-37517 curation list.
  ///
  /// [geocaches] order is preserved. Themes and map styles are limited to the
  /// CC.md values and geohashes to 3-6 characters.
  static NostrEvent generateCurationTemplate({
    required String dTag,
    required String title,
    required List<NostrEventAddress> geocaches,
    String content = '',
    String? description,
    String? image,
    List<String> geohashes = const [],
    String? theme,
    String? mapStyle,
    DateTime? createdAt,
  }) {
    if (dTag.trim().isEmpty) {
      throw ArgumentError.value(dTag, 'dTag', 'List id is empty');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'List title is empty');
    }

    if (geocaches.isEmpty) {
      throw ArgumentError.value(
        geocaches,
        'geocaches',
        'At least one geocache reference is required',
      );
    }

    for (final address in geocaches) {
      if (!isGeocacheReference(address)) {
        throw ArgumentError.value(
          address.address,
          'geocaches',
          'References must point to kind 37516 or 37515',
        );
      }
    }

    if (!areCurationGeohashes(geohashes)) {
      throw ArgumentError.value(
        geohashes,
        'geohashes',
        'Curation geohashes must be 3-6 characters from the geohash alphabet',
      );
    }

    if (theme != null && !themes.contains(theme)) {
      throw ArgumentError.value(theme, 'theme', 'Unknown theme');
    }

    if (mapStyle != null && !mapStyles.contains(mapStyle)) {
      throw ArgumentError.value(mapStyle, 'mapStyle', 'Unknown map style');
    }

    return NostrEvent(
      id: null,
      kind: curationKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        ['title', title],
        if (description != null) ['description', description],
        if (image != null) ['image', image],
        for (final geohash in geohashes) ['g', geohash],
        if (theme != null) ['theme', theme],
        if (mapStyle != null) ['map', mapStyle],
        for (final address in geocaches) ['a', address.address],
      ],
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Signs a kind-7517 verification with the cache verification key signer.
  Future<NostrEvent> publishVerification(
    NostrEvent event, {
    required NostrEventSigner verificationSigner,
  }) {
    if (event.kind != verificationKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Expected a kind 7517 verification event',
      );
    }

    return verificationSigner.sign(event);
  }

  /// Verified found logs ordered by `created_at`, then by ascending event id.
  ///
  /// A log counts only when its embedded proof parses and is authored by
  /// [cache]'s verification key; proof-less or foreign-key proofs are
  /// unverified.
  static List<NostrGeocacheFoundLog> sortVerifiedFinds(
    List<NostrGeocacheFoundLog> logs, {
    required NostrGeocache cache,
  }) {
    final verified = [
      for (final log in logs)
        if (log.isVerifiedFor(cache)) log,
    ]..sort((left, right) {
        final byTime = _createdAtOf(left).compareTo(_createdAtOf(right));
        if (byTime != 0) {
          return byTime;
        }

        return (left.id ?? '').compareTo(right.id ?? '');
      });

    return List<NostrGeocacheFoundLog>.unmodifiable(verified);
  }

  /// Earliest verified found log, the provisional first-to-find winner.
  ///
  /// Uses the same cache verification key check as [sortVerifiedFinds].
  static NostrGeocacheFoundLog? firstVerifiedFind(
    List<NostrGeocacheFoundLog> logs, {
    required NostrGeocache cache,
  }) {
    final sorted = sortVerifiedFinds(logs, cache: cache);

    return sorted.isEmpty ? null : sorted.first;
  }

  /// Exclusive claim winner: the `F` key when locked in, else the earliest
  /// verified log author.
  static String? claimWinner({
    required NostrGeocache cache,
    required List<NostrGeocacheFoundLog> logs,
  }) {
    final locked = cache.firstToFind;
    if (locked != null) {
      return locked;
    }

    return firstVerifiedFind(logs, cache: cache)?.pubkey;
  }

  /// Validates a verified find against the cache and its verification key.
  ///
  /// Checks the embedded event kind, the verification-key author, that the
  /// log `a` tag equals [cacheAddress], the finder in the composite `a` tag
  /// against the log author, and the naddr coordinate and npub values against
  /// [cacheAddress] and [log]. Signatures are not checked.
  static NostrGeocacheValidation validateVerifiedFind({
    required NostrGeocacheFoundLog log,
    required NostrGeocache cache,
    required NostrEventAddress cacheAddress,
    NostrBech32? bech32,
  }) {
    final problems = <String>[];
    final verification = log.verification;

    if (cache.verificationPubkey == null) {
      problems.add('cache has no verification key');
    }

    if (log.address.address != cacheAddress.address) {
      problems.add(
        'log address ${log.address.address} does not match the cache '
        'address ${cacheAddress.address}',
      );
    }

    if (verification == null) {
      problems.add('log has no embedded verification event');
      return NostrGeocacheValidation(problems: problems);
    }

    if (verification.kind != verificationKind) {
      problems.add('embedded event is not a kind 7517 verification');
    }

    if (cache.verificationPubkey != null &&
        verification.pubkey != cache.verificationPubkey) {
      problems.add(
        'verification event author ${verification.pubkey} does not match the '
        'cache verification key',
      );
    }

    final proof = NostrGeocacheVerification.tryParseEvent(verification);
    if (proof == null) {
      problems.add('embedded verification event is malformed');
      return NostrGeocacheValidation(problems: problems);
    }

    if (proof.finderPubkey != log.pubkey) {
      problems.add('verification finder does not match the log author');
    }

    final encoder = bech32 ?? NostrBech32();
    if (!_naddrMatchesAddress(proof.naddr, cacheAddress, encoder)) {
      problems.add('verification naddr does not reference the cache');
    }

    final expectedNpub = encoder.encodePublicKeyToNpub(log.pubkey);
    if (proof.content != NostrGeocacheVerification.contentFor(expectedNpub)) {
      problems.add('verification content does not name the finder npub');
    }

    if (cache.firstToFind != null && log.pubkey != cache.firstToFind) {
      problems.add('log author is not the locked-in F winner');
    }

    return NostrGeocacheValidation(problems: problems);
  }

  static bool _naddrMatchesAddress(
    String naddr,
    NostrEventAddress address,
    NostrBech32 encoder,
  ) {
    try {
      final decoded = encoder.decodeNaddrToMap(naddr);

      return decoded['kind'] == address.kind &&
          decoded['pubkey'] == address.pubkey &&
          decoded['identifier'] == address.identifier;
    } on Object catch (_) {
      return false;
    }
  }

  static bool _isCacheGeohash(String value) {
    final normalized = NostrValidators.tryGeohash(value);

    return normalized != null &&
        normalized.length >= 3 &&
        normalized.length <= 9;
  }

  static bool _isCurationGeohash(String value) {
    final normalized = NostrValidators.tryGeohash(value);

    return normalized != null &&
        normalized.length >= 3 &&
        normalized.length <= 6;
  }

  static void _checkScore(int score, String name) {
    if (score < 1 || score > 5) {
      throw ArgumentError.value(score, name, 'Score must be between 1 and 5');
    }
  }

  static void _checkImages(List<String> images) {
    for (final image in images) {
      if (image.trim().isEmpty) {
        throw ArgumentError.value(image, 'images', 'Image URL is empty');
      }
    }
  }

  static void _requireCacheAddress(
    NostrEventAddress address,
    String name,
  ) {
    if (address.kind != cacheKind ||
        (address.isAddressable && address.identifier.isEmpty)) {
      throw ArgumentError.value(
        address.address,
        name,
        'Expected a kind 37516 geocache address with a non-empty identifier',
      );
    }
  }

  static DateTime _createdAtOf(NostrGeocacheFoundLog log) =>
      log.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}
