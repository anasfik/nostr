import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nip36}
/// NIP-36 sensitive content / content warnings.
///
/// A `content-warning` tag asks clients to hide the event until the reader
/// accepts it. The reason is optional (`36.md:17-21`); a bare tag and a tag
/// with an empty reason mean different things, and [contentWarningReason]
/// preserves that difference.
/// {@endtemplate}
class NostrNip36 {
  /// {@macro nip36}
  const NostrNip36();

  /// Tag name used for content warnings.
  static const String tagName = 'content-warning';

  /// Whether [event] carries a `content-warning` tag, with or without a reason.
  static bool hasContentWarning(NostrEvent event) =>
      NostrTags.has(event.tags, tagName);

  /// Warning reason, or `null` when there is no tag or the tag is bare.
  ///
  /// Returns `''` when the reason is explicitly empty, as in
  /// `['content-warning', '']`.
  static String? contentWarningReason(NostrEvent event) {
    final warningTag = NostrTags.tag(event.tags, tagName);

    if (warningTag == null) {
      return null;
    }

    return NostrTags.at(warningTag, 1);
  }

  /// `['content-warning']`, or `['content-warning', reason]` when given.
  static List<String> tag({String? reason}) => [
        tagName,
        if (reason != null) reason,
      ];

  /// Copy of [event] with a single `content-warning` tag carrying [reason].
  ///
  /// Replaces existing `content-warning` tags and always clears `id` and
  /// `sig`; sign the result before publishing.
  static NostrEvent withContentWarning(NostrEvent event, {String? reason}) =>
      NostrTags.withTag(event, tag(reason: reason));

  /// Copy of [event] with every `content-warning` tag removed.
  ///
  /// `id` and `sig` are cleared; sign the result before publishing.
  static NostrEvent withoutContentWarning(NostrEvent event) =>
      NostrTags.withoutTag(event, const [tagName]);
}
