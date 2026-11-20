import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nip70}
/// NIP-70 protected events (`['-']` tag).
///
/// A protected event may only be published to a relay by its author. Reposts
/// of a protected event must not embed it. Relays enforce this with NIP-42;
/// this helper covers the client side.
/// {@endtemplate}
class NostrNip70 {
  /// {@macro nip70}
  const NostrNip70();

  /// Name/content of the protection tag.
  static const String protectedTag = '-';

  /// Whether [event] carries the `['-']` protection tag.
  static bool isProtected(NostrEvent event) =>
      NostrTags.has(event.tags, protectedTag);

  /// Returns a copy of [event] with exactly one `['-']` tag.
  ///
  /// Every existing protection tag is replaced by a single tag appended at the
  /// end; the order of all other tags is preserved. Adding a tag changes the
  /// canonical serialization, so `id` and `sig` are cleared; sign the result
  /// before publishing.
  static NostrEvent markProtected(NostrEvent event) {
    final tags = [
      for (final tag in event.tags ?? const <List<String>>[])
        if (tag.isEmpty || tag.first != protectedTag) tag,
      const [protectedTag],
    ];

    return NostrEvent(
      id: null,
      kind: event.kind,
      content: event.content,
      sig: null,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      tags: tags,
      subscriptionId: event.subscriptionId,
      ots: event.ots,
    );
  }

  /// Whether [source] may be embedded inside a repost event.
  ///
  /// `false` for protected events: NIP-18 reposts must then reference the
  /// event with an `e` tag only.
  static bool canRepostEmbed(NostrEvent source) => !isProtected(source);
}
