import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_social_builder}
/// Builders for common social-protocol event kinds. Every method returns a
/// signed [NostrEvent] ready to publish.
///
/// Covered kinds (with their NIPs):
/// - 0 metadata profile (NIP-01)
/// - 1 text note (NIP-01), with NIP-10 reply threading and NIP-27 mentions
/// - 3 follow list (NIP-02)
/// - 5 deletion (NIP-09)
/// - 6 repost (NIP-18)
/// - 7 reaction (NIP-25)
/// - 22 comment (NIP-22)
/// - 10002 relay list metadata (NIP-65)
/// - 30023 long-form article (NIP-23 / NIP-30023)
/// - generic parameterized replaceable lists (NIP-51) via [createListEvent]
/// {@endtemplate}
class NostrSocialBuilder {
  /// {@macro nostr_social_builder}
  NostrSocialBuilder({required this.signer});

  final NostrEventSigner signer;

  /// Kind 1 text note.
  ///
  /// For replies, pass [replyTo] with its id/author/root coordinates per
  /// NIP-10; for NIP-27 mentions pass [mentionedPubkeys] which appends `p`
  /// tags (the content itself must contain `nostr:` references).
  Future<NostrEvent> createTextNote(
    String content, {
    String? subject,
    List<String> mentionedPubkeys = const [],
    ({String eventId, String authorPubkey, String? rootEventId})? replyTo,
    DateTime? createdAt,
  }) async {
    final tags = <List<String>>[
      if (subject != null && subject.isNotEmpty) ...[
        ['subject', subject],
      ],
      for (final pubkey in mentionedPubkeys) ...[
        ['p', pubkey],
      ],
      if (replyTo != null) ...[
        if (replyTo.rootEventId != null) ...[
          ['e', replyTo.rootEventId!, '', 'root'],
        ],
        ['e', replyTo.eventId, '', 'reply'],
        ['p', replyTo.authorPubkey],
      ],
    ];

    return _sign(1, content, tags, createdAt);
  }

  /// Kind 0 profile metadata (JSON string per NIP-01).
  ///
  /// [lud16] is the Lightning Address (`user@wallet.co`) that enables zap
  /// buttons across clients; [lud06] is a raw LNURL for legacy wallets.
  Future<NostrEvent> updateProfile({
    required String name,
    String? about,
    String? picture,
    String? nip05,
    String? website,
    String? banner,
    String? displayName,
    String? lud16,
    String? lud06,
    Map<String, dynamic>? extraFields,
    DateTime? createdAt,
  }) async {
    final metadata = {
      'name': name,
      if (displayName != null) 'display_name': displayName,
      if (about != null) 'about': about,
      if (picture != null) 'picture': picture,
      if (nip05 != null) 'nip05': nip05,
      if (website != null) 'website': website,
      if (banner != null) 'banner': banner,
      if (lud16 != null) 'lud16': lud16,
      if (lud06 != null) 'lud06': lud06,
      ...?extraFields,
    };

    return _signJson(0, metadata, const [], createdAt);
  }

  /// Kind 3 follow list (NIP-02). Replaces the entire list, so pass all
  /// current follows.
  ///
  /// [followedPubkeys] produce `p` tags; [relayHints] maps a pubkey to a
  /// recommended relay URL stored as third element of its `p` tag.
  Future<NostrEvent> updateFollowList({
    required List<String> followedPubkeys,
    Map<String, String> relayHints = const {},
    DateTime? createdAt,
  }) async {
    final tags = [
      for (final pubkey in followedPubkeys)
        [
          'p',
          pubkey,
          if (relayHints[pubkey] != null) relayHints[pubkey]!,
        ],
    ];

    return _sign(3, '', tags, createdAt);
  }

  /// Kind 5 deletion request (NIP-09). [addressCoordinates] accepts
  /// `<kind>:<pubkey>:<d-tag>` coordinates for parameterized replaceable
  /// events in addition to plain event ids.
  Future<NostrEvent> createDeletionRequest({
    required List<String> eventIds,
    List<String> addressCoordinates = const [],
    String reason = '',
    DateTime? createdAt,
  }) async {
    final tags = [
      for (final id in eventIds) ['e', id],
      for (final coordinate in addressCoordinates) ['a', coordinate],
      ['k', '5'],
    ];

    return _sign(5, reason, tags, createdAt);
  }

  /// Kind 6 repost of a kind-1 note (NIP-18).
  Future<NostrEvent> createRepost({
    required NostrEvent note,
    required String relayUrl,
    DateTime? createdAt,
  }) async {
    return _sign(
      6,
      note.serialized(),
      [
        ['e', note.id!, relayUrl],
        ['p', note.pubkey],
      ],
      createdAt,
    );
  }

  /// Kind 7 reaction (NIP-25). [emoji] defaults to `+`; pass custom emoji or
  /// emoji shortcode per spec.
  Future<NostrEvent> createReaction({
    required String targetEventId,
    required String targetAuthorPubkey,
    String emoji = '+',
    String? targetKind,
    String? relayUrl,
    DateTime? createdAt,
  }) async {
    final tags = [
      ['e', targetEventId, if (relayUrl != null) relayUrl],
      ['p', targetAuthorPubkey],
      if (targetKind != null) ['k', targetKind],
    ];

    return _sign(7, emoji, tags, createdAt);
  }

  /// Kind 22 comment (NIP-22): comments on any event scope via root scopes.
  Future<NostrEvent> createComment({
    required String content,
    required String targetEventId,
    required String targetAuthorPubkey,
    int? targetKind,
    String? rootEventId,
    String? rootAuthorPubkey,
    DateTime? createdAt,
  }) async {
    final tags = <List<String>>[
      ['I', targetEventId],
      ['P', targetAuthorPubkey],
      if (targetKind != null) ['K', '$targetKind'],
      if (rootEventId != null) ...[
        ['E', rootEventId],
      ],
      if (rootAuthorPubkey != null) ...[
        ['A', rootAuthorPubkey],
      ],
    ];

    return _sign(22, content, tags, createdAt);
  }

  /// Kind 10002 relay list metadata (NIP-65).
  ///
  /// Each entry maps a relay URL to `(readable, writable)` flags.
  Future<NostrEvent> updateRelayList({
    required Map<String, ({bool read, bool write})> relays,
    DateTime? createdAt,
  }) async {
    final tags = [
      for (final entry in relays.entries)
        [
          'r',
          entry.key,
          if (!entry.value.read && entry.value.write) 'write',
          if (entry.value.read && !entry.value.write) 'read',
        ],
    ];

    return _sign(10002, '', tags, createdAt);
  }

  /// Kind 30023 long-form article (NIP-23). [dTagIdentifier] is required so
  /// updates replace prior versions; [image], [title], [summary],
  /// [publishedAt], [hashtags] map onto standard tags; [references] produce
  /// `r` tags for external URLs/IPFS refs as Yakihonne and other readers do.
  Future<NostrEvent> createLongFormArticle({
    required String content,
    required String dTagIdentifier,
    String? title,
    String? image,
    String? summary,
    DateTime? publishedAt,
    List<String> hashtags = const [],
    List<String> references = const [],
    DateTime? createdAt,
  }) async {
    final tags = <List<String>>[
      ['d', dTagIdentifier],
      if (title != null) ['title', title],
      if (image != null) ['image', image],
      if (summary != null) ['summary', summary],
      if (publishedAt != null)
        [
          'published_at',
          '${publishedAt.millisecondsSinceEpoch ~/ 1000}',
        ],
      for (final hashtag in hashtags) ['t', hashtag],
      for (final reference in references) ['r', reference],
    ];

    return _sign(30023, content, tags, createdAt);
  }

  /// Generic NIP-51 list event factory for any list kind (10000–10003 etc).
  ///
  /// Example — mute list (kind 10000):
  /// ```dart
  /// await builder.createListEvent(kind: 10000, entries: [
  ///   ['p', mutedPubkey],
  /// ]);
  /// ```
  Future<NostrEvent> createListEvent({
    required int kind,
    required List<List<String>> entries,
    String? dTag,
    String? title,
    String? image,
    String? description,
    DateTime? createdAt,
  }) async {
    final tags = <List<String>>[
      ...entries,
      if (dTag != null) ['d', dTag],
      if (title != null) ['title', title],
      if (image != null) ['image', image],
      if (description != null) ['description', description],
    ];

    return _sign(kind, '', tags, createdAt);
  }

  Future<NostrEvent> _sign(
    int kind,
    String content,
    List<List<String>> tags,
    DateTime? createdAt,
  ) {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: kind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: tags,
      ),
    );
  }

  Future<NostrEvent> _signJson(
    int kind,
    Map<String, dynamic> json,
    List<List<String>> tags,
    DateTime? createdAt,
  ) {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: kind,
        content: jsonEncode(json),
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: tags,
      ),
    );
  }
}
