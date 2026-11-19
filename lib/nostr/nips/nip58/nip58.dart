import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip58_thumbnail}
/// A `thumb` tag: URL plus optional `WxH` dimensions.
/// {@endtemplate}
class Nip58Thumbnail {
  /// {@macro nip58_thumbnail}
  const Nip58Thumbnail({required this.url, this.dimensions});

  /// Thumbnail URL.
  final String url;

  /// Optional dimensions such as `256x256`.
  final String? dimensions;
}

/// {@template nip58_badge_definition}
/// A parsed kind 30009 badge definition.
/// {@endtemplate}
class Nip58BadgeDefinition {
  /// {@macro nip58_badge_definition}
  const Nip58BadgeDefinition({
    required this.identifier,
    required this.pubkey,
    this.name,
    this.description,
    this.imageUrl,
    this.imageDimensions,
    this.thumbs = const [],
  });

  /// `d` tag, unique per issuer.
  final String identifier;

  /// Issuer pubkey (event author).
  final String pubkey;

  /// `name` tag.
  final String? name;

  /// `description` tag.
  final String? description;

  /// `image` tag URL.
  final String? imageUrl;

  /// `image` tag dimensions (`1024x1024`).
  final String? imageDimensions;

  /// `thumb` tags.
  final List<Nip58Thumbnail> thumbs;

  /// Address of this definition: `30009:<pubkey>:<d>`.
  String get address => '30009:$pubkey:$identifier';
}

/// {@template nip58_recipient}
/// A `p` tag recipient of a badge award.
/// {@endtemplate}
class Nip58Recipient {
  /// {@macro nip58_recipient}
  const Nip58Recipient({required this.pubkey, this.relay});

  /// Awarded pubkey.
  final String pubkey;

  /// Optional relay hint.
  final String? relay;
}

/// {@template nip58_badge_award}
/// A parsed kind 8 badge award.
/// {@endtemplate}
class Nip58BadgeAward {
  /// {@macro nip58_badge_award}
  const Nip58BadgeAward({
    required this.address,
    required this.pubkey,
    this.recipients = const [],
  });

  /// `a` tag pointing at the badge definition (`30009:<pubkey>:<d>`).
  final String address;

  /// Issuer pubkey (event author).
  final String pubkey;

  /// Awarded pubkeys.
  final List<Nip58Recipient> recipients;
}

/// {@template nip58_badge_pair}
/// An `a`/`e` pair in a profile badges (kind 10008) or badge set (30008).
/// {@endtemplate}
class Nip58BadgePair {
  /// {@macro nip58_badge_pair}
  const Nip58BadgePair({
    required this.address,
    this.awardEventIds = const [],
    this.relays = const [],
  });

  /// Badge definition address.
  final String address;

  /// Badge award event ids shown for that definition.
  final List<String> awardEventIds;

  /// Relay hints carried by the `e` tags.
  final List<String> relays;
}

/// {@template nip58_badge_list}
/// A parsed kind 10008 profile badges or kind 30008 badge set event.
/// {@endtemplate}
class Nip58BadgeList {
  /// {@macro nip58_badge_list}
  const Nip58BadgeList({
    required this.identifier,
    required this.pairs,
    this.title,
    this.description,
  });

  /// `d` tag (`profile_badges` for kind 10008).
  final String identifier;

  /// Ordered `a`/`e` pairs. `a` tags without a matching `e` are ignored.
  final List<Nip58BadgePair> pairs;

  /// Optional `title` tag (badge sets).
  final String? title;

  /// Optional `description` tag (badge sets).
  final String? description;
}

/// {@template nip58}
/// NIP-58 badges.
///
/// - Kind 30009 badge definition: `d`, `name`, `description`, `image`,
///   `thumb`.
/// - Kind 8 badge award: one `a` (definition address) plus one `p` per
///   recipient.
/// - Kind 10008 profile badges (replaceable) and kind 30008 badge sets
///   (addressable): ordered `a`/`e` pairs; the set form also accepts
///   `title`/`description`.
///
/// Parsing and validation are static; builders sign with [signer].
///
/// ```dart
/// final nip58 = NostrNip58(signer: signer);
/// final definition = await nip58.createBadgeDefinition(
///   identifier: 'bravery',
///   name: 'Medal of Bravery',
///   imageUrl: 'https://example.com/bravery.png',
///   imageDimensions: '1024x1024',
/// );
/// final award = await nip58.createBadgeAward(
///   definitionAddress:
///       '30009:${signer.publicKey}:bravery',
///   recipients: [Nip58Recipient(pubkey: friendPubkey)],
/// );
/// ```
/// {@endtemplate}
class NostrNip58 {
  /// {@macro nip58}
  NostrNip58({required this.signer});

  /// Signer used to publish badge events.
  final NostrEventSigner signer;

  /// Kind of a badge definition.
  static const int definitionKind = 30009;

  /// Kind of a badge award.
  static const int awardKind = 8;

  /// Kind of a profile badges list.
  static const int profileBadgesKind = 10008;

  /// Kind of a badge set.
  static const int badgeSetKind = 30008;

  /// `d` tag required by kind 10008.
  static const String profileBadgesIdentifier = 'profile_badges';

  /// Parses a kind 30009 badge definition.
  static Nip58BadgeDefinition? parseBadgeDefinition(NostrEvent event) {
    if (event.kind != definitionKind) {
      return null;
    }
    final tags = event.tags ?? const <List<String>>[];
    final identifier = _tagValue(tags, 'd');
    if (identifier == null) {
      return null;
    }
    final image = _tag(tags, 'image');
    return Nip58BadgeDefinition(
      identifier: identifier,
      pubkey: event.pubkey,
      name: _tagValue(tags, 'name'),
      description: _tagValue(tags, 'description'),
      imageUrl: image != null && image.length > 1 ? image[1] : null,
      imageDimensions: image != null && image.length > 2 ? image[2] : null,
      thumbs: [
        for (final tag in tags)
          if (tag.length > 1 && tag[0] == 'thumb')
            Nip58Thumbnail(
              url: tag[1],
              dimensions: tag.length > 2 ? tag[2] : null,
            ),
      ],
    );
  }

  /// Parses a kind 8 badge award. Returns `null` without an `a` tag.
  static Nip58BadgeAward? parseBadgeAward(NostrEvent event) {
    if (event.kind != awardKind) {
      return null;
    }
    final tags = event.tags ?? const <List<String>>[];
    final address = _tagValue(tags, 'a');
    if (address == null) {
      return null;
    }
    return Nip58BadgeAward(
      address: address,
      pubkey: event.pubkey,
      recipients: [
        for (final tag in tags)
          if (tag.length > 1 && tag[0] == 'p')
            Nip58Recipient(
              pubkey: tag[1],
              relay: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
            ),
      ],
    );
  }

  /// Parses a kind 10008 profile badges or kind 30008 badge set event.
  ///
  /// Only consecutive `a`/`e` pairs are kept; an `a` followed by another `a`
  /// (or by no `e`) is dropped, as the NIP requires.
  static Nip58BadgeList? parseBadgeList(NostrEvent event) {
    if (event.kind != profileBadgesKind && event.kind != badgeSetKind) {
      return null;
    }
    final tags = event.tags ?? const <List<String>>[];
    final pairs = <Nip58BadgePair>[];
    String? pendingAddress;
    for (final tag in tags) {
      if (tag.length < 2) {
        continue;
      }
      if (tag[0] == 'a') {
        pendingAddress = tag[1];
        continue;
      }
      if (tag[0] == 'e' && pendingAddress != null) {
        pairs.add(
          Nip58BadgePair(
            address: pendingAddress,
            awardEventIds: [tag[1]],
            relays: [
              if (tag.length > 2 && tag[2].isNotEmpty) tag[2],
            ],
          ),
        );
        pendingAddress = null;
      }
    }
    return Nip58BadgeList(
      identifier: _tagValue(tags, 'd') ?? '',
      pairs: pairs,
      title: _tagValue(tags, 'title'),
      description: _tagValue(tags, 'description'),
    );
  }

  /// Whether [event] is a valid kind 30009 definition (has a `d` tag).
  static bool validateBadgeDefinition(NostrEvent event) =>
      event.kind == definitionKind &&
      _tagValue(event.tags ?? const [], 'd') != null;

  /// Whether [event] is a valid kind 8 award (has `a` and at least one `p`).
  static bool validateBadgeAward(NostrEvent event) {
    if (event.kind != awardKind) {
      return false;
    }
    final tags = event.tags ?? const <List<String>>[];
    return _tagValue(tags, 'a') != null && _tagValue(tags, 'p') != null;
  }

  /// Whether [event] is a valid kind 10008 profile badges event.
  static bool validateProfileBadges(NostrEvent event) =>
      event.kind == profileBadgesKind &&
      _tagValue(event.tags ?? const [], 'd') == profileBadgesIdentifier;

  /// Builds and signs a kind 30009 badge definition.
  Future<NostrEvent> createBadgeDefinition({
    required String identifier,
    String? name,
    String? description,
    String? imageUrl,
    String? imageDimensions,
    List<Nip58Thumbnail> thumbs = const [],
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      definitionKind,
      '',
      [
        ['d', identifier],
        if (name != null && name.isNotEmpty) ['name', name],
        if (description != null && description.isNotEmpty)
          ['description', description],
        if (imageUrl != null)
          [
            'image',
            imageUrl,
            if (imageDimensions != null) imageDimensions,
          ],
        for (final thumb in thumbs)
          [
            'thumb',
            thumb.url,
            if (thumb.dimensions != null) thumb.dimensions!,
          ],
        ...extraTags,
      ],
      createdAt,
    );
  }

  /// Builds and signs a kind 8 badge award.
  Future<NostrEvent> createBadgeAward({
    required String definitionAddress,
    required List<Nip58Recipient> recipients,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    if (recipients.isEmpty) {
      throw ArgumentError.value(
        recipients,
        'recipients',
        'a badge award needs at least one recipient',
      );
    }
    return _sign(
      awardKind,
      '',
      [
        ['a', definitionAddress],
        for (final recipient in recipients)
          [
            'p',
            recipient.pubkey,
            if (recipient.relay != null) recipient.relay!,
          ],
        ...extraTags,
      ],
      createdAt,
    );
  }

  /// Builds and signs a kind 10008 profile badges event.
  Future<NostrEvent> createProfileBadges({
    required List<Nip58BadgePair> badges,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      profileBadgesKind,
      '',
      [
        ['d', profileBadgesIdentifier],
        for (final badge in badges) ...[
          ['a', badge.address],
          for (var i = 0; i < badge.awardEventIds.length; i++)
            [
              'e',
              badge.awardEventIds[i],
              if (i < badge.relays.length && badge.relays[i].isNotEmpty)
                badge.relays[i],
            ],
        ],
        ...extraTags,
      ],
      createdAt,
    );
  }

  /// Builds and signs a kind 30008 badge set.
  Future<NostrEvent> createBadgeSet({
    required String identifier,
    List<Nip58BadgePair> badges = const [],
    String? title,
    String? description,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      badgeSetKind,
      '',
      [
        ['d', identifier],
        if (title != null && title.isNotEmpty) ['title', title],
        if (description != null && description.isNotEmpty)
          ['description', description],
        for (final badge in badges) ...[
          ['a', badge.address],
          for (var i = 0; i < badge.awardEventIds.length; i++)
            [
              'e',
              badge.awardEventIds[i],
              if (i < badge.relays.length && badge.relays[i].isNotEmpty)
                badge.relays[i],
            ],
        ],
        ...extraTags,
      ],
      createdAt,
    );
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

  static List<String>? _tag(List<List<String>> tags, String name) {
    for (final tag in tags) {
      if (tag.length > 1 && tag[0] == name) {
        return tag;
      }
    }
    return null;
  }

  static String? _tagValue(List<List<String>> tags, String name) =>
      _tag(tags, name)?[1];
}
