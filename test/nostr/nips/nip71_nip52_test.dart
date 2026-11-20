import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip52/nip52.dart';
import 'package:dart_nostr/nostr/nips/nip71/nip71.dart';
import 'package:dart_nostr/nostr/nips/nip92/nip92.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

const String _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _hash =
    '3093509d1e0bc604ff60cb9286f4cd7c781553bc8991937befaacfdc28ec5cdc';
const String _audioHash =
    'b2e0a7a82ac9f3f3a71f1d9a78c381d5be9d1cf19dce258765c17c8a76287c93';

NostrEvent _event(
  List<List<String>> tags, {
  int kind = NostrVideoKind.normal,
  String content = 'Description',
  String pubkey = _pubkey,
}) {
  return NostrEvent(
    id: null,
    kind: kind,
    content: content,
    sig: null,
    pubkey: pubkey,
    createdAt: DateTime.utc(2024),
    tags: tags,
  );
}

/// Tag arrays taken from 71.md at the pinned spec revision.
const String _audioWaveform =
    '0 7 35 8 100 100 49 8 4 16 8 10 7 2 20 10 100 100 100 100 100 100 15 '
    '100 100 100 25 60 5 4 3 1 0 100 100 15 100 29 88 0 33 11 39 100 100 '
    '19 4 100 42 35 5 0 1 5 0 0 11 38 100 94 17 11 44 58 5 100 100 100 55 '
    '14 72 100 100 57 6 1 14 2 16 100 100 40 16 100 100 6 32 14 13 41 36 '
    '16 14 6 3 0 1 2 1 6 0';

const List<List<String>> _regularVideoTags = [
  ['title', 'My video'],
  ['published_at', '1700000000'],
  ['alt', 'Video description'],
  [
    'imeta',
    'dim 1920x1080',
    'url https://myvideo.com/1080/12345.mp4',
    'x $_hash',
    'm video/mp4',
    'image https://myvideo.com/1080/12345.jpg',
    'image https://myotherserver.com/1080/12345.jpg',
    'fallback https://myotherserver.com/1080/12345.mp4',
    'fallback https://andanotherserver.com/1080/12345.mp4',
    'service nip96',
  ],
  ['text-track', '<encoded kind 6000 event>', 'wss://relay.example'],
  ['content-warning', 'nsfw'],
  ['segment', '0', '30', 'Intro', 'https://myvideo.com/0.jpg'],
  ['p', _otherPubkey],
  ['t', 'nostr'],
  ['r', 'https://example.com'],
];

const List<List<String>> _addressableVideoTags = [
  ['d', 'video-1'],
  ['title', 'Addressable video'],
  ['published_at', '1700000000'],
  ['alt', 'Accessibility description'],
  [
    'imeta',
    'url https://example.com/media.mp4',
    'm video/mp4',
    'dim 480x480',
    'blurhash eVF\$^OI:\${M{%LRjWBoLoLaeR*',
    'image https://example.com/thumb.jpg',
    'x $_hash',
  ],
  [
    'imeta',
    'url https://example.com/audio.mp3',
    'x $_audioHash',
    'm audio/mp3',
    'l en ISO-639-1 ov',
  ],
  ['duration', '29'],
  ['content-warning', 'nsfw'],
  [
    'origin',
    'youtube',
    'abc123',
    'https://youtube.com/watch?v=abc123',
    'imported',
  ],
  ['p', _otherPubkey],
  ['t', 'music'],
  ['r', 'https://example.com'],
];

void main() {
  group('NIP-71 kinds', () {
    test('constants and predicates', () {
      expect(NostrVideoKind.normal, 21);
      expect(NostrVideoKind.short, 22);
      expect(NostrVideoKind.addressableNormal, 34235);
      expect(NostrVideoKind.addressableShort, 34236);
      expect(NostrVideoKind.isVideoKind(21), isTrue);
      expect(NostrVideoKind.isVideoKind(34236), isTrue);
      expect(NostrVideoKind.isVideoKind(1111), isFalse);
      expect(NostrVideoKind.isAddressable(34235), isTrue);
      expect(NostrVideoKind.isAddressable(21), isFalse);
      expect(NostrVideoKind.requiresD(34236), isTrue);
      expect(NostrVideoKind.requiresD(22), isFalse);
      expect(NostrVideoKind.isShort(22), isTrue);
      expect(NostrVideoKind.isShort(34236), isTrue);
      expect(NostrVideoKind.isShort(34235), isFalse);
    });
  });

  group('NIP-71 parsing', () {
    test('parses the regular kind-21 vector', () {
      final event = _event(_regularVideoTags);
      final video = NostrVideoEvent.parse(event);

      expect(video.title, 'My video');
      expect(video.description, 'Description');
      expect(video.publishedAt, 1700000000);
      expect(video.alt, 'Video description');
      expect(video.contentWarning, 'nsfw');
      expect(video.dTag, isNull);
      expect(video.isAddressable, isFalse);
      expect(video.tracks, hasLength(1));
      expect(video.videoTracks.single.mime, 'video/mp4');
      expect(video.videoTracks.single.dim, '1920x1080');
      expect(
          video.videoTracks.single.url, 'https://myvideo.com/1080/12345.mp4');
      expect(video.audioTracks, isEmpty);
      expect(video.segments.single.start, 0);
      expect(video.segments.single.end, 30);
      expect(video.segments.single.title, 'Intro');
      expect(
        video.segments.single.thumbnail,
        'https://myvideo.com/0.jpg',
      );
      expect(video.textTracks.single.event, '<encoded kind 6000 event>');
      expect(video.textTracks.single.relays, ['wss://relay.example']);
      expect(video.participants, [_otherPubkey]);
      expect(video.hashtags, ['nostr']);
      expect(video.references, ['https://example.com']);
      expect(video.tags, _regularVideoTags);
    });

    test('parses the addressable 34235 vector with audio variant', () {
      final video = NostrVideoEvent.parse(
        _event(_addressableVideoTags, kind: NostrVideoKind.addressableNormal),
      );

      expect(video.kind, 34235);
      expect(video.dTag, 'video-1');
      expect(video.isAddressable, isTrue);
      expect(video.tracks, hasLength(2));
      expect(video.videoTracks, hasLength(1));
      expect(video.audioTracks, hasLength(1));

      final audio = video.audioTracks.single;
      expect(audio.url, 'https://example.com/audio.mp3');
      expect(audio.mime, 'audio/mp3');
      expect(audio.language, 'en');
      expect(audio.isOriginalLanguage, isTrue);

      expect(video.duration, 29);
      expect(video.origin?.platform, 'youtube');
      expect(video.origin?.externalId, 'abc123');
      expect(
        video.origin?.url,
        'https://youtube.com/watch?v=abc123',
      );
      expect(video.origin?.metadata, 'imported');
      expect(video.tags, _addressableVideoTags);
    });

    test('imeta duration wins over the legacy duration tag (R2)', () {
      final video = NostrVideoEvent.parse(
        _event([
          ['title', 'T'],
          [
            'imeta',
            'url https://example.com/v.mp4',
            'm video/mp4',
            'duration 29.223',
          ],
          ['duration', '30'],
        ]),
      );

      expect(video.duration, 29.223);
      expect(video.tracks.single.duration, 29.223);
    });

    test('parses waveform and rejects malformed waveform values', () {
      final track = NostrVideoEvent.parse(
        _event([
          ['title', 'T'],
          [
            'imeta',
            'url https://example.com/a.mp3',
            'm audio/mp3',
            'waveform $_audioWaveform',
          ],
        ]),
      ).audioTracks.single;

      expect(track.waveform.first, 0);
      expect(track.waveform.last, 0);
      expect(track.waveform.length, greaterThan(50));

      final original = NostrVideoEvent.parse(
        _event([
          ['title', 'T'],
          ['imeta', 'url https://example.com/a.mp3', 'm audio/mp3', 'ov'],
        ]),
      ).audioTracks.single;
      expect(original.isOriginalLanguage, isTrue);
      expect(original.language, isNull);

      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/a.mp3',
              'm audio/mp3',
              'waveform loud',
            ],
          ]),
        ),
        isNull,
      );
      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/a.mp3',
              'm audio/mp3',
              'waveform 1 x 3',
            ],
          ]),
        ),
        isNull,
      );
    });

    test('treats HLS playlist MIME types as video', () {
      for (final mime in const [
        'application/x-mpegURL',
        'application/vnd.apple.mpegurl',
      ]) {
        final video = NostrVideoEvent.parse(
          _event([
            ['title', 'T'],
            ['imeta', 'url https://example.com/live.m3u8', 'm $mime'],
          ]),
        );

        expect(video.videoTracks, hasLength(1));
        expect(video.videoTracks.single.isVideo, isTrue);
      }

      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['title', 'T'],
            ['imeta', 'url https://x/v.bin', 'm application/octet-stream'],
          ]),
        ),
        isNull,
      );
    });

    test('skips malformed imeta tags but keeps valid ones', () {
      final video = NostrVideoEvent.parse(
        _event([
          ['title', 'T'],
          ['imeta', 'm video/mp4'],
          ['imeta'],
          [
            'imeta',
            'url https://example.com/a.mp3',
            'm audio/mp3',
            'waveform 1 x 3',
          ],
          [
            'imeta',
            'url https://example.com/v.mp4',
            'm video/mp4',
            'duration -1',
          ],
          ['imeta', 'url https://example.com/ok.mp4', 'm video/mp4'],
        ]),
      );

      expect(video.tracks, hasLength(1));
      expect(video.tracks.single.url, 'https://example.com/ok.mp4');

      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['title', 'T'],
            ['imeta', 'm video/mp4'],
          ]),
        ),
        isNull,
      );
    });

    test('skips malformed text-track tags without discarding the event', () {
      final video = NostrVideoEvent.parse(
        _event([
          ['title', 'T'],
          ['imeta', 'url https://example.com/v.mp4', 'm video/mp4'],
          ['text-track'],
          ['text-track', ''],
          ['text-track', 'encoded', 'wss://relay.example'],
        ]),
      );

      expect(video.textTracks, hasLength(1));
      expect(video.textTracks.single.event, 'encoded');
      expect(video.textTracks.single.relays, ['wss://relay.example']);
    });

    test('rejects empty origin platform or external id', () {
      for (final origin in const [
        ['origin', '', 'abc'],
        ['origin', 'youtube', ''],
        ['origin', 'youtube'],
      ]) {
        expect(
          NostrVideoEvent.tryParse(
            _event([
              ['title', 'T'],
              ['imeta', 'url https://example.com/v.mp4', 'm video/mp4'],
              origin,
            ]),
          ),
          isNull,
        );
      }
    });
  });

  group('NIP-71 validation', () {
    test('rejects missing title, bad d placement and missing media', () {
      expect(
        NostrVideoEvent.tryParse(
          _event([
            [
              'imeta',
              'url https://example.com/v.mp4',
              'm video/mp4',
            ],
          ]),
        ),
        isNull,
      );

      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/v.mp4',
              'm video/mp4',
            ],
          ], kind: NostrVideoKind.addressableNormal),
        ),
        isNull,
      );

      expect(
        NostrVideoEvent.tryParse(
          _event(_regularVideoTags, kind: NostrVideoKind.addressableNormal),
        ),
        isNull,
      );

      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['d', 'x'],
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/v.mp4',
              'm video/mp4',
            ],
          ], kind: NostrVideoKind.short),
        ),
        isNull,
      );

      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/v.mp4',
              'm image/png',
            ],
          ]),
        ),
        isNull,
      );

      expect(
        () => NostrVideoEvent.parse(_event(const [])),
        throwsArgumentError,
      );
    });

    test('rejects bad segments and durations', () {
      NostrEvent videoWith(List<String> extra) => _event([
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/v.mp4',
              'm video/mp4',
            ],
            extra,
          ]);

      expect(
        NostrVideoEvent.tryParse(
          videoWith(['segment', '10', '10', 'chapter']),
        ),
        isNull,
      );
      expect(
        NostrVideoEvent.tryParse(
          videoWith(['segment', 'abc', '20', 'chapter']),
        ),
        isNull,
      );
      expect(NostrVideoEvent.tryParse(videoWith(['duration', '-1'])), isNull);
      expect(
        NostrVideoEvent.tryParse(
          _event([
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/v.mp4',
              'm video/mp4',
              'duration -5',
            ],
          ]),
        ),
        isNull,
      );
    });
  });

  group('NIP-71 generation', () {
    late NostrNip71 nip71;

    setUp(() {
      nip71 = NostrNip71(
        signer: NostrLocalKeySigner(NostrKeyPairs.generate()),
      );
    });

    test('emits the exact kind-21 tag array', () {
      final event = nip71.generateTemplate(
        title: 'Title',
        description: 'Description',
        publishedAt: 1700000000,
        url: 'https://cdn.example/v.mp4',
        mime: 'video/mp4',
        dim: '1920x1080',
        alt: 'Alt text',
        duration: 30,
        bitrate: 3000000,
        segments: [
          const NostrVideoSegment(
            start: 30,
            end: 60.5,
            title: 'Intro',
            thumbnail: 'https://cdn.example/0.jpg',
          ),
        ],
        hashtags: const ['nostr'],
        contentWarning: 'nsfw',
      );

      expect(event.kind, NostrVideoKind.normal);
      expect(event.content, 'Description');
      expect(event.tags, [
        ['title', 'Title'],
        ['published_at', '1700000000'],
        ['alt', 'Alt text'],
        [
          'imeta',
          'url https://cdn.example/v.mp4',
          'm video/mp4',
          'dim 1920x1080',
          'alt Alt text',
          'duration 30',
          'bitrate 3000000',
        ],
        ['content-warning', 'nsfw'],
        [
          'segment',
          '00:00:30.000',
          '00:01:00.500',
          'Intro',
          'https://cdn.example/0.jpg',
        ],
        ['t', 'nostr'],
      ]);

      final parsed = NostrVideoEvent.parse(event).segments.single;
      expect(parsed.start, 30);
      expect(parsed.end, 60.5);
    });

    test('parses spec HH:MM:SS.sss segments and bare seconds', () {
      NostrEvent withSegment(List<String> segment) => _event([
            ['title', 'T'],
            [
              'imeta',
              'url https://example.com/v.mp4',
              'm video/mp4',
            ],
            segment,
          ]);

      final spec = NostrVideoEvent.parse(
        withSegment(['segment', '00:00:30.000', '00:01:00.500', 'Intro']),
      );
      expect(spec.segments.single.start, 30.0);
      expect(spec.segments.single.end, 60.5);

      final bare =
          NostrVideoEvent.parse(withSegment(['segment', '30', '60.5']));
      expect(bare.segments.single.start, 30);
      expect(bare.segments.single.end, 60.5);

      expect(
        NostrVideoEvent.tryParse(
          withSegment(['segment', '00:00:30', '00:00:30.000']),
        ),
        isNull,
      );
      expect(
        NostrVideoEvent.tryParse(
          withSegment(['segment', '1:2:3:4', '00:00:30.000']),
        ),
        isNull,
      );
      expect(
        NostrVideoEvent.tryParse(
          withSegment(['segment', '00:61:00.000', '00:62:00.000']),
        ),
        isNull,
      );
    });

    test('emits the exact audio-track imeta tag', () {
      final event = nip71.generateTemplate(
        kind: NostrVideoKind.addressableShort,
        dTag: 'audio-1',
        title: 'Audio',
        url: 'https://cdn.example/a.mp3',
        mime: 'audio/mp3',
        language: 'en',
        originalLanguage: true,
        waveform: const [0, 7, 35],
        duration: 12,
      );

      expect(event.tags, [
        ['d', 'audio-1'],
        ['title', 'Audio'],
        [
          'imeta',
          'url https://cdn.example/a.mp3',
          'm audio/mp3',
          'duration 12',
          'waveform 0 7 35',
          'l en ISO-639-1 ov',
        ],
      ]);
      expect(
        NostrVideoEvent.parse(event).audioTracks.single.language,
        'en',
      );
    });

    test('appends duration to supplied imeta tags without one', () {
      final event = nip71.generateTemplate(
        title: 'T',
        imeta: [
          NostrImeta.parse(
            const ['imeta', 'url https://x/v.mp4', 'm video/mp4'],
          ),
          NostrImeta.parse(
            const [
              'imeta',
              'url https://x/a.mp3',
              'm audio/mp3',
              'duration 5',
            ],
          ),
        ],
        duration: 9,
      );

      final media =
          event.tags!.where((tag) => tag.first == NostrNip92.tagName).toList();
      expect(media[0], [
        'imeta',
        'url https://x/v.mp4',
        'm video/mp4',
        'duration 9',
      ]);
      expect(media[1], [
        'imeta',
        'url https://x/a.mp3',
        'm audio/mp3',
        'duration 5',
      ]);
    });

    test('applies bitrate, waveform and language to supplied imeta tags', () {
      final event = nip71.generateTemplate(
        title: 'T',
        imeta: [
          NostrImeta.parse(
            const ['imeta', 'url https://x/a.mp3', 'm audio/mp3'],
          ),
        ],
        bitrate: 128000,
        waveform: const [1, 2],
        language: 'fr',
        languageType: 'none',
        originalLanguage: true,
      );

      final media =
          event.tags!.singleWhere((tag) => tag.first == NostrNip92.tagName);
      expect(media, [
        'imeta',
        'url https://x/a.mp3',
        'm audio/mp3',
        'bitrate 128000',
        'waveform 1 2',
        'l fr none ov',
      ]);

      final track = NostrVideoEvent.parse(event).tracks.single;
      expect(track.bitrate, 128000);
      expect(track.waveform, [1, 2]);
      expect(track.language, 'fr');
      expect(track.isOriginalLanguage, isTrue);
    });

    test('rejects addressable kinds without d and regular kinds with d', () {
      expect(
        () => nip71.generateTemplate(
          title: 'T',
          kind: NostrVideoKind.addressableNormal,
          url: 'https://x/v.mp4',
          mime: 'video/mp4',
        ),
        throwsArgumentError,
      );
      expect(
        () => nip71.generateTemplate(
          title: 'T',
          dTag: 'x',
          url: 'https://x/v.mp4',
          mime: 'video/mp4',
        ),
        throwsArgumentError,
      );
    });

    test('publish signs through the bound signer', () async {
      final event = nip71.generateTemplate(
        title: 'T',
        url: 'https://x/v.mp4',
        mime: 'video/mp4',
      );
      final signed = await nip71.publish(event);

      expect(signed.pubkey, nip71.signer.publicKey);
      expect(signed.id, isNotNull);
      expect(signed.sig, isNotNull);
      expect(NostrVideoEvent.parse(signed).title, 'T');
    });
  });

  group('NIP-52 kinds', () {
    test('constants and predicates', () {
      expect(NostrCalendarKind.dateEvent, 31922);
      expect(NostrCalendarKind.timeEvent, 31923);
      expect(NostrCalendarKind.calendar, 31924);
      expect(NostrCalendarKind.rsvp, 31925);
      expect(NostrCalendarKind.isCalendarEvent(31922), isTrue);
      expect(NostrCalendarKind.isCalendarEvent(31923), isTrue);
      expect(NostrCalendarKind.isCalendarEvent(31924), isFalse);
    });
  });

  group('NIP-52 calendar events', () {
    test('parses the time-based vector with D 82549', () {
      const start = 82549 * 86400;
      final event = _event(
        [
          ['d', 'event-1'],
          ['title', 'Calendar event'],
          ['summary', 'Brief description'],
          ['image', 'https://example.com/image.jpg'],
          ['start', '$start'],
          ['end', '${start + 7200}'],
          ['D', '82549'],
          ['start_tzid', 'America/Costa_Rica'],
          ['end_tzid', 'America/Costa_Rica'],
          ['location', 'San Jose'],
          ['g', '9q8yyk8ytpxr'],
          ['p', _otherPubkey],
        ],
        kind: NostrCalendarKind.timeEvent,
      );

      final parsed = NostrCalendarEvent.parse(event);
      expect(parsed.isTimeBased, isTrue);
      expect(parsed.dTag, 'event-1');
      expect(parsed.title, 'Calendar event');
      expect(parsed.summary, 'Brief description');
      expect(parsed.image, 'https://example.com/image.jpg');
      expect(parsed.startSeconds, start);
      expect(parsed.endSeconds, start + 7200);
      expect(parsed.startTzid, 'America/Costa_Rica');
      expect(parsed.endTzid, 'America/Costa_Rica');
      expect(parsed.effectiveEndTzid, 'America/Costa_Rica');
      expect(parsed.days, [82549]);
      expect(NostrTags.all(event.tags, 'D'), ['82549']);
      expect(parsed.geohash, '9q8yyk8ytpxr');
      expect(parsed.startsAt,
          DateTime.fromMillisecondsSinceEpoch(start * 1000, isUtc: true));
    });

    test('recomputes D and rejects a mismatched tag', () {
      const start = 82549 * 86400;
      NostrEvent withD(String day) => _event(
            [
              ['d', 'event-1'],
              ['title', 'T'],
              ['start', '$start'],
              ['D', day],
            ],
            kind: NostrCalendarKind.timeEvent,
          );

      expect(NostrCalendarEvent.tryParse(withD('82549')), isNotNull);
      expect(NostrCalendarEvent.tryParse(withD('82550')), isNull);
      expect(
        () => NostrCalendarEvent.parse(withD('82550')),
        throwsArgumentError,
      );
      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'event-1'],
              ['title', 'T'],
              ['start', '$start'],
            ],
            kind: NostrCalendarKind.timeEvent,
          ),
        ),
        isNull,
      );
    });

    test('covers each UTC day of a multi-day range', () {
      const start = 100 * 86400 + 100;
      const end = start + 2 * 86400;

      expect(NostrCalendarEvent.daysFor(start: start, end: end), [
        100,
        101,
        102,
      ]);
      expect(
        () => NostrCalendarEvent.daysFor(start: 100, end: 100),
        throwsArgumentError,
      );
      expect(
        () => NostrCalendarEvent.daysFor(start: 101, end: 100),
        throwsArgumentError,
      );
      expect(
        () => NostrCalendarEvent.daysFor(
          start: 0,
          end: 366 * 50 * 86400 + 1,
        ),
        throwsArgumentError,
      );
      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'event-1'],
              ['title', 'T'],
              ['start', '$start'],
              ['end', '$end'],
              ['D', '100'],
              ['D', '101'],
              ['D', '102'],
            ],
            kind: NostrCalendarKind.timeEvent,
          ),
        ),
        isNotNull,
      );
      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'event-1'],
              ['title', 'T'],
              ['start', '$start'],
              ['end', '$end'],
              ['D', '100'],
              ['D', '101'],
            ],
            kind: NostrCalendarKind.timeEvent,
          ),
        ),
        isNull,
      );
    });

    test('rejects invalid time ranges and time zones', () {
      NostrEvent time(Map<String, String?> tags) => _event(
            [
              ['d', 'event-1'],
              ['title', 'T'],
              for (final entry in tags.entries)
                if (entry.value != null) [entry.key, entry.value!],
            ],
            kind: NostrCalendarKind.timeEvent,
          );

      expect(
        NostrCalendarEvent.tryParse(
          time({'start': '1000', 'end': '1000', 'D': '0'}),
        ),
        isNull,
      );
      expect(
        NostrCalendarEvent.tryParse(
          time({'start': '1000', 'D': '0', 'start_tzid': 'not a zone'}),
        ),
        isNull,
      );
      expect(
        NostrCalendarEvent.tryParse(
          time({'start': '1000', 'D': '0', 'start_tzid': 'GMT'}),
        ),
        isNotNull,
      );
      expect(
        NostrCalendarEvent.tryParse(
          time({'start': 'not-seconds', 'D': '0'}),
        ),
        isNull,
      );
      expect(
        NostrCalendarEvent.tryParse(
          time({
            'start': '0',
            'end': '${366 * 50 * 86400 + 1}',
            'D': '0',
          }),
        ),
        isNull,
      );
    });

    test('parses date-based events and enforces exclusive end', () {
      final parsed = NostrCalendarEvent.parse(
        _event(
          [
            ['d', 'date-1'],
            ['title', 'Conference'],
            ['start', '2024-05-01'],
            ['end', '2024-05-03'],
          ],
          kind: NostrCalendarKind.dateEvent,
        ),
      );

      expect(parsed.isDateBased, isTrue);
      expect(parsed.startDate, '2024-05-01');
      expect(parsed.endDate, '2024-05-03');
      expect(parsed.startsAt, DateTime.utc(2024, 5, 1));
      expect(parsed.endsAt, DateTime.utc(2024, 5, 3));

      for (final range in const [
        ['2024-05-03', '2024-05-03'],
        ['2024-05-03', '2024-05-02'],
      ]) {
        expect(
          NostrCalendarEvent.tryParse(
            _event(
              [
                ['d', 'date-1'],
                ['title', 'T'],
                ['start', range[0]],
                ['end', range[1]],
              ],
              kind: NostrCalendarKind.dateEvent,
            ),
          ),
          isNull,
        );
      }

      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'date-1'],
              ['title', 'T'],
              ['start', '2024-05-01'],
              ['start_tzid', 'UTC'],
            ],
            kind: NostrCalendarKind.dateEvent,
          ),
        ),
        isNull,
      );
      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'date-1'],
              ['title', 'T'],
              ['start', '2024-5-1'],
            ],
            kind: NostrCalendarKind.dateEvent,
          ),
        ),
        isNull,
      );
    });

    test('rejects invalid ISO dates', () {
      for (final date in const ['2024-02-31', '2024-13-01', '2023-02-29']) {
        expect(
          NostrCalendarEvent.tryParse(
            _event(
              [
                ['d', 'date-1'],
                ['title', 'T'],
                ['start', date],
              ],
              kind: NostrCalendarKind.dateEvent,
            ),
          ),
          isNull,
          reason: date,
        );
      }

      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'date-1'],
              ['title', 'T'],
              ['start', '2024-02-29'],
            ],
            kind: NostrCalendarKind.dateEvent,
          ),
        ),
        isNotNull,
      );
    });

    test('ignores undefined legacy time/timezone tags on date events', () {
      final parsed = NostrCalendarEvent.parse(
        _event(
          [
            ['d', 'date-1'],
            ['title', 'T'],
            ['start', '2024-05-01'],
            ['time', '10:00'],
            ['timezone', 'Europe/Berlin'],
          ],
          kind: NostrCalendarKind.dateEvent,
        ),
      );

      expect(parsed.startDate, '2024-05-01');
    });

    test('validates a references across kinds', () {
      final calendarAddress = '31924:$_otherPubkey:calendar-1';
      final eventAddress = '31923:$_otherPubkey:event-1';

      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'date-1'],
              ['title', 'T'],
              ['start', '2024-05-01'],
              ['a', eventAddress],
            ],
            kind: NostrCalendarKind.dateEvent,
          ),
        ),
        isNull,
      );
      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'date-1'],
              ['title', 'T'],
              ['start', '2024-05-01'],
              ['a', calendarAddress],
            ],
            kind: NostrCalendarKind.dateEvent,
          ),
        ),
        isNotNull,
      );
    });
    test('parses kind-31924 calendars symmetrically', () {
      final event = _event(
        [
          ['d', 'calendar-1'],
          ['title', 'Work'],
          ['a', '31922:$_otherPubkey:date-1'],
        ],
        kind: NostrCalendarKind.calendar,
      );

      final parsed = NostrCalendarEvent.parse(event);
      expect(parsed.kind, NostrCalendarKind.calendar);
      expect(parsed.dTag, 'calendar-1');
      expect(parsed.calendars, ['31922:$_otherPubkey:date-1']);

      expect(
        NostrCalendarEvent.tryParse(
          _event(
            [
              ['d', 'calendar-1'],
              ['title', 'Work'],
              ['a', '31924:$_otherPubkey:other'],
            ],
            kind: NostrCalendarKind.calendar,
          ),
        ),
        isNull,
      );
    });
  });

  group('NIP-52 RSVP', () {
    const address = '31923:$_otherPubkey:event-1';

    test('builds and parses accepted/busy RSVPs', () {
      final event = NostrRsvp.build(
        eventAddress: address,
        dTag: 'rsvp-1',
        status: 'accepted',
        freeBusy: 'busy',
        eventId: _hash,
        eventAuthor: _otherPubkey,
        content: 'See you there',
      );

      final rsvp = NostrRsvp.parse(event);
      expect(rsvp.eventAddress, address);
      expect(rsvp.dTag, 'rsvp-1');
      expect(rsvp.status, 'accepted');
      expect(rsvp.freeBusy, 'busy');
      expect(rsvp.eventId, _hash);
      expect(rsvp.eventAuthor, _otherPubkey);
      expect(rsvp.content, 'See you there');
      expect(event.kind, NostrCalendarKind.rsvp);
    });

    test('omits fb for declined RSVPs and ignores fb on declined input', () {
      final declined = NostrRsvp.build(
        eventAddress: address,
        dTag: 'rsvp-2',
        status: 'declined',
        freeBusy: 'busy',
      );

      expect(NostrTags.has(declined.tags, 'fb'), isFalse);
      expect(NostrRsvp.parse(declined).freeBusy, isNull);

      final handBuilt = _event(
        [
          ['a', address],
          ['d', 'rsvp-3'],
          ['status', 'declined'],
          ['fb', 'busy'],
        ],
        kind: NostrCalendarKind.rsvp,
      );
      final parsed = NostrRsvp.parse(handBuilt);
      expect(parsed.isDeclined, isTrue);
      expect(parsed.freeBusy, isNull);

      expect(
        NostrRsvp.tryParse(
          _event(
            [
              ['a', address],
              ['d', 'rsvp-4'],
              ['status', 'accepted'],
              ['fb', 'maybe'],
            ],
            kind: NostrCalendarKind.rsvp,
          ),
        ),
        isNull,
      );
    });

    test('rejects missing or invalid required fields', () {
      NostrEvent rsvp(List<List<String>> tags) =>
          _event(tags, kind: NostrCalendarKind.rsvp);

      expect(
        NostrRsvp.tryParse(rsvp([
          ['d', 'x'],
          ['status', 'accepted']
        ])),
        isNull,
      );
      expect(
        NostrRsvp.tryParse(
          rsvp([
            ['a', address],
            ['d', 'x'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrRsvp.tryParse(
          rsvp([
            ['a', address],
            ['d', 'x'],
            ['status', 'maybe'],
          ]),
        ),
        isNull,
      );
      expect(
        NostrRsvp.tryParse(
          rsvp([
            ['a', '1:$_otherPubkey:event-1'],
            ['d', 'x'],
            ['status', 'accepted'],
          ]),
        ),
        isNull,
      );
    });
  });

  group('NIP-52 generation', () {
    late NostrNip52 nip52;

    setUp(() {
      nip52 = NostrNip52(
        signer: NostrLocalKeySigner(NostrKeyPairs.generate()),
      );
    });

    test('generates time events with computed D tags', () {
      const start = 82549 * 86400;
      final event = nip52.generateTimeEvent(
        dTag: 'event-1',
        title: 'Calendar event',
        start: start,
        end: start + 7200,
        startTzid: 'America/Costa_Rica',
      );

      expect(event.tags, [
        ['d', 'event-1'],
        ['title', 'Calendar event'],
        ['start', '$start'],
        ['end', '${start + 7200}'],
        ['D', '82549'],
        ['start_tzid', 'America/Costa_Rica'],
      ]);
      expect(NostrCalendarEvent.parse(event).days, [82549]);
      expect(
        NostrCalendarEvent.parse(event).effectiveEndTzid,
        'America/Costa_Rica',
      );
    });

    test('generates date events with exclusive ISO end', () {
      final event = nip52.generateDateEvent(
        dTag: 'date-1',
        title: 'Conference',
        start: '2024-05-01',
        end: '2024-05-03',
        locations: const ['Berlin'],
        hashtags: const ['nostr'],
      );

      expect(event.tags, [
        ['d', 'date-1'],
        ['title', 'Conference'],
        ['start', '2024-05-01'],
        ['end', '2024-05-03'],
        ['location', 'Berlin'],
        ['t', 'nostr'],
      ]);
      expect(NostrCalendarEvent.parse(event).endDate, '2024-05-03');
    });

    test('generates calendars and validates included addresses', () {
      final event = nip52.generateCalendar(
        dTag: 'calendar-1',
        title: 'Work',
        events: const ['31922:$_otherPubkey:date-1'],
      );

      expect(event.kind, NostrCalendarKind.calendar);
      expect(event.tags, [
        ['d', 'calendar-1'],
        ['title', 'Work'],
        ['a', '31922:$_otherPubkey:date-1'],
      ]);
      expect(nip52.tryParseEvent(event)?.dTag, 'calendar-1');
      expect(
        () => nip52.generateCalendar(
          dTag: 'calendar-1',
          title: 'Work',
          events: const ['31924:$_otherPubkey:other'],
        ),
        throwsArgumentError,
      );
      expect(
        () => nip52.generateCalendar(dTag: '', title: 'Work'),
        throwsArgumentError,
      );
      expect(
        () => nip52.generateCalendar(dTag: 'calendar-1', title: ' '),
        throwsArgumentError,
      );
    });

    test('parses and publishes', () async {
      final event = nip52.generateRsvp(
        eventAddress: '31923:$_otherPubkey:event-1',
        dTag: 'rsvp-1',
        status: 'tentative',
      );

      expect(nip52.tryParseEvent(event), isNull);
      expect(nip52.tryParseEvent(_event(const [])), isNull);
      expect(
        () => nip52.parseEvent(_event(const [])),
        throwsArgumentError,
      );

      final timeEvent = nip52.generateTimeEvent(
        dTag: 'event-1',
        title: 'T',
        start: 1000,
      );
      expect(nip52.tryParseEvent(timeEvent)?.title, 'T');

      final signed = await nip52.publish(timeEvent);
      expect(signed.pubkey, nip52.signer.publicKey);
      expect(signed.id, isNotNull);
      expect(NostrCalendarEvent.parse(signed).days, [0]);
    });
  });
}
