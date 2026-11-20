import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip11/relay_informations.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_relay_member}
/// One `member` tag of a NIP-43 relay membership list (kind 13534).
///
/// [roleIds] are the optional `d` values of role events assigned to
/// [pubkey]. Unknown role ids are kept as-is.
/// {@endtemplate}
class NostrRelayMember {
  /// {@macro nostr_relay_member}
  const NostrRelayMember({
    required this.pubkey,
    this.roleIds = const [],
  });

  /// Member public key, 64-character lowercase hex.
  final String pubkey;

  /// Assigned role ids, in tag order.
  final List<String> roleIds;

  /// `['member', pubkey, ...roleIds]`, the tag to publish.
  List<String> get toTag => ['member', pubkey, ...roleIds];

  @override
  String toString() => 'NostrRelayMember($pubkey, roles: $roleIds)';
}

/// {@template nostr_relay_role}
/// A NIP-43 role definition (kind 33534).
///
/// [roleId] is the `d` tag. [color] is a hue from 0 to 360, [order] an
/// integer used for client display only (43.md:27-41).
/// {@endtemplate}
class NostrRelayRole {
  /// {@macro nostr_relay_role}
  const NostrRelayRole({
    required this.roleId,
    this.label,
    this.description,
    this.color,
    this.order,
  });

  /// `d` tag: role id.
  final String roleId;

  /// Optional human-readable label.
  final String? label;

  /// Optional description.
  final String? description;

  /// Optional hue from 0 to 360.
  final int? color;

  /// Optional display order.
  final int? order;

  /// `['d', roleId]`, the tag that identifies this role.
  List<String> get toTag => ['d', roleId];

  /// The role's metadata tags: `d` plus the optional label, description,
  /// color and order tags. The NIP-70 `['-']` marker is not included;
  /// [NostrNip43.generateRoleTemplate] emits it.
  List<List<String>> get toTags => [
        toTag,
        if (label != null) ['label', label!],
        if (description != null) ['description', description!],
        if (color != null) ['color', '$color'],
        if (order != null) ['order', '$order'],
      ];

  @override
  String toString() => 'NostrRelayRole($roleId)';
}

/// {@template nostr_join_request}
/// Parsed NIP-43 join request (kind 28934).
///
/// [claim] is the invite code from the `claim` tag (43.md:117-146).
/// {@endtemplate}
class NostrJoinRequest {
  /// {@macro nostr_join_request}
  const NostrJoinRequest({required this.claim});

  /// Invite code.
  final String claim;
}

/// {@template nip43}
/// NIP-43 relay access metadata and requests.
///
/// Relays publish role definitions (33534), membership lists (13534) and
/// add/remove events (8000/8001), all signed by the relay's NIP-11 `self`
/// key and all carrying exactly one NIP-70 `['-']` marker. Users publish
/// join (28934) and leave (28936) requests.
///
/// This class is stateless: relay keys are not user keys, so nothing is
/// bound to a signer. Builders take a signer when a request must be signed.
///
/// Kind 28935 appears only in prose (43.md:164) with no defined shape, so it
/// is intentionally not implemented.
/// {@endtemplate}
class NostrNip43 {
  /// {@macro nip43}
  const NostrNip43();

  /// Role definition kind (addressable).
  static const int roleKind = 33534;

  /// Membership list kind (replaceable).
  static const int memberListKind = 13534;

  /// Member added kind.
  static const int addUserKind = 8000;

  /// Member removed kind.
  static const int removeUserKind = 8001;

  /// Join request kind.
  static const int joinRequestKind = 28934;

  /// Leave request kind.
  static const int leaveRequestKind = 28936;

  /// Kinds a relay publishes about its own access metadata.
  static const List<int> relayKinds = [
    roleKind,
    memberListKind,
    addUserKind,
    removeUserKind,
  ];

  /// Builds an unsigned role definition event (kind 33534).
  ///
  /// [roleId] must not be empty. [color] must be within 0..360.
  NostrEvent generateRoleTemplate({
    required String roleId,
    String? label,
    String? description,
    int? color,
    int? order,
    DateTime? createdAt,
  }) {
    if (roleId.isEmpty) {
      throw ArgumentError.value(roleId, 'roleId', 'Role id must not be empty');
    }

    if (color != null && (color < 0 || color > 360)) {
      throw ArgumentError.value(
        color,
        'color',
        'Role color must be a hue from 0 to 360',
      );
    }

    return _event(
      roleKind,
      [
        ['-'],
        ['d', roleId],
        if (label != null) ['label', label],
        if (description != null) ['description', description],
        if (color != null) ['color', '$color'],
        if (order != null) ['order', '$order'],
      ],
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned membership list event (kind 13534).
  ///
  /// [members] must not be empty and every pubkey must be 64-character
  /// lowercase hex.
  NostrEvent generateMemberListTemplate({
    required List<NostrRelayMember> members,
    DateTime? createdAt,
  }) {
    if (members.isEmpty) {
      throw ArgumentError.value(
        members,
        'members',
        'Member list must not be empty',
      );
    }

    for (final member in members) {
      _checkPubkey(member.pubkey, 'members');
    }

    return _event(
      memberListKind,
      [
        ['-'],
        for (final member in members) member.toTag,
      ],
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned "member added" event (kind 8000).
  NostrEvent generateAddUserTemplate({
    required String pubkey,
    DateTime? createdAt,
  }) {
    _checkPubkey(pubkey, 'pubkey');

    return _event(
      addUserKind,
      [
        ['-'],
        ['p', pubkey],
      ],
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned "member removed" event (kind 8001).
  NostrEvent generateRemoveUserTemplate({
    required String pubkey,
    DateTime? createdAt,
  }) {
    _checkPubkey(pubkey, 'pubkey');

    return _event(
      removeUserKind,
      [
        ['-'],
        ['p', pubkey],
      ],
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned join request (kind 28934).
  ///
  /// [claim] is the invite code and must not be empty.
  NostrEvent generateJoinRequestTemplate({
    required String claim,
    DateTime? createdAt,
  }) {
    if (claim.isEmpty) {
      throw ArgumentError.value(claim, 'claim', 'Claim must not be empty');
    }

    return _event(
      joinRequestKind,
      [
        ['-'],
        ['claim', claim],
      ],
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned leave request (kind 28936).
  NostrEvent generateLeaveRequestTemplate({DateTime? createdAt}) {
    return _event(
      leaveRequestKind,
      [
        ['-'],
      ],
      createdAt: createdAt,
    );
  }

  /// Parses a role definition event, or returns `null` for other kinds.
  ///
  /// A role event without a non-empty `d` tag is invalid. Out-of-range
  /// colors and unparseable orders are dropped rather than thrown.
  ///
  /// Parsing tolerates a missing NIP-70 `['-']` marker (lenient by design);
  /// every builder here emits exactly one.
  NostrRelayRole? tryParseRole(NostrEvent event) {
    if (event.kind != roleKind) {
      return null;
    }

    final roleId = NostrTags.first(event.tags, 'd');
    if (roleId == null || roleId.isEmpty) {
      return null;
    }

    return NostrRelayRole(
      roleId: roleId,
      label: NostrTags.first(event.tags, 'label'),
      description: NostrTags.first(event.tags, 'description'),
      color: NostrValidators.tryInt(
        NostrTags.first(event.tags, 'color'),
        min: 0,
        max: 360,
      ),
      order: NostrValidators.tryInt(NostrTags.first(event.tags, 'order')),
    );
  }

  /// Parses a membership list event, or returns `null` for other kinds.
  ///
  /// `member` tags whose pubkey is not 64-character lowercase hex are
  /// skipped. Role ids are kept verbatim, including unknown ones. A kind
  /// 13534 event with no usable member tag returns an empty list.
  List<NostrRelayMember>? tryParseMemberList(NostrEvent event) {
    if (event.kind != memberListKind) {
      return null;
    }

    return [
      for (final tag in event.tags ?? const <List<String>>[])
        if (tag.length > 1 &&
            tag.first == 'member' &&
            NostrValidators.isHex64(tag[1]))
          NostrRelayMember(
            pubkey: tag[1],
            roleIds: tag.length > 2 ? tag.sublist(2) : const [],
          ),
    ];
  }

  /// Parses a join request, or returns `null` when the event is not a
  /// kind-28934 event with a non-empty `claim` tag.
  NostrJoinRequest? tryParseJoinRequest(NostrEvent event) {
    if (event.kind != joinRequestKind) {
      return null;
    }

    final claim = NostrTags.first(event.tags, 'claim');
    if (claim == null || claim.isEmpty) {
      return null;
    }

    return NostrJoinRequest(claim: claim);
  }

  /// Whether [event] is relay access metadata signed by [relaySelfPubkey].
  ///
  /// Checks the four relay kinds and the author key; the NIP-70 `['-']`
  /// marker is required by the spec and is emitted by every builder here.
  bool isRelayAuthored(NostrEvent event, String relaySelfPubkey) {
    return relayKinds.contains(event.kind) &&
        event.pubkey == relaySelfPubkey &&
        NostrTags.has(event.tags, '-');
  }

  /// Whether [relay] advertises NIP-43 in `supported_nips` (43.md:162-164).
  bool relaySupportsNip43(RelayInformations relay) => relay.supportsNip(43);

  /// Builds and signs a join request (kind 28934).
  Future<NostrEvent> publishJoinRequest(
    NostrEventSigner signer, {
    required String claim,
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateJoinRequestTemplate(claim: claim, createdAt: createdAt),
    );
  }

  /// Builds and signs a leave request (kind 28936).
  Future<NostrEvent> publishLeaveRequest(
    NostrEventSigner signer, {
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateLeaveRequestTemplate(createdAt: createdAt),
    );
  }

  static NostrEvent _event(
    int kind,
    List<List<String>> tags, {
    DateTime? createdAt,
  }) {
    return NostrEvent(
      id: null,
      kind: kind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: tags,
    );
  }

  static void _checkPubkey(String pubkey, String name) {
    if (!NostrValidators.isHex64(pubkey)) {
      throw ArgumentError.value(
        pubkey,
        name,
        'Expected 64 lowercase hex characters',
      );
    }
  }
}
