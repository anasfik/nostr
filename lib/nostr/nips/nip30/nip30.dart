import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip30_emoji}
/// A custom emoji parsed from an `emoji` tag (NIP-30).
/// {@endtemplate}
class Nip30Emoji {
  /// {@macro nip30_emoji}
  const Nip30Emoji({
    required this.name,
    required this.url,
    this.setAddress,
  });

  /// Shortcode without colons (e.g. `blobcat`).
  final String name;

  /// Shortcode with colons (e.g. `:blobcat:`).
  String get shortcode => ':$name:';

  /// Image URL for the emoji.
  final String url;

  /// Optional `kind:pubkey:d-tag` pointer to the NIP-51 emoji set.
  final String? setAddress;
}

/// {@template nip30_emoji_match}
/// A `:shortcode:` occurrence found in text content.
/// {@endtemplate}
class Nip30EmojiMatch {
  /// {@macro nip30_emoji_match}
  const Nip30EmojiMatch({
    required this.name,
    required this.start,
    required this.end,
  });

  /// Shortcode without colons.
  final String name;

  /// Shortcode with colons.
  String get shortcode => ':$name:';

  /// Start offset of the match in the content (inclusive).
  final int start;

  /// End offset of the match in the content (exclusive).
  final int end;
}

/// {@template nip30}
/// NIP-30 custom emoji.
///
/// - `emoji` tags of the form `["emoji", shortcode, url, setAddress?]` are
///   parsed from any event (`kind 0/1/7/1111/30315`).
/// - `:shortcode:` occurrences in content are matched and replaced following
///   the `\B:([\w-]+):\B` rule used by `nostr-tools`.
/// - Kind 30030 emoji sets (NIP-51 addressable list) are built and parsed.
///
/// Matching and parsing are static: read-only usage needs no signer. Only
/// [createEmojiSet] signs and therefore needs one.
///
/// Usage:
/// ```dart
/// final emojis = NostrNip30.parseEmojiTags(event);
/// final html = NostrNip30.replaceAll(content, (m) => '<img src="..."/>');
/// final set = await NostrNip30.createEmojiSet(
///   signer: signer,
///   identifier: 'blobcats',
///   emojis: emojis,
/// );
/// ```
/// {@endtemplate}
class NostrNip30 {
  /// {@macro nip30}
  const NostrNip30();

  /// Kind of a NIP-51 emoji set event.
  static const int emojiSetKind = 30030;

  /// Matches a single `:shortcode:` surrounded by non-word-boundaries.
  static final RegExp shortcodeRegex = RegExp(r'\B:([\w-]+):\B');

  /// Parses every `emoji` tag of [event].
  static List<Nip30Emoji> parseEmojiTags(NostrEvent event) {
    final emojis = <Nip30Emoji>[];
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length < 3 || tag[0] != 'emoji') {
        continue;
      }
      final name = tag[1];
      if (name.isEmpty) {
        continue;
      }
      emojis.add(
        Nip30Emoji(
          name: name,
          url: tag[2],
          setAddress: tag.length > 3 && tag[3].isNotEmpty ? tag[3] : null,
        ),
      );
    }
    return emojis;
  }

  /// Parses a kind 30030 emoji set event.
  ///
  /// Returns an empty list when [event] is not an emoji set.
  static List<Nip30Emoji> parseEmojiSet(NostrEvent event) {
    if (event.kind != emojiSetKind) {
      return const [];
    }
    return parseEmojiTags(event);
  }

  /// Finds every `:shortcode:` occurrence in [content].
  static List<Nip30EmojiMatch> matchAll(String content) {
    return [
      for (final match in shortcodeRegex.allMatches(content))
        Nip30EmojiMatch(
          name: match.group(1)!,
          start: match.start,
          end: match.end,
        ),
    ];
  }

  /// Replaces every `:shortcode:` occurrence with [replacer]'s output.
  static String replaceAll(
    String content,
    String Function(Nip30EmojiMatch match) replacer,
  ) {
    return content.replaceAllMapped(shortcodeRegex, (match) {
      return replacer(
        Nip30EmojiMatch(
          name: match.group(1)!,
          start: match.start,
          end: match.end,
        ),
      );
    });
  }

  /// Builds the `emoji` tag for [emoji].
  static List<String> emojiTag(Nip30Emoji emoji) {
    return [
      'emoji',
      emoji.name,
      emoji.url,
      if (emoji.setAddress != null) emoji.setAddress!,
    ];
  }

  /// Builds and signs a kind 30030 emoji set.
  ///
  /// [identifier] is the `d` tag (the set name). [title] and [description]
  /// are optional NIP-51 metadata tags.
  static Future<NostrEvent> createEmojiSet({
    required NostrEventSigner signer,
    required String identifier,
    required List<Nip30Emoji> emojis,
    String? title,
    String? description,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: emojiSetKind,
        content: '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['d', identifier],
          if (title != null && title.isNotEmpty) ['title', title],
          if (description != null && description.isNotEmpty)
            ['description', description],
          for (final emoji in emojis) emojiTag(emoji),
          ...extraTags,
        ],
      ),
    );
  }
}
