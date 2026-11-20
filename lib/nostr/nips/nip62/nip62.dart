import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_request_to_vanish}
/// Parsed NIP-62 request to vanish (kind 62).
///
/// [relays] keeps every `relay` tag value in event order. [isGlobal] is true
/// when the event tags `ALL_RELAYS` (62.md:47), asking every relay to delete
/// the author's events. [content] is the optional reason or legal notice
/// (62.md:29).
/// {@endtemplate}
class NostrRequestToVanish {
  /// {@macro nostr_request_to_vanish}
  const NostrRequestToVanish({
    required this.relays,
    this.content = '',
    this.pubkey = '',
  });

  /// `relay` tag values, in event order.
  final List<String> relays;

  /// Reason or legal notice, empty when omitted.
  final String content;

  /// Author public key, when parsed from a signed event.
  final String pubkey;

  /// Whether this request targets every relay (`ALL_RELAYS`).
  bool get isGlobal => relays.contains(NostrNip62.allRelays);
}

/// {@template nip62}
/// NIP-62 request to vanish (kind 62).
///
/// A kind-62 event asks relays to delete every event from the author's pubkey,
/// including NIP-09 deletion events (62.md:13). The tag list MUST include at
/// least one `relay` value (62.md:27); `ALL_RELAYS` in uppercase targets every
/// relay (62.md:47).
///
/// [publish] signs through the signer bound to this instance. Clients SHOULD
/// send the event to the tagged relays only, or to as many relays as possible
/// for a global request (62.md:43, 61); that transport step is up to the
/// caller.
/// {@endtemplate}
class NostrNip62 {
  /// {@macro nip62}
  NostrNip62({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind 62: request to vanish.
  static const int vanishKind = 62;

  /// `relay` tag value that targets every relay (62.md:47).
  static const String allRelays = 'ALL_RELAYS';

  /// Builds an unsigned kind-62 request.
  ///
  /// [relays] must not be empty and no entry may be blank; each becomes
  /// `['relay', url]` (62.md:19-20, 53-54). Pass [allRelays] for a global
  /// request. [content] is the optional reason or legal notice.
  ///
  /// Throws [ArgumentError] when [relays] is empty or an entry is blank.
  static NostrEvent generateVanishTemplate({
    required List<String> relays,
    String content = '',
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    if (relays.isEmpty) {
      throw ArgumentError.value(
        relays,
        'relays',
        'A request to vanish must tag at least one relay',
      );
    }

    for (final relay in relays) {
      if (relay.trim().isEmpty) {
        throw ArgumentError.value(relay, 'relays', 'Relay must not be empty');
      }
    }

    return NostrEvent(
      id: null,
      kind: vanishKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final relay in relays) ['relay', relay],
        for (final tag in extraTags)
          if (tag.isEmpty || tag.first != 'relay') tag,
      ],
    );
  }

  /// Builds and signs a kind-62 request through [signer].
  Future<NostrEvent> publish({
    required List<String> relays,
    String content = '',
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateVanishTemplate(
        relays: relays,
        content: content,
        extraTags: extraTags,
        createdAt: createdAt,
      ),
    );
  }

  /// Parses [event] into [NostrRequestToVanish], or returns `null` when it is
  /// not a kind-62 event with at least one non-empty `relay` tag.
  static NostrRequestToVanish? tryParse(NostrEvent event) {
    if (event.kind != vanishKind) {
      return null;
    }

    final relays = [
      for (final relay in NostrTags.all(event.tags, 'relay'))
        if (relay.isNotEmpty) relay,
    ];

    if (relays.isEmpty) {
      return null;
    }

    return NostrRequestToVanish(
      relays: relays,
      content: event.content ?? '',
      pubkey: event.pubkey,
    );
  }

  /// Like [tryParse], but throws [ArgumentError] for invalid events.
  static NostrRequestToVanish parse(NostrEvent event) {
    final request = tryParse(event);

    if (request == null) {
      throw ArgumentError('Invalid NIP-62 request to vanish event');
    }

    return request;
  }
}
