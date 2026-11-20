import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_public_message}
/// Parsed NIP-A4 public message (kind 24).
///
/// [receiverTags] keeps the `p` tags whole, including their optional relay
/// hint, so the original addressing survives a round trip. [tags] keeps every
/// other tag verbatim. `e` tags are preserved but carry no meaning: NIP-A4
/// forbids threads (A4.md:29).
/// {@endtemplate}
class NostrPublicMessage {
  /// {@macro nostr_public_message}
  const NostrPublicMessage({
    required this.content,
    this.receiverTags = const <List<String>>[],
    this.tags = const <List<String>>[],
    this.pubkey = '',
  });

  /// Message text.
  final String content;

  /// Every `p` tag, in event order, as `['p', <hex>, <relay>?]`.
  final List<List<String>> receiverTags;

  /// Every non-`p` tag, preserved verbatim.
  final List<List<String>> tags;

  /// Author public key, when parsed from a signed event.
  final String pubkey;

  /// Receiver public keys from the `p` tags, in event order.
  List<String> get receivers => [
        for (final tag in receiverTags) tag[1],
      ];

  /// Whether this message carries an `e` tag, which NIP-A4 forbids
  /// (A4.md:29).
  ///
  /// Inbound events are still parsed and [NostrNipA4.validateMessage] still
  /// accepts them, because the `e` tag does not make the message unusable;
  /// callers that enforce the rule can check this flag.
  bool get hasForbiddenThreadTags =>
      tags.any((tag) => tag.isNotEmpty && tag.first == 'e');

  /// Whether this message carries a NIP-92 `imeta` tag.
  bool get hasImeta => tags.any(NostrNipA4._isImetaTag);
}

/// {@template nipa4}
/// NIP-A4 public messages (kind 24).
///
/// A kind-24 event is a plaintext message to one or more users: the text lives
/// in `content` and one `p` tag per receiver identifies the audience
/// (A4.md:9-22). There are no threads and `e` tags MUST NOT be used
/// (A4.md:29); builders reject them and parsers keep such events without
/// treating the `e` tags as threading.
///
/// [resolveTargetRelays] answers A4.md:24: publish to the NIP-65 inbox relays
/// of every receiver plus the sender's outbox relay. [kindTag] carries the
/// `k` tag that NIP-25 reactions and NIP-57 zaps must add when targeting a
/// kind-24 message (A4.md:44-46).
///
/// [publish] signs through the signer bound to this instance; sending the
/// signed event to those relays is up to the caller.
///
/// Usage:
/// ```dart
/// final message = await nips.nipa4.publish(
///   content: 'GM',
///   receivers: [receiverPubkey],
/// );
/// ```
/// {@endtemplate}
class NostrNipA4 {
  /// {@macro nipa4}
  NostrNipA4({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind 24: public message.
  static const int messageKind = 24;

  /// `k` tag value that reactions and zaps must add (A4.md:44-46).
  static const List<String> kindTag = ['k', '24'];

  /// Builds an unsigned kind-24 message.
  ///
  /// [receivers] must not be empty and every entry must be 64 lowercase hex
  /// characters; [relayHints] optionally maps a receiver to the relay the
  /// receiver is expected on. [extraTags] are appended after the `p` tags and
  /// may carry `expiration` (NIP-40), `q` (NIP-18) or `imeta` (NIP-92) tags.
  ///
  /// [content] may be empty when at least one `imeta` tag is present, so
  /// image/video-only messages are allowed (A4.md:50). Throws
  /// [ArgumentError] when [content] is blank and no `imeta` tag is given, when
  /// [receivers] is empty or malformed, or when [extraTags] contains an `e`
  /// tag (A4.md:29).
  static NostrEvent generateMessageTemplate({
    required String content,
    required List<String> receivers,
    Map<String, String> relayHints = const <String, String>{},
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    final hasImeta = extraTags.any(_isImetaTag);

    if (content.trim().isEmpty && !hasImeta) {
      throw ArgumentError.value(
        content,
        'content',
        'Public message content must not be empty unless the message carries '
            'an imeta tag',
      );
    }

    if (receivers.isEmpty) {
      throw ArgumentError.value(
        receivers,
        'receivers',
        'A public message needs at least one p tag',
      );
    }

    for (final receiver in receivers) {
      if (!NostrValidators.isHex64(receiver)) {
        throw ArgumentError.value(
          receiver,
          'receivers',
          'Expected 64 lowercase hex characters',
        );
      }
    }

    for (final tag in extraTags) {
      if (tag.isNotEmpty && tag.first == 'e') {
        throw ArgumentError.value(
          tag,
          'extraTags',
          'NIP-A4 messages must not carry e tags',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: messageKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final receiver in receivers)
          ['p', receiver, if (relayHints[receiver] case final hint?) hint],
        ...extraTags,
      ],
    );
  }

  /// Builds and signs a kind-24 message through [signer].
  Future<NostrEvent> publish({
    required String content,
    required List<String> receivers,
    Map<String, String> relayHints = const <String, String>{},
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    return signer.sign(
      NostrNipA4.generateMessageTemplate(
        content: content,
        receivers: receivers,
        relayHints: relayHints,
        extraTags: extraTags,
        createdAt: createdAt,
      ),
    );
  }

  /// Validates a kind-24 message: correct kind, at least one `p` tag with a
  /// valid hex public key, and non-blank content unless an `imeta` tag carries
  /// the media (A4.md:50).
  ///
  /// `e` tags are tolerated here rather than invalidating the event; use
  /// [NostrPublicMessage.hasForbiddenThreadTags] to reject them where the
  /// A4.md:29 rule must be enforced.
  static bool validateMessage(NostrEvent event) =>
      tryParseMessage(event) != null;

  /// Parses [event] into [NostrPublicMessage], or returns `null` when it is
  /// not a valid kind-24 message.
  ///
  /// `p` tags with malformed public keys are ignored; at least one valid
  /// receiver is required. Blank content is accepted only with an `imeta`
  /// tag. `e` tags are ignored for threading purposes but kept in
  /// [NostrPublicMessage.tags] so the event is not dropped, and surfaced via
  /// [NostrPublicMessage.hasForbiddenThreadTags] (A4.md:29).
  static NostrPublicMessage? tryParseMessage(NostrEvent event) {
    if (event.kind != messageKind) {
      return null;
    }

    final rawTags = event.tags ?? const <List<String>>[];
    final content = event.content ?? '';
    final hasImeta = rawTags.any(_isImetaTag);

    if (content.trim().isEmpty && !hasImeta) {
      return null;
    }

    final receiverTags = <List<String>>[];
    final tags = <List<String>>[];

    for (final tag in rawTags) {
      if (tag.length > 1 &&
          tag.first == 'p' &&
          NostrValidators.isHex64(tag[1])) {
        receiverTags.add(List<String>.of(tag));
      } else {
        tags.add(List<String>.of(tag));
      }
    }

    if (receiverTags.isEmpty) {
      return null;
    }

    return NostrPublicMessage(
      content: content,
      receiverTags: receiverTags,
      tags: tags,
      pubkey: event.pubkey,
    );
  }

  /// Like [tryParseMessage], but throws [ArgumentError] for invalid events.
  static NostrPublicMessage parseMessage(NostrEvent event) {
    final message = tryParseMessage(event);

    if (message == null) {
      throw ArgumentError('Invalid NIP-A4 public message event');
    }

    return message;
  }

  /// Whether [event] is a reaction or zap request targeting a kind-24
  /// message, as required by A4.md:44-46.
  static bool targetsMessage(NostrEvent event) =>
      NostrTags.first(event.tags, 'k') == '$messageKind';

  static bool _isImetaTag(List<String> tag) =>
      tag.isNotEmpty && tag.first == 'imeta';

  /// Publishing relays for a kind-24 message (A4.md:24).
  ///
  /// [relayLists] holds NIP-65 kind-10002 events. Their `r` tags with no
  /// marker or a `read` marker are inbox relays; no marker or `write` is an
  /// outbox relay. The result is the inbox relays of every entry in
  /// [receiverPubkeys] followed by the outbox relays of [senderPubkey],
  /// deduplicated in first-seen order. Invalid relay URLs and relay lists not
  /// authored by the matching pubkey are ignored.
  static List<String> resolveTargetRelays({
    required Iterable<NostrEvent> relayLists,
    required Iterable<String> receiverPubkeys,
    String? senderPubkey,
  }) {
    final listsByPubkey = <String, NostrEvent>{
      for (final list in relayLists)
        if (list.kind == 10002) list.pubkey: list,
    };

    final relays = <String>[];
    final seen = <String>{};

    void addFrom(NostrEvent? list, String marker) {
      for (final tag in list?.tags ?? const <List<String>>[]) {
        if (tag.length < 2 || tag.first != 'r') {
          continue;
        }

        final mode = tag.length > 2 ? tag[2] : '';
        if (mode.isNotEmpty && mode != marker) {
          continue;
        }

        final relay = tag[1];
        if (NostrValidators.isRelayUrl(relay) && seen.add(relay)) {
          relays.add(relay);
        }
      }
    }

    for (final receiver in receiverPubkeys) {
      addFrom(listsByPubkey[receiver], 'read');
    }

    if (senderPubkey != null) {
      addFrom(listsByPubkey[senderPubkey], 'write');
    }

    return relays;
  }
}
