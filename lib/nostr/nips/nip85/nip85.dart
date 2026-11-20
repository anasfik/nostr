import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_assertion_kind}
/// NIP-85 trusted assertion kinds.
/// {@endtemplate}
class NostrAssertionKind {
  const NostrAssertionKind._();

  /// User assertion (addressable).
  static const int user = 30382;

  /// Regular event assertion (addressable).
  static const int event = 30383;

  /// Addressable event assertion (addressable).
  static const int addressable = 30384;

  /// NIP-73 identifier assertion (addressable).
  static const int identifier = 30385;

  /// Provider recommendation list (replaceable).
  static const int providerRecommendation = 10040;

  /// Every assertion subject kind.
  static const List<int> assertionKinds = [
    user,
    event,
    addressable,
    identifier
  ];

  /// Whether [kind] is an assertion subject kind.
  static bool isAssertion(int? kind) => assertionKinds.contains(kind);

  /// Whether [kind] is an assertion or recommendation kind.
  static bool isAssertionKind(int? kind) =>
      isAssertion(kind) || kind == providerRecommendation;
}

/// {@template nostr_user_assertion}
/// Parsed NIP-85 user assertion (kind 30382).
///
/// The `d` tag is the subject pubkey. Numeric result tags are parsed
/// tolerantly: a missing or non-numeric value becomes `null` (`85.md:45-63`).
/// {@endtemplate}
class NostrUserAssertion {
  /// {@macro nostr_user_assertion}
  const NostrUserAssertion({
    this.id,
    required this.pubkey,
    required this.subject,
    this.rank,
    this.followers,
    this.firstCreatedAt,
    this.postCount,
    this.replyCount,
    this.reactionsCount,
    this.zapAmountReceived,
    this.zapAmountSent,
    this.zapCountReceived,
    this.zapCountSent,
    this.zapAvgAmountDayReceived,
    this.zapAvgAmountDaySent,
    this.reportsCountReceived,
    this.reportsCountSent,
    this.topics = const [],
    this.activeHoursStart,
    this.activeHoursEnd,
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Service provider public key.
  final String pubkey;

  /// Subject user pubkey from the `d` tag.
  final String subject;

  /// `rank`, normalized 0-100.
  final int? rank;

  /// `followers` count.
  final int? followers;

  /// `first_created_at` UNIX seconds.
  final int? firstCreatedAt;

  /// `post_cnt`.
  final int? postCount;

  /// `reply_cnt`.
  final int? replyCount;

  /// `reactions_cnt`.
  final int? reactionsCount;

  /// `zap_amt_recd` in sats.
  final int? zapAmountReceived;

  /// `zap_amt_sent` in sats.
  final int? zapAmountSent;

  /// `zap_cnt_recd`.
  final int? zapCountReceived;

  /// `zap_cnt_sent`.
  final int? zapCountSent;

  /// `zap_avg_amt_day_recd` in sats.
  final int? zapAvgAmountDayReceived;

  /// `zap_avg_amt_day_sent` in sats.
  final int? zapAvgAmountDaySent;

  /// `reports_cnt_recd`.
  final int? reportsCountReceived;

  /// `reports_cnt_sent`.
  final int? reportsCountSent;

  /// `t` common topics.
  final List<String> topics;

  /// `active_hours_start`, 0-24 UTC.
  final int? activeHoursStart;

  /// `active_hours_end`, 0-24 UTC.
  final int? activeHoursEnd;

  /// Event content, usually empty.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrUserAssertion parse(NostrEvent event) {
    if (event.kind != NostrAssertionKind.user) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-85 user assertion',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final subject = NostrTags.first(tags, 'd');
    if (!NostrValidators.isHex64(subject)) {
      throw ArgumentError.value(
        subject,
        'd',
        'User assertions require a subject pubkey',
      );
    }

    return NostrUserAssertion(
      id: event.id,
      pubkey: event.pubkey,
      subject: subject!,
      rank: _int(tags, 'rank'),
      followers: _int(tags, 'followers'),
      firstCreatedAt: _int(tags, 'first_created_at'),
      postCount: _int(tags, 'post_cnt'),
      replyCount: _int(tags, 'reply_cnt'),
      reactionsCount: _int(tags, 'reactions_cnt'),
      zapAmountReceived: _int(tags, 'zap_amt_recd'),
      zapAmountSent: _int(tags, 'zap_amt_sent'),
      zapCountReceived: _int(tags, 'zap_cnt_recd'),
      zapCountSent: _int(tags, 'zap_cnt_sent'),
      zapAvgAmountDayReceived: _int(tags, 'zap_avg_amt_day_recd'),
      zapAvgAmountDaySent: _int(tags, 'zap_avg_amt_day_sent'),
      reportsCountReceived: _int(tags, 'reports_cnt_recd'),
      reportsCountSent: _int(tags, 'reports_cnt_sent'),
      topics: NostrTags.all(tags, 't'),
      activeHoursStart: _int(tags, 'active_hours_start'),
      activeHoursEnd: _int(tags, 'active_hours_end'),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrUserAssertion? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid user assertion.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned kind-30382 user assertion and validates it.
  static NostrEvent build({
    required String subject,
    int? rank,
    int? followers,
    int? firstCreatedAt,
    int? postCount,
    int? replyCount,
    int? reactionsCount,
    int? zapAmountReceived,
    int? zapAmountSent,
    int? zapCountReceived,
    int? zapCountSent,
    int? zapAvgAmountDayReceived,
    int? zapAvgAmountDaySent,
    int? reportsCountReceived,
    int? reportsCountSent,
    List<String> topics = const [],
    int? activeHoursStart,
    int? activeHoursEnd,
    String content = '',
    DateTime? createdAt,
  }) {
    _requireHex64(subject, 'subject');
    _requireRange(rank, 'rank', 0, 100);
    _requireNonNegative(followers, 'followers');
    _requireNonNegative(firstCreatedAt, 'firstCreatedAt');
    _requireNonNegative(postCount, 'postCount');
    _requireNonNegative(replyCount, 'replyCount');
    _requireNonNegative(reactionsCount, 'reactionsCount');
    _requireNonNegative(zapAmountReceived, 'zapAmountReceived');
    _requireNonNegative(zapAmountSent, 'zapAmountSent');
    _requireNonNegative(zapCountReceived, 'zapCountReceived');
    _requireNonNegative(zapCountSent, 'zapCountSent');
    _requireNonNegative(zapAvgAmountDayReceived, 'zapAvgAmountDayReceived');
    _requireNonNegative(zapAvgAmountDaySent, 'zapAvgAmountDaySent');
    _requireNonNegative(reportsCountReceived, 'reportsCountReceived');
    _requireNonNegative(reportsCountSent, 'reportsCountSent');
    _requireRange(activeHoursStart, 'activeHoursStart', 0, 24);
    _requireRange(activeHoursEnd, 'activeHoursEnd', 0, 24);

    final event = NostrEvent(
      id: null,
      kind: NostrAssertionKind.user,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', subject],
        if (rank != null) ['rank', '$rank'],
        if (followers != null) ['followers', '$followers'],
        if (firstCreatedAt != null) ['first_created_at', '$firstCreatedAt'],
        if (postCount != null) ['post_cnt', '$postCount'],
        if (replyCount != null) ['reply_cnt', '$replyCount'],
        if (reactionsCount != null) ['reactions_cnt', '$reactionsCount'],
        if (zapAmountReceived != null) ['zap_amt_recd', '$zapAmountReceived'],
        if (zapAmountSent != null) ['zap_amt_sent', '$zapAmountSent'],
        if (zapCountReceived != null) ['zap_cnt_recd', '$zapCountReceived'],
        if (zapCountSent != null) ['zap_cnt_sent', '$zapCountSent'],
        if (zapAvgAmountDayReceived != null)
          ['zap_avg_amt_day_recd', '$zapAvgAmountDayReceived'],
        if (zapAvgAmountDaySent != null)
          ['zap_avg_amt_day_sent', '$zapAvgAmountDaySent'],
        if (reportsCountReceived != null)
          ['reports_cnt_recd', '$reportsCountReceived'],
        if (reportsCountSent != null) ['reports_cnt_sent', '$reportsCountSent'],
        for (final topic in topics) ['t', topic],
        if (activeHoursStart != null)
          ['active_hours_start', '$activeHoursStart'],
        if (activeHoursEnd != null) ['active_hours_end', '$activeHoursEnd'],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_event_assertion}
/// Parsed NIP-85 regular event assertion (kind 30383).
///
/// The `d` tag is the subject event id. Numeric tags are parsed tolerantly.
/// {@endtemplate}
class NostrEventAssertion {
  /// {@macro nostr_event_assertion}
  const NostrEventAssertion({
    this.id,
    required this.pubkey,
    required this.subject,
    this.rank,
    this.commentCount,
    this.quoteCount,
    this.repostCount,
    this.reactionCount,
    this.zapCount,
    this.zapAmount,
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Service provider public key.
  final String pubkey;

  /// Subject event id from the `d` tag.
  final String subject;

  /// `rank`, normalized 0-100.
  final int? rank;

  /// `comment_cnt`.
  final int? commentCount;

  /// `quote_cnt`.
  final int? quoteCount;

  /// `repost_cnt`.
  final int? repostCount;

  /// `reaction_cnt`.
  final int? reactionCount;

  /// `zap_cnt`.
  final int? zapCount;

  /// `zap_amount` in sats.
  final int? zapAmount;

  /// Event content, usually empty.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrEventAssertion parse(NostrEvent event) {
    if (event.kind != NostrAssertionKind.event) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-85 event assertion',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final subject = NostrTags.first(tags, 'd');
    if (!NostrValidators.isHex64(subject)) {
      throw ArgumentError.value(
        subject,
        'd',
        'Event assertions require a subject event id',
      );
    }

    return NostrEventAssertion(
      id: event.id,
      pubkey: event.pubkey,
      subject: subject!,
      rank: _int(tags, 'rank'),
      commentCount: _int(tags, 'comment_cnt'),
      quoteCount: _int(tags, 'quote_cnt'),
      repostCount: _int(tags, 'repost_cnt'),
      reactionCount: _int(tags, 'reaction_cnt'),
      zapCount: _int(tags, 'zap_cnt'),
      zapAmount: _int(tags, 'zap_amount'),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrEventAssertion? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid event assertion.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned kind-30383 event assertion and validates it.
  static NostrEvent build({
    required String subject,
    int? rank,
    int? commentCount,
    int? quoteCount,
    int? repostCount,
    int? reactionCount,
    int? zapCount,
    int? zapAmount,
    String content = '',
    DateTime? createdAt,
  }) {
    _requireHex64(subject, 'subject');
    _requireRange(rank, 'rank', 0, 100);
    _requireNonNegative(commentCount, 'commentCount');
    _requireNonNegative(quoteCount, 'quoteCount');
    _requireNonNegative(repostCount, 'repostCount');
    _requireNonNegative(reactionCount, 'reactionCount');
    _requireNonNegative(zapCount, 'zapCount');
    _requireNonNegative(zapAmount, 'zapAmount');

    final event = NostrEvent(
      id: null,
      kind: NostrAssertionKind.event,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', subject],
        if (rank != null) ['rank', '$rank'],
        if (commentCount != null) ['comment_cnt', '$commentCount'],
        if (quoteCount != null) ['quote_cnt', '$quoteCount'],
        if (repostCount != null) ['repost_cnt', '$repostCount'],
        if (reactionCount != null) ['reaction_cnt', '$reactionCount'],
        if (zapCount != null) ['zap_cnt', '$zapCount'],
        if (zapAmount != null) ['zap_amount', '$zapAmount'],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_address_assertion}
/// Parsed NIP-85 addressable event assertion (kind 30384).
///
/// The `d` tag is the subject `kind:pubkey:d` address. Numeric tags are
/// parsed tolerantly.
/// {@endtemplate}
class NostrAddressAssertion {
  /// {@macro nostr_address_assertion}
  const NostrAddressAssertion({
    this.id,
    required this.pubkey,
    required this.subject,
    this.rank,
    this.commentCount,
    this.quoteCount,
    this.repostCount,
    this.reactionCount,
    this.zapCount,
    this.zapAmount,
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Service provider public key.
  final String pubkey;

  /// Subject address from the `d` tag.
  final String subject;

  /// `rank`, normalized 0-100.
  final int? rank;

  /// `comment_cnt`.
  final int? commentCount;

  /// `quote_cnt`.
  final int? quoteCount;

  /// `repost_cnt`.
  final int? repostCount;

  /// `reaction_cnt`.
  final int? reactionCount;

  /// `zap_cnt`.
  final int? zapCount;

  /// `zap_amount` in sats.
  final int? zapAmount;

  /// Event content, usually empty.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrAddressAssertion parse(NostrEvent event) {
    if (event.kind != NostrAssertionKind.addressable) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-85 address assertion',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final address = NostrEventAddress.tryParse(NostrTags.first(tags, 'd'));
    if (address == null || !address.isAddressable) {
      throw ArgumentError.value(
        NostrTags.first(tags, 'd'),
        'd',
        'Address assertions require an addressable event address',
      );
    }

    return NostrAddressAssertion(
      id: event.id,
      pubkey: event.pubkey,
      subject: address.address,
      rank: _int(tags, 'rank'),
      commentCount: _int(tags, 'comment_cnt'),
      quoteCount: _int(tags, 'quote_cnt'),
      repostCount: _int(tags, 'repost_cnt'),
      reactionCount: _int(tags, 'reaction_cnt'),
      zapCount: _int(tags, 'zap_cnt'),
      zapAmount: _int(tags, 'zap_amount'),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrAddressAssertion? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid address assertion.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned kind-30384 address assertion and validates it.
  static NostrEvent build({
    required String subject,
    int? rank,
    int? commentCount,
    int? quoteCount,
    int? repostCount,
    int? reactionCount,
    int? zapCount,
    int? zapAmount,
    String content = '',
    DateTime? createdAt,
  }) {
    final address = NostrEventAddress.tryParse(subject);
    if (address == null || !address.isAddressable) {
      throw ArgumentError.value(
        subject,
        'subject',
        'Expected an addressable kind:pubkey:d address',
      );
    }

    _requireRange(rank, 'rank', 0, 100);
    _requireNonNegative(commentCount, 'commentCount');
    _requireNonNegative(quoteCount, 'quoteCount');
    _requireNonNegative(repostCount, 'repostCount');
    _requireNonNegative(reactionCount, 'reactionCount');
    _requireNonNegative(zapCount, 'zapCount');
    _requireNonNegative(zapAmount, 'zapAmount');

    final event = NostrEvent(
      id: null,
      kind: NostrAssertionKind.addressable,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', address.address],
        if (rank != null) ['rank', '$rank'],
        if (commentCount != null) ['comment_cnt', '$commentCount'],
        if (quoteCount != null) ['quote_cnt', '$quoteCount'],
        if (repostCount != null) ['repost_cnt', '$repostCount'],
        if (reactionCount != null) ['reaction_cnt', '$reactionCount'],
        if (zapCount != null) ['zap_cnt', '$zapCount'],
        if (zapAmount != null) ['zap_amount', '$zapAmount'],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_identifier_assertion}
/// Parsed NIP-85 NIP-73 identifier assertion (kind 30385).
///
/// The `d` tag is the subject `i`-tag value and `k` tags identify its kind.
/// Numeric tags are parsed tolerantly.
/// {@endtemplate}
class NostrIdentifierAssertion {
  /// {@macro nostr_identifier_assertion}
  const NostrIdentifierAssertion({
    this.id,
    required this.pubkey,
    required this.subject,
    this.rank,
    this.commentCount,
    this.reactionCount,
    this.kTags = const [],
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Service provider public key.
  final String pubkey;

  /// Subject identifier from the `d` tag.
  final String subject;

  /// `rank`, normalized 0-100.
  final int? rank;

  /// `comment_cnt`.
  final int? commentCount;

  /// `reaction_cnt`.
  final int? reactionCount;

  /// `k` NIP-73 identifier kinds.
  final List<String> kTags;

  /// Event content, usually empty.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrIdentifierAssertion parse(NostrEvent event) {
    if (event.kind != NostrAssertionKind.identifier) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-85 identifier assertion',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final subject = NostrTags.first(tags, 'd');
    if (subject == null || subject.isEmpty) {
      throw ArgumentError('Identifier assertions require a non-empty d tag');
    }

    return NostrIdentifierAssertion(
      id: event.id,
      pubkey: event.pubkey,
      subject: subject,
      rank: _int(tags, 'rank'),
      commentCount: _int(tags, 'comment_cnt'),
      reactionCount: _int(tags, 'reaction_cnt'),
      kTags: NostrTags.all(tags, 'k'),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrIdentifierAssertion? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid identifier assertion.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned kind-30385 identifier assertion and validates it.
  static NostrEvent build({
    required String subject,
    int? rank,
    int? commentCount,
    int? reactionCount,
    List<String> kTags = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    if (subject.isEmpty) {
      throw ArgumentError.value(
        subject,
        'subject',
        'Identifier subject must not be empty',
      );
    }

    _requireRange(rank, 'rank', 0, 100);
    _requireNonNegative(commentCount, 'commentCount');
    _requireNonNegative(reactionCount, 'reactionCount');

    final event = NostrEvent(
      id: null,
      kind: NostrAssertionKind.identifier,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', subject],
        for (final kTag in kTags) ['k', kTag],
        if (rank != null) ['rank', '$rank'],
        if (commentCount != null) ['comment_cnt', '$commentCount'],
        if (reactionCount != null) ['reaction_cnt', '$reactionCount'],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_provider_recommendation}
/// NIP-85 kind-10040 provider recommendation entry.
///
/// Each entry is a `["<kind:tag>", "<service pubkey>", "<relay>"]` tag
/// (`85.md:139-158`). The relay hint is optional in this model.
/// {@endtemplate}
class NostrProviderRecommendation {
  /// {@macro nostr_provider_recommendation}
  const NostrProviderRecommendation({
    required this.kindTag,
    required this.servicePubkey,
    this.relay,
    this.tag = const [],
  });

  /// `<assertion kind>:<result tag>` selector, for example `30382:rank`.
  final String kindTag;

  /// Recommended service provider public key.
  final String servicePubkey;

  /// Relay hint where assertion events can be found.
  final String? relay;

  /// Raw tag.
  final List<String> tag;

  static final RegExp _kindTag = RegExp(r'^\d+:[a-z0-9_]+$');

  /// Assertion kind from [kindTag], or `null`.
  int? get kind => int.tryParse(kindTag.split(':').first);

  /// Result tag name from [kindTag], or `null`.
  String? get resultTag {
    final separator = kindTag.indexOf(':');

    return separator < 0 ? null : kindTag.substring(separator + 1);
  }

  /// Builds the recommendation tag.
  List<String> toTag() => [
        kindTag,
        servicePubkey,
        if (relay != null) relay!,
      ];

  /// Whether [value] is a `<kind>:<tag>` selector.
  static bool isValidKindTag(String value) => _kindTag.hasMatch(value);

  /// Parses one tag, returning `null` when it is not a valid recommendation.
  static NostrProviderRecommendation? tryParseTag(List<String>? tag) {
    if (tag == null ||
        tag.length < 2 ||
        !isValidKindTag(tag[0]) ||
        !NostrValidators.isHex64(tag[1])) {
      return null;
    }

    final relay = NostrTags.at(tag, 2);

    return NostrProviderRecommendation(
      kindTag: tag[0],
      servicePubkey: tag[1],
      relay: relay == null || relay.isEmpty ? null : relay,
      tag: tag,
    );
  }

  /// Validates [recommendation] and builds its tag.
  List<String> requireTag() {
    if (!isValidKindTag(kindTag)) {
      throw ArgumentError.value(
        kindTag,
        'kindTag',
        'Expected <kind:tag>',
      );
    }

    if (!NostrValidators.isHex64(servicePubkey)) {
      throw ArgumentError.value(
        servicePubkey,
        'servicePubkey',
        'Expected 64 lowercase hex characters',
      );
    }

    return toTag();
  }

  /// Public recommendations from a kind-10040 event.
  ///
  /// Invalid entries are skipped; never throws.
  static List<NostrProviderRecommendation> parseEvent(NostrEvent event) {
    if (event.kind != NostrAssertionKind.providerRecommendation) {
      return const [];
    }

    final recommendations = <NostrProviderRecommendation>[];
    for (final tag in event.tags ?? const <List<String>>[]) {
      final recommendation = tryParseTag(tag);
      if (recommendation != null) {
        recommendations.add(recommendation);
      }
    }

    return recommendations;
  }

  /// Parses a decoded or JSON-encoded tag list; never throws.
  static List<NostrProviderRecommendation> parseList(Object? value) {
    var decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return const [];
      }
    }

    if (decoded is! List) {
      return const [];
    }

    final recommendations = <NostrProviderRecommendation>[];
    for (final entry in decoded) {
      if (entry is! List) {
        continue;
      }

      final tag = [
        for (final slot in entry)
          if (slot is String) slot
      ];
      if (tag.length != entry.length) {
        continue;
      }

      final recommendation = tryParseTag(tag);
      if (recommendation != null) {
        recommendations.add(recommendation);
      }
    }

    return recommendations;
  }
}

/// {@template nip85}
/// NIP-85 trusted assertions and provider recommendations.
///
/// Assertion generation, [publish] and [resolveProviderRecommendations] use
/// the bound signer. Parsing is also available without a signer.
/// {@endtemplate}
class NostrNip85 {
  /// {@macro nip85}
  NostrNip85({required this.signer});

  /// Signer used by [publish] and NIP-44 content resolution.
  final NostrEventSigner signer;

  /// Kind of a user assertion.
  static const int userAssertionKind = NostrAssertionKind.user;

  /// Kind of an event assertion.
  static const int eventAssertionKind = NostrAssertionKind.event;

  /// Kind of an addressable event assertion.
  static const int addressAssertionKind = NostrAssertionKind.addressable;

  /// Kind of an identifier assertion.
  static const int identifierAssertionKind = NostrAssertionKind.identifier;

  /// Kind of a provider recommendation list.
  static const int providerRecommendationKind =
      NostrAssertionKind.providerRecommendation;

  /// Builds an unsigned kind-30382 user assertion.
  NostrEvent generateUserAssertion({
    required String subject,
    int? rank,
    int? followers,
    int? firstCreatedAt,
    int? postCount,
    int? replyCount,
    int? reactionsCount,
    int? zapAmountReceived,
    int? zapAmountSent,
    int? zapCountReceived,
    int? zapCountSent,
    int? zapAvgAmountDayReceived,
    int? zapAvgAmountDaySent,
    int? reportsCountReceived,
    int? reportsCountSent,
    List<String> topics = const [],
    int? activeHoursStart,
    int? activeHoursEnd,
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrUserAssertion.build(
      subject: subject,
      rank: rank,
      followers: followers,
      firstCreatedAt: firstCreatedAt,
      postCount: postCount,
      replyCount: replyCount,
      reactionsCount: reactionsCount,
      zapAmountReceived: zapAmountReceived,
      zapAmountSent: zapAmountSent,
      zapCountReceived: zapCountReceived,
      zapCountSent: zapCountSent,
      zapAvgAmountDayReceived: zapAvgAmountDayReceived,
      zapAvgAmountDaySent: zapAvgAmountDaySent,
      reportsCountReceived: reportsCountReceived,
      reportsCountSent: reportsCountSent,
      topics: topics,
      activeHoursStart: activeHoursStart,
      activeHoursEnd: activeHoursEnd,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-30383 event assertion.
  NostrEvent generateEventAssertion({
    required String subject,
    int? rank,
    int? commentCount,
    int? quoteCount,
    int? repostCount,
    int? reactionCount,
    int? zapCount,
    int? zapAmount,
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrEventAssertion.build(
      subject: subject,
      rank: rank,
      commentCount: commentCount,
      quoteCount: quoteCount,
      repostCount: repostCount,
      reactionCount: reactionCount,
      zapCount: zapCount,
      zapAmount: zapAmount,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-30384 address assertion.
  NostrEvent generateAddressAssertion({
    required String subject,
    int? rank,
    int? commentCount,
    int? quoteCount,
    int? repostCount,
    int? reactionCount,
    int? zapCount,
    int? zapAmount,
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrAddressAssertion.build(
      subject: subject,
      rank: rank,
      commentCount: commentCount,
      quoteCount: quoteCount,
      repostCount: repostCount,
      reactionCount: reactionCount,
      zapCount: zapCount,
      zapAmount: zapAmount,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-30385 identifier assertion.
  NostrEvent generateIdentifierAssertion({
    required String subject,
    int? rank,
    int? commentCount,
    int? reactionCount,
    List<String> kTags = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrIdentifierAssertion.build(
      subject: subject,
      rank: rank,
      commentCount: commentCount,
      reactionCount: reactionCount,
      kTags: kTags,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-10040 provider recommendation list.
  ///
  /// [privateRecommendations] are NIP-44 encrypted to the signer and stored in
  /// `content` (`85.md:157-176`). Passing both private recommendations and
  /// non-empty [content] is rejected.
  Future<NostrEvent> generateProviderRecommendation({
    required List<NostrProviderRecommendation> recommendations,
    List<NostrProviderRecommendation> privateRecommendations = const [],
    String content = '',
    DateTime? createdAt,
  }) async {
    if (privateRecommendations.isNotEmpty && content.isNotEmpty) {
      throw ArgumentError(
        'Pass either private recommendations or content, not both',
      );
    }

    final tags = [
      for (final recommendation in recommendations) recommendation.requireTag(),
    ];

    var body = content;
    if (privateRecommendations.isNotEmpty) {
      final privateTags = [
        for (final recommendation in privateRecommendations)
          recommendation.requireTag(),
      ];
      body = await signer.nip44Encrypt(
        jsonEncode(privateTags),
        signer.publicKey,
      );
    }

    return NostrEvent(
      id: null,
      kind: NostrAssertionKind.providerRecommendation,
      content: body,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: tags,
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses a user assertion, throwing [ArgumentError] when invalid.
  NostrUserAssertion parseUserAssertion(NostrEvent event) =>
      NostrUserAssertion.parse(event);

  /// Parses a user assertion, returning `null` when invalid.
  NostrUserAssertion? tryParseUserAssertion(NostrEvent event) =>
      NostrUserAssertion.tryParse(event);

  /// Parses an event assertion, throwing [ArgumentError] when invalid.
  NostrEventAssertion parseEventAssertion(NostrEvent event) =>
      NostrEventAssertion.parse(event);

  /// Parses an event assertion, returning `null` when invalid.
  NostrEventAssertion? tryParseEventAssertion(NostrEvent event) =>
      NostrEventAssertion.tryParse(event);

  /// Parses an address assertion, throwing [ArgumentError] when invalid.
  NostrAddressAssertion parseAddressAssertion(NostrEvent event) =>
      NostrAddressAssertion.parse(event);

  /// Parses an address assertion, returning `null` when invalid.
  NostrAddressAssertion? tryParseAddressAssertion(NostrEvent event) =>
      NostrAddressAssertion.tryParse(event);

  /// Parses an identifier assertion, throwing [ArgumentError] when invalid.
  NostrIdentifierAssertion parseIdentifierAssertion(NostrEvent event) =>
      NostrIdentifierAssertion.parse(event);

  /// Parses an identifier assertion, returning `null` when invalid.
  NostrIdentifierAssertion? tryParseIdentifierAssertion(NostrEvent event) =>
      NostrIdentifierAssertion.tryParse(event);

  /// Public provider recommendations from a kind-10040 event.
  List<NostrProviderRecommendation> parseProviderRecommendation(
    NostrEvent event,
  ) =>
      NostrProviderRecommendation.parseEvent(event);

  /// Resolves public and encrypted provider recommendations.
  ///
  /// Public tags are always returned. When `content` is a NIP-44 payload from
  /// [event]'s author, it is decrypted with the bound signer and merged with
  /// the public entries, deduplicated in encounter order. Any decryption or
  /// JSON failure falls back to the public tags alone.
  Future<List<NostrProviderRecommendation>> resolveProviderRecommendations(
    NostrEvent event,
  ) async {
    if (event.kind != NostrAssertionKind.providerRecommendation) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-85 provider recommendation event',
      );
    }

    final public = NostrProviderRecommendation.parseEvent(event);
    final content = event.content ?? '';
    if (content.trim().isEmpty) {
      return public;
    }

    try {
      final plaintext = await signer.nip44Decrypt(content, event.pubkey);
      final private = NostrProviderRecommendation.parseList(plaintext);

      return _mergeRecommendations(public, private);
    } on Object catch (_) {
      return public;
    }
  }
}

/// Tolerant numeric result tags: non-numeric and negative values become null,
/// matching the non-negative builder rules (`85.md:45-63`).
int? _int(List<List<String>> tags, String name) =>
    NostrValidators.tryInt(NostrTags.first(tags, name), min: 0);

void _requireHex64(String value, String name) {
  if (!NostrValidators.isHex64(value)) {
    throw ArgumentError.value(value, name, 'Expected 64 lowercase hex chars');
  }
}

void _requireNonNegative(int? value, String name) {
  if (value != null && value < 0) {
    throw ArgumentError.value(value, name, 'Expected a non-negative integer');
  }
}

void _requireRange(int? value, String name, int min, int max) {
  if (value != null && (value < min || value > max)) {
    throw ArgumentError.value(value, name, 'Expected an integer in $min-$max');
  }
}

List<NostrProviderRecommendation> _mergeRecommendations(
  List<NostrProviderRecommendation> public,
  List<NostrProviderRecommendation> private,
) {
  final seen = <String>{};
  final merged = <NostrProviderRecommendation>[];

  for (final recommendation in [...public, ...private]) {
    final key = '${recommendation.kindTag}\u0000'
        '${recommendation.servicePubkey}\u0000'
        '${recommendation.relay ?? ''}';
    if (seen.add(key)) {
      merged.add(recommendation);
    }
  }

  return merged;
}
