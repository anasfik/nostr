import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';

/// {@template nip21}
/// NIP-21 `nostr:` URI scheme handling.
///
/// Parses and builds URIs such as:
/// - `nostr:npub1...`
/// - `nostr:nprofile1...`
/// - `nostr:nevent1...`
/// - `nostr:naddr1...`
///
/// Also tolerates bare entities (`npub1...`) without the scheme prefix.
/// {@endtemplate}
class NostrNip21 {
  /// {@macro nip21}
  NostrNip21({NostrBech32? bech32})
      : bech32 = bech32 ??
            NostrBech32(
              logger: _quietLogger(),
            );

  static NostrLogger _quietLogger() {
    final logger = NostrLogger(passedDebugOptions: NostrDebugOptions.general());
    logger.disableLogs();
    return logger;
  }

  static const String uriScheme = 'nostr:';

  /// Reused for entity decoding.
  final NostrBech32 bech32;

  /// Whether the given [uri] is a well-formed nostr URI (or bare entity).
  bool isNostrUri(String uri) {
    return _extractEntity(uri) != null;
  }

  /// Parses a nostr URI (or bare entity) into its components.
  ///
  /// Returns a map with:
  /// - `entity`: the raw bech32 entity without the scheme
  /// - `hrp`: the human readable part (`npub`, `nprofile`, ...)
  /// - `data`: decoded hex payload
  ///
  /// Throws [ArgumentError] on malformed input.
  Map<String, dynamic> parse(String uri) {
    final entity = _extractEntity(uri);

    if (entity == null || entity.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'not a valid nostr URI');
    }

    final decoded = bech32.decodeBech32(entity);

    return {'entity': entity, 'hrp': decoded[1], 'data': decoded[0]};
  }

  /// Parses a nostr URI and additionally decodes known TLV-based entities
  /// (`nprofile`, `nevent`, `naddr`) into their structured maps.
  Map<String, dynamic> parseFully(String uri) {
    final parsed = parse(uri);
    final hrp = parsed['hrp'] as String;
    final entity = parsed['entity'] as String;

    switch (hrp) {
      case NostrConstants.nProfile:
        return {...parsed, 'decoded': bech32.decodeNprofileToMap(entity)};
      case NostrConstants.nEvent:
        return {...parsed, 'decoded': bech32.decodeNeventToMap(entity)};
      case NostrConstants.nAddress:
        return {...parsed, 'decoded': bech32.decodeNaddrToMap(entity)};
      default:
        return parsed;
    }
  }

  /// Builds a nostr URI from an entity string, validating the prefix.
  String build(String entity) {
    final clean = entity.trim();
    if (!clean.startsWith(NostrConstants.npub) &&
        !clean.startsWith(NostrConstants.nsec) &&
        !clean.startsWith(NostrConstants.nProfile) &&
        !clean.startsWith(NostrConstants.nEvent) &&
        !clean.startsWith(NostrConstants.nAddress)) {
      throw ArgumentError.value(
        entity,
        'entity',
        'must be a npub/nsec/nprofile/nevent/naddr entity',
      );
    }
    return '$uriScheme$clean';
  }

  static const List<String> _knownPrefixes = [
    NostrConstants.npub,
    NostrConstants.nsec,
    NostrConstants.nProfile,
    NostrConstants.nEvent,
    NostrConstants.nAddress,
  ];

  String? _extractEntity(String uri) {
    var value = uri.trim();

    // Tolerate uppercase schemes per URI rules.
    if (value.length > uriScheme.length &&
        value.substring(0, uriScheme.length).toLowerCase() == uriScheme) {
      value = value.substring(uriScheme.length);
    }

    if (value.isEmpty) {
      return null;
    }

    // Reject strings that contain whitespace or path separators.
    if (RegExp(r'[\s/?#]').hasMatch(value)) {
      return null;
    }

    final hasKnownPrefix =
        _knownPrefixes.any((prefix) => value.startsWith(prefix));

    if (!hasKnownPrefix) {
      return null;
    }

    return value;
  }
}
