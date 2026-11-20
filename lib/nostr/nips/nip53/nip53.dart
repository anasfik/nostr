import 'package:dart_nostr/nostr/core/crypto_utils.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_live_kind}
/// NIP-53 live activity kinds.
/// {@endtemplate}
class NostrLiveKind {
  const NostrLiveKind._();

  /// Live streaming event (addressable).
  static const int liveEvent = 30311;

  /// Live chat channel message (regular).
  static const int chatMessage = 1311;

  /// Interactive room / space (addressable).
  static const int room = 30312;

  /// Meeting inside a room (addressable).
  static const int meeting = 30313;

  /// Room presence (replaceable).
  static const int presence = 10312;

  /// Every kind defined by NIP-53.
  static const List<int> values = [
    liveEvent,
    chatMessage,
    room,
    meeting,
    presence,
  ];

  /// Whether [kind] is defined by NIP-53.
  static bool isLiveKind(int? kind) => values.contains(kind);
}

/// {@template nostr_live_participant}
/// NIP-53 `p` tag participant.
///
/// Slots are `["p", pubkey, relay?, role?, proof?]` (`53.md:26`). The proof is
/// a BIP-340 signature over the SHA-256 of the activity's `kind:pubkey:d`
/// coordinate (`53.md:58`). It is optional; parsing never requires it.
///
/// The participant pubkey is intentionally not hex-validated: relay data often
/// carries abbreviated keys (for example `14aeb..8dad4`), so parsing stays
/// tolerant by design. [verifyProof] returns `false` for malformed keys.
/// {@endtemplate}
class NostrLiveParticipant {
  /// {@macro nostr_live_participant}
  const NostrLiveParticipant({
    required this.pubkey,
    this.relay,
    this.role,
    this.proof,
    this.tag = const [],
  });

  /// Conventional role for the activity owner.
  static const String hostRole = 'Host';

  /// Role allowed to moderate a room.
  static const String moderatorRole = 'Moderator';

  /// Role allowed to present.
  static const String speakerRole = 'Speaker';

  /// Default role for attendees.
  static const String participantRole = 'Participant';

  /// Participant public key.
  final String pubkey;

  /// Relay hint where the participant can be reached.
  final String? relay;

  /// Displayable role such as [hostRole] or [participantRole].
  final String? role;

  /// Optional Schnorr proof of agreement to participate.
  final String? proof;

  /// Raw `p` tag.
  final List<String> tag;

  /// Whether [role] is [hostRole].
  bool get isHost => role == hostRole;

  /// Whether a non-empty proof is present.
  bool get hasProof => proof != null && proof!.isNotEmpty;

  /// Builds the `p` tag, padding intermediate slots so [role] and [proof]
  /// stay positional (`53.md:26`).
  List<String> toTag() => [
        'p',
        pubkey,
        relay ?? '',
        if (role != null || proof != null) role ?? '',
        if (proof != null) proof!,
      ];

  /// Parses a `p` tag, returning `null` when it is not a usable participant.
  static NostrLiveParticipant? tryParseTag(List<String>? tag) {
    if (tag == null || tag.length < 2 || tag.first != 'p' || tag[1].isEmpty) {
      return null;
    }

    return NostrLiveParticipant(
      pubkey: tag[1],
      relay: _nonEmpty(NostrTags.at(tag, 2)),
      role: _nonEmpty(NostrTags.at(tag, 3)),
      proof: _nonEmpty(NostrTags.at(tag, 4)),
      tag: tag,
    );
  }

  /// Verifies [proof] against the activity coordinate `kind:pubkey:d`.
  ///
  /// Returns `false` for a missing or malformed proof; never throws.
  bool verifyProof({required String coordinate}) {
    final signature = proof;
    if (signature == null || signature.isEmpty) {
      return false;
    }

    try {
      final digest = NostrCryptoUtils.sha256Hash(coordinate);

      return NostrKeyPairs.verify(pubkey, digest, signature);
    } on Object catch (_) {
      return false;
    }
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}

/// {@template nostr_live_event}
/// Parsed NIP-53 live streaming event (kind 30311).
///
/// Only the `d` identifier is required; every other tag is optional
/// (`53.md:33`). [starts] and [ends] are UNIX seconds. [participants] keeps
/// `p` tags in event order, including relay hints, roles and optional proofs.
/// {@endtemplate}
class NostrLiveEvent {
  /// {@macro nostr_live_event}
  const NostrLiveEvent({
    this.id,
    required this.pubkey,
    required this.dTag,
    this.title,
    this.summary,
    this.image,
    this.hashtags = const [],
    this.streamingUrl,
    this.recordingUrl,
    this.starts,
    this.ends,
    this.status,
    this.rawStatus,
    this.currentParticipants,
    this.totalParticipants,
    this.participants = const [],
    this.relays = const [],
    this.pinned = const [],
    this.content = '',
    this.tags = const [],
  });

  /// Status values allowed on a live event.
  static const List<String> statuses = ['planned', 'live', 'ended'];

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// Required `d` identifier.
  final String dTag;

  /// Optional `title` tag.
  final String? title;

  /// Optional `summary` tag.
  final String? summary;

  /// Optional `image` URL.
  final String? image;

  /// `t` hashtags.
  final List<String> hashtags;

  /// `streaming` URL.
  final String? streamingUrl;

  /// `recording` URL.
  final String? recordingUrl;

  /// `starts` UNIX seconds.
  final int? starts;

  /// `ends` UNIX seconds.
  final int? ends;

  /// `status`: planned, live or ended, or `null` when absent or unknown.
  final String? status;

  /// Raw `status` tag value, including values outside [statuses].
  final String? rawStatus;

  /// `current_participants` count.
  final int? currentParticipants;

  /// `total_participants` count.
  final int? totalParticipants;

  /// `p` participants in event order.
  final List<NostrLiveParticipant> participants;

  /// `relays` list values.
  final List<String> relays;

  /// `pinned` live chat message ids.
  final List<String> pinned;

  /// Free-form content, usually empty.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether [status] is `live`.
  bool get isLive => status == 'live';

  /// Activity address as `30311:pubkey:d`, or `null` for a template.
  String? get address {
    if (!NostrValidators.isHex64(pubkey)) {
      return null;
    }

    return NostrEventAddress.build(
      kind: NostrLiveKind.liveEvent,
      pubkey: pubkey,
      identifier: dTag,
    );
  }

  /// Verifies [participant]'s proof against this activity coordinate.
  bool verifyParticipantProof(NostrLiveParticipant participant) {
    final activityAddress = address;

    return activityAddress != null &&
        participant.verifyProof(coordinate: activityAddress);
  }

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrLiveEvent parse(NostrEvent event) {
    if (event.kind != NostrLiveKind.liveEvent) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-53 live event',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.isEmpty) {
      throw ArgumentError('Live events require a non-empty d tag');
    }

    final status = NostrTags.first(tags, 'status');

    return NostrLiveEvent(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      title: NostrTags.first(tags, 'title'),
      summary: NostrTags.first(tags, 'summary'),
      image: NostrTags.first(tags, 'image'),
      hashtags: NostrTags.all(tags, 't'),
      streamingUrl: NostrTags.first(tags, 'streaming'),
      recordingUrl: NostrTags.first(tags, 'recording'),
      starts: _optionalInt(tags, 'starts'),
      ends: _optionalInt(tags, 'ends'),
      status: _typedStatus(status, statuses),
      rawStatus: status,
      currentParticipants: _optionalInt(tags, 'current_participants'),
      totalParticipants: _optionalInt(tags, 'total_participants'),
      participants: _participants(tags),
      relays: _relays(tags),
      pinned: NostrTags.all(tags, 'pinned'),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrLiveEvent? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a spec-conforming live event.
  ///
  /// A missing `status` is allowed (`53.md:33`); an unknown value is not,
  /// matching the [build] rule.
  static bool validate(NostrEvent event) {
    final live = tryParse(event);

    return live != null &&
        (live.rawStatus == null || statuses.contains(live.rawStatus));
  }

  /// Builds an unsigned kind-30311 live event and validates it.
  static NostrEvent build({
    required String dTag,
    String? title,
    String? summary,
    String? image,
    List<String> hashtags = const [],
    String? streamingUrl,
    String? recordingUrl,
    int? starts,
    int? ends,
    String? status,
    int? currentParticipants,
    int? totalParticipants,
    List<NostrLiveParticipant> participants = const [],
    List<String> relays = const [],
    List<String> pinned = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    _requireStatus(status, statuses);

    final event = NostrEvent(
      id: null,
      kind: NostrLiveKind.liveEvent,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        if (title != null) ['title', title],
        if (summary != null) ['summary', summary],
        if (image != null) ['image', image],
        for (final hashtag in hashtags) ['t', hashtag],
        if (streamingUrl != null) ['streaming', streamingUrl],
        if (recordingUrl != null) ['recording', recordingUrl],
        if (starts != null) ['starts', '$starts'],
        if (ends != null) ['ends', '$ends'],
        if (status != null) ['status', status],
        if (currentParticipants != null)
          ['current_participants', '$currentParticipants'],
        if (totalParticipants != null)
          ['total_participants', '$totalParticipants'],
        for (final participant in participants) participant.toTag(),
        if (relays.isNotEmpty) ['relays', ...relays],
        for (final eventId in pinned) ['pinned', eventId],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_live_chat_message}
/// Parsed NIP-53 live chat message (kind 1311).
///
/// The `a` tag is required and must address a kind-30311 activity. The `e`
/// tag replies to a parent message; `q` tags quote events or addresses.
/// {@endtemplate}
class NostrLiveChatMessage {
  /// {@macro nostr_live_chat_message}
  const NostrLiveChatMessage({
    this.id,
    required this.pubkey,
    required this.activityAddress,
    this.activityRelay,
    this.activityMarker,
    this.parentEventId,
    this.quotes = const [],
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// Required `a` address of the kind-30311 activity.
  final String activityAddress;

  /// Optional relay hint from the `a` tag.
  final String? activityRelay;

  /// Optional fourth `a` tag slot, for example `root`.
  final String? activityMarker;

  /// Optional `e` parent message id.
  final String? parentEventId;

  /// `q` first values: quoted event ids or event addresses.
  final List<String> quotes;

  /// Chat message text.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrLiveChatMessage parse(NostrEvent event) {
    if (event.kind != NostrLiveKind.chatMessage) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-53 chat message',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final activityTag = NostrTags.tag(tags, 'a');
    final parsedAddress = NostrEventAddress.tryParse(
      NostrTags.at(activityTag, 1),
    );
    if (parsedAddress == null ||
        parsedAddress.kind != NostrLiveKind.liveEvent) {
      throw ArgumentError.value(
        NostrTags.at(activityTag, 1),
        'a',
        'Chat messages require a kind-30311 activity address',
      );
    }

    final parentEventId = NostrTags.first(tags, 'e');
    if (parentEventId != null && !NostrValidators.isHex64(parentEventId)) {
      throw ArgumentError.value(parentEventId, 'e', 'Expected 64 hex chars');
    }

    return NostrLiveChatMessage(
      id: event.id,
      pubkey: event.pubkey,
      activityAddress: parsedAddress.address,
      activityRelay: _nonEmpty(NostrTags.at(activityTag, 2)),
      activityMarker: _nonEmpty(NostrTags.at(activityTag, 3)),
      parentEventId: parentEventId,
      quotes: NostrTags.all(tags, 'q'),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrLiveChatMessage? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid chat message.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned kind-1311 chat message and validates it.
  ///
  /// [activityMarker] fills the fourth `a` tag slot, for example `root`.
  static NostrEvent build({
    required String activityAddress,
    String? activityRelay,
    String? activityMarker,
    String? parentEventId,
    List<String> quotes = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    final event = NostrEvent(
      id: null,
      kind: NostrLiveKind.chatMessage,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        [
          'a',
          activityAddress,
          if (activityRelay != null)
            activityRelay
          else if (activityMarker != null)
            '',
          if (activityMarker != null) activityMarker,
        ],
        if (parentEventId != null) ['e', parentEventId],
        for (final quote in quotes) ['q', quote],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_live_room}
/// Parsed NIP-53 room / space (kind 30312).
///
/// The `d`, `room`, `status` and `service` tags are required and at least one
/// `p` provider must be present (`53.md:142-176`). Role names are free-form;
/// the conventional provider role is [NostrLiveParticipant.hostRole]. Parsing
/// stays tolerant of a missing `room` tag for legacy events; [validate] and
/// [build] enforce it.
/// {@endtemplate}
class NostrLiveRoom {
  /// {@macro nostr_live_room}
  const NostrLiveRoom({
    this.id,
    required this.pubkey,
    required this.dTag,
    this.roomName,
    this.summary,
    this.image,
    this.status,
    this.rawStatus,
    required this.serviceUrl,
    this.endpointUrl,
    this.hashtags = const [],
    this.participants = const [],
    this.relays = const [],
    this.content = '',
    this.tags = const [],
  });

  /// Status values allowed on a room.
  static const List<String> statuses = ['open', 'private', 'closed'];

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// Required `d` identifier.
  final String dTag;

  /// Optional `room` display name.
  final String? roomName;

  /// Optional `summary`.
  final String? summary;

  /// Optional `image` URL.
  final String? image;

  /// `status`: open, private or closed, or `null` when unknown.
  final String? status;

  /// Raw `status` tag value, including values outside [statuses].
  final String? rawStatus;

  /// Required `service` URL used to access the room.
  final String serviceUrl;

  /// Optional `endpoint` URL for status or info queries.
  final String? endpointUrl;

  /// `t` hashtags.
  final List<String> hashtags;

  /// `p` providers in event order.
  final List<NostrLiveParticipant> participants;

  /// `relays` list values.
  final List<String> relays;

  /// Free-form content.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether at least one provider carries [NostrLiveParticipant.hostRole].
  bool get hasHost => participants.any((participant) => participant.isHost);

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrLiveRoom parse(NostrEvent event) {
    if (event.kind != NostrLiveKind.room) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-53 room',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.isEmpty) {
      throw ArgumentError('Rooms require a non-empty d tag');
    }

    final status = NostrTags.first(tags, 'status');
    if (status == null || status.isEmpty) {
      throw ArgumentError('Rooms require a non-empty status tag');
    }

    final serviceUrl = NostrTags.first(tags, 'service');
    if (serviceUrl == null || serviceUrl.isEmpty) {
      throw ArgumentError('Rooms require a non-empty service tag');
    }

    final participants = _participants(tags);
    if (participants.isEmpty) {
      throw ArgumentError('Rooms require at least one p provider');
    }

    return NostrLiveRoom(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      roomName: NostrTags.first(tags, 'room'),
      summary: NostrTags.first(tags, 'summary'),
      image: NostrTags.first(tags, 'image'),
      status: _typedStatus(status, statuses),
      rawStatus: status,
      serviceUrl: serviceUrl,
      endpointUrl: NostrTags.first(tags, 'endpoint'),
      hashtags: NostrTags.all(tags, 't'),
      participants: participants,
      relays: _relays(tags),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrLiveRoom? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a spec-conforming room.
  ///
  /// Stricter than [parse]: `room` is required (`53.md:142`), `status` must be
  /// one of [statuses] (`53.md:157`), and at least one provider must carry the
  /// `Host` role (`53.md:160`). A room without those still parses for
  /// tolerance but does not validate.
  static bool validate(NostrEvent event) {
    final room = tryParse(event);

    return room != null &&
        (room.roomName ?? '').isNotEmpty &&
        room.hasHost &&
        statuses.contains(room.rawStatus);
  }

  /// Builds an unsigned kind-30312 room and validates it.
  ///
  /// [roomName] is required by the spec (`53.md:142`). Throws
  /// [ArgumentError] when it is empty or no participant has the `Host` role.
  static NostrEvent build({
    required String dTag,
    required String roomName,
    required String status,
    required String serviceUrl,
    String? summary,
    String? image,
    String? endpointUrl,
    List<String> hashtags = const [],
    List<NostrLiveParticipant> participants = const [],
    List<String> relays = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    if (roomName.trim().isEmpty) {
      throw ArgumentError.value(
        roomName,
        'roomName',
        'Rooms require a non-empty room tag',
      );
    }

    _requireStatus(status, statuses);

    if (!participants.any((participant) => participant.isHost)) {
      throw ArgumentError.value(
        participants,
        'participants',
        'Rooms require at least one Host provider',
      );
    }

    final event = NostrEvent(
      id: null,
      kind: NostrLiveKind.room,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        ['room', roomName],
        if (summary != null) ['summary', summary],
        if (image != null) ['image', image],
        ['status', status],
        ['service', serviceUrl],
        if (endpointUrl != null) ['endpoint', endpointUrl],
        for (final hashtag in hashtags) ['t', hashtag],
        for (final participant in participants) participant.toTag(),
        if (relays.isNotEmpty) ['relays', ...relays],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_live_meeting}
/// Parsed NIP-53 meeting (kind 30313).
///
/// A meeting references its parent room with an `a` tag of kind 30312 and
/// requires `d`, `title`, `starts` and `status` (`53.md:184-203`).
/// {@endtemplate}
class NostrLiveMeeting {
  /// {@macro nostr_live_meeting}
  const NostrLiveMeeting({
    this.id,
    required this.pubkey,
    required this.dTag,
    required this.roomAddress,
    this.roomRelay,
    required this.title,
    this.summary,
    this.image,
    required this.starts,
    this.ends,
    this.status,
    this.rawStatus,
    this.currentParticipants,
    this.totalParticipants,
    this.participants = const [],
    this.content = '',
    this.tags = const [],
  });

  /// Status values allowed on a meeting.
  static const List<String> statuses = ['planned', 'live', 'ended'];

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// Required `d` identifier.
  final String dTag;

  /// Required `a` address of the parent kind-30312 room.
  final String roomAddress;

  /// Optional relay hint from the `a` tag.
  final String? roomRelay;

  /// Required `title`.
  final String title;

  /// Optional `summary`.
  final String? summary;

  /// Optional `image` URL.
  final String? image;

  /// Required `starts` UNIX seconds.
  final int starts;

  /// Optional `ends` UNIX seconds, after [starts] by convention.
  final int? ends;

  /// `status`: planned, live or ended, or `null` when unknown.
  final String? status;

  /// Raw `status` tag value, including values outside [statuses].
  final String? rawStatus;

  /// Optional `current_participants` count.
  final int? currentParticipants;

  /// Optional `total_participants` count.
  final int? totalParticipants;

  /// `p` participants in event order.
  final List<NostrLiveParticipant> participants;

  /// Free-form content.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrLiveMeeting parse(NostrEvent event) {
    if (event.kind != NostrLiveKind.meeting) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-53 meeting',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.isEmpty) {
      throw ArgumentError('Meetings require a non-empty d tag');
    }

    final roomTag = NostrTags.tag(tags, 'a');
    final roomAddress = NostrEventAddress.tryParse(NostrTags.at(roomTag, 1));
    if (roomAddress == null || roomAddress.kind != NostrLiveKind.room) {
      throw ArgumentError.value(
        NostrTags.at(roomTag, 1),
        'a',
        'Meetings require a kind-30312 room address',
      );
    }

    final title = NostrTags.first(tags, 'title');
    if (title == null || title.trim().isEmpty) {
      throw ArgumentError('Meetings require a non-empty title tag');
    }

    final starts = _requiredInt(tags, 'starts');
    final ends = _optionalInt(tags, 'ends');

    final status = NostrTags.first(tags, 'status');
    if (status == null || status.isEmpty) {
      throw ArgumentError('Meetings require a non-empty status tag');
    }

    return NostrLiveMeeting(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      roomAddress: roomAddress.address,
      roomRelay: _nonEmpty(NostrTags.at(roomTag, 2)),
      title: title,
      summary: NostrTags.first(tags, 'summary'),
      image: NostrTags.first(tags, 'image'),
      starts: starts,
      ends: ends,
      status: _typedStatus(status, statuses),
      rawStatus: status,
      currentParticipants: _optionalInt(tags, 'current_participants'),
      totalParticipants: _optionalInt(tags, 'total_participants'),
      participants: _participants(tags),
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrLiveMeeting? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a spec-conforming meeting.
  ///
  /// `status` must be one of [statuses] (`53.md:196`), matching [build].
  static bool validate(NostrEvent event) {
    final meeting = tryParse(event);

    return meeting != null && statuses.contains(meeting.rawStatus);
  }

  /// Builds an unsigned kind-30313 meeting and validates it.
  static NostrEvent build({
    required String dTag,
    required String roomAddress,
    String? roomRelay,
    required String title,
    String? summary,
    String? image,
    required int starts,
    int? ends,
    required String status,
    int? currentParticipants,
    int? totalParticipants,
    List<NostrLiveParticipant> participants = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    _requireStatus(status, statuses);

    final event = NostrEvent(
      id: null,
      kind: NostrLiveKind.meeting,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        ['a', roomAddress, if (roomRelay != null) roomRelay],
        ['title', title],
        if (summary != null) ['summary', summary],
        if (image != null) ['image', image],
        ['starts', '$starts'],
        if (ends != null) ['ends', '$ends'],
        ['status', status],
        if (currentParticipants != null)
          ['current_participants', '$currentParticipants'],
        if (totalParticipants != null)
          ['total_participants', '$totalParticipants'],
        for (final participant in participants) participant.toTag(),
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nostr_presence}
/// Parsed NIP-53 room presence (kind 10312).
///
/// Presence is a regular replaceable event, so it points at exactly one room
/// (`53.md:252-272`). [handRaised] comes from the optional `hand` tag.
/// {@endtemplate}
class NostrPresence {
  /// {@macro nostr_presence}
  const NostrPresence({
    this.id,
    required this.pubkey,
    required this.roomAddress,
    this.roomRelay,
    this.handRaised = false,
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// Required `a` address of the kind-30312 room.
  final String roomAddress;

  /// Optional relay hint from the `a` tag.
  final String? roomRelay;

  /// Whether the `hand` tag raises a hand.
  final bool handRaised;

  /// Free-form content, usually empty.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrPresence parse(NostrEvent event) {
    if (event.kind != NostrLiveKind.presence) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-53 presence event',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    if (!NostrTags.hasExactly(tags, 'a', 1)) {
      throw ArgumentError('Presence requires exactly one a tag');
    }

    final roomTag = NostrTags.tag(tags, 'a');
    final roomAddress = NostrEventAddress.tryParse(NostrTags.at(roomTag, 1));
    if (roomAddress == null || roomAddress.kind != NostrLiveKind.room) {
      throw ArgumentError.value(
        NostrTags.at(roomTag, 1),
        'a',
        'Presence requires a kind-30312 room address',
      );
    }

    final hand = NostrTags.first(tags, 'hand');

    return NostrPresence(
      id: event.id,
      pubkey: event.pubkey,
      roomAddress: roomAddress.address,
      roomRelay: _nonEmpty(NostrTags.at(roomTag, 2)),
      handRaised: hand != null && hand != '0' && hand.toLowerCase() != 'false',
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrPresence? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid presence event.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned kind-10312 presence event and validates it.
  static NostrEvent build({
    required String roomAddress,
    String? roomRelay,
    bool handRaised = false,
    String content = '',
    DateTime? createdAt,
  }) {
    final event = NostrEvent(
      id: null,
      kind: NostrLiveKind.presence,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['a', roomAddress, roomRelay ?? '', 'root'],
        if (handRaised) ['hand', '1'],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nip53}
/// NIP-53 live activities: streams, chat, rooms, meetings and presence.
///
/// Generation and [publish] are signer-bound; parsing is also available
/// without a signer on each typed class.
/// {@endtemplate}
class NostrNip53 {
  /// {@macro nip53}
  NostrNip53({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind of a live streaming event.
  static const int liveEventKind = NostrLiveKind.liveEvent;

  /// Kind of a live chat message.
  static const int chatMessageKind = NostrLiveKind.chatMessage;

  /// Kind of a room / space.
  static const int roomKind = NostrLiveKind.room;

  /// Kind of a meeting.
  static const int meetingKind = NostrLiveKind.meeting;

  /// Kind of a presence event.
  static const int presenceKind = NostrLiveKind.presence;

  /// Builds an unsigned kind-30311 live event.
  NostrEvent generateLiveEvent({
    required String dTag,
    String? title,
    String? summary,
    String? image,
    List<String> hashtags = const [],
    String? streamingUrl,
    String? recordingUrl,
    int? starts,
    int? ends,
    String? status,
    int? currentParticipants,
    int? totalParticipants,
    List<NostrLiveParticipant> participants = const [],
    List<String> relays = const [],
    List<String> pinned = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrLiveEvent.build(
      dTag: dTag,
      title: title,
      summary: summary,
      image: image,
      hashtags: hashtags,
      streamingUrl: streamingUrl,
      recordingUrl: recordingUrl,
      starts: starts,
      ends: ends,
      status: status,
      currentParticipants: currentParticipants,
      totalParticipants: totalParticipants,
      participants: participants,
      relays: relays,
      pinned: pinned,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-1311 live chat message.
  NostrEvent generateChatMessage({
    required String activityAddress,
    String? activityRelay,
    String? activityMarker,
    String? parentEventId,
    List<String> quotes = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrLiveChatMessage.build(
      activityAddress: activityAddress,
      activityRelay: activityRelay,
      activityMarker: activityMarker,
      parentEventId: parentEventId,
      quotes: quotes,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-30312 room.
  ///
  /// [roomName] is required by the spec (`53.md:142`).
  NostrEvent generateRoom({
    required String dTag,
    required String roomName,
    required String status,
    required String serviceUrl,
    String? summary,
    String? image,
    String? endpointUrl,
    List<String> hashtags = const [],
    List<NostrLiveParticipant> participants = const [],
    List<String> relays = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrLiveRoom.build(
      dTag: dTag,
      status: status,
      serviceUrl: serviceUrl,
      roomName: roomName,
      summary: summary,
      image: image,
      endpointUrl: endpointUrl,
      hashtags: hashtags,
      participants: participants,
      relays: relays,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-30313 meeting.
  NostrEvent generateMeeting({
    required String dTag,
    required String roomAddress,
    String? roomRelay,
    required String title,
    String? summary,
    String? image,
    required int starts,
    int? ends,
    required String status,
    int? currentParticipants,
    int? totalParticipants,
    List<NostrLiveParticipant> participants = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrLiveMeeting.build(
      dTag: dTag,
      roomAddress: roomAddress,
      roomRelay: roomRelay,
      title: title,
      summary: summary,
      image: image,
      starts: starts,
      ends: ends,
      status: status,
      currentParticipants: currentParticipants,
      totalParticipants: totalParticipants,
      participants: participants,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned kind-10312 presence event.
  NostrEvent generatePresence({
    required String roomAddress,
    String? roomRelay,
    bool handRaised = false,
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrPresence.build(
      roomAddress: roomAddress,
      roomRelay: roomRelay,
      handRaised: handRaised,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses a live event, throwing [ArgumentError] when invalid.
  NostrLiveEvent parseLiveEvent(NostrEvent event) =>
      NostrLiveEvent.parse(event);

  /// Parses a live event, returning `null` when invalid.
  NostrLiveEvent? tryParseLiveEvent(NostrEvent event) =>
      NostrLiveEvent.tryParse(event);

  /// Parses a chat message, throwing [ArgumentError] when invalid.
  NostrLiveChatMessage parseChatMessage(NostrEvent event) =>
      NostrLiveChatMessage.parse(event);

  /// Parses a chat message, returning `null` when invalid.
  NostrLiveChatMessage? tryParseChatMessage(NostrEvent event) =>
      NostrLiveChatMessage.tryParse(event);

  /// Parses a room, throwing [ArgumentError] when invalid.
  NostrLiveRoom parseRoom(NostrEvent event) => NostrLiveRoom.parse(event);

  /// Parses a room, returning `null` when invalid.
  NostrLiveRoom? tryParseRoom(NostrEvent event) =>
      NostrLiveRoom.tryParse(event);

  /// Parses a meeting, throwing [ArgumentError] when invalid.
  NostrLiveMeeting parseMeeting(NostrEvent event) =>
      NostrLiveMeeting.parse(event);

  /// Parses a meeting, returning `null` when invalid.
  NostrLiveMeeting? tryParseMeeting(NostrEvent event) =>
      NostrLiveMeeting.tryParse(event);

  /// Parses a presence event, throwing [ArgumentError] when invalid.
  NostrPresence parsePresence(NostrEvent event) => NostrPresence.parse(event);

  /// Parses a presence event, returning `null` when invalid.
  NostrPresence? tryParsePresence(NostrEvent event) =>
      NostrPresence.tryParse(event);
}

int? _optionalInt(List<List<String>> tags, String name) {
  final value = NostrTags.first(tags, name);
  if (value == null) {
    return null;
  }

  return _parseInt(value, name);
}

int _requiredInt(List<List<String>> tags, String name) {
  final value = NostrTags.first(tags, name);
  if (value == null) {
    throw ArgumentError('Missing required "$name" tag');
  }

  return _parseInt(value, name);
}

int _parseInt(String value, String name) {
  final parsed = NostrValidators.tryUnixSeconds(value);
  if (parsed == null) {
    throw ArgumentError.value(value, name, 'Expected a non-negative integer');
  }

  return parsed;
}

List<NostrLiveParticipant> _participants(List<List<String>> tags) {
  final participants = <NostrLiveParticipant>[];
  for (final tag in tags) {
    final participant = NostrLiveParticipant.tryParseTag(tag);
    if (participant != null) {
      participants.add(participant);
    }
  }

  return participants;
}

List<String> _relays(List<List<String>> tags) {
  final relays = <String>[];
  for (final tag in tags) {
    if (tag.isNotEmpty && tag.first == 'relays') {
      relays.addAll(tag.skip(1));
    }
  }

  return relays;
}

String? _nonEmpty(String? value) =>
    value == null || value.isEmpty ? null : value;

String? _typedStatus(String? value, List<String> allowed) =>
    value != null && allowed.contains(value) ? value : null;

void _requireStatus(String? value, List<String> allowed) {
  if (value != null && !allowed.contains(value)) {
    throw ArgumentError.value(value, 'status', 'Expected $allowed');
  }
}
