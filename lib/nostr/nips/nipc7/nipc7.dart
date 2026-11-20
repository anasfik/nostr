import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';

/// {@template nostr_chat_message}
/// Parsed NIP-C7 chat message (kind 9).
///
/// [replyTo] is the id from the first `q` tag when the message quotes a parent
/// chat, together with the optional [relayHint] and quoted author [pubkey]
/// slots.
/// {@endtemplate}
class NostrChatMessage {
  /// {@macro nostr_chat_message}
  const NostrChatMessage({
    required this.content,
    required this.tags,
    this.replyTo,
    this.relayHint = '',
    this.pubkey = '',
  });

  /// Message text.
  final String content;

  /// Event id of the quoted parent chat, if any.
  final String? replyTo;

  /// Relay hint from the `q` tag (empty when omitted).
  final String relayHint;

  /// Quoted author public key from the `q` tag (empty when omitted).
  final String pubkey;

  /// Every other event tag, preserved verbatim. The first `q` tag is decoded
  /// into [replyTo], [relayHint] and [pubkey] and is therefore left out;
  /// additional `q` tags stay here unchanged.
  final List<List<String>> tags;

  /// Whether this message quotes a parent chat.
  bool get isReply => replyTo != null;
}

/// {@template nipc7}
/// NIP-C7 chat messages (kind 9).
///
/// A chat message is a kind-9 event with the text in `content`. A reply is
/// another kind-9 event quoting the parent with a `q` tag carrying four slots:
/// `["q", <event-id>, <relay-url>, <pubkey>]`. Chat clients rendering a stream
/// should subscribe to kind 9 only, so no other kinds are required to rebuild
/// context.
///
/// Templates carry no `pubkey`/`id`/`sig`; sign them before publishing.
///
/// Usage:
/// ```dart
/// final message = await signer.sign(
///   NostrNipC7.generateChatMessage(content: 'GM'),
/// );
/// final reply = await signer.sign(
///   NostrNipC7.generateChatMessage(content: 'yes', replyTo: message.id),
/// );
/// ```
/// {@endtemplate}
class NostrNipC7 {
  /// {@macro nipc7}
  const NostrNipC7();

  /// Kind 9: chat message.
  static const int chatKind = 9;

  /// Builds an unsigned kind-9 chat message.
  ///
  /// [content] must not be blank. When [replyTo] is set the event carries
  /// exactly one four-slot `q` tag: `['q', replyTo, relayHint, pubkey]`, with
  /// empty strings when the hint or quoted author is unknown. [extraTags] are
  /// appended after the `q` tag.
  ///
  /// Throws [ArgumentError] when [content] is blank or [replyTo] is set to a
  /// blank id.
  static NostrEvent generateChatMessage({
    required String content,
    String? replyTo,
    String relayHint = '',
    String pubkey = '',
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    if (content.trim().isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Chat content must not be empty',
      );
    }

    if (replyTo != null && replyTo.trim().isEmpty) {
      throw ArgumentError.value(
        replyTo,
        'replyTo',
        'Reply parent id must not be empty',
      );
    }

    return NostrEvent(
      id: null,
      kind: chatKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (replyTo != null) ['q', replyTo, relayHint, pubkey],
        ...extraTags,
      ],
    );
  }

  /// Kind-9 only filter, as NIP-C7 requires for chat views.
  ///
  /// [subjects] fills the `#q` key (parent chat event ids); other optional
  /// criteria narrow the stream further.
  static NostrFilter chatFilter({
    List<String>? subjects,
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    return NostrFilter(
      kinds: const [chatKind],
      authors: authors,
      since: since,
      until: until,
      limit: limit,
      additionalFilters:
          subjects == null || subjects.isEmpty ? null : {'#q': subjects},
    );
  }

  /// Validates a kind-9 chat message: correct kind, non-blank content and a
  /// non-empty event id on the first `q` tag.
  static bool validateChat(NostrEvent event) => tryParseChat(event) != null;

  /// Parses [event] into [NostrChatMessage], or returns `null` when it is not
  /// a valid kind-9 chat message.
  ///
  /// The first `q` tag wins; its id must be non-empty. [NostrChatMessage.tags]
  /// keeps every other tag verbatim, including any further `q` tags.
  static NostrChatMessage? tryParseChat(NostrEvent event) {
    if (event.kind != chatKind) {
      return null;
    }

    final content = event.content ?? '';
    if (content.trim().isEmpty) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final qIndex = tags.indexWhere((tag) => tag.isNotEmpty && tag.first == 'q');
    final qTag = qIndex < 0 ? null : tags[qIndex];
    if (qTag != null && (qTag.length < 2 || qTag[1].isEmpty)) {
      return null;
    }

    return NostrChatMessage(
      content: content,
      replyTo: qTag?[1],
      relayHint: qTag != null && qTag.length > 2 ? qTag[2] : '',
      pubkey: qTag != null && qTag.length > 3 ? qTag[3] : '',
      tags: [
        for (var i = 0; i < tags.length; i++)
          if (i != qIndex) List<String>.of(tags[i]),
      ],
    );
  }

  /// Like [tryParseChat], but throws [ArgumentError] for invalid events.
  static NostrChatMessage parseChat(NostrEvent event) {
    final chat = tryParseChat(event);

    if (chat == null) {
      throw ArgumentError('Invalid NIP-C7 chat event');
    }

    return chat;
  }
}
