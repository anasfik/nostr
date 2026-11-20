import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nostr_proxy_reference}
/// Parsed NIP-48 `proxy` tag: `['proxy', id, protocol]`.
///
/// [id] is the source object ID and its format depends on [protocol]
/// (48.md:15-18). [protocol] is kept open-ended: NIP-48 lists `activitypub`,
/// `atproto`, `rss` and `web` but says the list may be extended (48.md:26).
/// {@endtemplate}
class NostrProxyReference {
  /// {@macro nostr_proxy_reference}
  const NostrProxyReference({required this.id, required this.protocol});

  /// Source object ID, for example an ActivityPub object URL.
  final String id;

  /// Name of the source protocol, for example `activitypub`.
  final String protocol;

  /// Parses a `proxy` tag, with or without its leading `proxy` name.
  ///
  /// Returns `null` when the tag has no non-empty id or protocol.
  static NostrProxyReference? tryParse(List<String> tag) {
    final start = tag.isNotEmpty && tag.first == NostrNip48.tagName ? 1 : 0;
    final id = NostrTags.at(tag, start);
    final protocol = NostrTags.at(tag, start + 1);

    if (id == null || id.isEmpty || protocol == null || protocol.isEmpty) {
      return null;
    }

    return NostrProxyReference(id: id, protocol: protocol);
  }

  /// This reference as `['proxy', id, protocol]`.
  List<String> toTag() => [NostrNip48.tagName, id, protocol];
}

/// {@template nip48}
/// NIP-48 bridged events (`proxy` tags).
///
/// A `['proxy', id, protocol]` tag marks an event that did not originate on
/// Nostr; it may be added to any event kind (48.md:22). Parsing is tag-level,
/// so [tryParse] accepts events of any kind.
/// {@endtemplate}
class NostrNip48 {
  /// {@macro nip48}
  const NostrNip48();

  /// Tag name used to reference the source object.
  static const String tagName = 'proxy';

  /// ActivityPub source protocol.
  static const String activityPub = 'activitypub';

  /// AT Protocol (Bluesky) source protocol.
  static const String atProto = 'atproto';

  /// RSS feed source protocol.
  static const String rss = 'rss';

  /// Generic web page source protocol.
  static const String web = 'web';

  /// Protocols named by NIP-48; other values are still parsed.
  static const Set<String> supportedProtocols = {
    activityPub,
    atProto,
    rss,
    web,
  };

  /// Builds `['proxy', id, protocol]`.
  ///
  /// Throws [ArgumentError] when [id] or [protocol] is blank.
  static List<String> tag({required String id, required String protocol}) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Proxy id must not be empty');
    }

    if (protocol.trim().isEmpty) {
      throw ArgumentError.value(
        protocol,
        'protocol',
        'Proxy protocol must not be empty',
      );
    }

    return [tagName, id, protocol];
  }

  /// Every valid `proxy` tag on [event], in order.
  static List<NostrProxyReference> parseAll(NostrEvent event) =>
      parseTags(event.tags);

  /// Every valid `proxy` tag in [tags], skipping malformed ones.
  static List<NostrProxyReference> parseTags(List<List<String>>? tags) {
    final references = <NostrProxyReference>[];

    for (final tag in tags ?? const <List<String>>[]) {
      if (tag.isEmpty || tag.first != tagName) {
        continue;
      }

      final reference = NostrProxyReference.tryParse(tag);
      if (reference != null) {
        references.add(reference);
      }
    }

    return references;
  }

  /// First valid `proxy` tag on [event], or `null`.
  static NostrProxyReference? tryParse(NostrEvent event) {
    for (final reference in parseAll(event)) {
      return reference;
    }

    return null;
  }

  /// Like [tryParse], but throws [ArgumentError] when [event] has no valid
  /// `proxy` tag.
  static NostrProxyReference parse(NostrEvent event) {
    final reference = tryParse(event);

    if (reference == null) {
      throw ArgumentError('Invalid NIP-48 proxy tag');
    }

    return reference;
  }

  /// Whether [event] carries at least one valid `proxy` tag.
  static bool isBridged(NostrEvent event) => tryParse(event) != null;

  /// Copy of [event] with a single `proxy` tag, replacing existing ones.
  ///
  /// `id` and `sig` are cleared; sign the result before publishing.
  static NostrEvent withProxy(
    NostrEvent event, {
    required String id,
    required String protocol,
  }) =>
      NostrTags.withTag(event, tag(id: id, protocol: protocol));

  /// Copy of [event] with every `proxy` tag removed.
  ///
  /// `id` and `sig` are cleared; sign the result before publishing.
  static NostrEvent withoutProxy(NostrEvent event) =>
      NostrTags.withoutTag(event, const [tagName]);
}
