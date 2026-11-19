import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip99_price}
/// Price of a classified listing.
///
/// [amount] is a numeric string, [currency] a 3-letter ISO 4217 code and
/// [frequency] an optional payment period (`hour`, `day`, `week`, `month`,
/// `year` or a custom value).
/// {@endtemplate}
class NostrClassifiedPrice {
  /// {@macro nip99_price}
  const NostrClassifiedPrice({
    required this.amount,
    required this.currency,
    this.frequency,
  });

  /// Numeric amount as a string.
  final String amount;

  /// ISO 4217 currency code.
  final String currency;

  /// Optional payment frequency.
  final String? frequency;
}

/// {@template nip99_image}
/// Image attached to a classified listing.
/// {@endtemplate}
class NostrClassifiedImage {
  /// {@macro nip99_image}
  const NostrClassifiedImage({required this.url, this.dimensions});

  /// Image URL.
  final String url;

  /// Optional dimensions such as `800x600`.
  final String? dimensions;
}

/// {@template nip99_listing}
/// Classified listing payload (kind 30402, or 30403 when [isDraft]).
/// {@endtemplate}
class NostrClassifiedListing {
  /// {@macro nip99_listing}
  const NostrClassifiedListing({
    required this.title,
    required this.summary,
    required this.content,
    required this.publishedAt,
    required this.location,
    required this.price,
    this.isDraft = false,
    this.images = const [],
    this.hashtags = const [],
    this.additionalTags = const {},
  });

  /// Whether the listing is a draft (kind 30403).
  final bool isDraft;

  /// Listing title.
  final String title;

  /// Short tagline.
  final String summary;

  /// Markdown description.
  final String content;

  /// Publication timestamp as a UNIX seconds string.
  final String publishedAt;

  /// Free-form location.
  final String location;

  /// Price details.
  final NostrClassifiedPrice price;

  /// Listing images.
  final List<NostrClassifiedImage> images;

  /// Hashtags/categories (`t` tags).
  final List<String> hashtags;

  /// Extra tags.
  ///
  /// For `e` and `a` the values are emitted in a single three-element tag so
  /// the listing validates; other keys emit one tag per value. Parsing only
  /// surfaces `e` and `a` tags here.
  final Map<String, List<String>> additionalTags;
}

/// {@template nip99}
/// NIP-99 classified listings.
///
/// Wraps the parameterized replaceable kinds 30402 (published) and 30403
/// (draft). Validation, parsing and template generation are static;
/// [publish] signs through the bound signer.
///
/// The `d` tag is derived from the title: trimmed, lowercased and with spaces
/// replaced by dashes, so a listing's identifier changes if the title does.
/// {@endtemplate}
class NostrNip99 {
  /// {@macro nip99}
  NostrNip99({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind of a published classified listing.
  static const int classifiedListingKind = 30402;

  /// Kind of a draft classified listing.
  static const int draftClassifiedListingKind = 30403;

  /// Tags that must appear exactly once.
  static const List<String> requiredTags = [
    'd',
    'title',
    'summary',
    'location',
    'published_at',
    'price',
  ];

  /// Validates the required tag shape of a classified listing [event].
  static bool validateEvent(NostrEvent event) {
    final kind = event.kind;
    if (kind != classifiedListingKind && kind != draftClassifiedListingKind) {
      return false;
    }

    final tags = event.tags ?? const <List<String>>[];
    if (tags.length < requiredTags.length) {
      return false;
    }

    final counts = <String, int>{};

    for (final tag in tags) {
      if (tag.length < 2) {
        return false;
      }

      final name = tag.first;
      final values = tag.sublist(1);

      if (name == 'published_at' && int.tryParse(values.first) == null) {
        return false;
      }

      if (name == 'price') {
        if (values.length < 2) {
          return false;
        }
        if (num.tryParse(values.first) == null || values[1].length != 3) {
          return false;
        }
      }

      if ((name == 'e' || name == 'a') && tag.length != 3) {
        return false;
      }

      if (requiredTags.contains(name)) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    return counts.length == requiredTags.length &&
        counts.values.every((count) => count == 1);
  }

  /// Parses [event] into a [NostrClassifiedListing].
  ///
  /// Throws [ArgumentError] when [validateEvent] fails.
  static NostrClassifiedListing parseEvent(NostrEvent event) {
    if (!validateEvent(event)) {
      throw ArgumentError('Invalid classified listing event');
    }

    var title = '';
    var summary = '';
    var publishedAt = '';
    var location = '';
    var amount = '';
    var currency = '';
    String? frequency;
    final images = <NostrClassifiedImage>[];
    final hashtags = <String>[];
    final additionalTags = <String, List<String>>{};

    for (final tag in event.tags ?? const <List<String>>[]) {
      final name = tag.first;
      final values = tag.sublist(1);

      switch (name) {
        case 'title':
          title = values.first;
        case 'summary':
          summary = values.first;
        case 'published_at':
          publishedAt = values.first;
        case 'location':
          location = values.first;
        case 'price':
          amount = values.first;
          currency = values[1];
          if (values.length == 3) {
            frequency = values[2];
          }
        case 'image':
          images.add(
            NostrClassifiedImage(
              url: values.first,
              dimensions: values.length > 1 ? values[1] : null,
            ),
          );
        case 't':
          hashtags.add(values.first);
        case 'e' || 'a':
          additionalTags[name] = List<String>.of(values);
      }
    }

    return NostrClassifiedListing(
      isDraft: event.kind == draftClassifiedListingKind,
      title: title,
      summary: summary,
      content: event.content ?? '',
      publishedAt: publishedAt,
      location: location,
      price: NostrClassifiedPrice(
        amount: amount,
        currency: currency,
        frequency: frequency,
      ),
      images: images,
      hashtags: hashtags,
      additionalTags: additionalTags,
    );
  }

  /// Builds an unsigned classified listing event.
  static NostrEvent generateEventTemplate(
    NostrClassifiedListing listing, {
    DateTime? createdAt,
  }) {
    final priceTag = [
      'price',
      listing.price.amount,
      listing.price.currency,
      if (listing.price.frequency != null) listing.price.frequency!,
    ];

    final identifier = listing.title.trim().toLowerCase().replaceAll(' ', '-');

    final tags = <List<String>>[
      ['d', identifier],
      ['title', listing.title],
      ['published_at', listing.publishedAt],
      ['summary', listing.summary],
      ['location', listing.location],
      priceTag,
      for (final image in listing.images)
        [
          'image',
          image.url,
          if (image.dimensions != null) image.dimensions!,
        ],
      for (final hashtag in listing.hashtags) ['t', hashtag],
    ];

    for (final entry in listing.additionalTags.entries) {
      if (entry.key == 'e' || entry.key == 'a') {
        tags.add([entry.key, ...entry.value]);
      } else {
        for (final value in entry.value) {
          tags.add([entry.key, value]);
        }
      }
    }

    return NostrEvent(
      id: null,
      kind:
          listing.isDraft ? draftClassifiedListingKind : classifiedListingKind,
      content: listing.content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: tags,
    );
  }

  /// Builds and signs a classified listing event.
  Future<NostrEvent> publish(
    NostrClassifiedListing listing, {
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateEventTemplate(listing, createdAt: createdAt),
    );
  }
}
