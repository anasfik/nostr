import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip92/nip92.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_video_kind}
/// NIP-71 video event kinds.
///
/// `21`/`22` are regular events (normal and short video), `34235`/`34236`
/// their addressable counterparts. Kind `22` is a short video here; NIP-22
/// comments are kind `1111`.
/// {@endtemplate}
class NostrVideoKind {
  const NostrVideoKind._();

  /// Regular normal (mostly horizontal) video.
  static const int normal = 21;

  /// Regular short (mostly vertical) video.
  static const int short = 22;

  /// Addressable normal video, updatable via its `d` tag.
  static const int addressableNormal = 34235;

  /// Addressable short video, updatable via its `d` tag.
  static const int addressableShort = 34236;

  /// Every kind defined by NIP-71.
  static const List<int> values = [
    normal,
    short,
    addressableNormal,
    addressableShort,
  ];

  /// Whether [kind] is a NIP-71 video kind.
  static bool isVideoKind(int? kind) => values.contains(kind);

  /// Whether [kind] is an addressable video kind (34235/34236).
  static bool isAddressable(int kind) =>
      kind == addressableNormal || kind == addressableShort;

  /// Whether [kind] must carry a non-empty `d` tag.
  static bool requiresD(int kind) => isAddressable(kind);

  /// Whether [kind] is a regular video kind (21/22).
  static bool isRegular(int kind) => kind == normal || kind == short;

  /// Whether [kind] is a short-form video kind (22/34236).
  static bool isShort(int kind) => kind == short || kind == addressableShort;
}

/// {@template nostr_video_segment}
/// NIP-71 `segment` tag: chapter start/end in seconds plus title and thumbnail.
/// {@endtemplate}
class NostrVideoSegment {
  /// {@macro nostr_video_segment}
  const NostrVideoSegment({
    required this.start,
    required this.end,
    this.title,
    this.thumbnail,
  });

  /// Inclusive chapter start in seconds.
  final double start;

  /// Exclusive chapter end in seconds; must be greater than [start].
  final double end;

  /// Chapter title.
  final String? title;

  /// Chapter thumbnail URL.
  final String? thumbnail;

  /// `['segment', 'HH:MM:SS.sss', 'HH:MM:SS.sss', title?, thumbnail?]`.
  List<String> toTag() => [
        'segment',
        _formatSeconds(start),
        _formatSeconds(end),
        if (title != null) title!,
        if (thumbnail != null) thumbnail!,
      ];
}

/// {@template nostr_video_text_track}
/// NIP-71 `text-track` tag: encoded kind-6000 event and recommended relays.
/// {@endtemplate}
class NostrVideoTextTrack {
  /// {@macro nostr_video_text_track}
  const NostrVideoTextTrack({required this.event, this.relays = const []});

  /// Encoded kind-6000 text-track event.
  final String event;

  /// Recommended relays carrying [event].
  final List<String> relays;
}

/// {@template nostr_video_origin}
/// NIP-71 `origin` tag for imported content.
/// {@endtemplate}
class NostrVideoOrigin {
  /// {@macro nostr_video_origin}
  const NostrVideoOrigin({
    required this.platform,
    required this.externalId,
    this.url,
    this.metadata,
  });

  /// Original platform name.
  final String platform;

  /// Identifier on [platform].
  final String externalId;

  /// Original URL.
  final String? url;

  /// Optional extra metadata.
  final String? metadata;

  /// `['origin', platform, externalId, url?, metadata?]`.
  List<String> toTag() => [
        'origin',
        platform,
        externalId,
        if (url != null) url!,
        if (metadata != null) metadata!,
      ];
}

/// {@template nostr_video_track}
/// One `imeta` entry interpreted as a video or audio track.
///
/// NIP-71 adds `duration`, `bitrate` and (audio only) `waveform` to NIP-92
/// `imeta` tags. Audio tracks may carry `l <lang> ISO-639-1` and the `ov`
/// (original version) marker, either as part of that value or as a bare
/// `ov` entry.
/// {@endtemplate}
class NostrVideoTrack {
  /// {@macro nostr_video_track}
  const NostrVideoTrack(this.imeta);

  /// Underlying NIP-92 metadata.
  final NostrImeta imeta;

  /// Primary media URL.
  String? get url => imeta.url;

  /// MIME type.
  String? get mime => imeta.m;

  /// Raw `dim` value such as `1920x1080`.
  String? get dim => imeta.dim;

  /// Whether the MIME type is video, including HLS playlists.
  bool get isVideo {
    final type = mime?.toLowerCase();

    return type != null &&
        (type.startsWith('video/') || _hlsMimes.contains(type));
  }

  /// Whether the MIME type starts with `audio/`.
  bool get isAudio => mime?.startsWith('audio/') ?? false;

  static const Set<String> _hlsMimes = {
    'application/x-mpegurl',
    'application/vnd.apple.mpegurl',
  };

  /// Duration in seconds (`duration` imeta property).
  num? get duration => _num(imeta['duration']);

  /// Average bitrate in bits/sec (`bitrate` imeta property).
  int? get bitrate => _num(imeta['bitrate'])?.toInt();

  /// Amplitude samples (`waveform` imeta property).
  ///
  /// Returns an empty list when any token is not an integer, so parsing can
  /// reject the attachment uniformly.
  List<int> get waveform {
    final raw = imeta['waveform']?.trim();
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final samples = <int>[];
    for (final value in raw.split(RegExp(r'\s+'))) {
      final sample = int.tryParse(value);
      if (sample == null) {
        return const [];
      }

      samples.add(sample);
    }

    return samples;
  }

  /// First language token of the `l` value, such as `en`.
  String? get language {
    final value = imeta['l']?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value.split(RegExp(r'\s+')).first;
  }

  /// Whether the track is marked as the original language (`ov`).
  bool get isOriginalLanguage =>
      imeta['ov'] != null ||
      (imeta['l'] ?? '').split(RegExp(r'\s+')).contains('ov');

  static num? _num(String? value) => num.tryParse(value?.trim() ?? '');
}

/// {@template nostr_video_event}
/// Parsed NIP-71 video event (kinds 21/22/34235/34236).
///
/// The body lives in [description] (the event content) and media in
/// [tracks] (NIP-92 `imeta`, the primary payload). Use [duration] for the
/// effective duration: the first imeta `duration` wins, otherwise the legacy
/// top-level `duration` tag is used.
/// {@endtemplate}
class NostrVideoEvent {
  /// {@macro nostr_video_event}
  const NostrVideoEvent({
    this.id,
    required this.pubkey,
    required this.kind,
    required this.title,
    required this.description,
    this.publishedAt,
    this.alt,
    this.contentWarning,
    this.dTag,
    this.tracks = const [],
    this.segments = const [],
    this.textTracks = const [],
    this.hashtags = const [],
    this.participants = const [],
    this.references = const [],
    this.origin,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// One of [NostrVideoKind.values].
  final int kind;

  /// Required `title` tag.
  final String title;

  /// Event content: summary or description.
  final String description;

  /// `published_at` in UNIX seconds.
  final int? publishedAt;

  /// `alt` accessibility description.
  final String? alt;

  /// `content-warning` reason.
  final String? contentWarning;

  /// `d` identifier, required for addressable kinds and absent for regular.
  final String? dTag;

  /// Every valid `imeta` track, in tag order.
  final List<NostrVideoTrack> tracks;

  /// Chapter markers, in tag order.
  final List<NostrVideoSegment> segments;

  /// Text tracks (captions/subtitles/chapters), in tag order.
  final List<NostrVideoTextTrack> textTracks;

  /// `t` hashtags.
  final List<String> hashtags;

  /// `p` participant pubkeys.
  final List<String> participants;

  /// `r` reference links.
  final List<String> references;

  /// `origin` tag for imported content.
  final NostrVideoOrigin? origin;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Video tracks only.
  List<NostrVideoTrack> get videoTracks => [
        for (final track in tracks)
          if (track.isVideo) track
      ];

  /// Audio tracks only.
  List<NostrVideoTrack> get audioTracks => [
        for (final track in tracks)
          if (track.isAudio) track
      ];

  /// Effective duration in seconds, preferring the imeta property.
  num? get duration {
    for (final track in tracks) {
      final value = track.duration;
      if (value != null) {
        return value;
      }
    }

    return NostrValidators.tryInt(NostrTags.first(tags, 'duration'));
  }

  /// Effective bitrate in bits/sec from the first imeta that declares one.
  int? get bitrate {
    for (final track in tracks) {
      final value = track.bitrate;
      if (value != null) {
        return value;
      }
    }

    return null;
  }

  /// Whether the addressable `d` is present.
  bool get isAddressable => NostrVideoKind.isAddressable(kind);

  /// Whether this is a short-form video.
  bool get isShort => NostrVideoKind.isShort(kind);

  /// Parses [event], throwing [ArgumentError] when it is not a valid video.
  static NostrVideoEvent parse(NostrEvent event) {
    final kind = event.kind;
    if (!NostrVideoKind.isVideoKind(kind)) {
      throw ArgumentError.value(kind, 'event.kind', 'Not a NIP-71 video kind');
    }

    final tags = event.tags ?? const <List<String>>[];

    final title = NostrTags.first(tags, 'title');
    if (title == null || title.trim().isEmpty) {
      throw ArgumentError('Video events require a non-empty title tag');
    }

    final dTag = NostrTags.first(tags, 'd');
    if (NostrVideoKind.requiresD(kind!)) {
      if (dTag == null || dTag.isEmpty) {
        throw ArgumentError('Kind $kind requires a non-empty d tag');
      }
    } else if (NostrTags.has(tags, 'd')) {
      throw ArgumentError('Regular video kinds must not carry a d tag');
    }

    final tracks = <NostrVideoTrack>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != NostrNip92.tagName) {
        continue;
      }

      final imeta = NostrImeta.tryParse(tag);
      if (imeta == null) {
        continue;
      }

      final track = NostrVideoTrack(imeta);
      if ((track.duration ?? 0) < 0 ||
          (track.bitrate ?? 0) < 0 ||
          (imeta['waveform'] != null && track.waveform.isEmpty)) {
        continue;
      }

      tracks.add(track);
    }

    if (!tracks.any((track) => track.isVideo || track.isAudio)) {
      throw ArgumentError(
        'Video events require an imeta tag with a video/ or audio/ MIME type',
      );
    }

    final durationTag = NostrTags.first(tags, 'duration');
    if (durationTag != null &&
        NostrValidators.tryInt(durationTag, min: 0) == null) {
      throw ArgumentError.value(
        durationTag,
        'duration',
        'Expected a non-negative integer of seconds',
      );
    }

    final publishedAtTag = NostrTags.first(tags, 'published_at');
    final publishedAt = publishedAtTag == null
        ? null
        : NostrValidators.tryUnixSeconds(publishedAtTag);
    if (publishedAtTag != null && publishedAt == null) {
      throw ArgumentError.value(
        publishedAtTag,
        'published_at',
        'Expected non-negative UNIX seconds',
      );
    }

    final segments = <NostrVideoSegment>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'segment') {
        continue;
      }

      final start = tag.length > 1 ? _parseSeconds(tag[1]) : null;
      final end = tag.length > 2 ? _parseSeconds(tag[2]) : null;
      if (start == null || end == null || end <= start) {
        throw ArgumentError.value(
          tag,
          'segment',
          'Segment start/end must be HH:MM:SS.sss or seconds, with end > start',
        );
      }

      segments.add(
        NostrVideoSegment(
          start: start,
          end: end,
          title: NostrTags.at(tag, 3),
          thumbnail: NostrTags.at(tag, 4),
        ),
      );
    }

    final textTracks = <NostrVideoTextTrack>[];
    for (final tag in tags) {
      if (tag.length < 2 || tag.first != 'text-track') {
        continue;
      }

      final encoded = tag[1];
      if (encoded.trim().isEmpty) {
        continue;
      }

      textTracks.add(
        NostrVideoTextTrack(event: encoded, relays: tag.sublist(2)),
      );
    }

    final originTag = NostrTags.tag(tags, 'origin');
    NostrVideoOrigin? origin;
    if (originTag != null) {
      if (originTag.length < 3 ||
          originTag[1].trim().isEmpty ||
          originTag[2].trim().isEmpty) {
        throw ArgumentError.value(
          originTag,
          'origin',
          'Origin requires a non-empty platform and external id',
        );
      }

      origin = NostrVideoOrigin(
        platform: originTag[1],
        externalId: originTag[2],
        url: NostrTags.at(originTag, 3),
        metadata: NostrTags.at(originTag, 4),
      );
    }

    return NostrVideoEvent(
      id: event.id,
      pubkey: event.pubkey,
      kind: kind,
      title: title,
      description: event.content ?? '',
      publishedAt: publishedAt,
      alt: NostrTags.first(tags, 'alt'),
      contentWarning: NostrTags.first(tags, 'content-warning'),
      dTag: dTag,
      tracks: List<NostrVideoTrack>.unmodifiable(tracks),
      segments: List<NostrVideoSegment>.unmodifiable(segments),
      textTracks: List<NostrVideoTextTrack>.unmodifiable(textTracks),
      hashtags: NostrTags.all(tags, 't'),
      participants: NostrTags.all(tags, 'p'),
      references: NostrTags.all(tags, 'r'),
      origin: origin,
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for non-video or invalid events.
  static NostrVideoEvent? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid NIP-71 video event.
  static bool validate(NostrEvent event) => tryParse(event) != null;
}

/// {@template nip71}
/// NIP-71 video events (21/22/34235/34236).
///
/// [generateTemplate] builds an unsigned event, [publish] signs through the
/// bound signer. New events carry `duration`/`bitrate` inside `imeta` only;
/// parsing still accepts the older top-level `duration` tag.
/// {@endtemplate}
class NostrNip71 {
  /// {@macro nip71}
  NostrNip71({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Builds an unsigned video event.
  ///
  /// Pass either ready [imeta] tags or a single [url]/[mime] pair. Addressable
  /// [kind]s require [dTag]; regular kinds must not set it.
  NostrEvent generateTemplate({
    required String title,
    String description = '',
    int kind = NostrVideoKind.normal,
    String? dTag,
    List<NostrImeta>? imeta,
    String? url,
    String? mime,
    String? dim,
    String? alt,
    int? publishedAt,
    List<NostrVideoSegment> segments = const [],
    List<String> hashtags = const [],
    List<String> participants = const [],
    List<String> references = const [],
    String? contentWarning,
    int? duration,
    int? bitrate,
    String? language,
    String languageType = 'ISO-639-1',
    bool originalLanguage = false,
    List<int> waveform = const [],
    NostrVideoOrigin? origin,
    List<NostrVideoTextTrack> textTracks = const [],
    DateTime? createdAt,
  }) {
    if (!NostrVideoKind.isVideoKind(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Not a NIP-71 video kind');
    }

    if (NostrVideoKind.requiresD(kind)) {
      if (dTag == null || dTag.isEmpty) {
        throw ArgumentError.value(
          dTag,
          'dTag',
          'Addressable video kinds require a non-empty d tag',
        );
      }
    } else if (dTag != null) {
      throw ArgumentError.value(
        dTag,
        'dTag',
        'Regular video kinds must not carry a d tag',
      );
    }

    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title must not be empty');
    }

    final mediaTags = <List<String>>[
      if (imeta != null)
        for (final entry in imeta)
          _withMediaProperties(
            entry.toTag(),
            duration: duration,
            bitrate: bitrate,
            language: language,
            languageType: languageType,
            originalLanguage: originalLanguage,
            waveform: waveform,
          ),
      if (url != null)
        _imetaTag(
          url: url,
          mime: mime,
          dim: dim,
          alt: alt,
          duration: duration,
          bitrate: bitrate,
          language: language,
          languageType: languageType,
          originalLanguage: originalLanguage,
          waveform: waveform,
        ),
    ];

    if (mediaTags.isEmpty) {
      throw ArgumentError('Provide imeta tags or a media url');
    }

    final event = NostrEvent(
      id: null,
      kind: kind,
      content: description,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (dTag != null) ['d', dTag],
        ['title', title],
        if (publishedAt != null) ['published_at', '$publishedAt'],
        if (alt != null) ['alt', alt],
        ...mediaTags,
        for (final track in textTracks)
          ['text-track', track.event, ...track.relays],
        if (contentWarning != null) ['content-warning', contentWarning],
        for (final segment in segments) segment.toTag(),
        for (final participant in participants) ['p', participant],
        for (final hashtag in hashtags) ['t', hashtag],
        for (final reference in references) ['r', reference],
        if (origin != null) origin.toTag(),
      ],
    );

    NostrVideoEvent.parse(event);

    return event;
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  static List<String> _imetaTag({
    required String url,
    String? mime,
    String? dim,
    String? alt,
    int? duration,
    int? bitrate,
    String? language,
    String languageType = 'ISO-639-1',
    bool originalLanguage = false,
    List<int> waveform = const [],
  }) {
    if (mime == null || mime.isEmpty) {
      throw ArgumentError.value(mime, 'mime', 'imeta requires a MIME type');
    }

    return [
      NostrNip92.tagName,
      'url $url',
      'm $mime',
      if (dim != null && dim.isNotEmpty) 'dim $dim',
      if (alt != null && alt.isNotEmpty) 'alt $alt',
      if (duration != null) 'duration $duration',
      if (bitrate != null) 'bitrate $bitrate',
      if (waveform.isNotEmpty) 'waveform ${waveform.join(' ')}',
      if (language != null && language.isNotEmpty)
        'l $language $languageType${originalLanguage ? ' ov' : ''}',
    ];
  }

  /// Adds [duration]/[bitrate]/[waveform]/[language] to [tag] when absent.
  static List<String> _withMediaProperties(
    List<String> tag, {
    int? duration,
    int? bitrate,
    String? language,
    String languageType = 'ISO-639-1',
    bool originalLanguage = false,
    List<int> waveform = const [],
  }) {
    final imeta = NostrImeta.parse(tag);
    final additions = <String>[
      if (duration != null && imeta['duration'] == null) 'duration $duration',
      if (bitrate != null && imeta['bitrate'] == null) 'bitrate $bitrate',
      if (waveform.isNotEmpty && imeta['waveform'] == null)
        'waveform ${waveform.join(' ')}',
      if (language != null && language.isNotEmpty && imeta['l'] == null)
        'l $language $languageType${originalLanguage ? ' ov' : ''}',
    ];

    return additions.isEmpty ? tag : [...tag, ...additions];
  }
}

/// Parses `HH:MM:SS.sss` or bare seconds, returning `null` for anything else.
double? _parseSeconds(String value) {
  final parts = value.trim().split(':');
  if (parts.length == 1) {
    final seconds = double.tryParse(parts[0]);

    return seconds != null && seconds.isFinite && seconds >= 0 ? seconds : null;
  }

  if (parts.length != 3) {
    return null;
  }

  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final seconds = double.tryParse(parts[2]);
  if (hours == null ||
      minutes == null ||
      seconds == null ||
      hours < 0 ||
      minutes < 0 ||
      minutes > 59 ||
      seconds < 0 ||
      seconds >= 60 ||
      !seconds.isFinite) {
    return null;
  }

  return hours * 3600 + minutes * 60 + seconds;
}

/// Formats seconds as `HH:MM:SS.sss` with millisecond precision.
String _formatSeconds(double value) {
  final totalMillis = (value * 1000).round();
  final hours = totalMillis ~/ 3600000;
  final minutes = (totalMillis % 3600000) ~/ 60000;
  final seconds = (totalMillis % 60000) ~/ 1000;
  final millis = totalMillis % 1000;
  String pad(int number, int width) => number.toString().padLeft(width, '0');

  return '${pad(hours, 2)}:${pad(minutes, 2)}:${pad(seconds, 2)}'
      '.${pad(millis, 3)}';
}
