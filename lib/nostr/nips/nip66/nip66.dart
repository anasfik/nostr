import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nostr_relay_timeout}
/// One `timeout` tag of a NIP-66 relay monitor list.
///
/// The prose says index 1 is the timeout in milliseconds and index 2 the check
/// name, while the example writes `["timeout", "open", "5000"]` (66.md:73-88).
/// [tryParse] accepts both orders: whichever slot is numeric is the
/// millisecond value. When both are numeric the prose order wins.
/// {@endtemplate}
class NostrRelayTimeout {
  /// {@macro nostr_relay_timeout}
  const NostrRelayTimeout({required this.milliseconds, this.check});

  /// Timeout in milliseconds.
  final int milliseconds;

  /// Check the timeout applies to, or `null` for all checks.
  ///
  /// An empty string means the slot is present but empty, not absent: [toTag]
  /// emits it so the trailing millisecond slot keeps its position. `null` omits
  /// the slot.
  final String? check;

  /// Serializes to a `timeout` tag in the example's order.
  List<String> toTag() => [
        'timeout',
        if (check != null) check!,
        '$milliseconds',
      ];

  /// Parses a `timeout` tag in either documented order.
  static NostrRelayTimeout? tryParse(List<String> tag) {
    if (tag.length < 2 || tag.first != 'timeout') {
      return null;
    }

    final first = int.tryParse(tag[1]);
    final second = tag.length > 2 ? int.tryParse(tag[2]) : null;

    int? milliseconds;
    String? check;

    if (first != null && second == null) {
      // Prose order: index 1 is the timeout, index 2 the check.
      milliseconds = first;
      check = tag.length > 2 ? tag[2] : null;
    } else if (first == null && second != null) {
      // Example order: index 1 is the check, index 2 the timeout.
      milliseconds = second;
      check = tag[1];
    } else if (first != null && second != null) {
      // Ambiguous; the prose is normative, so slot 1 is the timeout.
      milliseconds = first;
      check = tag[2];
    }

    if (milliseconds == null || milliseconds <= 0) {
      return null;
    }

    return NostrRelayTimeout(milliseconds: milliseconds, check: check);
  }
}

/// {@template nostr_relay_monitor_announcement}
/// Parsed NIP-66 relay discovery event (kind 30166).
///
/// [relay] is the `d` tag normalized per RFC 3986, or a hex pubkey for relays
/// without a URL. [nip11] is the optional NIP-11 document from `content`;
/// malformed JSON is ignored rather than throwing (66.md:15).
/// {@endtemplate}
class NostrRelayMonitorAnnouncement {
  /// {@macro nostr_relay_monitor_announcement}
  const NostrRelayMonitorAnnouncement({
    required this.relay,
    this.pubkey = '',
    this.rttOpen,
    this.rttRead,
    this.rttWrite,
    this.network,
    this.relayTypes = const <String>[],
    this.nips = const <String>[],
    this.requirements = const <String>[],
    this.topics = const <String>[],
    this.kinds = const <String>[],
    this.geohashes = const <String>[],
    this.languages = const <String>[],
    this.nip11,
    this.content = '',
    this.tags = const <List<String>>[],
  });

  /// `d` tag: normalized relay URL or hex pubkey.
  final String relay;

  /// Monitor public key, when parsed from an event.
  final String pubkey;

  /// `rtt-open` in milliseconds.
  final int? rttOpen;

  /// `rtt-read` in milliseconds.
  final int? rttRead;

  /// `rtt-write` in milliseconds.
  final int? rttWrite;

  /// `n` tag: `clearnet`, `tor`, `i2p`, `loki` or an unknown value kept
  /// verbatim because the spec only recommends the enumerated set.
  final String? network;

  /// `T` tags: relay types in PascalCase.
  final List<String> relayTypes;

  /// `N` tags: supported NIP numbers.
  final List<String> nips;

  /// `R` tags: NIP-11 limitations, with `!` marking false values.
  final List<String> requirements;

  /// `t` tags: topics.
  final List<String> topics;

  /// `k` tags: accepted kinds, with `!` marking unaccepted ones.
  final List<String> kinds;

  /// `g` tags: NIP-52 geohashes.
  final List<String> geohashes;

  /// `l` tags: language codes.
  final List<String> languages;

  /// Parsed NIP-11 document, or `null` when absent or malformed.
  final Map<String, dynamic>? nip11;

  /// Raw `content`, kept even when it is not valid JSON.
  final String content;

  /// Tags not consumed by a typed getter, preserved verbatim.
  final List<List<String>> tags;

  /// Whether the `d` tag is a normalized relay URL or a hex pubkey and every
  /// RTT is non-negative. An unknown `n` value is preserved, not fatal.
  bool get isValid =>
      (NostrValidators.isRelayUrl(relay) || NostrValidators.isHex64(relay)) &&
      (rttOpen == null || rttOpen! >= 0) &&
      (rttRead == null || rttRead! >= 0) &&
      (rttWrite == null || rttWrite! >= 0);

  /// Whether [network] is absent or one of the enumerated values.
  bool get hasKnownNetwork =>
      network == null || NostrNip66.networkTypes.contains(network);
}

/// {@template nostr_relay_monitor_list}
/// Parsed NIP-66 relay monitor announcement (kind 10166).
///
/// [frequency] is the publishing cadence in seconds, [timeouts] the per-check
/// timeouts and [checks] the `c` values describing what the monitor probes.
/// {@endtemplate}
class NostrRelayMonitorList {
  /// {@macro nostr_relay_monitor_list}
  const NostrRelayMonitorList({
    required this.frequency,
    this.pubkey = '',
    this.timeouts = const <NostrRelayTimeout>[],
    this.checks = const <String>[],
    this.geohashes = const <String>[],
    this.tags = const <List<String>>[],
  });

  /// `frequency` tag in seconds.
  final int frequency;

  /// Monitor public key, when parsed from an event.
  final String pubkey;

  /// `timeout` tags.
  final List<NostrRelayTimeout> timeouts;

  /// `c` tags: checks the monitor conducts.
  final List<String> checks;

  /// `g` tags: monitor geohashes.
  final List<String> geohashes;

  /// Tags not consumed by a typed getter, preserved verbatim.
  final List<List<String>> tags;

  /// Whether the frequency and every timeout are positive.
  bool get isValid =>
      frequency > 0 && timeouts.every((timeout) => timeout.milliseconds > 0);
}

/// {@template nip66}
/// NIP-66 relay liveness monitoring (kinds 30166 and 10166).
///
/// The module is read-only and stateless: it normalizes relay identifiers,
/// builds unsigned monitor events and parses/verifies published ones.
/// Builders return templates; sign them before publishing because monitor
/// events are authored assertions (verify helpers require a signature by
/// default).
///
/// Client rule (documented, not enforced): monitoring data is optional.
/// Clients MUST NOT require kind-30166 events and their absence MUST NOT block
/// relay connections or filter relays out (66.md:91-94). Nothing in this
/// module is consulted by the transport layer.
/// {@endtemplate}
class NostrNip66 {
  /// {@macro nip66}
  const NostrNip66();

  /// Kind 30166: relay discovery event.
  static const int discoveryKind = 30166;

  /// Kind 10166: relay monitor announcement.
  static const int monitorListKind = 10166;

  /// `n` values enumerated by 66.md:27.
  static const Set<String> networkTypes = {'clearnet', 'tor', 'i2p', 'loki'};

  /// RTT tag names mapped to their parser slot.
  static const List<String> rttTags = ['rtt-open', 'rtt-read', 'rtt-write'];

  /// Canonical `d` value for a relay URL or a hex relay pubkey.
  ///
  /// Hex pubkeys are lowercased and returned as-is. URLs are lowercased,
  /// stripped of default ports and fragments, and keep their path and query.
  /// Returns `null` for anything that is neither.
  static String? normalizeRelayIdentifier(String value) {
    final trimmed = value.trim();

    if (NostrValidators.isHex64(trimmed.toLowerCase())) {
      return trimmed.toLowerCase();
    }

    final uri = Uri.tryParse(trimmed);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    final defaultPort = (scheme == 'ws' && uri.port == 80) ||
        (scheme == 'wss' && uri.port == 443);
    final query = uri.hasQuery ? '?${uri.query}' : '';

    return '$scheme://${uri.host.toLowerCase()}'
        '${uri.hasPort && !defaultPort ? ':${uri.port}' : ''}'
        '${uri.path}$query';
  }

  /// Whether [identifier] addresses [relayUrl] after normalization.
  ///
  /// A trailing slash on the root path is treated as equivalent so
  /// `wss://relay.example/` and `wss://relay.example` describe the same relay.
  static bool describesRelay(String identifier, String relayUrl) {
    final left = normalizeRelayIdentifier(identifier);
    final right = normalizeRelayIdentifier(relayUrl);

    if (left == null || right == null) {
      return false;
    }

    return left.replaceFirst(RegExp(r'/$'), '') ==
        right.replaceFirst(RegExp(r'/$'), '');
  }

  /// Decodes the optional NIP-11 document in `content`, never throwing.
  static Map<String, dynamic>? tryParseNip11(String? content) {
    if (content == null || content.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(content);

      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Builds an unsigned kind-30166 relay discovery event.
  ///
  /// [relay] is normalized to its canonical `d` value. Throws [ArgumentError]
  /// when the identifier is neither a relay URL nor a hex pubkey, when a
  /// timeout is negative or when [network] is not enumerated.
  static NostrEvent createMonitorAnnouncement({
    required String relay,
    int? rttOpen,
    int? rttRead,
    int? rttWrite,
    String? network,
    List<String> relayTypes = const <String>[],
    List<String> nips = const <String>[],
    List<String> requirements = const <String>[],
    List<String> topics = const <String>[],
    List<String> kinds = const <String>[],
    List<String> geohashes = const <String>[],
    List<String> languages = const <String>[],
    Map<String, dynamic>? nip11,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    final identifier = normalizeRelayIdentifier(relay);

    if (identifier == null) {
      throw ArgumentError.value(
        relay,
        'relay',
        'Expected a normalized relay URL or a hex relay pubkey',
      );
    }

    if (network != null && !networkTypes.contains(network)) {
      throw ArgumentError.value(
        network,
        'network',
        'Network must be one of ${networkTypes.join(', ')}',
      );
    }

    for (final rtt in [rttOpen, rttRead, rttWrite]) {
      if (rtt != null && rtt < 0) {
        throw ArgumentError.value(rtt, 'rtt', 'RTT must not be negative');
      }
    }

    for (final kind in kinds) {
      _validateKindValue(kind, 'kinds');
    }

    for (final requirement in requirements) {
      _validateNegatableValue(requirement, 'requirements');
    }

    return NostrEvent(
      id: null,
      kind: discoveryKind,
      content: nip11 == null ? '' : jsonEncode(nip11),
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', identifier],
        if (network != null) ['n', network],
        for (final value in relayTypes) ['T', value],
        for (final value in nips) ['N', value],
        for (final value in requirements) ['R', value],
        for (final value in topics) ['t', value],
        for (final value in kinds) ['k', value],
        for (final value in geohashes) ['g', value],
        for (final value in languages) ['l', value, 'ISO-639-1'],
        if (rttOpen != null) ['rtt-open', '$rttOpen'],
        if (rttRead != null) ['rtt-read', '$rttRead'],
        if (rttWrite != null) ['rtt-write', '$rttWrite'],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-10166 relay monitor announcement.
  ///
  /// Throws [ArgumentError] when [frequency] or a timeout is not positive.
  static NostrEvent createMonitorList({
    required int frequency,
    List<NostrRelayTimeout> timeouts = const <NostrRelayTimeout>[],
    List<String> checks = const <String>[],
    List<String> geohashes = const <String>[],
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (frequency <= 0) {
      throw ArgumentError.value(
        frequency,
        'frequency',
        'Frequency must be a positive number of seconds',
      );
    }

    for (final timeout in timeouts) {
      if (timeout.milliseconds <= 0) {
        throw ArgumentError.value(
          timeout.milliseconds,
          'timeouts',
          'Timeout must be a positive number of milliseconds',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: monitorListKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final timeout in timeouts) timeout.toTag(),
        ['frequency', '$frequency'],
        for (final check in checks) ['c', check],
        for (final geohash in geohashes) ['g', geohash],
        ...extraTags,
      ],
    );
  }

  /// Parses a kind-30166 event, returning `null` when invalid.
  ///
  /// A malformed NIP-11 document is tolerated and leaves
  /// [NostrRelayMonitorAnnouncement.nip11] `null`. A malformed `rtt-*` tag is
  /// not tolerated: it invalidates the whole announcement by design, rather
  /// than being preserved as an unknown tag.
  static NostrRelayMonitorAnnouncement? tryParseAnnouncement(
    NostrEvent event,
  ) {
    if (event.kind != discoveryKind) {
      return null;
    }

    final rawRelay = NostrTags.first(event.tags, 'd');
    final relay = rawRelay == null ? null : normalizeRelayIdentifier(rawRelay);

    if (relay == null) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final rttOpen = _tryNonNegativeInt(NostrTags.first(tags, 'rtt-open'));
    final rttRead = _tryNonNegativeInt(NostrTags.first(tags, 'rtt-read'));
    final rttWrite = _tryNonNegativeInt(NostrTags.first(tags, 'rtt-write'));

    if ((NostrTags.first(tags, 'rtt-open') != null && rttOpen == null) ||
        (NostrTags.first(tags, 'rtt-read') != null && rttRead == null) ||
        (NostrTags.first(tags, 'rtt-write') != null && rttWrite == null)) {
      return null;
    }

    final consumed = <String>{
      'd',
      'n',
      'T',
      'N',
      'R',
      't',
      'k',
      'g',
      'l',
      ...rttTags,
    };
    final extra = <List<String>>[
      for (final tag in tags)
        if (tag.isEmpty || !consumed.contains(tag.first)) List<String>.of(tag),
    ];

    final announcement = NostrRelayMonitorAnnouncement(
      relay: relay,
      pubkey: event.pubkey,
      rttOpen: rttOpen,
      rttRead: rttRead,
      rttWrite: rttWrite,
      network: NostrTags.first(tags, 'n'),
      relayTypes: NostrTags.all(tags, 'T'),
      nips: NostrTags.all(tags, 'N'),
      requirements: NostrTags.all(tags, 'R'),
      topics: NostrTags.all(tags, 't'),
      kinds: NostrTags.all(tags, 'k'),
      geohashes: NostrTags.all(tags, 'g'),
      languages: NostrTags.all(tags, 'l'),
      nip11: tryParseNip11(event.content),
      content: event.content ?? '',
      tags: extra,
    );

    return announcement.isValid ? announcement : null;
  }

  /// Like [tryParseAnnouncement], but throws [ArgumentError] when invalid.
  static NostrRelayMonitorAnnouncement parseAnnouncement(NostrEvent event) {
    final announcement = tryParseAnnouncement(event);

    if (announcement == null) {
      throw ArgumentError('Invalid NIP-66 relay discovery event');
    }

    return announcement;
  }

  /// Parses a kind-10166 event, returning `null` when invalid.
  static NostrRelayMonitorList? tryParseMonitorList(NostrEvent event) {
    if (event.kind != monitorListKind) {
      return null;
    }

    final frequency =
        int.tryParse(NostrTags.first(event.tags, 'frequency') ?? '');

    if (frequency == null || frequency <= 0) {
      return null;
    }

    final timeouts = <NostrRelayTimeout>[];
    final extra = <List<String>>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isEmpty) {
        continue;
      }

      if (tag.first == 'timeout') {
        final timeout = NostrRelayTimeout.tryParse(tag);

        if (timeout == null) {
          return null;
        }

        timeouts.add(timeout);
        continue;
      }

      if (tag.first == 'frequency' || tag.first == 'c' || tag.first == 'g') {
        continue;
      }

      extra.add(List<String>.of(tag));
    }

    return NostrRelayMonitorList(
      frequency: frequency,
      pubkey: event.pubkey,
      timeouts: timeouts,
      checks: NostrTags.all(event.tags, 'c'),
      geohashes: NostrTags.all(event.tags, 'g'),
      tags: extra,
    );
  }

  /// Like [tryParseMonitorList], but throws [ArgumentError] when invalid.
  static NostrRelayMonitorList parseMonitorList(NostrEvent event) {
    final list = tryParseMonitorList(event);

    if (list == null) {
      throw ArgumentError('Invalid NIP-66 relay monitor announcement');
    }

    return list;
  }

  /// Whether [event] is a structurally valid kind-30166 event and, when
  /// [requireSignature] is set, carries a valid signature.
  ///
  /// Monitor announcements are publisher assertions, so consumers should
  /// check the signature before trusting them (66.md:95).
  static bool verifyAnnouncement(
    NostrEvent event, {
    bool requireSignature = true,
  }) =>
      tryParseAnnouncement(event) != null &&
      (!requireSignature || event.isVerified());

  /// Whether [event] is a structurally valid kind-10166 event and, when
  /// [requireSignature] is set, carries a valid signature.
  static bool verifyMonitorList(
    NostrEvent event, {
    bool requireSignature = true,
  }) =>
      tryParseMonitorList(event) != null &&
      (!requireSignature || event.isVerified());

  static void _validateKindValue(String value, String name) {
    final candidate = value.startsWith('!') ? value.substring(1) : value;

    if (candidate.isEmpty || !RegExp(r'^\d+$').hasMatch(candidate)) {
      throw ArgumentError.value(
        value,
        name,
        'Kind values must be numeric, optionally prefixed with !',
      );
    }
  }

  static void _validateNegatableValue(String value, String name) {
    final candidate = value.startsWith('!') ? value.substring(1) : value;

    if (candidate.isEmpty) {
      throw ArgumentError.value(
        value,
        name,
        'Values must not be empty or a bare negation',
      );
    }
  }

  static int? _tryNonNegativeInt(String? value) {
    final parsed = int.tryParse(value ?? '');

    return parsed != null && parsed >= 0 ? parsed : null;
  }
}
