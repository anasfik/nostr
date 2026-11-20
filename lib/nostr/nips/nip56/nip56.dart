import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip32/nip32.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip56_report_type}
/// Report type carried in slot 2 of the reported `e`, `p` or `x` tag
/// (56.md:25-34).
/// {@endtemplate}
enum NostrReportType {
  /// Depictions of nudity or porn.
  nudity('nudity'),

  /// Viruses, trojans, spyware and other malicious software.
  malware('malware'),

  /// Profanity or hateful speech.
  profanity('profanity'),

  /// Content that may be illegal in some jurisdiction.
  illegal('illegal'),

  /// Spam.
  spam('spam'),

  /// Someone pretending to be someone else.
  impersonation('impersonation'),

  /// Anything that does not fit the other types.
  other('other');

  const NostrReportType(this.value);

  /// Wire value used in the report tag.
  final String value;

  /// Resolves a wire value, returning `null` for unknown types.
  static NostrReportType? fromValue(String value) {
    for (final type in values) {
      if (type.value == value) {
        return type;
      }
    }

    return null;
  }
}

/// {@template nip56_report}
/// Parsed NIP-56 report (kind 1984).
///
/// [rawType] is preserved even when the type is not one this package knows,
/// so events from newer clients are never dropped; [knownType] is `null` in
/// that case.
/// {@endtemplate}
class NostrReport {
  /// {@macro nip56_report}
  const NostrReport({
    required this.reportedPubkey,
    required this.rawType,
    this.knownType,
    this.eventId,
    this.blobHash,
    this.server,
    this.content = '',
    this.labels = const [],
  });

  /// `p` tag: the pubkey being reported. Always present.
  final String reportedPubkey;

  /// `e` tag: the reported note, when reporting an event.
  final String? eventId;

  /// `x` tag: the info hash of a reported blob.
  final String? blobHash;

  /// `server` tag: media server that may host the blob, verbatim.
  final String? server;

  /// Report type as published, for example `nudity`.
  final String rawType;

  /// [rawType] resolved to a known type, or `null` for unknown values.
  final NostrReportType? knownType;

  /// Optional explanation (56.md:14-15).
  final String content;

  /// `L`/`l` tags attached as NIP-32 qualifications (56.md:40-41).
  final List<NostrLabel> labels;
}

/// {@template nip56}
/// NIP-56 reporting (kind 1984).
///
/// A report MUST carry a `p` tag with the reported pubkey, and the report
/// type MUST sit in slot 2 of the reported `e`, `p` or `x` tag (56.md:20-26).
/// Note reports add an `e` tag; blob reports add an `x` tag and MUST also
/// carry the `e` tag of the event holding the blob (56.md:38).
///
/// Slot 2 means a report type here. In NIP-32 the same slot of an `e`/`p`
/// target is a relay hint, so the two modules deliberately do not share a
/// slot-2 helper.
///
/// ```dart
/// final nip56 = NostrNip56(signer: signer);
/// final report = await nip56.createReport(
///   reportedPubkey: authorPubkey,
///   eventId: noteId,
///   type: 'illegal',
///   content: 'He is insulting the king!',
/// );
/// ```
/// {@endtemplate}
class NostrNip56 {
  /// {@macro nip56}
  NostrNip56({required this.signer});

  /// Signer used by [createReport].
  final NostrEventSigner signer;

  /// Kind of a report event.
  static const int reportKind = 1984;

  /// Known report type strings, in spec order.
  static const List<String> reportTypes = [
    'nudity',
    'malware',
    'profanity',
    'illegal',
    'spam',
    'impersonation',
    'other',
  ];

  /// Whether [type] is one of the known [reportTypes].
  static bool isValidReportType(String type) => reportTypes.contains(type);

  /// Whether [event] is a shaped kind-1984 report.
  ///
  /// Requires a `p` tag and a non-empty report type in slot 2 of an `e`,
  /// `p` or `x` tag. Unknown type strings are still valid. A blob `x` tag
  /// without the `e` tag of the event holding the blob is invalid
  /// (56.md:38).
  static bool validateEvent(NostrEvent event) {
    if (event.kind != reportKind) {
      return false;
    }

    final tags = event.tags ?? const <List<String>>[];
    final reportedPubkey = NostrTags.first(tags, 'p');
    final blobHash = NostrTags.first(tags, 'x');
    final eventId = NostrTags.first(tags, 'e');

    return reportedPubkey != null &&
        reportedPubkey.isNotEmpty &&
        _reportType(tags) != null &&
        (blobHash == null || eventId != null);
  }

  /// Parses [event], returning `null` when [validateEvent] fails.
  static NostrReport? tryParse(NostrEvent event) {
    if (!validateEvent(event)) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final rawType = _reportType(tags)!;

    return NostrReport(
      reportedPubkey: NostrTags.first(tags, 'p')!,
      eventId: NostrTags.first(tags, 'e'),
      blobHash: NostrTags.first(tags, 'x'),
      server: NostrTags.first(tags, 'server'),
      rawType: rawType,
      knownType: NostrReportType.fromValue(rawType),
      content: event.content ?? '',
      labels: _labels(tags),
    );
  }

  /// Parses [event], throwing [ArgumentError] when it is not a report.
  static NostrReport parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError.value(event, 'event', 'Invalid NIP-56 report');
    }

    return parsed;
  }

  /// Builds and signs a kind-1984 report.
  ///
  /// [type] must be a known [reportTypes] value. Throws [ArgumentError] when
  /// [reportedPubkey] or [type] is empty, when [type] is unknown, or when
  /// [blobHash] is set without [eventId] (56.md:38).
  Future<NostrEvent> createReport({
    required String reportedPubkey,
    required String type,
    String? eventId,
    String? blobHash,
    String? server,
    String content = '',
    List<NostrLabel> labels = const [],
    DateTime? createdAt,
  }) {
    if (reportedPubkey.isEmpty) {
      throw ArgumentError.value(
        reportedPubkey,
        'reportedPubkey',
        'Reports require a p tag',
      );
    }

    if (type.isEmpty) {
      throw ArgumentError.value(type, 'type', 'Report type must not be empty');
    }

    if (!isValidReportType(type)) {
      throw ArgumentError.value(type, 'type', 'Unknown report type');
    }

    if (blobHash != null && eventId == null) {
      throw ArgumentError.value(
        blobHash,
        'blobHash',
        'An x tag requires the e tag of the event containing the blob',
      );
    }

    final namespaces = <String>{for (final label in labels) label.namespace};

    return signer.sign(
      NostrEvent(
        id: null,
        kind: reportKind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['p', reportedPubkey, type],
          if (eventId != null) ['e', eventId, type],
          if (blobHash != null) ['x', blobHash, type],
          if (server != null) ['server', server],
          for (final namespace in namespaces) ['L', namespace],
          for (final label in labels) label.toTag,
        ],
      ),
    );
  }

  /// First non-empty report type among `p`, `e` and `x` tags.
  ///
  /// A profile report carries it on `p`; a note report on `e`; a blob report
  /// on `x` and on its containing `e` tag (56.md:25-26,38). Unknown strings
  /// are returned as-is.
  static String? _reportType(List<List<String>>? tags) {
    for (final name in const ['p', 'e', 'x']) {
      for (final tag in tags ?? const <List<String>>[]) {
        if (tag.length > 2 && tag.first == name && tag[2].isNotEmpty) {
          return tag[2];
        }
      }
    }

    return null;
  }

  /// NIP-32 `L`/`l` tags carried by a report.
  static List<NostrLabel> _labels(List<List<String>> tags) {
    final labels = <NostrLabel>[];

    for (final tag in tags) {
      if (tag.length < 2 || tag.first != 'l') {
        continue;
      }

      final mark = NostrTags.at(tag, 2);
      labels.add(
        NostrLabel(
          value: tag[1],
          namespace:
              mark == null || mark.isEmpty ? NostrNip32.defaultNamespace : mark,
        ),
      );
    }

    return labels;
  }
}
