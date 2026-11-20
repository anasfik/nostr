import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_web_bookmark}
/// Parsed NIP-B0 web bookmark (kind 39701).
///
/// [coordinate] is the `d` tag, the URL without its `https://` prefix, and
/// [url] the absolute URL rebuilt from it. [publishedAt] is the
/// `published_at` unix timestamp, [title] the optional title and [topics] the
/// `t` hashtags. [content] is the bookmark description.
///
/// Replies to a bookmark are kind-1111 comments scoped to [address]; this
/// class does not build them.
/// {@endtemplate}
class NostrWebBookmark {
  /// {@macro nostr_web_bookmark}
  const NostrWebBookmark({
    this.id,
    required this.pubkey,
    required this.coordinate,
    required this.url,
    this.publishedAt,
    this.title,
    this.topics = const [],
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Bookmark author public key.
  final String pubkey;

  /// `d` tag: URL without the `https://` prefix.
  final String coordinate;

  /// Absolute bookmark URL.
  final String url;

  /// `published_at` tag in unix seconds.
  final int? publishedAt;

  /// `title` tag.
  final String? title;

  /// `t` tag values.
  final List<String> topics;

  /// Bookmark description.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Host of [url].
  String? get domain => Uri.tryParse(url)?.host;

  /// NIP-01 address of this bookmark for kind-1111 comments.
  ///
  /// Comments use the address as both root and parent content; feed this to
  /// the comment builder as `A`/`K`/`P` and `a`/`k`/`p`.
  NostrEventAddress get address => NostrEventAddress(
        kind: NostrNipB0.kind,
        pubkey: pubkey,
        identifier: coordinate,
      );

  /// Parses a kind-39701 event, throwing [ArgumentError] when invalid.
  static NostrWebBookmark parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-B0 web bookmark event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrWebBookmark? tryParse(NostrEvent event) {
    if (event.kind != NostrNipB0.kind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final coordinate = NostrTags.first(tags, 'd');
    if (coordinate == null || coordinate.trim().isEmpty) {
      return null;
    }

    final url = NostrNipB0.tryUrlForCoordinate(coordinate);
    if (url == null) {
      return null;
    }

    final title = NostrTags.first(tags, 'title');

    return NostrWebBookmark(
      id: event.id,
      pubkey: event.pubkey,
      coordinate: coordinate,
      url: url,
      publishedAt: NostrValidators.tryUnixSeconds(
        NostrTags.first(tags, 'published_at'),
      ),
      title: title == null || title.isEmpty ? null : title,
      topics: NostrTags.all(tags, 't'),
      content: event.content ?? '',
      tags: tags,
    );
  }
}

/// {@template nipb0}
/// NIP-B0 editable web bookmarks (kind 39701).
///
/// The `d` tag is the bookmark URL with the `https://` prefix omitted, so
/// clients can query bookmarks by URL. `published_at`, `title` and `t` tags
/// carry metadata and the content is the description. Replies are NIP-22
/// kind-1111 comments addressed to the bookmark coordinate.
/// {@endtemplate}
class NostrNipB0 {
  /// {@macro nipb0}
  NostrNipB0({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Web bookmark kind.
  static const int kind = 39701;

  /// `d` tag for [url].
  ///
  /// An `https` URL loses the literal scheme prefix, as B0.md requires; the
  /// remainder is kept verbatim so distinct URLs (case, fragment) do not
  /// collapse together. Other accepted forms keep their text unchanged.
  ///
  /// Throws [ArgumentError] when [url] is not an absolute http(s) URL.
  static String coordinateForUrl(String url) {
    final value = url.trim();
    if (NostrValidators.tryHttpUrl(value) == null) {
      throw ArgumentError.value(url, 'url', 'Expected an http(s) URL');
    }

    return value.startsWith('https://')
        ? value.substring('https://'.length)
        : value;
  }

  /// Absolute URL for a `d` [coordinate].
  ///
  /// Accepts both addressable forms: a bare `host/path` (implicitly `https`)
  /// and a coordinate that still carries an `http(s)://` scheme.
  ///
  /// Throws [ArgumentError] when the result is not an absolute http(s) URL.
  static String urlForCoordinate(String coordinate) {
    final url = tryUrlForCoordinate(coordinate);
    if (url == null) {
      throw ArgumentError.value(
        coordinate,
        'coordinate',
        'Expected a URL or a host/path coordinate',
      );
    }

    return url;
  }

  /// Like [urlForCoordinate], returning `null` for invalid coordinates.
  static String? tryUrlForCoordinate(String coordinate) {
    final value = coordinate.trim();
    if (value.isEmpty) {
      return null;
    }

    final candidate = switch (value) {
      final String v when v.startsWith('http://') => v,
      final String v when v.startsWith('https://') => v,
      final String v when v.startsWith('//') => 'https:$v',
      _ => 'https://$value',
    };

    return NostrValidators.tryHttpUrl(candidate)?.toString();
  }

  /// Builds an unsigned kind-39701 bookmark.
  ///
  /// [publishedAt] defaults to [createdAt] in unix seconds when omitted.
  ///
  /// Throws [ArgumentError] when [url] is not http(s), a title/topic is blank,
  /// or [publishedAt] is negative.
  static NostrEvent generateBookmarkTemplate({
    required String url,
    String content = '',
    String? title,
    int? publishedAt,
    List<String> topics = const [],
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now();
    final published = publishedAt ?? timestamp.millisecondsSinceEpoch ~/ 1000;

    if (published < 0) {
      throw ArgumentError.value(
        publishedAt,
        'publishedAt',
        'Timestamp must not be negative',
      );
    }

    if (title != null && title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title is empty');
    }

    for (final topic in topics) {
      if (topic.trim().isEmpty) {
        throw ArgumentError.value(topic, 'topics', 'Topic is empty');
      }
    }

    return NostrEvent(
      id: null,
      kind: kind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: timestamp,
      tags: [
        ['d', coordinateForUrl(url)],
        ['published_at', '$published'],
        if (title != null) ['title', title],
        for (final topic in topics) ['t', topic],
      ],
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);
}
