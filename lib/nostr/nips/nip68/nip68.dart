import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip92/nip92.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_picture_annotation}
/// NIP-68 `annotate-user` entry inside an `imeta` tag.
///
/// Positions are kept as the raw `posX`/`posY` tokens so clients can decide
/// whether they are pixels, percentages or fractions.
/// {@endtemplate}
class NostrPictureAnnotation {
  /// {@macro nostr_picture_annotation}
  const NostrPictureAnnotation({
    required this.pubkey,
    required this.x,
    required this.y,
  });

  /// Tagged user public key (64 lowercase hex characters).
  final String pubkey;

  /// Horizontal position token.
  final String x;

  /// Vertical position token.
  final String y;

  /// `pubkey:posX:posY`, or `null` when [raw] is malformed.
  static NostrPictureAnnotation? tryParse(String raw) {
    final parts = raw.split(':');
    if (parts.length != 3 || !NostrValidators.isHex64(parts[0])) {
      return null;
    }

    if (num.tryParse(parts[1]) == null || num.tryParse(parts[2]) == null) {
      return null;
    }

    return NostrPictureAnnotation(pubkey: parts[0], x: parts[1], y: parts[2]);
  }

  @override
  String toString() => '$pubkey:$x:$y';
}

/// {@template nostr_picture_event}
/// Parsed NIP-68 picture-first event (kind 20).
///
/// [images] holds every valid `imeta` with an accepted image MIME type.
/// [mimeTypes] and [hashes] are derived from those images, in image order.
/// {@endtemplate}
class NostrPictureEvent {
  /// {@macro nostr_picture_event}
  const NostrPictureEvent({
    this.id,
    required this.pubkey,
    required this.title,
    required this.description,
    this.contentWarning,
    this.images = const [],
    this.annotations = const [],
    this.participants = const [],
    this.hashtags = const [],
    this.location,
    this.geohash,
    this.language,
    this.languageType,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// Required `title` tag.
  final String title;

  /// Event content: the post description.
  final String description;

  /// `content-warning` reason, when NSFW.
  final String? contentWarning;

  /// Accepted image attachments, in tag order.
  final List<NostrImeta> images;

  /// Every `annotate-user` position across [images].
  final List<NostrPictureAnnotation> annotations;

  /// `p` tagged users.
  final List<String> participants;

  /// `t` hashtags.
  final List<String> hashtags;

  /// `location` tag.
  final String? location;

  /// `g` geohash.
  final String? geohash;

  /// `l` language code, when text appears in the images.
  final String? language;

  /// `L` language namespace, normally `ISO-639-1`.
  final String? languageType;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Distinct image MIME types, in image order.
  List<String> get mimeTypes {
    final seen = <String>{};

    return [
      for (final image in images)
        if (image.m != null && seen.add(image.m!)) image.m!,
    ];
  }

  /// Distinct `x` hashes, in image order.
  List<String> get hashes {
    final seen = <String>{};

    return [
      for (final image in images)
        if (image.x != null && seen.add(image.x!)) image.x!,
    ];
  }

  /// Parses [event], throwing [ArgumentError] when it is not a valid picture.
  static NostrPictureEvent parse(NostrEvent event) {
    if (event.kind != NostrNip68.kind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-68 picture event',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final title = NostrTags.first(tags, 'title');
    if (title == null || title.trim().isEmpty) {
      throw ArgumentError('Picture events require a non-empty title tag');
    }

    final images = <NostrImeta>[];
    final annotations = <NostrPictureAnnotation>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != NostrNip92.tagName) {
        continue;
      }

      final imeta = NostrImeta.tryParse(tag);
      if (imeta == null) {
        continue;
      }

      if (!NostrNip68.isAcceptedMimeType(imeta.m)) {
        throw ArgumentError.value(
          imeta.m,
          'imeta.m',
          'Only image/apng, avif, gif, jpeg, png and webp are accepted',
        );
      }

      images.add(imeta);
      for (final raw in imeta.extras['annotate-user'] ?? const <String>[]) {
        final annotation = NostrPictureAnnotation.tryParse(raw);
        if (annotation == null) {
          throw ArgumentError.value(
            raw,
            'annotate-user',
            'Expected pubkey:posX:posY',
          );
        }
        annotations.add(annotation);
      }
    }

    if (images.isEmpty) {
      throw ArgumentError(
        'Picture events require at least one imeta image tag',
      );
    }

    for (final mime in NostrTags.all(tags, 'm')) {
      if (!NostrNip68.isAcceptedMimeType(mime)) {
        throw ArgumentError.value(
          mime,
          'm',
          'Only image/apng, avif, gif, jpeg, png and webp are accepted',
        );
      }
    }

    return NostrPictureEvent(
      id: event.id,
      pubkey: event.pubkey,
      title: title,
      description: event.content ?? '',
      contentWarning: NostrTags.first(tags, 'content-warning'),
      images: List<NostrImeta>.unmodifiable(images),
      annotations: List<NostrPictureAnnotation>.unmodifiable(annotations),
      participants: NostrTags.all(tags, 'p'),
      hashtags: NostrTags.all(tags, 't'),
      location: NostrTags.first(tags, 'location'),
      geohash: NostrTags.first(tags, 'g'),
      language: NostrTags.first(tags, 'l'),
      languageType: NostrTags.first(tags, 'L'),
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for non-picture or invalid events.
  static NostrPictureEvent? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid NIP-68 picture event.
  static bool validate(NostrEvent event) => tryParse(event) != null;
}

/// {@template nip68}
/// NIP-68 picture-first feeds (kind 20).
///
/// [generateTemplate] builds an unsigned event with one `imeta` per image and
/// the queryable top-level `m`/`x` tags; [publish] signs through the bound
/// signer.
/// {@endtemplate}
class NostrNip68 {
  /// {@macro nip68}
  NostrNip68({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Picture-first event kind.
  static const int kind = 20;

  /// Media types accepted by NIP-68.
  static const Set<String> acceptedMimeTypes = {
    'image/apng',
    'image/avif',
    'image/gif',
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Whether [mime] is one of [acceptedMimeTypes].
  static bool isAcceptedMimeType(String? mime) =>
      mime != null && acceptedMimeTypes.contains(mime.toLowerCase());

  /// Builds an `imeta` tag for one picture, validating the URL and MIME type.
  static NostrImeta buildImage({
    required String url,
    required String mime,
    String? alt,
    String? dim,
    String? hash,
    String? thumbhash,
    String? blurhash,
    List<String> fallbacks = const [],
    List<NostrPictureAnnotation> annotations = const [],
  }) {
    if (url.trim().isEmpty) {
      throw ArgumentError.value(url, 'url', 'Image URL must not be empty');
    }

    if (!isAcceptedMimeType(mime)) {
      throw ArgumentError.value(
        mime,
        'mime',
        'Only image/apng, avif, gif, jpeg, png and webp are accepted',
      );
    }

    if (dim != null && !RegExp(r'^\d+x\d+$').hasMatch(dim)) {
      throw ArgumentError.value(dim, 'dim', 'Expected WIDTHxHEIGHT');
    }

    if (hash != null && !NostrValidators.isHex64(hash)) {
      throw ArgumentError.value(
        hash,
        'hash',
        'Expected 64 lowercase hex characters',
      );
    }

    return NostrImeta.parse([
      NostrNip92.tagName,
      'url $url',
      'm ${mime.toLowerCase()}',
      if (thumbhash != null) 'thumbhash $thumbhash',
      if (blurhash != null) 'blurhash $blurhash',
      if (dim != null) 'dim $dim',
      if (alt != null) 'alt $alt',
      if (hash != null) 'x $hash',
      for (final fallback in fallbacks) 'fallback $fallback',
      for (final annotation in annotations)
        'annotate-user ${annotation.pubkey}:${annotation.x}:${annotation.y}',
    ]);
  }

  /// Builds an unsigned kind-20 picture event.
  ///
  /// Requires a non-empty [title] and at least one [images] entry. Each image
  /// must carry an accepted MIME type; the top-level `m`/`x` tags are derived
  /// from the images so filters can find them.
  static NostrEvent generateTemplate({
    required String title,
    required List<NostrImeta> images,
    String description = '',
    String? contentWarning,
    List<String> participants = const [],
    List<String> hashtags = const [],
    String? location,
    String? geohash,
    String? language,
    String languageType = 'ISO-639-1',
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title must not be empty');
    }

    if (images.isEmpty) {
      throw ArgumentError.value(
        images,
        'images',
        'At least one image is required',
      );
    }

    for (final image in images) {
      if (image.url == null || image.url!.trim().isEmpty) {
        throw ArgumentError.value(
          image.toTag(),
          'images',
          'Every image requires a non-empty url',
        );
      }

      if (!isAcceptedMimeType(image.m)) {
        throw ArgumentError.value(
          image.m,
          'images',
          'Only image/apng, avif, gif, jpeg, png and webp are accepted',
        );
      }

      for (final raw in image.extras['annotate-user'] ?? const <String>[]) {
        if (NostrPictureAnnotation.tryParse(raw) == null) {
          throw ArgumentError.value(
            raw,
            'annotate-user',
            'Expected pubkey:posX:posY',
          );
        }
      }
    }

    if (language != null && languageType.trim().isEmpty) {
      throw ArgumentError.value(
        languageType,
        'languageType',
        'Language namespace must not be empty',
      );
    }

    final mimeTypes = <String>{};
    final hashes = <String>{};
    for (final image in images) {
      if (image.m != null) {
        mimeTypes.add(image.m!);
      }
      if (image.x != null) {
        hashes.add(image.x!);
      }
    }

    final event = NostrEvent(
      id: null,
      kind: kind,
      content: description,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['title', title],
        for (final image in images) image.toTag(),
        if (contentWarning != null) ['content-warning', contentWarning],
        for (final participant in participants) ['p', participant],
        for (final mime in mimeTypes) ['m', mime],
        for (final hash in hashes) ['x', hash],
        for (final hashtag in hashtags) ['t', hashtag],
        if (location != null) ['location', location],
        if (geohash != null) ['g', geohash],
        if (language != null) ...[
          ['L', languageType],
          ['l', language, languageType],
        ],
        ...tags,
      ],
    );

    NostrPictureEvent.parse(event);

    return event;
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);
}
