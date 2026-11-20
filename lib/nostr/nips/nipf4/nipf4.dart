import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_podcast_person}
/// One `p` tag of a NIP-F4 podcast metadata event.
///
/// [role] is optional and, when present, should be `host`, `cohost` or
/// `editor` (F4.md:58). Unknown roles are preserved so clients can show the
/// raw value; use [hasKnownRole] for the strict check.
/// {@endtemplate}
class NostrPodcastPerson {
  /// {@macro nostr_podcast_person}
  const NostrPodcastPerson({
    required this.pubkey,
    this.role,
    this.relayUrl,
  });

  /// Person public key in 64-char hex.
  final String pubkey;

  /// Optional role: `host`, `cohost` or `editor`.
  final String? role;

  /// Relay hint from the `p` tag, when present.
  final String? relayUrl;

  /// Whether [role] is one of the roles listed by F4.md:58.
  bool get hasKnownRole => role == null || NostrNipF4.roles.contains(role);
}

/// {@template nostr_podcast_audio}
/// One `audio` tag of a NIP-F4 episode: a URL plus an optional media type.
/// {@endtemplate}
class NostrPodcastAudio {
  /// {@macro nostr_podcast_audio}
  const NostrPodcastAudio({required this.url, this.mediaType});

  /// Direct audio URL.
  final String url;

  /// Optional MIME type from the tag's third slot.
  final String? mediaType;
}

/// {@template nostr_podcast_metadata}
/// Parsed NIP-F4 podcast metadata (kind 10154).
///
/// The podcast itself is a keypair, so [pubkey] is the show identity.
/// [people] keeps every `p` tag with its optional role (F4.md:40-58).
/// {@endtemplate}
class NostrPodcastMetadata {
  /// {@macro nostr_podcast_metadata}
  const NostrPodcastMetadata({
    required this.title,
    this.pubkey = '',
    this.image,
    this.description,
    this.websites = const <String>[],
    this.people = const <NostrPodcastPerson>[],
    this.tags = const <List<String>>[],
    this.content = '',
  });

  /// Show title (`title` tag).
  final String title;

  /// Podcast public key, when parsed from an event.
  final String pubkey;

  /// Cover image URL (`image` tag).
  final String? image;

  /// Show description (`description` tag).
  final String? description;

  /// Website URLs (`website` tags), in order.
  final List<String> websites;

  /// People credited by the show (`p` tags).
  final List<NostrPodcastPerson> people;

  /// Every remaining tag, preserved verbatim.
  final List<List<String>> tags;

  /// Event content, normally empty.
  final String content;

  /// Whether the mandatory fields are present and every URL/pubkey is valid.
  bool get isValid =>
      title.trim().isNotEmpty &&
      (image == null || NostrValidators.tryHttpUrl(image!) != null) &&
      websites.every((url) => NostrValidators.tryHttpUrl(url) != null) &&
      people.every(
        (person) => NostrValidators.isHex64(person.pubkey),
      );

  /// Hosts credited by the show, in tag order.
  List<String> get hosts => [
        for (final person in people)
          if (person.role == 'host') person.pubkey,
      ];
}

/// {@template nostr_authored_podcast_list}
/// Parsed NIP-F4 authored-podcast list (kind 10064).
///
/// The spec prose says `kind: 10164` while its body example shows
/// `kind: 10064` (F4.md:66-89). Builders emit 10064; the parser accepts both
/// and reports the prose form through [isLegacy].
/// {@endtemplate}
class NostrAuthoredPodcastList {
  /// {@macro nostr_authored_podcast_list}
  const NostrAuthoredPodcastList({
    required this.podcastPubkeys,
    this.pubkey = '',
    this.isLegacy = false,
    this.tags = const <List<String>>[],
  });

  /// Public keys of the podcasts the author claims to author.
  final List<String> podcastPubkeys;

  /// Author public key, when parsed from an event.
  final String pubkey;

  /// Whether the event used the legacy kind 10164.
  final bool isLegacy;

  /// Raw tags, preserved verbatim.
  final List<List<String>> tags;
}

/// {@template nostr_podcast_episode}
/// Parsed NIP-F4 podcast episode (kind 54).
///
/// Episodes are authored by the podcast key directly. [audios] keeps every
/// `audio` tag, because a show may publish several encodings of one episode
/// (F4.md:100-113). [content] is the episode's markdown body.
/// {@endtemplate}
class NostrPodcastEpisode {
  /// {@macro nostr_podcast_episode}
  const NostrPodcastEpisode({
    required this.title,
    this.pubkey = '',
    this.image,
    this.description,
    this.audios = const <NostrPodcastAudio>[],
    this.content = '',
    this.tags = const <List<String>>[],
  });

  /// Episode title (`title` tag).
  final String title;

  /// Podcast public key, when parsed from an event.
  final String pubkey;

  /// Episode image URL (`image` tag).
  final String? image;

  /// Short description (`description` tag).
  final String? description;

  /// Every `audio` tag, in order.
  final List<NostrPodcastAudio> audios;

  /// Markdown show notes.
  final String content;

  /// Every remaining tag, preserved verbatim.
  final List<List<String>> tags;

  /// Whether the episode has a title, at least one playable audio URL and
  /// valid optional URLs.
  bool get isValid =>
      title.trim().isNotEmpty &&
      audios.isNotEmpty &&
      audios.every((audio) => NostrValidators.tryHttpUrl(audio.url) != null) &&
      (image == null || NostrValidators.tryHttpUrl(image!) != null);
}

/// {@template nipf4}
/// NIP-F4 podcasts: kind 10154 metadata, kind 10064 authored-podcast lists
/// and kind 54 episodes.
///
/// [publish] signs events through the signer bound to this instance.
/// {@endtemplate}
class NostrNipF4 {
  /// {@macro nipf4}
  NostrNipF4({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind 10154: replaceable podcast metadata.
  static const int metadataKind = 10154;

  /// Kind 10064: replaceable authored-podcast list.
  static const int authoredListKind = 10064;

  /// Legacy kind from the spec prose; accepted on parse only.
  static const int legacyAuthoredListKind = 10164;

  /// Kind 54: podcast episode.
  static const int episodeKind = 54;

  /// Roles allowed by F4.md:58.
  static const Set<String> roles = {'host', 'cohost', 'editor'};

  /// Builds an unsigned kind-10154 podcast metadata event.
  ///
  /// [title] is required. [image] and every entry in [websites] must be
  /// absolute http(s) URLs, and [people] entries must carry valid public keys
  /// and known roles.
  static NostrEvent createPodcastMetadata({
    required String title,
    String? image,
    String? description,
    List<String> websites = const <String>[],
    List<NostrPodcastPerson> people = const <NostrPodcastPerson>[],
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Podcast title is required');
    }

    _validateHttpUrl(image, 'image');

    for (final url in websites) {
      _validateHttpUrl(url, 'websites');
    }

    for (final person in people) {
      if (!NostrValidators.isHex64(person.pubkey)) {
        throw ArgumentError.value(
          person.pubkey,
          'people',
          'Expected 64 lowercase hex characters',
        );
      }

      if (!person.hasKnownRole) {
        throw ArgumentError.value(
          person.role,
          'people',
          'Role must be one of ${roles.join(', ')}',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: metadataKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['title', title],
        if (image != null) ['image', image],
        if (description != null) ['description', description],
        for (final url in websites) ['website', url],
        for (final person in people)
          [
            'p',
            person.pubkey,
            if (person.role != null || person.relayUrl != null)
              person.role ?? '',
            if (person.relayUrl != null) person.relayUrl!,
          ],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-10064 authored-podcast list.
  ///
  /// Emits the current kind even though the spec prose says 10164 and its
  /// example shows 10064; see [NostrAuthoredPodcastList].
  static NostrEvent createAuthoredPodcastList({
    required List<String> podcastPubkeys,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    for (final pubkey in podcastPubkeys) {
      if (!NostrValidators.isHex64(pubkey)) {
        throw ArgumentError.value(
          pubkey,
          'podcastPubkeys',
          'Expected 64 lowercase hex characters',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: authoredListKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final pubkey in podcastPubkeys) ['p', pubkey],
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-54 episode.
  ///
  /// [audios] requires at least one entry; every URL must be absolute http(s).
  /// [content] holds the markdown show notes.
  static NostrEvent createEpisode({
    required String title,
    required List<NostrPodcastAudio> audios,
    String? image,
    String? description,
    String content = '',
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Episode title is required');
    }

    if (audios.isEmpty) {
      throw ArgumentError.value(
        audios,
        'audios',
        'An episode needs at least one audio tag',
      );
    }

    _validateHttpUrl(image, 'image');

    for (final audio in audios) {
      _validateHttpUrl(audio.url, 'audios');
    }

    return NostrEvent(
      id: null,
      kind: episodeKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['title', title],
        if (image != null) ['image', image],
        if (description != null) ['description', description],
        for (final audio in audios)
          [
            'audio',
            audio.url,
            if (audio.mediaType != null) audio.mediaType!,
          ],
        ...extraTags,
      ],
    );
  }

  /// Signs [event] with the bound signer; sending it is up to the caller.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses kind-10154 metadata, returning `null` when the event is invalid.
  static NostrPodcastMetadata? tryParseMetadata(NostrEvent event) {
    if (event.kind != metadataKind) {
      return null;
    }

    final title = NostrTags.first(event.tags, 'title');
    if (title == null || title.trim().isEmpty) {
      return null;
    }

    final people = <NostrPodcastPerson>[];
    final tags = <List<String>>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == 'p') {
        people.add(
          NostrPodcastPerson(
            pubkey: tag[1],
            role: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
            relayUrl: tag.length > 3 && tag[3].isNotEmpty ? tag[3] : null,
          ),
        );
        continue;
      }

      if (tag.isNotEmpty &&
          (tag.first == 'title' ||
              tag.first == 'image' ||
              tag.first == 'description' ||
              tag.first == 'website')) {
        continue;
      }

      tags.add(List<String>.of(tag));
    }

    final metadata = NostrPodcastMetadata(
      title: title,
      pubkey: event.pubkey,
      image: NostrTags.first(event.tags, 'image'),
      description: NostrTags.first(event.tags, 'description'),
      websites: NostrTags.all(event.tags, 'website'),
      people: people,
      tags: tags,
      content: event.content ?? '',
    );

    return metadata.isValid ? metadata : null;
  }

  /// Like [tryParseMetadata], but throws [ArgumentError] when invalid.
  static NostrPodcastMetadata parseMetadata(NostrEvent event) {
    final metadata = tryParseMetadata(event);

    if (metadata == null) {
      throw ArgumentError('Invalid NIP-F4 podcast metadata event');
    }

    return metadata;
  }

  /// Parses kind 10064 or the legacy kind 10164.
  ///
  /// Returns `null` for any other kind or a malformed `p` tag.
  static NostrAuthoredPodcastList? tryParseAuthoredList(NostrEvent event) {
    final kind = event.kind;

    if (kind != authoredListKind && kind != legacyAuthoredListKind) {
      return null;
    }

    final pubkeys = <String>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isEmpty || tag.first != 'p') {
        continue;
      }

      if (tag.length < 2 || !NostrValidators.isHex64(tag[1])) {
        return null;
      }

      pubkeys.add(tag[1]);
    }

    return NostrAuthoredPodcastList(
      podcastPubkeys: pubkeys,
      pubkey: event.pubkey,
      isLegacy: kind == legacyAuthoredListKind,
      tags: [
        for (final tag in event.tags ?? const <List<String>>[])
          List<String>.of(tag),
      ],
    );
  }

  /// Like [tryParseAuthoredList], but throws [ArgumentError] when invalid.
  static NostrAuthoredPodcastList parseAuthoredList(NostrEvent event) {
    final list = tryParseAuthoredList(event);

    if (list == null) {
      throw ArgumentError('Invalid NIP-F4 authored-podcast list event');
    }

    return list;
  }

  /// Parses a kind-54 episode, returning `null` when invalid.
  static NostrPodcastEpisode? tryParseEpisode(NostrEvent event) {
    if (event.kind != episodeKind) {
      return null;
    }

    final title = NostrTags.first(event.tags, 'title');
    if (title == null || title.trim().isEmpty) {
      return null;
    }

    final audios = <NostrPodcastAudio>[];
    final tags = <List<String>>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == 'audio') {
        audios.add(
          NostrPodcastAudio(
            url: tag[1],
            mediaType: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
          ),
        );
        continue;
      }

      if (tag.isNotEmpty &&
          (tag.first == 'title' ||
              tag.first == 'image' ||
              tag.first == 'description')) {
        continue;
      }

      tags.add(List<String>.of(tag));
    }

    final episode = NostrPodcastEpisode(
      title: title,
      pubkey: event.pubkey,
      image: NostrTags.first(event.tags, 'image'),
      description: NostrTags.first(event.tags, 'description'),
      audios: audios,
      content: event.content ?? '',
      tags: tags,
    );

    return episode.isValid ? episode : null;
  }

  /// Like [tryParseEpisode], but throws [ArgumentError] when invalid.
  static NostrPodcastEpisode parseEpisode(NostrEvent event) {
    final episode = tryParseEpisode(event);

    if (episode == null) {
      throw ArgumentError('Invalid NIP-F4 podcast episode event');
    }

    return episode;
  }

  /// Whether [authored] countersigns the `p` claims in [metadata].
  ///
  /// The check is the two-way claim required by F4.md:60-64: [authored] lists
  /// `metadata.pubkey` and [metadata] lists `authored.pubkey`. Signatures are
  /// not checked unless [requireValidSignatures] is set, because callers may
  /// want to inspect unsigned templates.
  static bool verifyAuthorship(
    NostrEvent metadata,
    NostrEvent authored, {
    bool requireValidSignatures = false,
  }) {
    if (metadata.kind != metadataKind ||
        (authored.kind != authoredListKind &&
            authored.kind != legacyAuthoredListKind)) {
      return false;
    }

    if (requireValidSignatures &&
        (!metadata.isVerified() || !authored.isVerified())) {
      return false;
    }

    final claims = NostrTags.all(metadata.tags, 'p');
    final authoredPubkeys = NostrTags.all(authored.tags, 'p');

    return claims.contains(authored.pubkey) &&
        authoredPubkeys.contains(metadata.pubkey);
  }

  static void _validateHttpUrl(String? value, String name) {
    if (value != null && NostrValidators.tryHttpUrl(value) == null) {
      throw ArgumentError.value(
        value,
        name,
        'Expected an absolute http(s) URL',
      );
    }
  }
}
