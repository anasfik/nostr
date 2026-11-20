import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nostr_thread}
/// Parsed NIP-7D forum thread (kind 11).
///
/// [title] comes from the `title` tag, not from [content]: NIP-7D says threads
/// SHOULD include a title, and its example carries the body in `content`
/// ("Good morning") and the title in `["title", "GM"]`.
/// {@endtemplate}
class NostrThread {
  /// {@macro nostr_thread}
  const NostrThread({
    required this.title,
    required this.content,
    required this.tags,
    this.pubkey = '',
  });

  /// Thread title (`title` tag value).
  final String title;

  /// Thread body, as stored in `content`.
  final String content;

  /// Remaining event tags, with the `title` tag removed.
  final List<List<String>> tags;

  /// Author public key, when parsed from a signed event.
  final String pubkey;
}

/// {@template nip7d}
/// NIP-7D forum threads (kind 11).
///
/// A thread is a kind-11 event whose title lives in a `title` tag. Replies are
/// NIP-22 kind-1111 comments rooted at the thread:
/// `["K", "11"]` plus `["E", <thread-id>, <relay>, <pubkey>]`.
///
/// This class only builds and parses the thread itself. Comment creation lives
/// in `NostrSocialBuilder.createComment` (NIP-22, `social/`), which already
/// emits `K`/`E`/`P` root tags alongside `k`/`e`/`p`; pass
/// `targetKind: NostrNip7d.threadKind` to root a reply at a thread. Replies
/// should always target the root kind-11 thread, never another comment.
///
/// Templates carry no `pubkey`/`id`/`sig`; sign them before publishing.
///
/// Usage:
/// ```dart
/// final thread = await signer.sign(
///   NostrNip7d.generateThreadTemplate(title: 'GM', content: 'Good morning'),
/// );
/// ```
/// {@endtemplate}
class NostrNip7d {
  /// {@macro nip7d}
  const NostrNip7d();

  /// Kind 11: forum thread.
  static const int threadKind = 11;

  /// Kind 1111: NIP-22 comment used for thread replies.
  static const int commentKind = 1111;

  /// Builds an unsigned kind-11 thread.
  ///
  /// [title] is required and must not be blank; it becomes `["title", title]`.
  /// [content] is the optional thread body. [extraTags] are appended after the
  /// title tag, except for any `title` tag they carry, which is ignored so the
  /// event has exactly one title. When parsing, the first `title` tag wins.
  ///
  /// Throws [ArgumentError] when [title] is blank.
  static NostrEvent generateThreadTemplate({
    required String title,
    String content = '',
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Thread title must not be empty',
      );
    }

    return NostrEvent(
      id: null,
      kind: threadKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['title', title],
        for (final tag in extraTags)
          if (tag.isEmpty || tag.first != 'title') tag,
      ],
    );
  }

  /// Validates a kind-11 thread: correct kind and a non-blank title tag.
  static bool validateThread(NostrEvent event) => tryParseThread(event) != null;

  /// Parses [event] into [NostrThread], or returns `null` when it is not a
  /// valid kind-11 thread with a non-blank `title` tag.
  ///
  /// When the event has several `title` tags, the first one wins and all of
  /// them are omitted from [NostrThread.tags].
  static NostrThread? tryParseThread(NostrEvent event) {
    if (event.kind != threadKind) {
      return null;
    }

    final title = NostrTags.first(event.tags, 'title');
    if (title == null || title.trim().isEmpty) {
      return null;
    }

    return NostrThread(
      title: title,
      content: event.content ?? '',
      pubkey: event.pubkey,
      tags: [
        for (final tag in event.tags ?? const <List<String>>[])
          if (tag.isEmpty || tag.first != 'title') List<String>.of(tag),
      ],
    );
  }

  /// Like [tryParseThread], but throws [ArgumentError] for invalid events.
  static NostrThread parseThread(NostrEvent event) {
    final thread = tryParseThread(event);

    if (thread == null) {
      throw ArgumentError('Invalid NIP-7D thread event');
    }

    return thread;
  }

  /// Title of [event], or `null` when it carries no title tag.
  static String? titleOf(NostrEvent event) =>
      NostrTags.first(event.tags, 'title');
}
