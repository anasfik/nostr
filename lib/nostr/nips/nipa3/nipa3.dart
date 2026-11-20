import 'package:dart_nostr/nostr/model/event/event.dart';

/// {@template nostr_payto_target}
/// Parsed NIP-A3 `payto` payment target.
///
/// The tag shape is `["payto", <type>, <address>]` (A3.md:15-23). [extra]
/// keeps any slots after the address so newer revisions of the NIP stay
/// readable.
/// {@endtemplate}
class NostrPaytoTarget {
  /// {@macro nostr_payto_target}
  const NostrPaytoTarget({
    required this.type,
    required this.address,
    this.extra = const <String>[],
  });

  /// Payment type, always lowercase (for example `bitcoin`).
  final String type;

  /// Payment address, username or cashtag.
  final String address;

  /// Slots after the address, preserved verbatim.
  final List<String> extra;

  /// Payment types that also have a dedicated URI scheme.
  ///
  /// A3.md:42 allows `<type>:<address>` when a scheme exists. `nano` is not
  /// listed on purpose: the spec renders it as `payto://nano/<address>`.
  static const Set<String> uriSchemeTypes = {
    'bitcoin',
    'bitcoincash',
    'ethereum',
    'litecoin',
    'monero',
    'solana',
    'zcash',
  };

  /// Whether [type] renders with a dedicated scheme instead of `payto://`.
  ///
  /// Matches case-insensitively, so a hand-built target with `Bitcoin` still
  /// renders as `bitcoin:<address>`; builder validation still rejects
  /// non-lowercase types.
  bool get hasUriScheme => uriSchemeTypes.contains(type.toLowerCase());

  /// The tag for this target, including any preserved extra slots.
  List<String> get tag => ['payto', type, address, ...extra];

  /// Renders this target as a payment URI.
  ///
  /// Known [uriSchemeTypes] become `<type>:<address>`; every other type falls
  /// back to RFC-8905 `payto://<type>/<address>` (A3.md:42-47). Address and
  /// type are percent-encoded by [Uri].
  Uri toUri() {
    if (hasUriScheme) {
      return Uri(scheme: type.toLowerCase(), path: address);
    }

    return Uri(scheme: 'payto', host: type, pathSegments: [address]);
  }

  @override
  String toString() => toUri().toString();
}

/// {@template nipa3}
/// NIP-A3 payment targets (kind 10133).
///
/// A kind-10133 event lists one `payto` tag per payment address:
/// `["payto", "<lowercase type>", "<address>"]` (A3.md:15-23). Unknown types
/// are valid; clients render the ones they understand and fall back to
/// `payto://` URIs for the rest (A3.md:42-47).
///
/// Templates carry no `pubkey`/`id`/`sig`; sign them before publishing.
///
/// Usage:
/// ```dart
/// final event = await signer.sign(
///   NostrNipA3.generatePaymentTargetsTemplate(targets: [
///     const NostrPaytoTarget(type: 'bitcoin', address: 'bc1q…'),
///   ]),
/// );
/// ```
/// {@endtemplate}
class NostrNipA3 {
  /// {@macro nipa3}
  const NostrNipA3();

  /// Kind 10133: payment targets.
  static const int paymentTargetsKind = 10133;

  static final RegExp _typePattern = RegExp(r'^[a-z0-9][a-z0-9+.-]*$');

  /// Builds an unsigned kind-10133 event.
  ///
  /// Every target becomes one `payto` tag. Throws [ArgumentError] when
  /// [targets] is empty, or when a target has a blank address or a type that
  /// is blank, not lowercase, or not a URI-safe payment type.
  static NostrEvent generatePaymentTargetsTemplate({
    required List<NostrPaytoTarget> targets,
    DateTime? createdAt,
  }) {
    if (targets.isEmpty) {
      throw ArgumentError.value(
        targets,
        'targets',
        'A payment targets event needs at least one payto tag',
      );
    }

    targets.forEach(_validate);

    return NostrEvent(
      id: null,
      kind: paymentTargetsKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [for (final target in targets) target.tag],
    );
  }

  /// Validates a kind-10133 event: correct kind and at least one valid
  /// `payto` tag.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Parses every valid `payto` tag of [event], or returns `null` when
  /// [event] is not kind 10133 or has no valid payment target.
  ///
  /// Invalid or unrelated tags are skipped, matching the spec's tolerance for
  /// unknown payment types; extra tag slots are kept in
  /// [NostrPaytoTarget.extra].
  static List<NostrPaytoTarget>? tryParse(NostrEvent event) {
    if (event.kind != paymentTargetsKind) {
      return null;
    }

    final targets = <NostrPaytoTarget>[
      for (final tag in event.tags ?? const <List<String>>[])
        if (tryParseTag(tag) case final target?) target,
    ];

    return targets.isEmpty ? null : targets;
  }

  /// Like [tryParse], but throws [ArgumentError] for invalid events.
  static List<NostrPaytoTarget> parse(NostrEvent event) {
    final targets = tryParse(event);

    if (targets == null) {
      throw ArgumentError('Invalid NIP-A3 payment targets event');
    }

    return targets;
  }

  /// Parses one `payto` tag, or returns `null` when it is not a payment tag.
  ///
  /// Slots after the address are preserved in [NostrPaytoTarget.extra].
  static NostrPaytoTarget? tryParseTag(List<String>? tag) {
    if (tag == null || tag.length < 3 || tag.first != 'payto') {
      return null;
    }

    final type = tag[1].trim();
    final address = tag[2].trim();

    if (type.isEmpty || address.isEmpty) {
      return null;
    }

    return NostrPaytoTarget(
      type: type,
      address: address,
      extra: tag.length > 3 ? tag.sublist(3) : const <String>[],
    );
  }

  /// Like [tryParseTag], but throws [ArgumentError] for invalid tags.
  static NostrPaytoTarget parseTag(List<String> tag) {
    final target = tryParseTag(tag);

    if (target == null) {
      throw ArgumentError('Invalid NIP-A3 payto tag: $tag');
    }

    return target;
  }

  static void _validate(NostrPaytoTarget target) {
    if (target.type.trim().isEmpty) {
      throw ArgumentError.value(
        target.type,
        'type',
        'Payment type must not be empty',
      );
    }

    if (target.type != target.type.toLowerCase()) {
      throw ArgumentError.value(
        target.type,
        'type',
        'Payment type must be lowercase',
      );
    }

    if (!_typePattern.hasMatch(target.type)) {
      throw ArgumentError.value(
        target.type,
        'type',
        'Payment type must be a URI-safe lowercase identifier',
      );
    }

    if (target.address.trim().isEmpty) {
      throw ArgumentError.value(
        target.address,
        'address',
        'Payment address must not be empty',
      );
    }
  }
}
