import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nostr_torrent_file}
/// Parsed NIP-35 `file` tag: `['file', name, size]`.
///
/// [size] stays a string because the tag carries "file-size-in-bytes" verbatim
/// (35.md:15, 47) and NIP-35's own example uses a placeholder there. Use
/// `int.tryParse(file.size)` when the value has to be numeric.
/// {@endtemplate}
class NostrTorrentFile {
  /// {@macro nostr_torrent_file}
  const NostrTorrentFile({required this.name, required this.size});

  /// Relative path inside the torrent, for example `info/example.txt`.
  final String name;

  /// File size in bytes, as written in the tag.
  final String size;

  /// Parses a `file` tag, or returns `null` when the name or size is missing.
  static NostrTorrentFile? tryParse(List<String> tag) {
    final name = NostrTags.at(tag, 1);
    final size = NostrTags.at(tag, 2);

    if (name == null || name.isEmpty || size == null || size.isEmpty) {
      return null;
    }

    return NostrTorrentFile(name: name, size: size);
  }

  /// This file as `['file', name, size]`.
  List<String> toTag() => ['file', name, size];
}

/// {@template nostr_torrent}
/// Parsed NIP-35 torrent index (kind 2003).
///
/// [infoHash] is the `x` tag, the BitTorrent V1 info hash used to build the
/// magnet link (35.md:14). [references] keeps every `i` tag value verbatim,
/// including the `tcat`/`newznab`/`tmdb`/`ttvdb`/`imdb`/`mal`/`anilist`
/// prefixes (35.md:20-36) and the optional second level. [categories] keeps
/// the `t` tags used for general search (`movie`, `tv`, `HD`, `UHD`, ...).
/// {@endtemplate}
class NostrTorrent {
  /// {@macro nostr_torrent}
  const NostrTorrent({
    required this.infoHash,
    this.title = '',
    this.content = '',
    this.files = const [],
    this.trackers = const [],
    this.references = const [],
    this.categories = const [],
    this.pubkey = '',
  });

  /// `x` tag: BitTorrent V1 info hash.
  final String infoHash;

  /// `title` tag value, empty when absent.
  final String title;

  /// Long pre-formatted description (`content`).
  final String content;

  /// `file` tags, in event order.
  final List<NostrTorrentFile> files;

  /// `tracker` tag values, in event order.
  final List<String> trackers;

  /// `i` tag values (`tcat:...`, `imdb:...`, ...), in event order.
  final List<String> references;

  /// `t` tag values, in event order.
  final List<String> categories;

  /// Author public key, when parsed from a signed event.
  final String pubkey;
}

/// {@template nip35}
/// NIP-35 torrents (kind 2003) and torrent comments (kind 2004).
///
/// Kind 2003 is a searchable torrent index: the `x` tag carries the V1 info
/// hash, `file` tags carry the file list, `tracker` tags are optional and the
/// `i`/`t` tags label the content for discovery. A torrent comment is a
/// kind-2004 event that replies like a kind-1 note and follows NIP-10, so the
/// reply tags are built by `NostrSocialBuilder`.
///
/// Templates carry no `pubkey`/`id`/`sig`; sign them before publishing.
///
/// Usage:
/// ```dart
/// final event = await signer.sign(
///   NostrNip35.generateTorrentTemplate(
///     infoHash: 'b' * 40,
///     title: 'Dune: Part Two',
///   ),
/// );
/// ```
/// {@endtemplate}
class NostrNip35 {
  /// {@macro nip35}
  const NostrNip35();

  /// Kind 2003: torrent index.
  static const int torrentKind = 2003;

  /// Kind 2004: torrent comment, a NIP-10 reply to a kind-2003 event.
  static const int commentKind = 2004;

  /// Builds an unsigned kind-2003 torrent index.
  ///
  /// [infoHash] is required and becomes `['x', infoHash]` (35.md:14, 46).
  /// Every [files] entry becomes `['file', name, size]` (35.md:47-48),
  /// [trackers] become `['tracker', url]` (35.md:16, 49-50), [references]
  /// become `['i', value]` (35.md:51-55) and [categories] become `['t', value]`
  /// (35.md:56-57).
  ///
  /// Throws [ArgumentError] when [infoHash] is blank, a file name or size is
  /// blank, or a tracker/reference/category is blank.
  static NostrEvent generateTorrentTemplate({
    required String infoHash,
    String title = '',
    String content = '',
    List<NostrTorrentFile> files = const [],
    List<String> trackers = const [],
    List<String> references = const [],
    List<String> categories = const [],
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    if (infoHash.trim().isEmpty) {
      throw ArgumentError.value(
        infoHash,
        'infoHash',
        'Torrent info hash must not be empty',
      );
    }

    for (final file in files) {
      if (file.name.trim().isEmpty) {
        throw ArgumentError.value(
          file.name,
          'files',
          'File name must not be empty',
        );
      }

      if (file.size.trim().isEmpty) {
        throw ArgumentError.value(
          file.size,
          'files',
          'File size must not be empty',
        );
      }
    }

    for (final tracker in trackers) {
      if (tracker.trim().isEmpty) {
        throw ArgumentError.value(
          tracker,
          'trackers',
          'Tracker must not be empty',
        );
      }
    }

    for (final reference in references) {
      if (reference.trim().isEmpty) {
        throw ArgumentError.value(
          reference,
          'references',
          'Reference must not be empty',
        );
      }
    }

    for (final category in categories) {
      if (category.trim().isEmpty) {
        throw ArgumentError.value(
          category,
          'categories',
          'Category must not be empty',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: torrentKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (title.isNotEmpty) ['title', title],
        ['x', infoHash],
        for (final file in files) file.toTag(),
        for (final tracker in trackers) ['tracker', tracker],
        for (final reference in references) ['i', reference],
        for (final category in categories) ['t', category],
        for (final tag in extraTags)
          if (tag.isEmpty || !_generatedTagNames.contains(tag.first)) tag,
      ],
    );
  }

  /// Tag names this builder emits; [generateTorrentTemplate] drops them from
  /// `extraTags` so the event keeps exactly one of each.
  static const Set<String> _generatedTagNames = {
    'title',
    'x',
    'file',
    'tracker',
    'i',
    't',
  };

  /// Whether [event] is a kind-2003 torrent index.
  static bool isTorrent(NostrEvent event) => event.kind == torrentKind;

  /// Whether [event] is a kind-2004 torrent comment.
  static bool isComment(NostrEvent event) => event.kind == commentKind;

  /// Parses [event] into [NostrTorrent], or returns `null` when it is not a
  /// kind-2003 event with a non-empty `x` tag.
  ///
  /// Malformed `file` tags (missing name or size) are skipped, matching the
  /// lenient parsers used by other NIPs.
  static NostrTorrent? tryParse(NostrEvent event) {
    if (event.kind != torrentKind) {
      return null;
    }

    final infoHash = NostrTags.first(event.tags, 'x');
    if (infoHash == null || infoHash.isEmpty) {
      return null;
    }

    final files = <NostrTorrentFile>[];
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isEmpty || tag.first != 'file') {
        continue;
      }

      final file = NostrTorrentFile.tryParse(tag);
      if (file != null) {
        files.add(file);
      }
    }

    return NostrTorrent(
      infoHash: infoHash,
      title: NostrTags.first(event.tags, 'title') ?? '',
      content: event.content ?? '',
      files: files,
      trackers: NostrTags.all(event.tags, 'tracker'),
      references: NostrTags.all(event.tags, 'i'),
      categories: NostrTags.all(event.tags, 't'),
      pubkey: event.pubkey,
    );
  }

  /// Like [tryParse], but throws [ArgumentError] for invalid events.
  static NostrTorrent parse(NostrEvent event) {
    final torrent = tryParse(event);

    if (torrent == null) {
      throw ArgumentError('Invalid NIP-35 torrent event');
    }

    return torrent;
  }
}
