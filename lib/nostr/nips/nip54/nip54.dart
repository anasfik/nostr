import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip54_article}
/// A parsed NIP-54 wiki article (kind 30818).
/// {@endtemplate}
class Nip54Article {
  /// {@macro nip54_article}
  const Nip54Article({
    required this.identifier,
    required this.content,
    this.title,
    this.summary,
    this.forkedFromAddresses = const [],
    this.forkedFromEventIds = const [],
  });

  /// Normalized `d` tag.
  final String identifier;

  /// Djot content.
  final String content;

  /// Display title from the `title` tag, if any.
  final String? title;

  /// List summary from the `summary` tag, if any.
  final String? summary;

  /// `a` tags pointing at the fork source article.
  final List<String> forkedFromAddresses;

  /// `e` tags pointing at the fork source event.
  final List<String> forkedFromEventIds;
}

/// {@template nip54_highlight_author}
/// `p` tag attribution carried by a highlight.
/// {@endtemplate}
class Nip54HighlightAuthor {
  /// {@macro nip54_highlight_author}
  const Nip54HighlightAuthor({
    required this.pubkey,
    this.relay,
    this.role,
  });

  /// Author/editor pubkey.
  final String pubkey;

  /// Optional relay hint.
  final String? relay;

  /// Optional role (`author`, `editor`, ...).
  final String? role;
}

/// {@template nip54_highlight}
/// A parsed highlight (`kind 9802`).
///
/// Highlights are defined by NIP-84; they live in this file because they
/// share the long-form content surface with wiki articles.
/// {@endtemplate}
class Nip54Highlight {
  /// {@macro nip54_highlight}
  const Nip54Highlight({
    required this.content,
    this.eventId,
    this.address,
    this.relay,
    this.context,
    this.sourceUrl,
    this.authors = const [],
  });

  /// Highlighted text (may be empty for non-text media).
  final String content;

  /// Referenced event id from the `e` tag.
  final String? eventId;

  /// Referenced address from the `a` tag.
  final String? address;

  /// Relay hint from the reference tag.
  final String? relay;

  /// Surrounding text from the `context` tag.
  final String? context;

  /// Non-nostr source URL from the `r` tag.
  final String? sourceUrl;

  /// `p` tag attributions.
  final List<Nip54HighlightAuthor> authors;
}

/// {@template nip54_redirect}
/// A parsed NIP-54 wiki redirect (kind 30819).
/// {@endtemplate}
class Nip54Redirect {
  /// {@macro nip54_redirect}
  const Nip54Redirect({required this.identifier, this.targets = const []});

  /// Normalized `d` tag.
  final String identifier;

  /// `a` tags with the addresses redirected to.
  final List<String> targets;
}

/// {@template nip54}
/// NIP-54 wiki articles plus NIP-84 highlights.
///
/// - Kind 30818 articles: [normalizeIdentifier] implements the `d` tag rules
///   (lowercase, whitespace to `-`, punctuation/symbols removed, repeated and
///   edge hyphens collapsed, non-ASCII letters and numbers preserved).
/// - Kind 818 merge requests and kind 30819 redirects.
/// - Forks: `a`/`e` tags pointing at the source article are parsed into
///   [Nip54Article.forkedFromAddresses] / [Nip54Article.forkedFromEventIds]
///   and built by [NostrNip54.createArticle]. Client-side merge/defer
///   conflict resolution is out of scope.
/// - Kind 9802 highlights (formally NIP-84, grouped here with the long-form
///   content helpers): highlighted text plus `e`/`a` source, `p` attribution,
///   `context`, `i` and `r` tags.
///
/// Gap: Dart core has no Unicode normalization, so NFKC is not applied —
/// decomposed input (`e` + combining accent) is not recomposed. Everything
/// else in the NIP-54 rules is implemented. Djot rendering is out of scope.
///
/// ```dart
/// final nip54 = NostrNip54(signer: signer);
/// final article = await nip54.createArticle(
///   title: 'Wiki Article',
///   content: 'A wiki is ...',
/// );
/// expect(article.tags!.first, ['d', 'wiki-article']);
/// ```
/// {@endtemplate}
class NostrNip54 {
  /// {@macro nip54}
  NostrNip54({required this.signer});

  /// Signer used to publish wiki and highlight events.
  final NostrEventSigner signer;

  /// Kind of a wiki article.
  static const int articleKind = 30818;

  /// Kind of a wiki merge request.
  static const int mergeRequestKind = 818;

  /// Kind of a wiki redirect.
  static const int redirectKind = 30819;

  /// Kind of a highlight (NIP-84).
  static const int highlightKind = 9802;

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _punctuationOrSymbol =
      RegExp(r'(?!-)[\p{P}\p{S}][\p{M}\u200D]*', unicode: true);
  static final RegExp _repeatedHyphens = RegExp(r'-+');
  static final RegExp _edgeHyphens = RegExp(r'^-+|-+$');

  /// Normalizes [name] into a wiki `d` tag per the NIP-54 rules.
  static String normalizeIdentifier(String name) {
    final lowered = name.toLowerCase();
    return lowered
        .replaceAll(_whitespace, '-')
        .replaceAll(_punctuationOrSymbol, '')
        .replaceAll(_repeatedHyphens, '-')
        .replaceAll(_edgeHyphens, '');
  }

  /// Parses a kind 30818 wiki article.
  ///
  /// Throws [FormatException] when [event] has no `d` tag.
  static Nip54Article parseArticle(NostrEvent event) {
    final tags = event.tags ?? const <List<String>>[];
    final identifier = _tagValue(tags, 'd');
    if (identifier == null) {
      throw const FormatException('NIP-54 article is missing its d tag');
    }
    return Nip54Article(
      identifier: identifier,
      content: event.content ?? '',
      title: _tagValue(tags, 'title'),
      summary: _tagValue(tags, 'summary'),
      forkedFromAddresses: [
        for (final tag in tags)
          if (tag.length > 1 && tag[0] == 'a') tag[1],
      ],
      forkedFromEventIds: [
        for (final tag in tags)
          if (tag.length > 1 && tag[0] == 'e') tag[1],
      ],
    );
  }

  /// Parses a kind 30819 wiki redirect.
  static Nip54Redirect parseRedirect(NostrEvent event) {
    final tags = event.tags ?? const <List<String>>[];
    final identifier = _tagValue(tags, 'd');
    if (identifier == null) {
      throw const FormatException('NIP-54 redirect is missing its d tag');
    }
    return Nip54Redirect(
      identifier: identifier,
      targets: [
        for (final tag in tags)
          if (tag.length > 1 && tag[0] == 'a') tag[1],
      ],
    );
  }

  /// Parses a kind 9802 highlight.
  ///
  /// Reads the first `e`/`a`/`r`/`context` tags; a `d` tag is not expected.
  static Nip54Highlight parseHighlight(NostrEvent event) {
    final tags = event.tags ?? const <List<String>>[];
    List<String>? reference;
    for (final tag in tags) {
      if (tag.length > 1 && (tag[0] == 'e' || tag[0] == 'a')) {
        reference = tag;
        break;
      }
    }
    final context = _tagValue(tags, 'context');
    final sourceUrl = _tagValue(tags, 'r');
    return Nip54Highlight(
      content: event.content ?? '',
      eventId: reference?.first == 'e' ? reference![1] : null,
      address: reference?.first == 'a' ? reference![1] : null,
      relay: reference != null && reference.length > 2 ? reference[2] : null,
      context: context,
      sourceUrl: sourceUrl,
      authors: [
        for (final tag in tags)
          if (tag.length > 1 && tag[0] == 'p')
            Nip54HighlightAuthor(
              pubkey: tag[1],
              relay: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
              role: tag.length > 3 && tag[3].isNotEmpty ? tag[3] : null,
            ),
      ],
    );
  }

  /// Builds and signs a kind 30818 wiki article.
  ///
  /// [identifier] defaults to [normalizeIdentifier] of [title].
  Future<NostrEvent> createArticle({
    required String title,
    required String content,
    String? identifier,
    String? summary,
    List<String> forkedFromAddresses = const [],
    List<String> forkedFromEventIds = const [],
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    final normalized = identifier == null || identifier.isEmpty
        ? normalizeIdentifier(title)
        : normalizeIdentifier(identifier);
    if (normalized.isEmpty) {
      throw ArgumentError.value(title, 'title', 'normalizes to an empty d tag');
    }
    return _sign(
      articleKind,
      content,
      [
        ['d', normalized],
        if (title.isNotEmpty) ['title', title],
        if (summary != null && summary.isNotEmpty) ['summary', summary],
        for (final address in forkedFromAddresses) ['a', address],
        for (final eventId in forkedFromEventIds) ['e', eventId],
        ...extraTags,
      ],
      createdAt,
    );
  }

  /// Builds and signs a kind 818 merge request.
  Future<NostrEvent> createMergeRequest({
    required String destinationAddress,
    required String destinationPubkey,
    required String sourceEventId,
    String? baseEventId,
    String? relayUrl,
    String? explanation,
    DateTime? createdAt,
  }) {
    return _sign(
      mergeRequestKind,
      explanation ?? '',
      [
        ['a', destinationAddress, if (relayUrl != null) relayUrl],
        if (baseEventId != null)
          ['e', baseEventId, if (relayUrl != null) relayUrl],
        ['p', destinationPubkey],
        ['e', sourceEventId, if (relayUrl != null) relayUrl, 'source'],
      ],
      createdAt,
    );
  }

  /// Builds and signs a kind 30819 wiki redirect.
  Future<NostrEvent> createRedirect({
    required String identifier,
    required List<String> targetAddresses,
    DateTime? createdAt,
  }) {
    return _sign(
      redirectKind,
      '',
      [
        ['d', normalizeIdentifier(identifier)],
        for (final address in targetAddresses) ['a', address],
      ],
      createdAt,
    );
  }

  /// Builds and signs a kind 9802 highlight.
  ///
  /// [content] is the highlighted text. Reference the source with [eventId]
  /// or [address] (plus optional [relayUrl]), attribute authors with
  /// [authors], and pass [context] when the highlight is a text subset.
  Future<NostrEvent> createHighlight({
    required String content,
    String? eventId,
    String? address,
    String? relayUrl,
    String? context,
    String? sourceUrl,
    String? structuredSource,
    List<Nip54HighlightAuthor> authors = const [],
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      highlightKind,
      content,
      [
        if (eventId != null) ['e', eventId, if (relayUrl != null) relayUrl],
        if (address != null) ['a', address, if (relayUrl != null) relayUrl],
        if (sourceUrl != null) ['r', sourceUrl],
        if (structuredSource != null) ['i', structuredSource],
        if (context != null) ['context', context],
        for (final author in authors)
          [
            'p',
            author.pubkey,
            if (author.relay != null) author.relay!,
            if (author.role != null) author.role!,
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

  static String? _tagValue(List<List<String>> tags, String name) {
    for (final tag in tags) {
      if (tag.length > 1 && tag[0] == name) {
        return tag[1];
      }
    }
    return null;
  }
}
