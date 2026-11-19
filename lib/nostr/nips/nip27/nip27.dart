import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';

/// Kind of a [Nip27Block] produced by [NostrNip27.parse].
enum Nip27BlockType {
  /// Plain text between other blocks.
  text,

  /// A `nostr:` URI referencing a profile, event or address.
  reference,

  /// A regular `http(s)` link.
  url,

  /// A `ws(s)` relay URL.
  relay,

  /// An image link (`png`, `jpg`, `gif`, `webp`, `heic`, `svg`).
  image,

  /// A video link (`mp4`, `avi`, `webm`, `mkv`, `mov`).
  video,

  /// An audio link (`mp3`, `aac`, `ogg`, `opus`, `wav`, `flac`).
  audio,

  /// A `:shortcode:` backed by an `emoji` tag on the event.
  emoji,

  /// A `#hashtag`.
  hashtag,
}

/// Type of entity behind a [Nip27Pointer].
enum Nip27PointerType {
  /// `npub` / `nprofile`.
  profile,

  /// `note` / `nevent`.
  event,

  /// `naddr` (parameterized replaceable event).
  address,
}

/// {@template nip27_pointer}
/// Decoded target of a `nostr:` URI, mirroring the pointers produced by
/// `nostr-tools`' `nip27.parse()`.
/// {@endtemplate}
class Nip27Pointer {
  /// A profile pointer (`npub` or `nprofile`).
  const Nip27Pointer.profile({
    required this.pubkey,
    this.relays = const [],
  })  : type = Nip27PointerType.profile,
        id = null,
        author = null,
        kind = null,
        identifier = null;

  /// An event pointer (`note` or `nevent`).
  const Nip27Pointer.event({
    required this.id,
    this.author,
    this.kind,
    this.relays = const [],
  })  : type = Nip27PointerType.event,
        pubkey = null,
        identifier = null;

  /// An address pointer (`naddr`).
  const Nip27Pointer.address({
    required this.pubkey,
    required this.kind,
    required this.identifier,
    this.relays = const [],
  })  : type = Nip27PointerType.address,
        id = null,
        author = null;

  /// Entity type.
  final Nip27PointerType type;

  /// Author/reference pubkey (profile or address pointers).
  final String? pubkey;

  /// Referenced event id (event pointers).
  final String? id;

  /// Author pubkey carried by an `nevent` (event pointers).
  final String? author;

  /// Event kind (address pointers, optional on `nevent`).
  final int? kind;

  /// `d` tag identifier (address pointers).
  final String? identifier;

  /// Relays advertised inside the bech32 entity.
  final List<String> relays;
}

/// {@template nip27_block}
/// One parsed chunk of a text note. [start] and [end] are UTF-16 code unit
/// offsets into the original content, matching JavaScript string indices.
/// {@endtemplate}
class Nip27Block {
  const Nip27Block._(
    this.type,
    this.start,
    this.end, {
    this.text,
    this.pointer,
    this.url,
    this.value,
    this.shortcode,
  });

  /// Block type.
  final Nip27BlockType type;

  /// Inclusive start offset.
  final int start;

  /// Exclusive end offset.
  final int end;

  /// Text content for [Nip27BlockType.text].
  final String? text;

  /// Target for [Nip27BlockType.reference].
  final Nip27Pointer? pointer;

  /// URL for url/relay/image/video/audio blocks.
  final String? url;

  /// Hashtag value (without the leading `#`).
  final String? value;

  /// Emoji shortcode (without the surrounding colons).
  final String? shortcode;

  @override
  String toString() => 'Nip27Block(${type.name}, $start..$end, '
      '${text ?? value ?? shortcode ?? url ?? pointer?.id ?? pointer?.pubkey})';
}

/// {@template nip27}
/// NIP-27 text note references.
///
/// Parses note content into ordered text/reference/url/relay/image/video/
/// audio/emoji/hashtag blocks, byte-for-byte compatible with
/// `nostr-tools`' `nip27.parse()` (pinned reference `d2f8be4`).
///
/// `nostr:` URIs are decoded through [NostrBech32]; `nsec` URIs are ignored
/// so a private key pasted into a note is never surfaced as a reference.
///
/// Usage:
/// ```dart
/// final nips = Nostr.instance.nips;
/// final blocks = nips.nip27.parse('gm nostr:npub1...');
/// final mentions = nips.nip27.mentions('gm nostr:npub1...');
/// ```
/// {@endtemplate}
class NostrNip27 {
  /// {@macro nip27}
  const NostrNip27({NostrBech32? bech32}) : _bech32 = bech32;

  final NostrBech32? _bech32;

  NostrBech32 get _codec => _bech32 ?? NostrBech32();

  static const int _maxHashtagLength = 42;

  static final RegExp _noCharacter = RegExp(r'\W');
  static final RegExp _whitespace = RegExp(r'\s');
  static final RegExp _trailingPunctuation = RegExp(r'[.,]*[^\w/]?[.,]*$');
  static final RegExp _wsBoundary = RegExp(r'(?:^|\W)ws$');
  static final RegExp _imagePath = RegExp(
    r'\.(png|jpe?g|gif|webp|heic|svg)$',
    caseSensitive: false,
  );
  static final RegExp _videoPath = RegExp(
    r'\.(mp4|avi|webm|mkv|mov)$',
    caseSensitive: false,
  );
  static final RegExp _audioPath = RegExp(
    r'\.(mp3|aac|ogg|opus|wav|flac)$',
    caseSensitive: false,
  );

  /// Parses [content] into ordered blocks.
  List<Nip27Block> parse(String content) => _parse(content, const []);

  /// Parses a whole [event], using its `emoji` tags to resolve `:shortcode:`
  /// sequences.
  List<Nip27Block> parseEvent(NostrEvent event) {
    final emojis = <(String, String)>[];
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length >= 3 && tag[0] == 'emoji') {
        emojis.add((tag[1], tag[2]));
      }
    }
    return _parse(event.content ?? '', emojis);
  }

  /// Returns only the `nostr:` references found in [content].
  List<Nip27Pointer> mentions(String content) => [
        for (final block in parse(content))
          if (block.type == Nip27BlockType.reference && block.pointer != null)
            block.pointer!,
      ];

  List<Nip27Block> _parse(String content, List<(String, String)> emojis) {
    final blocks = <Nip27Block>[];
    final max = content.length;
    var prevIndex = 0;
    var index = 0;

    mainloop:
    while (index < max) {
      final u = content.indexOf(':', index);
      final h = content.indexOf('#', index);
      if (u == -1 && h == -1) {
        break;
      }

      if (u == -1 || (h >= 0 && h < u)) {
        final previous = h == 0 ? '' : content[h - 1];
        if (h == 0 || _noCharacter.hasMatch(previous)) {
          final sliceEnd =
              h + 1 + _maxHashtagLength > max ? max : h + 1 + _maxHashtagLength;
          final match =
              _noCharacter.firstMatch(content.substring(h + 1, sliceEnd));
          final end = match == null ? max : h + 1 + match.start;
          final length = end - h - 1;

          if (length > 0 && length < _maxHashtagLength) {
            if (prevIndex != h) {
              blocks.add(_text(content, prevIndex, h));
            }
            blocks.add(
              Nip27Block._(
                Nip27BlockType.hashtag,
                h,
                end,
                value: content.substring(h + 1, end),
              ),
            );
            index = end;
            prevIndex = index;
            continue;
          }
        }

        index = h + 1;
        continue;
      }

      final before = u >= 5 ? content.substring(u - 5, u) : '';
      if (before == 'nostr') {
        final end = _endAfter(content, u + 60);
        try {
          final raw = content.substring(u + 1, end);
          final decoded = _codec.decodeBech32(raw);
          final hrp = decoded[1];

          if (hrp == 'nsec') {
            index = end + 1;
            continue;
          }

          final pointer = _pointerFrom(hrp, decoded[0], raw);
          if (prevIndex != u - 5) {
            blocks.add(_text(content, prevIndex, u - 5));
          }
          blocks.add(
            Nip27Block._(
              Nip27BlockType.reference,
              u - 5,
              end,
              pointer: pointer,
            ),
          );
          index = end;
          prevIndex = index;
          continue;
        } on Object catch (_) {
          index = u + 1;
          continue;
        }
      }

      final isHttps = before == 'https';
      final isHttp = u >= 4 && content.substring(u - 4, u) == 'http';
      if (isHttps || isHttp) {
        final end = _urlEnd(content, u + 4);
        final prefixLength = content[u - 1] == 's' ? 5 : 4;
        try {
          final url = _normalizeUrl(content.substring(u - prefixLength, end));
          if (prevIndex != u - prefixLength) {
            blocks.add(_text(content, prevIndex, u - prefixLength));
          }

          final path = Uri.parse(url).path;
          final type = _imagePath.hasMatch(path)
              ? Nip27BlockType.image
              : _videoPath.hasMatch(path)
                  ? Nip27BlockType.video
                  : _audioPath.hasMatch(path)
                      ? Nip27BlockType.audio
                      : Nip27BlockType.url;

          blocks.add(
            Nip27Block._(
              type,
              u - prefixLength,
              end,
              url: url,
            ),
          );
          index = end;
          prevIndex = index;
          continue;
        } on Object catch (_) {
          index = end + 1;
          continue;
        }
      }

      final isWss = u >= 3 && content.substring(u - 3, u) == 'wss';
      final maybeWs = isWss ||
          _wsBoundary.hasMatch(
            u >= 3 ? content.substring(u - 3, u) : content.substring(0, u),
          );
      if (maybeWs) {
        final end = _urlEnd(content, u + 4);
        final prefixLength = isWss ? 3 : 2;
        try {
          final url = _normalizeUrl(content.substring(u - prefixLength, end));
          if (prevIndex != u - prefixLength) {
            blocks.add(_text(content, prevIndex, u - prefixLength));
          }
          blocks.add(
            Nip27Block._(
              Nip27BlockType.relay,
              u - prefixLength,
              end,
              url: url,
            ),
          );
          index = end;
          prevIndex = index;
          continue;
        } on Object catch (_) {
          index = end + 1;
          continue;
        }
      }

      for (final emoji in emojis) {
        final (shortcode, url) = emoji;
        final close = u + shortcode.length + 1;
        if (close < max &&
            content[close] == ':' &&
            u + 1 + shortcode.length <= max &&
            content.substring(u + 1, close) == shortcode) {
          if (prevIndex != u) {
            blocks.add(_text(content, prevIndex, u));
          }
          blocks.add(
            Nip27Block._(
              Nip27BlockType.emoji,
              u,
              u + shortcode.length + 2,
              shortcode: shortcode,
              url: url,
            ),
          );
          index = u + shortcode.length + 2;
          prevIndex = index;
          continue mainloop;
        }
      }

      index = u + 1;
    }

    if (prevIndex != max) {
      blocks.add(_text(content, prevIndex, max));
    }

    return blocks;
  }

  Nip27Block _text(String content, int start, int end) {
    return Nip27Block._(
      Nip27BlockType.text,
      start,
      end,
      text: content.substring(start, end),
    );
  }

  Nip27Pointer _pointerFrom(String hrp, String hex, String raw) {
    switch (hrp) {
      case 'npub':
        return Nip27Pointer.profile(pubkey: hex);
      case 'note':
        return Nip27Pointer.event(id: hex);
      case 'nprofile':
        final map = _codec.decodeNprofileToMap(raw);
        return Nip27Pointer.profile(
          pubkey: map['pubkey'] as String,
          relays: List<String>.from(map['relays'] as List),
        );
      case 'nevent':
        final map = _codec.decodeNeventToMap(raw);
        final author = map['pubkey'] as String;
        // The optional `kind` TLV is decoded by the codec but not carried:
        // [Nip27Pointer.event] has no kind field. Use
        // `decodeNeventToMap` directly when the kind is needed.
        return Nip27Pointer.event(
          id: map['eventId'] as String,
          author: author.isEmpty ? null : author,
          relays: List<String>.from(map['relays'] as List),
        );
      case 'naddr':
        final map = _codec.decodeNaddrToMap(raw);
        return Nip27Pointer.address(
          pubkey: map['pubkey'] as String,
          kind: map['kind'] as int,
          identifier: map['identifier'] as String,
          relays: List<String>.from(map['relays'] as List),
        );
      default:
        throw FormatException('unsupported nostr entity: $hrp');
    }
  }

  /// Finds the first non-word character at or after [from].
  int _endAfter(String content, int from) {
    if (from >= content.length) {
      return content.length;
    }
    final match = _noCharacter.firstMatch(content.substring(from));
    return match == null ? content.length : from + match.start;
  }

  /// URL end per `nostr-tools`: stop at whitespace, then drop trailing
  /// punctuation while keeping a `)` that closes an opened `(`.
  int _urlEnd(String content, int from) {
    final whitespaceMatch = from >= content.length
        ? null
        : _whitespace.firstMatch(
            content.substring(from),
          );

    final end =
        whitespaceMatch == null ? content.length : from + whitespaceMatch.start;
    final match = _trailingPunctuation.firstMatch(content.substring(from, end));
    final trailing = match?.group(0) ?? '';
    final urlEnd = end - trailing.length;
    final paren = trailing.indexOf(')');

    if (paren != -1) {
      final url = content.substring(from, urlEnd);
      if (')'.allMatches(url).length < '('.allMatches(url).length) {
        return urlEnd + paren + 1;
      }
    }
    return urlEnd;
  }

  static String _normalizeUrl(String raw) {
    final uri = Uri.parse(raw);
    if (uri.host.isEmpty || !uri.host.contains('.')) {
      throw FormatException('invalid url: $raw');
    }
    return uri.replace(path: uri.path.isEmpty ? '/' : uri.path).toString();
  }
}
