import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_pgn_tag}
/// One PGN tag pair: a name and its unescaped value.
///
/// PGN escapes only `\` and `"` inside values. Any other backslash sequence
/// resolves to the character that follows it, matching the PGN import format.
/// {@endtemplate}
class NostrPgnTag {
  /// {@macro nostr_pgn_tag}
  const NostrPgnTag(this.name, this.value);

  /// Tag name, such as `White`.
  final String name;

  /// Unescaped tag value.
  final String value;

  /// `[Name "value"]` with PGN escaping applied.
  String toPgn() => '[$name "${_escapePgnTagValue(value)}"]';

  @override
  String toString() => toPgn();
}

/// {@template nostr_pgn_game}
/// One PGN game: ordered tag pairs plus movetext.
///
/// [movetext] keeps the source text (trimmed only). [toPgn] serializes the
/// PGN export format: seven tag roster order, one tag per line, a blank line,
/// movetext wrapped at 80 columns and terminated by the result token.
///
/// Parsing accepts the lax import format; a missing result token defaults to
/// `*`, and a `Result` tag that contradicts the movetext is rejected.
/// {@endtemplate}
class NostrPgnGame {
  /// {@macro nostr_pgn_game}
  const NostrPgnGame({required this.tags, required this.movetext});

  /// Result tokens defined by PGN.
  static const List<String> results = ['1-0', '0-1', '1/2-1/2', '*'];

  /// Seven tag roster, in the order required by the PGN export format.
  static const List<String> sevenTagRoster = [
    'Event',
    'Site',
    'Date',
    'Round',
    'White',
    'Black',
    'Result',
  ];

  /// Tag pairs in source order.
  final List<NostrPgnTag> tags;

  /// Movetext, trimmed but otherwise verbatim.
  final String movetext;

  /// Value of the first tag named [name], or `null`.
  String? tag(String name) {
    for (final tag in tags) {
      if (tag.name == name) {
        return tag.value;
      }
    }

    return null;
  }

  /// Result token from the movetext, the `Result` tag, or `*`.
  String get result => _resultToken(movetext) ?? tag('Result') ?? results.last;

  /// Serializes this game in PGN export format.
  String toPgn() {
    final ordered = <NostrPgnTag>[
      for (final name in sevenTagRoster)
        for (final tag in tags)
          if (tag.name == name) tag,
      for (final tag in tags)
        if (!sevenTagRoster.contains(tag.name)) tag,
    ];

    final buffer = StringBuffer();
    for (final tag in ordered) {
      buffer.writeln(tag.toPgn());
    }
    if (ordered.isNotEmpty) {
      buffer.writeln();
    }
    buffer.write(_wrap80(_withResultToken(movetext, tag('Result'))));

    return buffer.toString();
  }

  /// Parses exactly one game, throwing [ArgumentError] otherwise.
  static NostrPgnGame parse(String pgn) {
    final games = parseDatabase(pgn);
    if (games.length != 1) {
      throw ArgumentError.value(
        pgn,
        'pgn',
        'Expected exactly one PGN game, found ${games.length}',
      );
    }

    return games.first;
  }

  /// Like [parse], returning `null` for invalid PGN.
  static NostrPgnGame? tryParse(String pgn) {
    try {
      return parse(pgn);
    } on ArgumentError {
      return null;
    }
  }

  /// Parses a PGN database (one or more games), throwing [ArgumentError].
  static List<NostrPgnGame> parseDatabase(String pgn) {
    final games = <NostrPgnGame>[];
    var tags = <NostrPgnTag>[];
    final movetext = StringBuffer();
    var hasMovetext = false;
    var inComment = false;

    void flush() {
      if (tags.isEmpty && !hasMovetext) {
        return;
      }

      games.add(_createGame(tags, movetext.toString()));
      tags = <NostrPgnTag>[];
      movetext.clear();
      hasMovetext = false;
    }

    for (final rawLine in const LineSplitter().convert(pgn)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      if (!inComment && line.startsWith('[')) {
        if (hasMovetext) {
          flush();
        }
        tags.add(_parseTagLine(line));
        continue;
      }

      hasMovetext = true;
      movetext.writeln(line);
      inComment = _commentStateAfter(line, inComment);
    }

    flush();

    if (games.isEmpty) {
      throw ArgumentError.value(pgn, 'pgn', 'No PGN game found');
    }

    return List<NostrPgnGame>.unmodifiable(games);
  }

  static NostrPgnGame _createGame(List<NostrPgnTag> tags, String movetext) {
    final text = movetext.trim();
    if (text.isEmpty) {
      throw ArgumentError('PGN games require movetext');
    }

    String? declared;
    for (final tag in tags) {
      if (tag.name == 'Result') {
        declared = tag.value;
        break;
      }
    }
    final token = _resultToken(text);
    if (declared != null && token != null && declared != token) {
      throw ArgumentError.value(
        declared,
        'Result',
        'Tag result "$declared" does not match movetext result "$token"',
      );
    }

    return NostrPgnGame(
      tags: List<NostrPgnTag>.unmodifiable(tags),
      movetext: text,
    );
  }

  static final RegExp _tagLine = RegExp(
    r'^\[\s*([A-Za-z0-9_]+)\s+"((?:[^"\\]|\\.)*)"\s*\]$',
  );

  static NostrPgnTag _parseTagLine(String line) {
    final match = _tagLine.firstMatch(line);
    if (match == null) {
      throw ArgumentError.value(
        line,
        'pgn',
        'Invalid PGN tag pair',
      );
    }

    return NostrPgnTag(match.group(1)!, _unescapePgnTagValue(match.group(2)!));
  }
}

/// Escapes `\` and `"` for a PGN tag value.
String _escapePgnTagValue(String value) =>
    value.replaceAll('\\', r'\\').replaceAll('"', r'\"');

/// Resolves PGN tag escapes; a backslash yields the character after it.
String _unescapePgnTagValue(String value) {
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == '\\' && i + 1 < value.length) {
      i++;
      out.write(value[i]);
    } else {
      out.write(char);
    }
  }

  return out.toString();
}

String? _resultToken(String movetext) {
  final tokens = movetext.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty) {
    return null;
  }

  final last = tokens.last;

  return NostrPgnGame.results.contains(last) ? last : null;
}

String _withResultToken(String movetext, String? declared) {
  final text = movetext.trim();
  if (_resultToken(text) != null) {
    return text;
  }

  return '$text ${declared ?? NostrPgnGame.results.last}';
}

/// Tracks `{ ... }` comment state across movetext lines.
bool _commentStateAfter(String line, bool inComment) {
  var open = inComment;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '{') {
      open = true;
    } else if (char == '}') {
      open = false;
    }
  }

  return open;
}

String _wrap80(String text) {
  const width = 80;
  final lines = <String>[];
  final current = StringBuffer();

  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) {
      continue;
    }

    if (current.isEmpty) {
      current.write(word);
    } else if (current.length + 1 + word.length <= width) {
      current.write(' $word');
    } else {
      lines.add(current.toString());
      current
        ..clear()
        ..write(word);
    }
  }

  if (current.isNotEmpty) {
    lines.add(current.toString());
  }

  return lines.join('\n');
}

/// {@template nip64}
/// NIP-64 chess games as PGN notes (kind 64).
///
/// The content is a PGN database; [generateTemplate] validates it and
/// serializes export format. [publish] signs through the bound signer.
/// {@endtemplate}
class NostrNip64 {
  /// {@macro nip64}
  NostrNip64({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Chess PGN note kind.
  static const int kind = 64;

  /// Tag name for the optional human-readable fallback.
  static const String altTag = 'alt';

  /// Builds an unsigned kind-64 event from a PGN database.
  ///
  /// Throws [ArgumentError] when [pgn] is not a valid PGN database. The
  /// content is re-serialized in PGN export format.
  static NostrEvent generateTemplate({
    required String pgn,
    String? alt,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    final games = NostrPgnGame.parseDatabase(pgn);
    final content = games.map((game) => game.toPgn()).join('\n\n');

    return NostrEvent(
      id: null,
      kind: kind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (alt != null) [altTag, alt],
        ...tags,
      ],
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses the games in a kind-64 [event].
  ///
  /// Throws [ArgumentError] when the event kind is wrong or the PGN invalid.
  static List<NostrPgnGame> parseEvent(NostrEvent event) {
    if (event.kind != kind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-64 chess event',
      );
    }

    return NostrPgnGame.parseDatabase(event.content ?? '');
  }

  /// Like [parseEvent], returning `null` for invalid events.
  static List<NostrPgnGame>? tryParseEvent(NostrEvent event) {
    try {
      return parseEvent(event);
    } on ArgumentError {
      return null;
    }
  }
}
