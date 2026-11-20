import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// Status values of a NIP-34 root patch, PR or issue.
enum NostrGitStatusKind {
  /// Kind 1630.
  open(1630, 'open'),

  /// Kind 1631: applied or merged for patches, resolved for issues.
  applied(1631, 'applied'),

  /// Kind 1632.
  closed(1632, 'closed'),

  /// Kind 1633.
  draft(1633, 'draft');

  const NostrGitStatusKind(this.kind, this.label);

  /// Event kind.
  final int kind;

  /// Human-readable status name.
  final String label;

  /// Resolves a status kind, returning `null` for non-status kinds.
  static NostrGitStatusKind? tryFromKind(int? kind) {
    for (final value in values) {
      if (value.kind == kind) {
        return value;
      }
    }

    return null;
  }
}

/// {@template nostr_git_clone_uri}
/// Parsed `nostr://` clone URI (34.md:34-59).
///
/// Accepted forms:
/// - `nostr://<naddr>`
/// - `nostr://<npub|nip05>/<identifier>`
/// - `nostr://<npub|nip05>/<relay-hint>/<identifier>`
///
/// [relayHint] and [identifier] are percent-encoded on the wire and decoded
/// in this object. [toString] rebuilds the canonical form, so parsed spec
/// examples round-trip byte for byte.
/// {@endtemplate}
class NostrGitCloneUri {
  const NostrGitCloneUri._({
    required this.raw,
    this.naddr,
    this.pubkeyOrNip05,
    this.relayHint,
    this.identifier,
  });

  /// Original URI.
  final String raw;

  /// `naddr` when the URI uses the entity form.
  final String? naddr;

  /// `npub` or NIP-05 identifier when the URI uses the path form.
  final String? pubkeyOrNip05;

  /// Decoded relay hint for the three-segment form.
  final String? relayHint;

  /// Decoded repository identifier (`d` tag value).
  final String? identifier;

  /// Whether this URI addresses the repository through an `naddr`.
  bool get isNaddr => naddr != null;

  /// Builds the `naddr` form.
  factory NostrGitCloneUri.naddr(String naddr) {
    if (!_isNaddrEntity(naddr)) {
      throw ArgumentError.value(naddr, 'naddr', 'Expected an naddr entity');
    }

    return NostrGitCloneUri._(raw: 'nostr://$naddr', naddr: naddr);
  }

  /// Builds the path form, with an optional relay hint.
  factory NostrGitCloneUri.repository({
    required String pubkeyOrNip05,
    required String identifier,
    String? relayHint,
  }) {
    if (!_isOwner(pubkeyOrNip05)) {
      throw ArgumentError.value(
        pubkeyOrNip05,
        'pubkeyOrNip05',
        'Expected an npub or a NIP-05 identifier',
      );
    }

    if (identifier.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Repository identifier must not be empty',
      );
    }

    final builder = StringBuffer('nostr://$pubkeyOrNip05/');

    if (relayHint != null) {
      if (relayHint.isEmpty) {
        throw ArgumentError.value(
          relayHint,
          'relayHint',
          'Relay hint must not be empty',
        );
      }

      builder
        ..write(_encodeSegment(relayHint))
        ..write('/');
    }

    builder.write(_encodeSegment(identifier));

    return NostrGitCloneUri.tryParse(builder.toString())!;
  }

  /// Parses [value], returning `null` when it is not a `nostr://` clone URI.
  static NostrGitCloneUri? tryParse(String value) {
    if (!value.startsWith('nostr://')) {
      return null;
    }

    final rest = value.substring('nostr://'.length);

    if (rest.isEmpty) {
      return null;
    }

    final segments = rest.split('/');

    if (segments.any((segment) => segment.isEmpty) || segments.length > 3) {
      return null;
    }

    final decoded = <String>[];
    for (final segment in segments) {
      final value = _tryDecodeSegment(segment);

      if (value == null) {
        return null;
      }

      decoded.add(value);
    }

    if (decoded.length == 1) {
      if (!_isNaddrEntity(decoded.single)) {
        return null;
      }

      return NostrGitCloneUri._(raw: value, naddr: decoded.single);
    }

    final owner = decoded.first;

    if (!_isOwner(owner)) {
      return null;
    }

    if (decoded.length == 2) {
      if (decoded[1].isEmpty) {
        return null;
      }

      return NostrGitCloneUri._(
        raw: value,
        pubkeyOrNip05: owner,
        identifier: decoded[1],
      );
    }

    if (decoded[1].isEmpty || decoded[2].isEmpty) {
      return null;
    }

    return NostrGitCloneUri._(
      raw: value,
      pubkeyOrNip05: owner,
      relayHint: decoded[1],
      identifier: decoded[2],
    );
  }

  /// Like [tryParse], but throws [FormatException] when invalid.
  static NostrGitCloneUri parse(String value) {
    final uri = tryParse(value);

    if (uri == null) {
      throw FormatException('Invalid nostr:// clone URI: $value');
    }

    return uri;
  }

  /// Canonical URI.
  @override
  String toString() {
    final entity = naddr;

    if (entity != null) {
      return 'nostr://$entity';
    }

    final owner = pubkeyOrNip05!;
    final hint = relayHint;
    final id = _encodeSegment(identifier!);

    return 'nostr://$owner/${hint == null ? '' : '${_encodeSegment(hint)}/'}$id';
  }

  static bool _isNaddrEntity(String value) =>
      value.startsWith('naddr1') && value.length > 'naddr1'.length;

  /// Encodes a URI segment using only RFC 3986 unreserved characters, so
  /// characters such as `!*'()` are escaped instead of left literal.
  static String _encodeSegment(String value) {
    final buffer = StringBuffer();

    for (final byte in utf8.encode(value)) {
      final unreserved = (byte >= 0x41 && byte <= 0x5a) ||
          (byte >= 0x61 && byte <= 0x7a) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2d ||
          byte == 0x2e ||
          byte == 0x5f ||
          byte == 0x7e;

      if (unreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }

    return buffer.toString();
  }

  static bool _isOwner(String value) {
    if (value.startsWith('npub1') || value.startsWith('nprofile1')) {
      return true;
    }

    // NIP-05 identifiers are either `name@domain` or a bare domain.
    return RegExp(r'^[^/@\s]+@[^/@\s]+\.[^/@\s]+$').hasMatch(value) ||
        RegExp(r'^[^/@\s]+\.[^/@\s]+$').hasMatch(value);
  }

  /// Validates percent escapes before decoding so malformed input returns
  /// `null` instead of throwing.
  static String? _tryDecodeSegment(String value) {
    const hexDigits = '0123456789abcdefABCDEF';

    for (var index = 0; index < value.length; index++) {
      if (value[index] != '%') {
        continue;
      }

      if (index + 2 >= value.length ||
          !hexDigits.contains(value[index + 1]) ||
          !hexDigits.contains(value[index + 2])) {
        return null;
      }

      index += 2;
    }

    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      // Invalid percent-encoded UTF-8 is bad input, not a caller error.
      return null;
    }
  }
}

/// {@template nostr_git_repo_announcement}
/// Parsed NIP-34 repository announcement (kind 30617).
/// {@endtemplate}
class NostrGitRepoAnnouncement {
  /// {@macro nostr_git_repo_announcement}
  const NostrGitRepoAnnouncement({
    required this.identifier,
    this.pubkey = '',
    this.name,
    this.description,
    this.web = const <String>[],
    this.clone = const <String>[],
    this.relays = const <String>[],
    this.maintainers = const <String>[],
    this.earliestUniqueCommit,
    this.hashtags = const <String>[],
    this.forkAddress,
    this.forkUrl,
    this.forkTag,
    this.forkRelayUrl,
    this.forkAuthorPubkey,
    this.tags = const <List<String>>[],
  });

  /// `d` tag: repository identifier.
  final String identifier;

  /// Maintainer public key, when parsed from an event.
  final String pubkey;

  /// `name` tag.
  final String? name;

  /// `description` tag.
  final String? description;

  /// `web` tags.
  final List<String> web;

  /// `clone` tags.
  final List<String> clone;

  /// `relays` tags.
  final List<String> relays;

  /// `maintainers` tags.
  final List<String> maintainers;

  /// `r` tag annotated `euc`.
  final String? earliestUniqueCommit;

  /// `t` tags.
  final List<String> hashtags;

  /// Address part of the first `u` tag for a subordinate fork.
  final String? forkAddress;

  /// Optional `<git-url>` part after the `|` separator in the fork `u` tag.
  final String? forkUrl;

  /// Raw fork `u` tag, preserved verbatim.
  final List<String>? forkTag;

  /// Relay hint on the fork `u` tag.
  final String? forkRelayUrl;

  /// Author hint on the fork `u` tag.
  final String? forkAuthorPubkey;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;

  /// Event address: `30617:<pubkey>:<identifier>`.
  String get address => '30617:$pubkey:$identifier';

  /// Whether the identifier, relay URLs and maintainer keys are valid.
  bool get isValid =>
      identifier.isNotEmpty &&
      relays.every(NostrValidators.isRelayUrl) &&
      maintainers.every(NostrValidators.isHex64) &&
      (earliestUniqueCommit == null ||
          NostrNip34.isCommitId(earliestUniqueCommit!));
}

/// {@template nostr_git_repo_state}
/// Parsed NIP-34 repository state announcement (kind 30618).
///
/// [refs] keeps full ref names such as `refs/heads/main`. [heads] and [tags]
/// are filtered views, and [headBranch] is the branch named by the `HEAD` tag.
/// {@endtemplate}
class NostrGitRepoState {
  /// {@macro nostr_git_repo_state}
  const NostrGitRepoState({
    required this.identifier,
    this.pubkey = '',
    this.refs = const <String, String>{},
    this.headBranch,
    this.tags = const <List<String>>[],
  });

  /// `d` tag matching the repository announcement.
  final String identifier;

  /// Maintainer public key, when parsed from an event.
  final String pubkey;

  /// Ref name to commit id.
  final Map<String, String> refs;

  /// Branch name from `HEAD = ref: refs/heads/<branch>`.
  final String? headBranch;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;

  /// `refs/heads/*` entries with the prefix stripped.
  Map<String, String> get heads => {
        for (final entry in refs.entries)
          if (entry.key.startsWith('refs/heads/'))
            entry.key.substring('refs/heads/'.length): entry.value,
      };

  /// `refs/tags/*` entries with the prefix stripped.
  Map<String, String> get tagRefs => {
        for (final entry in refs.entries)
          if (entry.key.startsWith('refs/tags/'))
            entry.key.substring('refs/tags/'.length): entry.value,
      };

  /// Whether the identifier is present and every ref value is a commit id.
  bool get isValid =>
      identifier.isNotEmpty &&
      refs.keys.every(
        (ref) => ref.startsWith('refs/heads/') || ref.startsWith('refs/tags/'),
      ) &&
      refs.values.every(NostrNip34.isCommitId);
}

/// {@template nostr_git_committer}
/// `committer` tag of a NIP-34 patch.
/// {@endtemplate}
class NostrGitCommitter {
  /// {@macro nostr_git_committer}
  const NostrGitCommitter({
    required this.name,
    required this.email,
    this.timestamp,
    this.timezoneOffsetMinutes,
  });

  /// Committer name.
  final String name;

  /// Committer email.
  final String email;

  /// Commit timestamp in unix seconds.
  final int? timestamp;

  /// Timezone offset in minutes.
  final int? timezoneOffsetMinutes;

  /// Serializes to a `committer` tag.
  List<String> toTag() => [
        'committer',
        name,
        email,
        if (timestamp != null) '$timestamp',
        if (timezoneOffsetMinutes != null) '$timezoneOffsetMinutes',
      ];
}

/// {@template nostr_git_patch}
/// Parsed NIP-34 patch (kind 1617).
///
/// The first bare `r` tag is the repository's earliest unique commit and any
/// later `r` tags point at the current commit (34.md:92-101). [rootEventId]
/// carries the optional NIP-10 `reply` tag toward a previous patch.
/// {@endtemplate}
class NostrGitPatch {
  /// {@macro nostr_git_patch}
  const NostrGitPatch({
    required this.content,
    this.pubkey = '',
    this.repositoryAddress,
    this.earliestUniqueCommit,
    this.currentCommits = const <String>[],
    this.recipients = const <String>[],
    this.isRoot = false,
    this.isRootRevision = false,
    this.commit,
    this.parentCommit,
    this.commitPgpSig,
    this.committer,
    this.rootEventId,
    this.tags = const <List<String>>[],
  });

  /// `git format-patch` output.
  final String content;

  /// Patch author, when parsed from an event.
  final String pubkey;

  /// `a` tag: base repository address.
  final String? repositoryAddress;

  /// First `r` tag.
  final String? earliestUniqueCommit;

  /// Later `r` tags.
  final List<String> currentCommits;

  /// `p` tags.
  final List<String> recipients;

  /// Whether a `t root` tag is present.
  final bool isRoot;

  /// Whether a `t root-revision` tag is present.
  final bool isRootRevision;

  /// `commit` tag.
  final String? commit;

  /// `parent-commit` tag.
  final String? parentCommit;

  /// `commit-pgp-sig` tag.
  final String? commitPgpSig;

  /// `committer` tag.
  final NostrGitCommitter? committer;

  /// Event id from the NIP-10 `reply` tag.
  final String? rootEventId;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;

  /// Whether the content is non-empty and every commit id is well formed.
  bool get isValid =>
      content.trim().isNotEmpty &&
      (earliestUniqueCommit == null ||
          NostrNip34.isCommitId(earliestUniqueCommit!)) &&
      (commit == null || NostrNip34.isCommitId(commit!)) &&
      (parentCommit == null || NostrNip34.isCommitId(parentCommit!)) &&
      currentCommits.every(NostrNip34.isCommitId);
}

/// {@template nostr_git_pull_request}
/// Parsed NIP-34 pull request (kind 1618).
/// {@endtemplate}
class NostrGitPullRequest {
  /// {@macro nostr_git_pull_request}
  const NostrGitPullRequest({
    required this.content,
    this.pubkey = '',
    this.repositoryAddress,
    this.earliestUniqueCommit,
    this.recipients = const <String>[],
    this.subject,
    this.labels = const <String>[],
    this.commit,
    this.clone = const <String>[],
    this.branchName,
    this.rootPatchEventId,
    this.mergeBase,
    this.tags = const <List<String>>[],
  });

  /// Markdown description.
  final String content;

  /// PR author, when parsed from an event.
  final String pubkey;

  /// `a` tag: base repository address.
  final String? repositoryAddress;

  /// `r` tag: earliest unique commit.
  final String? earliestUniqueCommit;

  /// `p` tags.
  final List<String> recipients;

  /// `subject` tag.
  final String? subject;

  /// `t` tags.
  final List<String> labels;

  /// `c` tag: tip commit.
  final String? commit;

  /// `clone` tags.
  final List<String> clone;

  /// `branch-name` tag.
  final String? branchName;

  /// `e` tag: root patch this PR revises.
  final String? rootPatchEventId;

  /// `merge-base` tag.
  final String? mergeBase;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;

  /// Whether the tip commit is valid and at least one clone URL is present.
  bool get isValid =>
      commit != null &&
      NostrNip34.isCommitId(commit!) &&
      clone.isNotEmpty &&
      (earliestUniqueCommit == null ||
          NostrNip34.isCommitId(earliestUniqueCommit!)) &&
      (mergeBase == null || NostrNip34.isCommitId(mergeBase!));
}

/// {@template nostr_git_pull_request_update}
/// Parsed NIP-34 pull request update (kind 1619).
///
/// The task brief calls 1619 a reply, but the pinned spec defines it as an
/// update that moves a PR tip using NIP-22 `E`/`P` tags (34.md:133-152).
/// Replies to issues, patches and PRs are plain NIP-22 kind-1111 comments and
/// are intentionally not reimplemented here.
/// {@endtemplate}
class NostrGitPullRequestUpdate {
  /// {@macro nostr_git_pull_request_update}
  const NostrGitPullRequestUpdate({
    this.pubkey = '',
    this.repositoryAddress,
    this.earliestUniqueCommit,
    this.recipients = const <String>[],
    this.pullRequestEventId,
    this.pullRequestAuthorPubkey,
    this.commit,
    this.clone = const <String>[],
    this.mergeBase,
    this.tags = const <List<String>>[],
  });

  /// Update author, when parsed from an event.
  final String pubkey;

  /// `a` tag: base repository address.
  final String? repositoryAddress;

  /// `r` tag: earliest unique commit.
  final String? earliestUniqueCommit;

  /// `p` tags.
  final List<String> recipients;

  /// `E` tag: updated PR.
  final String? pullRequestEventId;

  /// `P` tag: PR author.
  final String? pullRequestAuthorPubkey;

  /// `c` tag: new tip.
  final String? commit;

  /// `clone` tags.
  final List<String> clone;

  /// `merge-base` tag.
  final String? mergeBase;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;

  /// Whether the update names a PR, a valid tip and at least one clone URL.
  bool get isValid =>
      pullRequestEventId != null &&
      commit != null &&
      NostrNip34.isCommitId(commit!) &&
      clone.isNotEmpty;
}

/// {@template nostr_git_issue}
/// Parsed NIP-34 issue (kind 1621).
/// {@endtemplate}
class NostrGitIssue {
  /// {@macro nostr_git_issue}
  const NostrGitIssue({
    required this.content,
    this.pubkey = '',
    this.repositoryAddress,
    this.recipients = const <String>[],
    this.subject,
    this.labels = const <String>[],
    this.tags = const <List<String>>[],
  });

  /// Markdown issue text.
  final String content;

  /// Issue author, when parsed from an event.
  final String pubkey;

  /// `a` tag: repository address.
  final String? repositoryAddress;

  /// `p` tags.
  final List<String> recipients;

  /// `subject` tag.
  final String? subject;

  /// `t` tags.
  final List<String> labels;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;
}

/// {@template nostr_git_patch_ref}
/// One `q` tag of a NIP-34 status event.
///
/// The tag is `['q', <event-id>, <relay-url>?, <pubkey>?]` (34.md:220); the
/// relay hint and author slot are optional.
/// {@endtemplate}
class NostrGitPatchRef {
  /// {@macro nostr_git_patch_ref}
  const NostrGitPatchRef(this.id, {this.relayUrl, this.pubkey});

  /// Applied or merged patch event id.
  final String id;

  /// Optional relay hint.
  ///
  /// An empty string means the slot is present but empty, not absent: it keeps
  /// the following author slot in position, and [toTag] emits it. `null` omits
  /// the slot.
  final String? relayUrl;

  /// Optional patch author public key.
  final String? pubkey;

  /// Serializes to a `q` tag, keeping the optional slots in spec order.
  List<String> toTag() => [
        'q',
        id,
        if (relayUrl != null) relayUrl!,
        if (pubkey != null) pubkey!,
      ];
}

/// {@template nostr_git_status}
/// Parsed NIP-34 status event (kinds 1630-1633).
///
/// Root and accepted-revision references use four-slot `e` tags with the
/// literal `root` and `reply` markers (34.md:196-200).
/// {@endtemplate}
class NostrGitStatus {
  /// {@macro nostr_git_status}
  const NostrGitStatus({
    required this.status,
    this.content = '',
    this.pubkey = '',
    this.rootEventId,
    this.acceptedRevisionId,
    this.recipients = const <String>[],
    this.repositoryAddress,
    this.repositoryRelayUrl,
    this.earliestUniqueCommit,
    this.appliedPatchIds = const <String>[],
    this.appliedPatches = const <NostrGitPatchRef>[],
    this.mergeCommit,
    this.appliedAsCommits = const <String>[],
    this.commitRefs = const <String>[],
    this.tags = const <List<String>>[],
  });

  /// One of the four status kinds.
  final NostrGitStatusKind status;

  /// Optional markdown explanation.
  final String content;

  /// Status author, when parsed from an event.
  final String pubkey;

  /// `e` tag marked `root`.
  final String? rootEventId;

  /// `e` tag marked `reply`.
  final String? acceptedRevisionId;

  /// `p` tags.
  final List<String> recipients;

  /// `a` tag: repository address.
  final String? repositoryAddress;

  /// Relay hint on the `a` tag.
  final String? repositoryRelayUrl;

  /// `r` tag: earliest unique commit.
  final String? earliestUniqueCommit;

  /// `q` tags: applied or merged patch ids.
  final List<String> appliedPatchIds;

  /// `q` tags with their optional relay hint and author slots.
  final List<NostrGitPatchRef> appliedPatches;

  /// `merge-commit` tag.
  final String? mergeCommit;

  /// `applied-as-commits` tag values.
  final List<String> appliedAsCommits;

  /// Bare `r` tags after the first one, i.e. merge or applied commit ids.
  final List<String> commitRefs;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;
}

/// {@template nostr_git_repo_list}
/// Parsed NIP-34 grasp server list (kind 10317).
/// {@endtemplate}
class NostrGitRepoList {
  /// {@macro nostr_git_repo_list}
  const NostrGitRepoList({
    this.graspServers = const <String>[],
    this.pubkey = '',
    this.tags = const <List<String>>[],
  });

  /// `g` tags: grasp websocket URLs in preference order.
  final List<String> graspServers;

  /// List author, when parsed from an event.
  final String pubkey;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;

  /// Whether every grasp URL is a websocket URL.
  bool get isValid => graspServers.every(NostrValidators.isRelayUrl);
}

/// {@template nip34}
/// NIP-34 `git` stuff: repository announcements and state, patches, pull
/// requests and updates, issues, statuses and grasp lists.
///
/// Repository metadata kinds are 30617/30618, collaboration kinds are
/// 1617-1633 and the grasp list is 10317. Deprecated kind 1622 replies are
/// deliberately not implemented; replies use NIP-22 kind 1111.
///
/// [publish] signs events through the signer bound to this instance.
/// {@endtemplate}
class NostrNip34 {
  /// {@macro nip34}
  NostrNip34({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind 30617: repository announcement.
  static const int repoAnnouncementKind = 30617;

  /// Kind 30618: repository state announcement.
  static const int repoStateKind = 30618;

  /// Kind 1617: patch.
  static const int patchKind = 1617;

  /// Kind 1618: pull request.
  static const int pullRequestKind = 1618;

  /// Kind 1619: pull request update.
  static const int pullRequestUpdateKind = 1619;

  /// Kind 1621: issue.
  static const int issueKind = 1621;

  /// Kind 10317: grasp server list.
  static const int repoListKind = 10317;

  /// Whether [value] is a 40-char SHA-1 or 64-char SHA-256 commit id.
  static bool isCommitId(String value) =>
      (value.length == 40 || value.length == 64) &&
      RegExp(r'^[0-9a-f]+$').hasMatch(value);

  /// Builds an unsigned kind-30617 repository announcement.
  static NostrEvent createRepoAnnouncement({
    required String identifier,
    String? name,
    String? description,
    List<String> web = const <String>[],
    List<String> clone = const <String>[],
    List<String> relays = const <String>[],
    List<String> maintainers = const <String>[],
    String? earliestUniqueCommit,
    List<String> hashtags = const <String>[],
    String? forkAddress,
    String? forkUrl,
    String? forkRelayUrl,
    String? forkAuthorPubkey,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Repository identifier is required',
      );
    }

    for (final relay in relays) {
      if (!NostrValidators.isRelayUrl(relay)) {
        throw ArgumentError.value(
          relay,
          'relays',
          'Expected a ws:// or wss:// relay URL',
        );
      }
    }

    for (final maintainer in maintainers) {
      if (!NostrValidators.isHex64(maintainer)) {
        throw ArgumentError.value(
          maintainer,
          'maintainers',
          'Expected 64 lowercase hex characters',
        );
      }
    }

    if (earliestUniqueCommit != null && !isCommitId(earliestUniqueCommit)) {
      throw ArgumentError.value(
        earliestUniqueCommit,
        'earliestUniqueCommit',
        'Expected a 40 or 64 character commit id',
      );
    }

    if (forkAddress != null) {
      final parsed = NostrEventAddress.tryParse(forkAddress);

      if (parsed == null || parsed.kind != repoAnnouncementKind) {
        throw ArgumentError.value(
          forkAddress,
          'forkAddress',
          'Expected a 30617 repository address',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: repoAnnouncementKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', identifier],
        if (name != null) ['name', name],
        if (description != null) ['description', description],
        for (final url in web) ['web', url],
        for (final url in clone) ['clone', url],
        for (final relay in relays) ['relays', relay],
        if (earliestUniqueCommit != null) ['r', earliestUniqueCommit, 'euc'],
        for (final maintainer in maintainers) ['maintainers', maintainer],
        if (forkAddress != null)
          [
            'u',
            forkUrl == null ? forkAddress : '$forkAddress|$forkUrl',
            if (forkRelayUrl != null)
              forkRelayUrl
            else if (forkAuthorPubkey != null)
              '',
            if (forkAuthorPubkey != null) forkAuthorPubkey,
          ],
        for (final hashtag in hashtags) ['t', hashtag],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-30618 repository state announcement.
  ///
  /// [heads] and [tags] map branch/tag names to commit ids. [headBranch]
  /// emits `['HEAD', 'ref: refs/heads/<branch>']`.
  static NostrEvent createRepoState({
    required String identifier,
    Map<String, String> heads = const <String, String>{},
    Map<String, String> tags = const <String, String>{},
    String? headBranch,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Repository identifier is required',
      );
    }

    for (final commit in [...heads.values, ...tags.values]) {
      if (!isCommitId(commit)) {
        throw ArgumentError.value(
          commit,
          'heads/tags',
          'Expected a 40 or 64 character commit id',
        );
      }
    }

    if (headBranch != null && !heads.containsKey(headBranch)) {
      throw ArgumentError.value(
        headBranch,
        'headBranch',
        'headBranch must be one of the heads',
      );
    }

    return NostrEvent(
      id: null,
      kind: repoStateKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', identifier],
        for (final entry in heads.entries)
          ['refs/heads/${entry.key}', entry.value],
        for (final entry in tags.entries)
          ['refs/tags/${entry.key}', entry.value],
        if (headBranch != null) ['HEAD', 'ref: refs/heads/$headBranch'],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-1617 patch.
  ///
  /// [rootEventId] emits a four-slot NIP-10 `['e', id, relay, 'reply']` tag
  /// pointing at the previous patch. Only the first patch of a series sets
  /// [isRoot]; the first patch of each revision sets [isRootRevision].
  static NostrEvent createPatch({
    required String content,
    String? repositoryAddress,
    String? earliestUniqueCommit,
    List<String> recipients = const <String>[],
    bool isRoot = false,
    bool isRootRevision = false,
    String? commit,
    String? currentCommit,
    String? parentCommit,
    String? commitPgpSig,
    NostrGitCommitter? committer,
    String? rootEventId,
    String? relayUrl,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (content.trim().isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Patch content must not be empty',
      );
    }

    _validateRepoAddress(repositoryAddress);
    _validateRecipients(recipients);
    _validateCommit(earliestUniqueCommit, 'earliestUniqueCommit');
    _validateCommit(commit, 'commit');
    _validateCommit(currentCommit, 'currentCommit');
    _validateCommit(parentCommit, 'parentCommit');

    if (rootEventId != null && !NostrValidators.isHex64(rootEventId)) {
      throw ArgumentError.value(
        rootEventId,
        'rootEventId',
        'Expected 64 lowercase hex characters',
      );
    }

    return NostrEvent(
      id: null,
      kind: patchKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (repositoryAddress != null) ['a', repositoryAddress],
        if (earliestUniqueCommit != null) ['r', earliestUniqueCommit],
        for (final recipient in recipients) ['p', recipient],
        if (isRoot) ['t', 'root'],
        if (isRootRevision) ['t', 'root-revision'],
        if (commit != null) ['commit', commit],
        if (currentCommit != null) ['r', currentCommit],
        if (parentCommit != null) ['parent-commit', parentCommit],
        if (commitPgpSig != null) ['commit-pgp-sig', commitPgpSig],
        if (committer != null) committer.toTag(),
        if (rootEventId != null) ['e', rootEventId, relayUrl ?? '', 'reply'],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-1618 pull request.
  static NostrEvent createPullRequest({
    required String content,
    required String commit,
    required List<String> clone,
    String? repositoryAddress,
    String? earliestUniqueCommit,
    List<String> recipients = const <String>[],
    String? subject,
    List<String> labels = const <String>[],
    String? branchName,
    String? rootPatchEventId,
    String? mergeBase,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    _validateRepoAddress(repositoryAddress);
    _validateRecipients(recipients);
    _validateCommit(commit, 'commit');
    _validateCommit(earliestUniqueCommit, 'earliestUniqueCommit');
    _validateCommit(mergeBase, 'mergeBase');
    _validateCloneUrls(clone, requireOne: true);

    if (rootPatchEventId != null &&
        !NostrValidators.isHex64(rootPatchEventId)) {
      throw ArgumentError.value(
        rootPatchEventId,
        'rootPatchEventId',
        'Expected 64 lowercase hex characters',
      );
    }

    return NostrEvent(
      id: null,
      kind: pullRequestKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (repositoryAddress != null) ['a', repositoryAddress],
        if (earliestUniqueCommit != null) ['r', earliestUniqueCommit],
        for (final recipient in recipients) ['p', recipient],
        if (subject != null) ['subject', subject],
        for (final label in labels) ['t', label],
        ['c', commit],
        for (final url in clone) ['clone', url],
        if (branchName != null) ['branch-name', branchName],
        if (rootPatchEventId != null) ['e', rootPatchEventId],
        if (mergeBase != null) ['merge-base', mergeBase],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-1619 pull request update.
  static NostrEvent createPullRequestUpdate({
    required String pullRequestEventId,
    required String pullRequestAuthorPubkey,
    required String commit,
    required List<String> clone,
    String? repositoryAddress,
    String? earliestUniqueCommit,
    List<String> recipients = const <String>[],
    String? mergeBase,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (!NostrValidators.isHex64(pullRequestEventId)) {
      throw ArgumentError.value(
        pullRequestEventId,
        'pullRequestEventId',
        'Expected 64 lowercase hex characters',
      );
    }

    if (!NostrValidators.isHex64(pullRequestAuthorPubkey)) {
      throw ArgumentError.value(
        pullRequestAuthorPubkey,
        'pullRequestAuthorPubkey',
        'Expected 64 lowercase hex characters',
      );
    }

    _validateRepoAddress(repositoryAddress);
    _validateRecipients(recipients);
    _validateCommit(commit, 'commit');
    _validateCommit(earliestUniqueCommit, 'earliestUniqueCommit');
    _validateCommit(mergeBase, 'mergeBase');
    _validateCloneUrls(clone, requireOne: true);

    return NostrEvent(
      id: null,
      kind: pullRequestUpdateKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (repositoryAddress != null) ['a', repositoryAddress],
        if (earliestUniqueCommit != null) ['r', earliestUniqueCommit],
        for (final recipient in recipients) ['p', recipient],
        ['E', pullRequestEventId],
        ['P', pullRequestAuthorPubkey],
        ['c', commit],
        for (final url in clone) ['clone', url],
        if (mergeBase != null) ['merge-base', mergeBase],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-1621 issue.
  static NostrEvent createIssue({
    required String content,
    String? repositoryAddress,
    List<String> recipients = const <String>[],
    String? subject,
    List<String> labels = const <String>[],
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (content.trim().isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Issue content must not be empty',
      );
    }

    _validateRepoAddress(repositoryAddress);
    _validateRecipients(recipients);

    return NostrEvent(
      id: null,
      kind: issueKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (repositoryAddress != null) ['a', repositoryAddress],
        for (final recipient in recipients) ['p', recipient],
        if (subject != null) ['subject', subject],
        for (final label in labels) ['t', label],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned status event for [kind].
  ///
  /// [rootEventId] becomes `['e', id, '', 'root']`; [acceptedRevisionId]
  /// becomes `['e', id, '', 'reply']` (34.md:199-200).
  static NostrEvent createStatus({
    required NostrGitStatusKind kind,
    required String rootEventId,
    String? acceptedRevisionId,
    String content = '',
    List<String> recipients = const <String>[],
    String? repositoryAddress,
    String? repositoryRelayUrl,
    String? earliestUniqueCommit,
    List<String> appliedPatchIds = const <String>[],
    List<NostrGitPatchRef> appliedPatches = const <NostrGitPatchRef>[],
    String? mergeCommit,
    List<String> appliedAsCommits = const <String>[],
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (!NostrValidators.isHex64(rootEventId)) {
      throw ArgumentError.value(
        rootEventId,
        'rootEventId',
        'Expected 64 lowercase hex characters',
      );
    }

    if (acceptedRevisionId != null &&
        !NostrValidators.isHex64(acceptedRevisionId)) {
      throw ArgumentError.value(
        acceptedRevisionId,
        'acceptedRevisionId',
        'Expected 64 lowercase hex characters',
      );
    }

    _validateRecipients(recipients);
    _validateRepoAddress(repositoryAddress);
    _validateCommit(earliestUniqueCommit, 'earliestUniqueCommit');
    _validateCommit(mergeCommit, 'mergeCommit');

    for (final commit in appliedAsCommits) {
      _validateCommit(commit, 'appliedAsCommits');
    }

    return NostrEvent(
      id: null,
      kind: kind.kind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['e', rootEventId, '', 'root'],
        if (acceptedRevisionId != null) ['e', acceptedRevisionId, '', 'reply'],
        for (final recipient in recipients) ['p', recipient],
        if (repositoryAddress != null)
          [
            'a',
            repositoryAddress,
            if (repositoryRelayUrl != null) repositoryRelayUrl,
          ],
        if (earliestUniqueCommit != null) ['r', earliestUniqueCommit],
        for (final patch in appliedPatchIds) ['q', patch],
        for (final patch in appliedPatches) patch.toTag(),
        if (mergeCommit != null) ['merge-commit', mergeCommit],
        if (mergeCommit != null) ['r', mergeCommit],
        if (appliedAsCommits.isNotEmpty)
          ['applied-as-commits', ...appliedAsCommits],
        for (final commit in appliedAsCommits) ['r', commit],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-10317 grasp server list.
  static NostrEvent createRepoList({
    List<String> graspServers = const <String>[],
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    for (final url in graspServers) {
      if (!NostrValidators.isRelayUrl(url)) {
        throw ArgumentError.value(
          url,
          'graspServers',
          'Expected a ws:// or wss:// relay URL',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: repoListKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final url in graspServers) ['g', url],
        ...extraTags,
      ],
    );
  }

  /// Signs [event] with the bound signer; sending it is up to the caller.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses a kind-30617 announcement, returning `null` when invalid.
  static NostrGitRepoAnnouncement? tryParseRepoAnnouncement(
    NostrEvent event,
  ) {
    if (event.kind != repoAnnouncementKind) {
      return null;
    }

    final identifier = NostrTags.first(event.tags, 'd');

    if (identifier == null || identifier.isEmpty) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final maintainers = NostrTags.all(tags, 'maintainers');

    if (!maintainers.every(NostrValidators.isHex64)) {
      return null;
    }

    String? forkAddress;
    String? forkUrl;
    List<String>? forkTag;
    String? forkRelay;
    String? forkAuthor;
    final rawForkTag = NostrTags.tag(tags, 'u');

    if (rawForkTag != null && rawForkTag.length > 1) {
      forkTag = List<String>.of(rawForkTag);
      final raw = rawForkTag[1];
      final separator = raw.indexOf('|');

      if (separator < 0) {
        forkAddress = raw;
      } else {
        forkAddress = raw.substring(0, separator);
        final url = raw.substring(separator + 1);
        forkUrl = url.isEmpty ? null : url;
      }

      forkRelay = rawForkTag.length > 2 && rawForkTag[2].isNotEmpty
          ? rawForkTag[2]
          : null;
      forkAuthor = rawForkTag.length > 3 && rawForkTag[3].isNotEmpty
          ? rawForkTag[3]
          : null;
    }

    final consumed = <String>{
      'd',
      'name',
      'description',
      'web',
      'clone',
      'relays',
      'maintainers',
      't',
      'u',
    };
    final extra = <List<String>>[
      for (final tag in tags)
        if (tag.isEmpty || !consumed.contains(tag.first))
          if (tag.isEmpty ||
              !(tag.first == 'r' && tag.length > 2 && tag[2] == 'euc'))
            List<String>.of(tag),
    ];

    final announcement = NostrGitRepoAnnouncement(
      identifier: identifier,
      pubkey: event.pubkey,
      name: NostrTags.first(tags, 'name'),
      description: NostrTags.first(tags, 'description'),
      web: NostrTags.all(tags, 'web'),
      clone: NostrTags.all(tags, 'clone'),
      relays: NostrTags.all(tags, 'relays'),
      maintainers: maintainers,
      earliestUniqueCommit: _euc(tags),
      hashtags: NostrTags.all(tags, 't'),
      forkAddress: forkAddress,
      forkUrl: forkUrl,
      forkTag: forkTag,
      forkRelayUrl: forkRelay,
      forkAuthorPubkey: forkAuthor,
      tags: extra,
    );

    return announcement.isValid ? announcement : null;
  }

  /// Like [tryParseRepoAnnouncement], but throws [ArgumentError].
  static NostrGitRepoAnnouncement parseRepoAnnouncement(NostrEvent event) {
    final announcement = tryParseRepoAnnouncement(event);

    if (announcement == null) {
      throw ArgumentError('Invalid NIP-34 repository announcement event');
    }

    return announcement;
  }

  /// Parses a kind-30618 repository state, returning `null` when invalid.
  static NostrGitRepoState? tryParseRepoState(NostrEvent event) {
    if (event.kind != repoStateKind) {
      return null;
    }

    final identifier = NostrTags.first(event.tags, 'd');

    if (identifier == null || identifier.isEmpty) {
      return null;
    }

    final refs = <String, String>{};
    String? headBranch;
    final extra = <List<String>>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isEmpty) {
        continue;
      }

      if (tag.first.startsWith('refs/')) {
        if (tag.length < 2 || !isCommitId(tag[1])) {
          return null;
        }

        refs[tag.first] = tag[1];
        continue;
      }

      if (tag.first == 'HEAD') {
        final head = tag.length > 1 ? tag[1] : '';

        if (!head.startsWith('ref: refs/heads/')) {
          return null;
        }

        headBranch = head.substring('ref: refs/heads/'.length);
        if (headBranch.isEmpty) {
          return null;
        }

        continue;
      }

      if (tag.first == 'd') {
        continue;
      }

      extra.add(List<String>.of(tag));
    }

    final state = NostrGitRepoState(
      identifier: identifier,
      pubkey: event.pubkey,
      refs: refs,
      headBranch: headBranch,
      tags: extra,
    );

    return state.isValid ? state : null;
  }

  /// Like [tryParseRepoState], but throws [ArgumentError].
  static NostrGitRepoState parseRepoState(NostrEvent event) {
    final state = tryParseRepoState(event);

    if (state == null) {
      throw ArgumentError('Invalid NIP-34 repository state event');
    }

    return state;
  }

  /// Parses a kind-1617 patch, returning `null` when invalid.
  static NostrGitPatch? tryParsePatch(NostrEvent event) {
    if (event.kind != patchKind) {
      return null;
    }

    final content = event.content ?? '';

    if (content.trim().isEmpty) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final currentCommits = <String>[];
    var earliestUniqueCommit = NostrTags.first(tags, 'r');
    var sawEuc = false;
    var isRoot = false;
    var isRootRevision = false;
    NostrGitCommitter? committer;
    String? rootEventId;
    final extra = <List<String>>[];

    for (final tag in tags) {
      if (tag.isEmpty) {
        continue;
      }

      switch (tag.first) {
        case 'r':
          if (!sawEuc) {
            sawEuc = true;
            earliestUniqueCommit = tag.length > 1 ? tag[1] : null;
          } else if (tag.length > 1) {
            currentCommits.add(tag[1]);
          }
        case 't':
          if (tag.length > 1 &&
              (tag[1] == 'root' || tag[1] == 'root-revision')) {
            if (tag[1] == 'root') {
              isRoot = true;
            } else {
              isRootRevision = true;
            }
          } else {
            extra.add(List<String>.of(tag));
          }
        case 'e':
          rootEventId = tag.length > 1 ? tag[1] : null;
        case 'committer':
          committer = _parseCommitter(tag);
        case 'a':
        case 'p':
        case 'commit':
        case 'parent-commit':
        case 'commit-pgp-sig':
          continue;
        default:
          extra.add(List<String>.of(tag));
      }
    }

    final patch = NostrGitPatch(
      content: content,
      pubkey: event.pubkey,
      repositoryAddress: NostrTags.first(tags, 'a'),
      earliestUniqueCommit: earliestUniqueCommit,
      currentCommits: currentCommits,
      recipients: NostrTags.all(tags, 'p'),
      isRoot: isRoot,
      isRootRevision: isRootRevision,
      commit: NostrTags.first(tags, 'commit'),
      parentCommit: NostrTags.first(tags, 'parent-commit'),
      commitPgpSig: NostrTags.first(tags, 'commit-pgp-sig'),
      committer: committer,
      rootEventId: rootEventId,
      tags: extra,
    );

    if (!patch.isValid ||
        (patch.rootEventId != null &&
            !NostrValidators.isHex64(patch.rootEventId!))) {
      return null;
    }

    return patch;
  }

  /// Like [tryParsePatch], but throws [ArgumentError].
  static NostrGitPatch parsePatch(NostrEvent event) {
    final patch = tryParsePatch(event);

    if (patch == null) {
      throw ArgumentError('Invalid NIP-34 patch event');
    }

    return patch;
  }

  /// Parses a kind-1618 pull request, returning `null` when invalid.
  static NostrGitPullRequest? tryParsePullRequest(NostrEvent event) {
    if (event.kind != pullRequestKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final clone = NostrTags.all(tags, 'clone');
    final rootPatchEventId = NostrTags.first(tags, 'e');

    if (!_areCloneUrls(clone) || clone.isEmpty) {
      return null;
    }

    if (rootPatchEventId != null &&
        !NostrValidators.isHex64(rootPatchEventId)) {
      return null;
    }

    final consumed = <String>{
      'a',
      'r',
      'p',
      'subject',
      't',
      'c',
      'clone',
      'branch-name',
      'e',
      'merge-base',
    };
    final pr = NostrGitPullRequest(
      content: event.content ?? '',
      pubkey: event.pubkey,
      repositoryAddress: NostrTags.first(tags, 'a'),
      earliestUniqueCommit: NostrTags.first(tags, 'r'),
      recipients: NostrTags.all(tags, 'p'),
      subject: NostrTags.first(tags, 'subject'),
      labels: NostrTags.all(tags, 't'),
      commit: NostrTags.first(tags, 'c'),
      clone: clone,
      branchName: NostrTags.first(tags, 'branch-name'),
      rootPatchEventId: rootPatchEventId,
      mergeBase: NostrTags.first(tags, 'merge-base'),
      tags: [
        for (final tag in tags)
          if (tag.isEmpty || !consumed.contains(tag.first))
            List<String>.of(tag),
      ],
    );

    return pr.isValid ? pr : null;
  }

  /// Like [tryParsePullRequest], but throws [ArgumentError].
  static NostrGitPullRequest parsePullRequest(NostrEvent event) {
    final pr = tryParsePullRequest(event);

    if (pr == null) {
      throw ArgumentError('Invalid NIP-34 pull request event');
    }

    return pr;
  }

  /// Parses a kind-1619 PR update, returning `null` when invalid.
  static NostrGitPullRequestUpdate? tryParsePullRequestUpdate(
    NostrEvent event,
  ) {
    if (event.kind != pullRequestUpdateKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final clone = NostrTags.all(tags, 'clone');
    final pullRequestEventId = NostrTags.first(tags, 'E');

    if (pullRequestEventId == null ||
        !NostrValidators.isHex64(pullRequestEventId) ||
        !_areCloneUrls(clone) ||
        clone.isEmpty) {
      return null;
    }

    final consumed = <String>{
      'a',
      'r',
      'p',
      'E',
      'P',
      'c',
      'clone',
      'merge-base',
    };
    final update = NostrGitPullRequestUpdate(
      pubkey: event.pubkey,
      repositoryAddress: NostrTags.first(tags, 'a'),
      earliestUniqueCommit: NostrTags.first(tags, 'r'),
      recipients: NostrTags.all(tags, 'p'),
      pullRequestEventId: pullRequestEventId,
      pullRequestAuthorPubkey: NostrTags.first(tags, 'P'),
      commit: NostrTags.first(tags, 'c'),
      clone: clone,
      mergeBase: NostrTags.first(tags, 'merge-base'),
      tags: [
        for (final tag in tags)
          if (tag.isEmpty || !consumed.contains(tag.first))
            List<String>.of(tag),
      ],
    );

    return update.isValid ? update : null;
  }

  /// Like [tryParsePullRequestUpdate], but throws [ArgumentError].
  static NostrGitPullRequestUpdate parsePullRequestUpdate(NostrEvent event) {
    final update = tryParsePullRequestUpdate(event);

    if (update == null) {
      throw ArgumentError('Invalid NIP-34 pull request update event');
    }

    return update;
  }

  /// Parses a kind-1621 issue, returning `null` when invalid.
  static NostrGitIssue? tryParseIssue(NostrEvent event) {
    if (event.kind != issueKind) {
      return null;
    }

    final content = event.content ?? '';

    if (content.trim().isEmpty) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final consumed = <String>{'a', 'p', 'subject', 't'};

    return NostrGitIssue(
      content: content,
      pubkey: event.pubkey,
      repositoryAddress: NostrTags.first(tags, 'a'),
      recipients: NostrTags.all(tags, 'p'),
      subject: NostrTags.first(tags, 'subject'),
      labels: NostrTags.all(tags, 't'),
      tags: [
        for (final tag in tags)
          if (tag.isEmpty || !consumed.contains(tag.first))
            List<String>.of(tag),
      ],
    );
  }

  /// Like [tryParseIssue], but throws [ArgumentError].
  static NostrGitIssue parseIssue(NostrEvent event) {
    final issue = tryParseIssue(event);

    if (issue == null) {
      throw ArgumentError('Invalid NIP-34 issue event');
    }

    return issue;
  }

  /// Parses a kind-1630..1633 status, returning `null` when invalid.
  static NostrGitStatus? tryParseStatus(NostrEvent event) {
    final status = NostrGitStatusKind.tryFromKind(event.kind);

    if (status == null) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    String? rootEventId;
    String? acceptedRevisionId;
    final commitRefs = <String>[];
    final appliedPatches = <NostrGitPatchRef>[];
    var sawEuc = false;
    final extra = <List<String>>[];

    for (final tag in tags) {
      if (tag.isEmpty) {
        continue;
      }

      switch (tag.first) {
        case 'e':
          if (tag.length < 2) {
            return null;
          }

          final marker = tag.length > 3 ? tag[3] : '';

          if (marker == 'root') {
            rootEventId = tag[1];
          } else if (marker == 'reply' || marker == 'revision') {
            acceptedRevisionId = tag[1];
          } else {
            // Tolerate older events without the literal marker; the first
            // unmarked e tag addresses the root.
            rootEventId ??= tag[1];
          }
        case 'r':
          if (!sawEuc) {
            sawEuc = true;
          } else if (tag.length > 1) {
            commitRefs.add(tag[1]);
          }
        case 'a':
        case 'p':
          continue;
        case 'q':
          if (tag.length < 2) {
            return null;
          }

          final hasPubkey = tag.length > 3 && tag[3].isNotEmpty;
          final relay = tag.length > 2 ? tag[2] : '';

          appliedPatches.add(
            NostrGitPatchRef(
              tag[1],
              relayUrl: relay.isNotEmpty || hasPubkey ? relay : null,
              pubkey: hasPubkey ? tag[3] : null,
            ),
          );
          continue;
        case 'merge-commit':
        case 'applied-as-commits':
          continue;
        default:
          extra.add(List<String>.of(tag));
      }
    }

    if (rootEventId == null || !NostrValidators.isHex64(rootEventId)) {
      return null;
    }

    if (acceptedRevisionId != null &&
        !NostrValidators.isHex64(acceptedRevisionId)) {
      return null;
    }

    final parsed = NostrGitStatus(
      status: status,
      content: event.content ?? '',
      pubkey: event.pubkey,
      rootEventId: rootEventId,
      acceptedRevisionId: acceptedRevisionId,
      recipients: NostrTags.all(tags, 'p'),
      repositoryAddress: NostrTags.first(tags, 'a'),
      repositoryRelayUrl: NostrTags.at(
        NostrTags.tag(tags, 'a'),
        2,
      ),
      earliestUniqueCommit: NostrTags.first(tags, 'r'),
      appliedPatchIds: [
        for (final patch in appliedPatches) patch.id,
      ],
      appliedPatches: appliedPatches,
      mergeCommit: NostrTags.first(tags, 'merge-commit'),
      appliedAsCommits: NostrTags.tail(
        NostrTags.tag(tags, 'applied-as-commits') ??
            const <String>['applied-as-commits'],
      ),
      commitRefs: commitRefs,
      tags: extra,
    );

    if (parsed.mergeCommit != null && !isCommitId(parsed.mergeCommit!)) {
      return null;
    }

    return parsed;
  }

  /// Like [tryParseStatus], but throws [ArgumentError].
  static NostrGitStatus parseStatus(NostrEvent event) {
    final status = tryParseStatus(event);

    if (status == null) {
      throw ArgumentError('Invalid NIP-34 status event');
    }

    return status;
  }

  /// Parses a kind-10317 grasp list, returning `null` when invalid.
  static NostrGitRepoList? tryParseRepoList(NostrEvent event) {
    if (event.kind != repoListKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final list = NostrGitRepoList(
      graspServers: NostrTags.all(tags, 'g'),
      pubkey: event.pubkey,
      tags: [
        for (final tag in tags)
          if (tag.isEmpty || tag.first != 'g') List<String>.of(tag),
      ],
    );

    return list.isValid ? list : null;
  }

  /// Like [tryParseRepoList], but throws [ArgumentError].
  static NostrGitRepoList parseRepoList(NostrEvent event) {
    final list = tryParseRepoList(event);

    if (list == null) {
      throw ArgumentError('Invalid NIP-34 grasp list event');
    }

    return list;
  }

  /// Picks the winning status for a root patch, PR or issue.
  ///
  /// Per 34.md:231-233, the most recent status by `created_at` from either
  /// the root author or a maintainer wins. Statuses from anyone else are
  /// ignored. Ties keep the first event in the input order.
  ///
  /// For a patch revision, pass the resolved [rootStatus] and its [revisionId].
  /// When the revision has no status of its own, it inherits the root status,
  /// except that an applied root (1631) makes an untagged revision closed
  /// (1632) per 34.md:233.
  static NostrGitStatus? resolveStatus({
    required Iterable<NostrEvent> statuses,
    required String rootAuthorPubkey,
    Iterable<String> maintainers = const <String>[],
    NostrGitStatus? rootStatus,
    String? revisionId,
  }) {
    final trusted = <String>{rootAuthorPubkey, ...maintainers};
    NostrEvent? winner;
    NostrGitStatus? winnerStatus;

    for (final event in statuses) {
      if (!trusted.contains(event.pubkey)) {
        continue;
      }

      final status = tryParseStatus(event);

      if (status == null) {
        continue;
      }

      final createdAt = event.createdAt?.millisecondsSinceEpoch ?? 0;
      final winnerCreatedAt = winner?.createdAt?.millisecondsSinceEpoch ?? -1;

      if (winner == null || createdAt > winnerCreatedAt) {
        winner = event;
        winnerStatus = status;
      }
    }

    if (winnerStatus != null) {
      if (revisionId != null &&
          winnerStatus.status == NostrGitStatusKind.applied &&
          !winnerStatus.appliedPatchIds.contains(revisionId)) {
        return const NostrGitStatus(status: NostrGitStatusKind.closed);
      }

      return winnerStatus;
    }

    if (rootStatus == null) {
      return null;
    }

    if (rootStatus.status == NostrGitStatusKind.applied &&
        revisionId != null &&
        !rootStatus.appliedPatchIds.contains(revisionId)) {
      return const NostrGitStatus(status: NostrGitStatusKind.closed);
    }

    return rootStatus;
  }

  static String? _euc(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length > 2 && tag.first == 'r' && tag[2] == 'euc') {
        return tag[1];
      }
    }

    return null;
  }

  static NostrGitCommitter? _parseCommitter(List<String> tag) {
    if (tag.length < 3) {
      return null;
    }

    return NostrGitCommitter(
      name: tag[1],
      email: tag[2],
      timestamp: tag.length > 3 ? int.tryParse(tag[3]) : null,
      timezoneOffsetMinutes: tag.length > 4 ? int.tryParse(tag[4]) : null,
    );
  }

  static void _validateRepoAddress(String? address) {
    if (address == null) {
      return;
    }

    final parsed = NostrEventAddress.tryParse(address);

    if (parsed == null || parsed.kind != repoAnnouncementKind) {
      throw ArgumentError.value(
        address,
        'repositoryAddress',
        'Expected a 30617 repository address',
      );
    }
  }

  static void _validateRecipients(List<String> recipients) {
    for (final recipient in recipients) {
      if (!NostrValidators.isHex64(recipient)) {
        throw ArgumentError.value(
          recipient,
          'recipients',
          'Expected 64 lowercase hex characters',
        );
      }
    }
  }

  static void _validateCommit(String? commit, String name) {
    if (commit != null && !isCommitId(commit)) {
      throw ArgumentError.value(
        commit,
        name,
        'Expected a 40 or 64 character commit id',
      );
    }
  }

  static void _validateCloneUrls(
    List<String> clone, {
    required bool requireOne,
  }) {
    if (requireOne && clone.isEmpty) {
      throw ArgumentError.value(
        clone,
        'clone',
        'At least one clone URL is required',
      );
    }

    if (!_areCloneUrls(clone)) {
      throw ArgumentError.value(
        clone,
        'clone',
        'Expected http(s), git://, ssh:// or git@ clone URLs',
      );
    }
  }

  static bool _areCloneUrls(List<String> clone) => clone.every(_isCloneUrl);

  static bool _isCloneUrl(String value) {
    if (NostrValidators.tryHttpUrl(value) != null) {
      return true;
    }

    return value.startsWith('git://') ||
        value.startsWith('ssh://') ||
        RegExp(r'^[^@\s]+@[^:\s]+:.+$').hasMatch(value);
  }
}
