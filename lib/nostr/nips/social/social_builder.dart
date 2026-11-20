import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip24/nip24.dart';
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
/// - 1111 comment (NIP-22, not the kind 22 reserved by NIP-71 for short
///   video)
/// - 10002 relay list metadata (NIP-65)
/// - 30023 long-form article (NIP-23 / NIP-30023)
/// - generic parameterized replaceable lists (NIP-51) via [createListEvent]
/// {@endtemplate}
class NostrSocialBuilder {
  /// {@macro nostr_social_builder}
  NostrSocialBuilder({required this.signer});

  /// Signer used for every event produced by this builder.
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
  /// [bot] and [birthday] are the NIP-24 extras (`24.md:15-19`).
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
    bool? bot,
    NostrMetadataBirthday? birthday,
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
      if (bot != null) 'bot': bot,
      if (birthday != null && !birthday.isEmpty) 'birthday': birthday.toJson(),
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

  /// Kind 1111 comment (NIP-22, `22.md:11`).
  ///
  /// Root scope uses uppercase tags (`K`/`E`/`A`/`I`) and the direct parent
  /// uses the lowercase ones (`k`/`e`/`a`/`i`) — `22.md:13-17`, `22.md:44`.
  ///
  /// Event scope (unchanged, backward compatible):
  /// - Top-level comment: omit [rootEventId]. The parent is the commented event
  ///   itself, so the root and parent tags carry the same id and kind
  ///   (`22.md:95-107`).
  /// - Reply to a comment: set [rootEventId] to the event the thread is rooted
  ///   on, and [targetEventId] to the comment being replied to. [rootKind] is
  ///   the root event kind (defaults to [targetKind]) — `22.md:114-133`.
  ///
  /// Address scope: pass [rootAddress] and/or [parentAddress] as NIP-01
  /// `kind:pubkey:d` coordinates (`22.md:63-86`). Root and parent kind default
  /// to the kind embedded in each coordinate. [targetEventId] may be supplied
  /// alongside [parentAddress] to add the `e` reference the spec asks for when
  /// the parent is addressable.
  ///
  /// External scope: pass [rootExternalId] and/or [parentExternalId] as NIP-73
  /// `i` values plus [externalKind] for the shared `K`/`k` value
  /// (`22.md:137-176`). Replying to a comment in an external thread uses
  /// [targetEventId] instead of [parentExternalId] (`22.md:180-198`).
  ///
  /// Exactly one root scope family may be used; mixing them throws
  /// [ArgumentError]. [relayUrl] is an optional hint stored on the id and
  /// author tags; [authorPubkey] fills `P`/`p` when the per-scope author is not
  /// given (address scopes otherwise derive it from the coordinate).
  Future<NostrEvent> createComment({
    required String content,
    String? targetEventId,
    String? targetAuthorPubkey,
    int? targetKind,
    String? rootEventId,
    String? rootAuthorPubkey,
    int? rootKind,
    String? relayUrl,
    String? rootAddress,
    String? parentAddress,
    String? rootExternalId,
    String? parentExternalId,
    String? externalKind,
    String? authorPubkey,
    DateTime? createdAt,
  }) async {
    if (content.trim().isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Comment must not be empty',
      );
    }

    final explicitRoots = [
      rootEventId != null,
      rootAddress != null,
      rootExternalId != null,
    ].where((present) => present).length;

    if (explicitRoots > 1) {
      throw ArgumentError(
        'A NIP-22 comment has exactly one root scope family; '
        'got a mix of event, address and external roots',
      );
    }

    final scope = rootEventId != null
        ? _CommentScope.event
        : rootAddress != null
            ? _CommentScope.address
            : rootExternalId != null
                ? _CommentScope.external
                : targetEventId != null
                    ? _CommentScope.event
                    : parentAddress != null
                        ? _CommentScope.address
                        : parentExternalId != null
                            ? _CommentScope.external
                            : throw ArgumentError(
                                'A NIP-22 comment needs a root scope: '
                                'rootEventId, rootAddress or rootExternalId',
                              );

    if (scope != _CommentScope.address && parentAddress != null) {
      throw ArgumentError(
        'parentAddress belongs to an address-scoped comment, '
        'but the root scope is ${scope.name}',
      );
    }

    if (scope != _CommentScope.external && parentExternalId != null) {
      throw ArgumentError(
        'parentExternalId belongs to an external-scoped comment, '
        'but the root scope is ${scope.name}',
      );
    }

    // Event tags keep an empty placeholder for a missing relay/author so older
    // call shapes keep the same tag shape (`22.md:25-38`).
    final relay = relayUrl ?? '';

    switch (scope) {
      case _CommentScope.event:
        final parentId = targetEventId;
        if (parentId == null) {
          throw ArgumentError(
            'Event-scoped comments require targetEventId',
          );
        }

        final resolvedRootKind = rootKind ?? targetKind;
        if (resolvedRootKind == null) {
          throw ArgumentError(
            'rootKind (or targetKind) is required for event-scoped comments',
          );
        }

        final parentKind = targetKind ?? resolvedRootKind;
        final rootAuthor =
            rootAuthorPubkey ?? targetAuthorPubkey ?? authorPubkey ?? '';
        final parentAuthor = targetAuthorPubkey ?? authorPubkey ?? '';

        final tags = <List<String>>[
          ['K', '$resolvedRootKind'],
          ['E', rootEventId ?? parentId, relay, rootAuthor],
          if (rootAuthor.isNotEmpty)
            ['P', rootAuthor, if (relayUrl != null) relayUrl],
          ['k', '$parentKind'],
          ['e', parentId, relay, parentAuthor],
          if (parentAuthor.isNotEmpty)
            ['p', parentAuthor, if (relayUrl != null) relayUrl],
        ];

        return _sign(1111, content, tags, createdAt);

      case _CommentScope.address:
        final rootAddressValue = rootAddress ?? parentAddress!;
        final parentAddressValue = parentAddress ?? rootAddressValue;
        final parsedRoot = _parseAddress(rootAddressValue, 'rootAddress');
        final parsedParent = _parseAddress(parentAddressValue, 'parentAddress');

        final resolvedRootKind = rootKind ?? targetKind ?? parsedRoot.kind;
        final resolvedParentKind = targetKind ?? rootKind ?? parsedParent.kind;
        final rootAuthor =
            rootAuthorPubkey ?? authorPubkey ?? parsedRoot.pubkey;
        final parentAuthor =
            targetAuthorPubkey ?? authorPubkey ?? parsedParent.pubkey;

        if (targetEventId != null && targetKind == null) {
          // The parent is an event id, so its kind cannot come from the
          // address; require it rather than guessing.
          throw ArgumentError(
            'targetKind is required when an address-scoped comment also '
            'references targetEventId',
          );
        }

        final tags = <List<String>>[
          ['A', rootAddressValue, if (relayUrl != null) relayUrl],
          ['K', '$resolvedRootKind'],
          ['P', rootAuthor, if (relayUrl != null) relayUrl],
          ['a', parentAddressValue, if (relayUrl != null) relayUrl],
          if (targetEventId != null)
            ['e', targetEventId, relay, targetAuthorPubkey ?? parentAuthor],
          ['k', '$resolvedParentKind'],
          ['p', parentAuthor, if (relayUrl != null) relayUrl],
        ];

        return _sign(1111, content, tags, createdAt);

      case _CommentScope.external:
        final rootExternal = rootExternalId ?? parentExternalId!;
        final parentExternal = parentExternalId;

        if (rootExternal.trim().isEmpty ||
            (parentExternal != null && parentExternal.trim().isEmpty)) {
          throw ArgumentError.value(
            rootExternal,
            'rootExternalId',
            'External NIP-73 identifier must not be empty',
          );
        }

        final kind = externalKind ?? rootKind?.toString();
        if (kind == null || kind.isEmpty) {
          throw ArgumentError(
            'externalKind (or rootKind/targetKind) is required for '
            'external-scoped comments',
          );
        }

        final parentAuthor = targetAuthorPubkey ?? authorPubkey;
        if (targetEventId != null && targetKind == null) {
          throw ArgumentError(
            'targetKind is required when an external-scoped comment '
            'references targetEventId',
          );
        }

        final tags = <List<String>>[
          ['I', rootExternal, if (relayUrl != null) relayUrl],
          ['K', kind],
          if (targetEventId != null) ...[
            ['e', targetEventId, relay, parentAuthor ?? ''],
            ['k', '$targetKind'],
            if (parentAuthor != null && parentAuthor.isNotEmpty)
              ['p', parentAuthor, if (relayUrl != null) relayUrl],
          ] else ...[
            [
              'i',
              parentExternal ?? rootExternal,
              if (relayUrl != null) relayUrl,
            ],
            ['k', kind],
          ],
        ];

        return _sign(1111, content, tags, createdAt);
    }
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

enum _CommentScope { event, address, external }

NostrEventAddress _parseAddress(String address, String name) {
  final parsed = NostrEventAddress.tryParse(address);
  if (parsed == null) {
    throw ArgumentError.value(
      address,
      name,
      'Invalid NIP-22 address; expected kind:pubkey:d',
    );
  }
  return parsed;
}

/// {@template nostr_comment}
/// Parsed NIP-22 kind-1111 comment (`22.md:11-42`).
///
/// A comment has one root scope family, exposed as one of
/// [rootEventId]/[rootAddress]/[rootExternalId], and a matching parent:
/// [parentEventId], [parentAddress] or [parentExternalId]. Uppercase tags carry
/// the root scope, lowercase tags the direct parent.
/// {@endtemplate}
class NostrComment {
  /// {@macro nostr_comment}
  const NostrComment({
    required this.content,
    this.rootEventId,
    this.rootAuthorPubkey,
    this.rootKind,
    this.rootAddress,
    this.rootExternalId,
    this.parentEventId,
    this.parentAuthorPubkey,
    this.parentKind,
    this.parentAddress,
    this.parentExternalId,
    this.relayUrl,
    this.tags = const [],
  });

  /// Comment body.
  final String content;

  /// `E` tag value: root event id.
  final String? rootEventId;

  /// `P` tag value (or the author of the root `E` tag).
  final String? rootAuthorPubkey;

  /// `K` tag value.
  final String? rootKind;

  /// `A` tag value: root `kind:pubkey:d` coordinate.
  final String? rootAddress;

  /// `I` tag value: root NIP-73 external identifier.
  final String? rootExternalId;

  /// `e` tag value: direct parent event id.
  final String? parentEventId;

  /// `p` tag value (or the author of the parent `e` tag).
  final String? parentAuthorPubkey;

  /// `k` tag value.
  final String? parentKind;

  /// `a` tag value: parent `kind:pubkey:d` coordinate.
  final String? parentAddress;

  /// `i` tag value: parent NIP-73 external identifier.
  final String? parentExternalId;

  /// Relay or web-page hint from the root reference tag.
  final String? relayUrl;

  /// Raw event tags.
  final List<List<String>> tags;

  /// Parses [event] as a NIP-22 comment, or returns `null` when it is not a
  /// kind-1111 event or mixes root scope families.
  static NostrComment? tryParse(NostrEvent event) {
    if (event.kind != 1111) {
      return null;
    }

    final tags = event.tags ?? <List<String>>[];
    final rootMarkers = <String>{
      for (final tag in tags)
        if (tag.isNotEmpty &&
            (tag.first == 'A' || tag.first == 'E' || tag.first == 'I'))
          tag.first,
    };
    if (rootMarkers.length > 1) {
      return null;
    }

    String? value(String name) {
      for (final tag in tags) {
        if (tag.length > 1 && tag.first == name) {
          return tag[1];
        }
      }
      return null;
    }

    String? authorOf(String name, String pubkeyName) {
      for (final tag in tags) {
        if (tag.isNotEmpty && tag.first == name && tag.length > 3) {
          return tag[3];
        }
      }
      return value(pubkeyName);
    }

    String? hintOf(String name) {
      for (final tag in tags) {
        if (tag.isNotEmpty && tag.first == name && tag.length > 2) {
          return tag[2];
        }
      }
      return null;
    }

    return NostrComment(
      content: event.content ?? '',
      rootEventId: value('E'),
      rootAuthorPubkey: authorOf('E', 'P'),
      rootKind: value('K'),
      rootAddress: value('A'),
      rootExternalId: value('I'),
      parentEventId: value('e'),
      parentAuthorPubkey: authorOf('e', 'p'),
      parentKind: value('k'),
      parentAddress: value('a'),
      parentExternalId: value('i'),
      relayUrl: hintOf('E') ?? hintOf('A') ?? hintOf('I'),
      tags: [
        for (final tag in tags) [...tag],
      ],
    );
  }

  /// Like [tryParse], but throws [ArgumentError] when [event] is not a valid
  /// NIP-22 comment.
  static NostrComment parse(NostrEvent event) {
    final comment = tryParse(event);
    if (comment == null) {
      throw ArgumentError(
        'Invalid NIP-22 comment event: expected kind 1111 with a single root '
        'scope family',
      );
    }
    return comment;
  }
}
