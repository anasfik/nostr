import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

const int maxRelayCount = 3;
const int maxLogEntries = 200;
const int maxEventFeed = 100;
const int maxJsonInputLength = 100000;
const int maxContentLength = 5000;
const int maxTags = 20;
const int maxKinds = 20;
const int maxAuthors = 20;
const int maxAuthenticityCacheEntries = 128;

/// Bounds for untrusted relay events. These are deliberately separate from
/// the compose limits above: composing a note is capped at [maxContentLength],
/// while a relay may legitimately deliver larger historical events.
const int maxRelayEventBytes = 256 * 1024;
const int maxRelayEventContentChars = 65536;
const int maxRelayEventTags = 100;
const int maxRelayEventTagChars = 32768;
const int maxRelayEventTagValueChars = 2048;

class RelayInput {
  const RelayInput({required this.urls, this.error});

  final List<String> urls;
  final String? error;

  bool get isValid => error == null;
}

RelayInput parseRelayInput(String raw) {
  final parts = raw
      .split(RegExp(r'[\s,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return const RelayInput(
      urls: [],
      error: 'Add at least one wss:// relay URL.',
    );
  }

  final urls = <String>[];
  for (final part in parts) {
    final uri = Uri.tryParse(part);
    if (uri == null || uri.scheme != 'wss') {
      return RelayInput(
        urls: const [],
        error: 'Only secure wss:// relay URLs are supported. Invalid: $part',
      );
    }
    if (uri.host.isEmpty) {
      return RelayInput(urls: const [], error: 'Relay has no host: $part');
    }
    if (uri.userInfo.isNotEmpty) {
      return const RelayInput(
        urls: [],
        error: 'Relay URLs must not contain credentials.',
      );
    }
    if (uri.hasFragment) {
      return RelayInput(
        urls: const [],
        error: 'Relay URL must not contain a fragment: $part',
      );
    }
    final normalized = uri.toString();
    if (!urls.contains(normalized)) {
      urls.add(normalized);
    }
  }

  if (urls.length > maxRelayCount) {
    return const RelayInput(
      urls: [],
      error: 'Use at most 3 relays to keep this demo bounded.',
    );
  }

  return RelayInput(urls: urls);
}

List<int> parseKinds(String raw) {
  final parts = raw
      .split(RegExp(r'[\s,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  if (parts.length > maxKinds) {
    throw FormatException('Use at most $maxKinds kinds.');
  }

  return parts
      .map((value) {
        final kind = int.tryParse(value);
        if (kind == null || kind < 0 || kind > 65535) {
          throw FormatException(
            'Kind must be an integer between 0 and 65535: $value',
          );
        }
        return kind;
      })
      .toList(growable: false);
}

int parseKind(String raw) {
  final kinds = parseKinds(raw);
  if (kinds.length != 1) {
    throw const FormatException('Enter exactly one kind.');
  }
  return kinds.single;
}

List<String> parseAuthors(String raw) {
  final parts = raw
      .split(RegExp(r'[\s,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  if (parts.length > maxAuthors) {
    throw FormatException('Use at most $maxAuthors authors.');
  }

  for (final author in parts) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(author)) {
      throw FormatException(
        'Authors must be 64 character lowercase hex public keys: $author',
      );
    }
  }
  return parts;
}

List<List<String>> parseTags(String raw) {
  if (raw.trim().isEmpty) {
    return [];
  }
  if (raw.length > maxJsonInputLength) {
    throw const FormatException('Tags JSON is too large.');
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw const FormatException(
      'Tags must be valid JSON like [["t","nostr"]].',
    );
  }

  if (decoded is! List) {
    throw const FormatException('Tags must be a JSON array of arrays.');
  }
  if (decoded.length > maxTags) {
    throw const FormatException('Use at most $maxTags tags.');
  }

  return decoded
      .map((tag) {
        if (tag is! List) {
          throw const FormatException('Each tag must be a JSON array.');
        }
        if (tag.length > 10) {
          throw const FormatException(
            'Each tag may contain at most 10 values.',
          );
        }
        return tag
            .map((value) {
              if (value is! String) {
                throw const FormatException('Tag values must be strings.');
              }
              if (value.length > 1024) {
                throw const FormatException('A tag value is too long.');
              }
              return value;
            })
            .toList(growable: false);
      })
      .toList(growable: false);
}

class FilterInput {
  const FilterInput({
    required this.kinds,
    required this.authors,
    required this.limit,
    this.error,
  });

  final List<int> kinds;
  final List<String> authors;
  final int limit;
  final String? error;

  bool get isValid => error == null;
}

FilterInput parseFilterInput({
  required String kinds,
  required String authors,
  required String limit,
}) {
  try {
    final parsedKinds = parseKinds(kinds);
    final parsedAuthors = parseAuthors(authors);
    final parsedLimit = int.tryParse(limit.trim());
    if (parsedLimit == null || parsedLimit < 1 || parsedLimit > maxEventFeed) {
      throw FormatException('Limit must be between 1 and $maxEventFeed.');
    }
    if (parsedKinds.isEmpty && parsedAuthors.isEmpty) {
      throw const FormatException('Add at least one kind or author.');
    }

    return FilterInput(
      kinds: parsedKinds,
      authors: parsedAuthors,
      limit: parsedLimit,
    );
  } on FormatException catch (e) {
    return FilterInput(
      kinds: const [],
      authors: const [],
      limit: 0,
      error: e.message,
    );
  }
}

NostrEvent signLocalEvent({
  required NostrKeyPairs keys,
  required int kind,
  required String content,
  required List<List<String>> tags,
  DateTime? createdAt,
}) {
  if (content.length > maxContentLength) {
    throw FormatException(
      'Content is too long (max $maxContentLength characters).',
    );
  }
  return NostrEvent.fromPartialData(
    kind: kind,
    content: content,
    keyPairs: keys,
    tags: tags,
    createdAt: createdAt,
  );
}

/// Returns a short reason when an untrusted relay event exceeds the playground
/// payload bounds, or null when it is safe to retain and render.
String? relayEventRejection(NostrEvent event) {
  final content = event.content ?? '';

  if (content.length > maxRelayEventContentChars) {
    return 'content exceeds $maxRelayEventContentChars characters';
  }

  var bytes = utf8.encode(content).length;
  if (bytes > maxRelayEventBytes) {
    return 'content exceeds $maxRelayEventBytes bytes';
  }

  final tags = event.tags ?? const <List<String>>[];
  if (tags.length > maxRelayEventTags) {
    return 'tags exceed $maxRelayEventTags entries';
  }

  var tagChars = 0;
  for (final tag in tags) {
    if (tag.length > 10) {
      return 'a tag has more than 10 values';
    }
    for (final value in tag) {
      if (value.length > maxRelayEventTagValueChars) {
        return 'a tag value exceeds $maxRelayEventTagValueChars characters';
      }
      tagChars += value.length;
      bytes += utf8.encode(value).length;
      if (tagChars > maxRelayEventTagChars) {
        return 'tags exceed $maxRelayEventTagChars characters';
      }
      if (bytes > maxRelayEventBytes) {
        return 'event content and tags exceed $maxRelayEventBytes bytes';
      }
    }
  }

  if ((event.id?.length ?? 0) > 256) {
    return 'id field is oversized';
  }
  if ((event.sig?.length ?? 0) > 256) {
    return 'signature field is oversized';
  }
  if (event.pubkey.length > 128) {
    return 'pubkey field is oversized';
  }
  if (event.kind == null || event.kind! < 0 || event.kind! > 65535) {
    return 'kind is missing or out of range';
  }

  return null;
}

bool isEventAuthentic(NostrEvent event) {
  if (event.id == null ||
      event.sig == null ||
      event.kind == null ||
      event.createdAt == null) {
    return false;
  }
  try {
    final expectedId = NostrEvent.getEventId(
      kind: event.kind!,
      content: event.content ?? '',
      createdAt: event.createdAt!,
      tags: event.tags ?? const [],
      pubkey: event.pubkey,
    );
    return expectedId == event.id &&
        NostrKeyPairs.verify(event.pubkey, event.id!, event.sig!);
  } catch (_) {
    return false;
  }
}

String prettyEventJson(NostrEvent event) =>
    const JsonEncoder.withIndent('  ').convert(event.toMap());

String shortId(String? id) {
  if (id == null || id.isEmpty) {
    return 'no id';
  }
  return id.length <= 16
      ? id
      : '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
}
