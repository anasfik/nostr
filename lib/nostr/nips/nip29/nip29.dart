import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';

/// {@template nip29}
/// NIP-29 relay-based groups.
///
/// Builds the unsigned event templates the relay (or an admin) signs:
/// - 39000 group metadata, 39001 admins, 39002 members
/// - 9000 put-user, 9001 remove-user, 9002 edit-metadata, 9005 delete-event,
///   9007 create-group, 9008 delete-group, 9009 create-invite
///
/// Subset note: 39003 (roles), 39004/39005 (group lists), and 9010/9021/9022
/// (join/leave/put-user variants) are not implemented yet.
///
/// Templates carry no `pubkey`/`id`/`sig`; pass them to an event signer
/// before publishing. Parsing and validation helpers accept signed events.
///
/// Usage:
/// ```dart
/// final nip29 = NostrNip29();
/// final template = nip29.createGroupMembersEvent(
///   groupId: 'my-group',
///   members: [GroupMember(pubkey: memberPubkey)],
/// );
/// final signed = await signer.sign(template);
/// ```
/// {@endtemplate}
class NostrNip29 {
  /// {@macro nip29}
  ///
  /// [bech32] enables `naddr` decoding in [parseGroupReference]; without it
  /// only the `host'id` form is accepted.
  NostrNip29({NostrBech32? bech32}) : _bech32 = bech32;

  final NostrBech32? _bech32;

  /// Kind 39000: group metadata.
  static const int metadataKind = 39000;

  /// Kind 39001: group admins.
  static const int adminsKind = 39001;

  /// Kind 39002: group members.
  static const int membersKind = 39002;

  /// Kind 9000: put (add or update) a user.
  static const int putUserKind = 9000;

  /// Kind 9001: remove a user.
  static const int removeUserKind = 9001;

  /// Kind 9002: edit group metadata.
  static const int editMetadataKind = 9002;

  /// Kind 9005: delete an event from the group.
  static const int deleteEventKind = 9005;

  /// Kind 9007: create a group.
  static const int createGroupKind = 9007;

  /// Kind 9008: delete a group.
  static const int deleteGroupKind = 9008;

  /// Kind 9009: create an invite.
  static const int createInviteKind = 9009;

  // ---------------------------------------------------------------------------
  // 39000-39002 group state events
  // ---------------------------------------------------------------------------

  /// Builds a kind-39000 group metadata template from [metadata].
  NostrEvent createGroupMetadataEvent(
    GroupMetadata metadata, {
    DateTime? createdAt,
  }) {
    return _template(
      metadataKind,
      '',
      [
        ['d', metadata.id],
        ..._metadataTags(metadata),
      ],
      createdAt,
    );
  }

  /// Validates a kind-39000 event: correct kind, non-empty `pubkey`, `d` tag.
  bool validateGroupMetadataEvent(NostrEvent event) {
    return event.kind == metadataKind &&
        event.pubkey.isNotEmpty &&
        _hasTag(event, 'd');
  }

  /// Parses a kind-39000 event into [GroupMetadata].
  ///
  /// Throws [FormatException] when the event fails validation.
  GroupMetadata parseGroupMetadataEvent(NostrEvent event) {
    if (!validateGroupMetadataEvent(event)) {
      throw const FormatException('invalid group metadata event');
    }

    var id = '';
    String? name;
    String? picture;
    String? banner;
    String? about;
    var isPrivate = false;
    var isRestricted = false;
    var isHidden = false;
    var isClosed = false;
    var hasLiveKit = false;
    String? parent;
    final supportedKinds = <String>[];
    final children = <String>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      final tagName = tag.isEmpty ? '' : tag.first;
      final value = tag.length > 1 ? tag[1] : null;

      switch (tagName) {
        case 'd':
          id = value ?? '';
        case 'name':
          name = value;
        case 'picture':
          picture = value;
        case 'banner':
          banner = value;
        case 'about':
          about = value;
        case 'private':
          isPrivate = true;
        case 'restricted':
          isRestricted = true;
        case 'hidden':
          isHidden = true;
        case 'closed':
          isClosed = true;
        case 'livekit':
          hasLiveKit = true;
        case 'parent':
          parent = value;
        case 'supported_kinds':
          supportedKinds.addAll(tag.skip(1));
        case 'child':
          if (value != null) {
            children.add(value);
          }
      }
    }

    return GroupMetadata(
      id: id,
      pubkey: event.pubkey,
      name: name,
      picture: picture,
      banner: banner,
      about: about,
      isPrivate: isPrivate,
      isRestricted: isRestricted,
      isHidden: isHidden,
      isClosed: isClosed,
      hasLiveKit: hasLiveKit,
      supportedKinds: supportedKinds,
      parent: parent,
      children: children,
    );
  }

  /// Builds a kind-39001 admins template for [groupId].
  NostrEvent createGroupAdminsEvent({
    required String groupId,
    required List<GroupAdmin> admins,
    DateTime? createdAt,
  }) {
    return _template(
      adminsKind,
      '',
      [
        ['d', groupId],
        for (final admin in admins)
          [
            'p',
            admin.pubkey,
            admin.label ?? '',
            for (final permission in admin.permissions) permission.value,
          ],
      ],
      createdAt,
    );
  }

  /// Validates a kind-39001 event, including every admin permission name.
  bool validateGroupAdminsEvent(NostrEvent event) {
    if (event.kind != adminsKind || !_hasTag(event, 'd')) {
      return false;
    }

    for (final tag in event.tags ?? const <List<String>>[]) {
      if ((tag.isEmpty ? '' : tag.first) != 'p') {
        continue;
      }
      for (final permission in tag.skip(3)) {
        if (GroupAdminPermission.fromValue(permission) == null) {
          return false;
        }
      }
    }

    return true;
  }

  /// Parses a kind-39001 event into its admins.
  ///
  /// Throws [FormatException] when the event fails validation.
  List<GroupAdmin> parseGroupAdminsEvent(NostrEvent event) {
    if (!validateGroupAdminsEvent(event)) {
      throw const FormatException('invalid group admins event');
    }

    return [
      for (final tag in event.tags ?? const <List<String>>[])
        if ((tag.isEmpty ? '' : tag.first) == 'p')
          GroupAdmin(
            pubkey: tag.length > 1 ? tag[1] : '',
            label: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
            permissions: [
              for (final raw in tag.skip(3))
                GroupAdminPermission.fromValue(raw)!,
            ],
          ),
    ];
  }

  /// Builds a kind-39002 members template for [groupId].
  NostrEvent createGroupMembersEvent({
    required String groupId,
    required List<GroupMember> members,
    DateTime? createdAt,
  }) {
    return _template(
      membersKind,
      '',
      [
        ['d', groupId],
        for (final member in members) ['p', member.pubkey, member.label ?? ''],
      ],
      createdAt,
    );
  }

  /// Validates a kind-39002 event: correct kind and a `d` tag.
  bool validateGroupMembersEvent(NostrEvent event) {
    return event.kind == membersKind && _hasTag(event, 'd');
  }

  /// Parses a kind-39002 event into its members.
  ///
  /// Throws [FormatException] when the event fails validation.
  List<GroupMember> parseGroupMembersEvent(NostrEvent event) {
    if (!validateGroupMembersEvent(event)) {
      throw const FormatException('invalid group members event');
    }

    return [
      for (final tag in event.tags ?? const <List<String>>[])
        if ((tag.isEmpty ? '' : tag.first) == 'p')
          GroupMember(
            pubkey: tag.length > 1 ? tag[1] : '',
            label: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
          ),
    ];
  }

  // ---------------------------------------------------------------------------
  // 9000-9009 moderation events
  // ---------------------------------------------------------------------------

  /// Kind 9000: adds or updates [pubkey] with optional [roles].
  NostrEvent createPutUserEvent({
    required String groupId,
    required String pubkey,
    List<String> roles = const [],
    String reason = '',
    List<String> previous = const [],
    DateTime? createdAt,
  }) {
    return _moderation(
      putUserKind,
      groupId,
      reason,
      [
        ['p', pubkey, ...roles],
      ],
      previous,
      createdAt,
    );
  }

  /// Kind 9001: removes [pubkey] from the group.
  NostrEvent createRemoveUserEvent({
    required String groupId,
    required String pubkey,
    String reason = '',
    List<String> previous = const [],
    DateTime? createdAt,
  }) {
    return _moderation(
      removeUserKind,
      groupId,
      reason,
      [
        ['p', pubkey],
      ],
      previous,
      createdAt,
    );
  }

  /// Kind 9002: replaces the group metadata with [metadata].
  NostrEvent createEditGroupMetadataEvent({
    required GroupMetadata metadata,
    String reason = '',
    List<String> previous = const [],
    DateTime? createdAt,
  }) {
    return _moderation(
      editMetadataKind,
      metadata.id,
      reason,
      _metadataTags(metadata),
      previous,
      createdAt,
    );
  }

  /// Kind 9005: deletes [eventId] from the group timeline.
  NostrEvent createDeleteEventEvent({
    required String groupId,
    required String eventId,
    String reason = '',
    List<String> previous = const [],
    DateTime? createdAt,
  }) {
    return _moderation(
      deleteEventKind,
      groupId,
      reason,
      [
        ['e', eventId],
      ],
      previous,
      createdAt,
    );
  }

  /// Kind 9007: creates the group [groupId].
  NostrEvent createCreateGroupEvent({
    required String groupId,
    String reason = '',
    List<String> previous = const [],
    DateTime? createdAt,
  }) {
    return _moderation(
      createGroupKind,
      groupId,
      reason,
      const [],
      previous,
      createdAt,
    );
  }

  /// Kind 9008: deletes the group [groupId].
  NostrEvent createDeleteGroupEvent({
    required String groupId,
    String reason = '',
    List<String> previous = const [],
    DateTime? createdAt,
  }) {
    return _moderation(
      deleteGroupKind,
      groupId,
      reason,
      const [],
      previous,
      createdAt,
    );
  }

  /// Kind 9009: creates an invite [code] for the group.
  NostrEvent createCreateInviteEvent({
    required String groupId,
    required String code,
    String reason = '',
    List<String> previous = const [],
    DateTime? createdAt,
  }) {
    return _moderation(
      createInviteKind,
      groupId,
      reason,
      [
        ['code', code],
      ],
      previous,
      createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Group references
  // ---------------------------------------------------------------------------

  /// Encodes a group reference as `host'id`, stripping any URL scheme.
  String encodeGroupReference(GroupReference reference) {
    return reference.encode();
  }

  /// Parses a group reference from an `naddr` (requires `nip19`) or the
  /// `host'id` form. Returns `null` when [code] is not a group reference.
  GroupReference? parseGroupReference(String code) {
    final bech32 = _bech32;

    if (bech32 != null && code.startsWith('naddr1')) {
      try {
        final data = bech32.decodeNaddrToMap(code);
        final relays = (data['relays'] as List?)?.cast<String>() ?? const [];
        final identifier = data['identifier'] as String?;

        if (relays.isEmpty || identifier == null) {
          return null;
        }

        return GroupReference(
          host: relays.first.replaceFirst(RegExp('^wss://'), ''),
          id: identifier,
        );
      } on Object catch (_) {
        return null;
      }
    }

    final parts = code.split("'");
    if (parts.length == 2) {
      return GroupReference(host: parts[0], id: parts[1]);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static NostrEvent _template(
    int kind,
    String content,
    List<List<String>> tags,
    DateTime? createdAt,
  ) {
    return NostrEvent(
      id: null,
      kind: kind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: tags,
    );
  }

  static NostrEvent _moderation(
    int kind,
    String groupId,
    String reason,
    List<List<String>> tags,
    List<String> previous,
    DateTime? createdAt,
  ) {
    return _template(
      kind,
      reason,
      [
        ['h', groupId],
        ...tags,
        if (previous.isNotEmpty) ['previous', ...previous],
      ],
      createdAt,
    );
  }

  static List<List<String>> _metadataTags(GroupMetadata metadata) {
    return [
      if (metadata.name case final name? when name.isNotEmpty) ['name', name],
      if (metadata.picture case final picture? when picture.isNotEmpty)
        ['picture', picture],
      if (metadata.banner case final banner? when banner.isNotEmpty)
        ['banner', banner],
      if (metadata.about case final about? when about.isNotEmpty)
        ['about', about],
      if (metadata.isPrivate) ['private'],
      if (metadata.isRestricted) ['restricted'],
      if (metadata.isHidden) ['hidden'],
      if (metadata.isClosed) ['closed'],
      if (metadata.hasLiveKit) ['livekit'],
      if (metadata.supportedKinds.isNotEmpty)
        ['supported_kinds', ...metadata.supportedKinds],
      if (metadata.parent case final parent? when parent.isNotEmpty)
        ['parent', parent],
      for (final child in metadata.children) ['child', child],
    ];
  }

  static bool _hasTag(NostrEvent event, String name) {
    return (event.tags ?? const <List<String>>[])
        .any((tag) => tag.isNotEmpty && tag.first == name);
  }
}

/// {@template nip29_group_metadata}
/// NIP-29 group metadata (kind 39000).
/// {@endtemplate}
class GroupMetadata {
  /// {@macro nip29_group_metadata}
  const GroupMetadata({
    required this.id,
    this.pubkey = '',
    this.name,
    this.picture,
    this.banner,
    this.about,
    this.isPrivate = false,
    this.isRestricted = false,
    this.isHidden = false,
    this.isClosed = false,
    this.hasLiveKit = false,
    this.supportedKinds = const [],
    this.parent,
    this.children = const [],
  });

  /// Group identifier (`d` tag).
  final String id;

  /// Relay public key that authored the metadata event.
  final String pubkey;

  /// Display name.
  final String? name;

  /// Picture URL.
  final String? picture;

  /// Banner URL.
  final String? banner;

  /// Description.
  final String? about;

  /// Whether the group is private.
  final bool isPrivate;

  /// Whether the group is restricted.
  final bool isRestricted;

  /// Whether the group is hidden from listings.
  final bool isHidden;

  /// Whether the group is closed to joins.
  final bool isClosed;

  /// Whether the group has LiveKit audio/video rooms.
  final bool hasLiveKit;

  /// Event kinds the group accepts.
  final List<String> supportedKinds;

  /// Parent group id, if any.
  final String? parent;

  /// Child group ids.
  final List<String> children;
}

/// {@template nip29_group_member}
/// NIP-29 group member.
/// {@endtemplate}
class GroupMember {
  /// {@macro nip29_group_member}
  const GroupMember({required this.pubkey, this.label});

  /// Member public key (64-char hex).
  final String pubkey;

  /// Optional relay-assigned label.
  final String? label;
}

/// {@template nip29_group_admin}
/// NIP-29 group admin with the permissions granted to them.
/// {@endtemplate}
class GroupAdmin {
  /// {@macro nip29_group_admin}
  const GroupAdmin({
    required this.pubkey,
    this.label,
    this.permissions = const [],
  });

  /// Admin public key (64-char hex).
  final String pubkey;

  /// Optional relay-assigned label.
  final String? label;

  /// Permissions granted to the admin.
  final List<GroupAdminPermission> permissions;
}

/// NIP-29 admin permission names, as carried in `p` tags after the label.
enum GroupAdminPermission {
  /// Add users (deprecated, use [putUser]).
  addUser('add-user'),

  /// Edit group metadata.
  editMetadata('edit-metadata'),

  /// Delete events.
  deleteEvent('delete-event'),

  /// Remove users.
  removeUser('remove-user'),

  /// Add permissions (deprecated, removed from the NIP).
  addPermission('add-permission'),

  /// Remove permissions (deprecated, removed from the NIP).
  removePermission('remove-permission'),

  /// Edit group status flags.
  editGroupStatus('edit-group-status'),

  /// Add or update a user.
  putUser('put-user'),

  /// Create groups.
  createGroup('create-group'),

  /// Delete groups.
  deleteGroup('delete-group'),

  /// Create invites.
  createInvite('create-invite'),

  /// Update the pinned-event list.
  updatePinList('update-pin-list');

  const GroupAdminPermission(this.value);

  /// Wire value used inside `p` tags.
  final String value;

  /// Resolves a wire value, returning `null` for unknown permissions.
  static GroupAdminPermission? fromValue(String value) {
    for (final permission in values) {
      if (permission.value == value) {
        return permission;
      }
    }
    return null;
  }
}

/// {@template nip29_group_reference}
/// Reference to a NIP-29 group: relay host plus group id.
/// {@endtemplate}
class GroupReference {
  /// {@macro nip29_group_reference}
  const GroupReference({required this.host, required this.id});

  /// Relay host, with or without a `wss://` scheme.
  final String host;

  /// Group identifier.
  final String id;

  /// Encodes as `host'id`, stripping any URL scheme from [host].
  String encode() {
    final host_ = host.replaceFirst(RegExp('^(https?://|wss?://)'), '');
    return "$host_'$id";
  }

  @override
  String toString() => encode();
}
