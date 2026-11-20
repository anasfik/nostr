import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_calendar_kind}
/// NIP-52 calendar event kinds.
/// {@endtemplate}
class NostrCalendarKind {
  const NostrCalendarKind._();

  /// Date-based calendar event (addressable).
  static const int dateEvent = 31922;

  /// Time-based calendar event (addressable).
  static const int timeEvent = 31923;

  /// Calendar: an addressable list of events (kind 31924).
  static const int calendar = 31924;

  /// Calendar event RSVP (addressable).
  static const int rsvp = 31925;

  /// Every kind defined by NIP-52.
  static const List<int> values = [dateEvent, timeEvent, calendar, rsvp];

  /// Whether [kind] is a date- or time-based calendar event.
  static bool isCalendarEvent(int? kind) =>
      kind == dateEvent || kind == timeEvent;
}

/// {@template nostr_calendar_event}
/// Parsed NIP-52 calendar event (kinds 31922 date-based, 31923 time-based) or
/// calendar list (kind 31924).
///
/// Date-based events use ISO `YYYY-MM-DD` [startDate]/[endDate] and never
/// carry timezone or `D` tags. Time-based events use UNIX seconds
/// [startSeconds]/[endSeconds], optional IANA [startTzid]/[endTzid] and one
/// `D` tag per covered UTC day, recomputed from the range during validation.
/// Calendars carry `a` addresses of the events they include.
/// {@endtemplate}
class NostrCalendarEvent {
  /// {@macro nostr_calendar_event}
  const NostrCalendarEvent({
    this.id,
    required this.pubkey,
    required this.kind,
    required this.dTag,
    required this.title,
    this.description = '',
    this.summary,
    this.image,
    this.startDate,
    this.endDate,
    this.startSeconds,
    this.endSeconds,
    this.startTzid,
    this.endTzid,
    this.days = const [],
    this.locations = const [],
    this.hashtags = const [],
    this.references = const [],
    this.calendars = const [],
    this.participants = const [],
    this.geohash,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// [NostrCalendarKind.dateEvent], [NostrCalendarKind.timeEvent] or
  /// [NostrCalendarKind.calendar].
  final int kind;

  /// Required `d` identifier.
  final String dTag;

  /// Required `title`.
  final String title;

  /// Event content.
  final String description;

  /// Optional `summary`.
  final String? summary;

  /// Optional `image` URL.
  final String? image;

  /// ISO `YYYY-MM-DD` start (date-based only).
  final String? startDate;

  /// ISO `YYYY-MM-DD` exclusive end (date-based only).
  final String? endDate;

  /// Inclusive start in UNIX seconds (time-based only).
  final int? startSeconds;

  /// Exclusive end in UNIX seconds (time-based only).
  final int? endSeconds;

  /// IANA time zone of the start timestamp.
  final String? startTzid;

  /// IANA time zone of the end timestamp.
  final String? endTzid;

  /// [endTzid] when set, otherwise [startTzid] (NIP-52 inheritance).
  String? get effectiveEndTzid => endTzid ?? startTzid;

  /// `D` day numbers: `floor(unix_seconds / 86400)`.
  final List<int> days;

  /// `location` values.
  final List<String> locations;

  /// `t` hashtags.
  final List<String> hashtags;

  /// `r` reference links.
  final List<String> references;

  /// `a` references, to calendars for events and to events for calendars.
  final List<String> calendars;

  /// `p` participant pubkeys.
  final List<String> participants;

  /// `g` geohash.
  final String? geohash;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether this is a date-based event (kind 31922).
  bool get isDateBased => kind == NostrCalendarKind.dateEvent;

  /// Whether this is a time-based event (kind 31923).
  bool get isTimeBased => kind == NostrCalendarKind.timeEvent;

  /// Start as UTC, from [startDate] or [startSeconds].
  DateTime? get startsAt {
    final seconds = startSeconds;
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }

    final date = startDate;

    return date == null ? null : _parseIsoDateUtc(date);
  }

  /// End as UTC, from [endDate] or [endSeconds].
  DateTime? get endsAt {
    final seconds = endSeconds;
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }

    final date = endDate;

    return date == null ? null : _parseIsoDateUtc(date);
  }

  /// Day numbers covered by `[start, end)`, inclusive start and exclusive end.
  ///
  /// Throws [ArgumentError] when [end] is not after [start] or the range
  /// exceeds 50 years, bounding the number of generated `D` tags.
  static List<int> daysFor({required int start, int? end}) {
    if (end == null) {
      return [NostrValidators.dayIndex(start)];
    }

    if (end <= start) {
      throw ArgumentError('End must be greater than start');
    }

    if (end - start > _maxRangeSeconds) {
      throw ArgumentError('Event range must not exceed 50 years');
    }

    final firstDay = NostrValidators.dayIndex(start);
    final lastDay = NostrValidators.dayIndex(end - 1);

    return [for (var day = firstDay; day <= lastDay; day++) day];
  }

  static const int _maxRangeSeconds = 366 * 50 * 86400;

  /// Parses [event], throwing [ArgumentError] when it is not a valid calendar
  /// event, calendar, or event referenced by an invalid kind.
  static NostrCalendarEvent parse(NostrEvent event) {
    final kind = event.kind;
    if (kind != NostrCalendarKind.calendar &&
        !NostrCalendarKind.isCalendarEvent(kind)) {
      throw ArgumentError.value(
        kind,
        'event.kind',
        'Not a NIP-52 calendar event kind',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.isEmpty) {
      throw ArgumentError('Calendar events require a non-empty d tag');
    }

    final title = NostrTags.first(tags, 'title');
    if (title == null || title.trim().isEmpty) {
      throw ArgumentError('Calendar events require a non-empty title tag');
    }

    final calendars = NostrTags.all(tags, 'a');
    final isCalendar = kind == NostrCalendarKind.calendar;
    for (final address in calendars) {
      final parsed = NostrEventAddress.tryParse(address);
      if (parsed == null) {
        throw ArgumentError.value(address, 'a', 'Invalid event address');
      }

      final valid = isCalendar
          ? NostrCalendarKind.isCalendarEvent(parsed.kind)
          : parsed.kind == NostrCalendarKind.calendar;
      if (!valid) {
        throw ArgumentError.value(
          address,
          'a',
          isCalendar
              ? 'Calendars reference kind 31922/31923 events'
              : 'Calendar events reference kind 31924 calendars',
        );
      }
    }

    String? startDate;
    String? endDate;
    int? startSeconds;
    int? endSeconds;
    String? startTzid;
    String? endTzid;
    var days = const <int>[];

    if (kind == NostrCalendarKind.dateEvent) {
      startDate = _requiredIsoDate(tags, 'start');
      endDate = _optionalIsoDate(tags, 'end');
      if (endDate != null && !_dateAfter(endDate, startDate)) {
        throw ArgumentError('Date-based end must be after start');
      }

      for (final name in const ['start_tzid', 'end_tzid', 'D']) {
        if (NostrTags.has(tags, name)) {
          throw ArgumentError(
            'Date-based events must not carry a "$name" tag',
          );
        }
      }
    } else if (kind == NostrCalendarKind.timeEvent) {
      final startTag = NostrTags.first(tags, 'start');
      startSeconds = NostrValidators.tryUnixSeconds(startTag);
      if (startSeconds == null) {
        throw ArgumentError.value(
          startTag,
          'start',
          'Time-based events require UNIX seconds',
        );
      }

      final endTag = NostrTags.first(tags, 'end');
      if (endTag != null) {
        endSeconds = NostrValidators.tryUnixSeconds(endTag);
        if (endSeconds == null || endSeconds <= startSeconds) {
          throw ArgumentError('Time-based end must be greater than start');
        }
      }

      startTzid = _optionalTimeZone(tags, 'start_tzid');
      endTzid = _optionalTimeZone(tags, 'end_tzid');

      final expected = daysFor(start: startSeconds, end: endSeconds);
      final declared = <int>[];
      var tagCount = 0;
      for (final tag in tags) {
        if (tag.isEmpty || tag.first != 'D') {
          continue;
        }

        tagCount++;
        final day = tag.length > 1 ? int.tryParse(tag[1]) : null;
        if (day == null) {
          throw ArgumentError.value(
              tag, 'D', 'D must be an integer day number');
        }
        declared.add(day);
      }

      declared.sort();
      if (tagCount != expected.length || !_sameInts(declared, expected)) {
        throw ArgumentError.value(
          declared,
          'D',
          'D tags must cover every UTC day of the range: $expected',
        );
      }

      days = List<int>.unmodifiable(declared);
    }

    return NostrCalendarEvent(
      id: event.id,
      pubkey: event.pubkey,
      kind: kind!,
      dTag: dTag,
      title: title,
      description: event.content ?? '',
      summary: NostrTags.first(tags, 'summary'),
      image: NostrTags.first(tags, 'image'),
      startDate: startDate,
      endDate: endDate,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      startTzid: startTzid,
      endTzid: endTzid,
      days: days,
      locations: NostrTags.all(tags, 'location'),
      hashtags: NostrTags.all(tags, 't'),
      references: NostrTags.all(tags, 'r'),
      calendars: calendars,
      participants: NostrTags.all(tags, 'p'),
      geohash: NostrTags.first(tags, 'g'),
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for non-calendar or invalid events.
  static NostrCalendarEvent? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid NIP-52 calendar event.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  static String _requiredIsoDate(List<List<String>> tags, String name) {
    final value = NostrTags.first(tags, name);
    if (value == null || !_isIsoDate(value)) {
      throw ArgumentError.value(
        value,
        name,
        'Expected an ISO YYYY-MM-DD date',
      );
    }

    return value;
  }

  static String? _optionalIsoDate(List<List<String>> tags, String name) {
    final value = NostrTags.first(tags, name);

    return value == null ? null : _requiredIsoDate(tags, name);
  }

  static String? _optionalTimeZone(List<List<String>> tags, String name) {
    final value = NostrTags.first(tags, name);
    if (value != null && !_isIanaTimeZone(value)) {
      throw ArgumentError.value(
        value,
        name,
        'Expected an IANA time zone identifier',
      );
    }

    return value;
  }

  static final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static final RegExp _ianaTimeZone = RegExp(r'^[A-Za-z0-9_+/\-]{1,64}$');

  static bool _isIsoDate(String value) => _parseIsoDateUtc(value) != null;

  static DateTime? _parseIsoDateUtc(String value) {
    final match = _isoDate.firstMatch(value);
    if (match == null) {
      return null;
    }

    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime.utc(year, month, day);

    // Date.utc rolls overflow over (2024-02-31 -> 2024-03-02); reject it.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  static bool _isIanaTimeZone(String value) => _ianaTimeZone.hasMatch(value);

  static bool _dateAfter(String end, String start) {
    final endDate = _parseIsoDateUtc(end);
    final startDate = _parseIsoDateUtc(start);

    return endDate != null && startDate != null && endDate.isAfter(startDate);
  }

  static bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }

    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }

    return true;
  }
}

/// {@template nostr_rsvp}
/// Parsed NIP-52 RSVP (kind 31925).
///
/// [status] is `accepted`, `declined` or `tentative`. [freeBusy] is `free` or
/// `busy` and is ignored (parsed as `null`) when [status] is `declined`.
/// {@endtemplate}
class NostrRsvp {
  /// {@macro nostr_rsvp}
  const NostrRsvp({
    this.id,
    required this.pubkey,
    required this.eventAddress,
    required this.dTag,
    required this.status,
    this.freeBusy,
    this.eventId,
    this.eventAuthor,
    this.content = '',
    this.tags = const [],
  });

  /// RSVP status values.
  static const List<String> statuses = ['accepted', 'declined', 'tentative'];

  /// Free/busy values.
  static const List<String> freeBusyValues = ['free', 'busy'];

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// `a` address of the calendar event being answered.
  final String eventAddress;

  /// Required `d` identifier.
  final String dTag;

  /// One of [statuses].
  final String status;

  /// One of [freeBusyValues]; `null` for declined RSVPs.
  final String? freeBusy;

  /// Optional `e` id of the answered revision.
  final String? eventId;

  /// Optional `p` pubkey of the calendar event author.
  final String? eventAuthor;

  /// Free-form note.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether [status] is `declined`.
  bool get isDeclined => status == 'declined';

  /// Parses [event], throwing [ArgumentError] when it is not a valid RSVP.
  static NostrRsvp parse(NostrEvent event) {
    if (event.kind != NostrCalendarKind.rsvp) {
      throw ArgumentError.value(event.kind, 'event.kind', 'Not an RSVP');
    }

    final tags = event.tags ?? const <List<String>>[];
    final address = NostrTags.first(tags, 'a');
    final parsedAddress = NostrEventAddress.tryParse(address);
    if (address == null ||
        parsedAddress == null ||
        !NostrCalendarKind.isCalendarEvent(parsedAddress.kind)) {
      throw ArgumentError.value(
        address,
        'a',
        'RSVP requires an address of a kind 31922/31923 event',
      );
    }

    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.isEmpty) {
      throw ArgumentError('RSVP requires a non-empty d tag');
    }

    final status = NostrTags.first(tags, 'status');
    if (status == null || !statuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Expected $statuses');
    }

    final fbTag = NostrTags.first(tags, 'fb');
    String? freeBusy;
    if (fbTag != null && status != 'declined') {
      if (!freeBusyValues.contains(fbTag)) {
        throw ArgumentError.value(fbTag, 'fb', 'Expected free or busy');
      }

      freeBusy = fbTag;
    }

    final eventId = NostrTags.first(tags, 'e');
    if (eventId != null && !NostrValidators.isHex64(eventId)) {
      throw ArgumentError.value(eventId, 'e', 'Expected 64 hex characters');
    }

    final eventAuthor = NostrTags.first(tags, 'p');
    if (eventAuthor != null && !NostrValidators.isHex64(eventAuthor)) {
      throw ArgumentError.value(eventAuthor, 'p', 'Expected 64 hex characters');
    }

    return NostrRsvp(
      id: event.id,
      pubkey: event.pubkey,
      eventAddress: address,
      dTag: dTag,
      status: status,
      freeBusy: freeBusy,
      eventId: eventId,
      eventAuthor: eventAuthor,
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for non-RSVP or invalid events.
  static NostrRsvp? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid RSVP.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned kind-31925 RSVP.
  ///
  /// [freeBusy] is ignored (omitted) when [status] is `declined`.
  static NostrEvent build({
    required String eventAddress,
    required String dTag,
    required String status,
    String? freeBusy,
    String? eventId,
    String? eventAuthor,
    String content = '',
    DateTime? createdAt,
  }) {
    final event = NostrEvent(
      id: null,
      kind: NostrCalendarKind.rsvp,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (eventId != null) ['e', eventId],
        ['a', eventAddress],
        ['d', dTag],
        ['status', status],
        if (freeBusy != null && status != 'declined') ['fb', freeBusy],
        if (eventAuthor != null) ['p', eventAuthor],
      ],
    );

    parse(event);

    return event;
  }
}

/// {@template nip52}
/// NIP-52 calendar events, calendars and RSVPs.
///
/// Template generation and [publish] are signer-bound; parsing is also
/// available without a signer through [NostrCalendarEvent] and [NostrRsvp].
/// {@endtemplate}
class NostrNip52 {
  /// {@macro nip52}
  NostrNip52({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Builds an unsigned date-based calendar event (kind 31922).
  ///
  /// [start] and [end] are ISO `YYYY-MM-DD`; [end] is exclusive.
  NostrEvent generateDateEvent({
    required String dTag,
    required String title,
    required String start,
    String? end,
    String content = '',
    String? summary,
    String? image,
    List<String> locations = const [],
    List<String> hashtags = const [],
    List<String> references = const [],
    List<String> calendars = const [],
    List<String> participants = const [],
    String? geohash,
    DateTime? createdAt,
  }) {
    final event = NostrEvent(
      id: null,
      kind: NostrCalendarKind.dateEvent,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        ['title', title],
        if (summary != null) ['summary', summary],
        if (image != null) ['image', image],
        ['start', start],
        if (end != null) ['end', end],
        for (final location in locations) ['location', location],
        if (geohash != null) ['g', geohash],
        for (final participant in participants) ['p', participant],
        for (final hashtag in hashtags) ['t', hashtag],
        for (final reference in references) ['r', reference],
        for (final calendar in calendars) ['a', calendar],
      ],
    );

    NostrCalendarEvent.parse(event);

    return event;
  }

  /// Builds an unsigned time-based calendar event (kind 31923).
  ///
  /// [start] and [end] are inclusive/exclusive UNIX seconds. One `D` tag per
  /// covered UTC day is computed from the range.
  NostrEvent generateTimeEvent({
    required String dTag,
    required String title,
    required int start,
    int? end,
    String content = '',
    String? summary,
    String? image,
    String? startTzid,
    String? endTzid,
    List<String> locations = const [],
    List<String> hashtags = const [],
    List<String> references = const [],
    List<String> calendars = const [],
    List<String> participants = const [],
    String? geohash,
    DateTime? createdAt,
  }) {
    final event = NostrEvent(
      id: null,
      kind: NostrCalendarKind.timeEvent,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        ['title', title],
        if (summary != null) ['summary', summary],
        if (image != null) ['image', image],
        ['start', '$start'],
        if (end != null) ['end', '$end'],
        for (final day in NostrCalendarEvent.daysFor(start: start, end: end))
          ['D', '$day'],
        if (startTzid != null) ['start_tzid', startTzid],
        if (endTzid != null) ['end_tzid', endTzid],
        for (final location in locations) ['location', location],
        if (geohash != null) ['g', geohash],
        for (final participant in participants) ['p', participant],
        for (final hashtag in hashtags) ['t', hashtag],
        for (final reference in references) ['r', reference],
        for (final calendar in calendars) ['a', calendar],
      ],
    );

    NostrCalendarEvent.parse(event);

    return event;
  }

  /// Builds an unsigned calendar (kind 31924).
  ///
  /// [events] are `a` addresses of kind 31922/31923 events included in it.
  NostrEvent generateCalendar({
    required String dTag,
    required String title,
    String content = '',
    List<String> events = const [],
    DateTime? createdAt,
  }) {
    if (dTag.isEmpty) {
      throw ArgumentError('Calendar events require a non-empty d tag');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError('Calendar events require a non-empty title tag');
    }

    final event = NostrEvent(
      id: null,
      kind: NostrCalendarKind.calendar,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        ['title', title],
        for (final address in events) ['a', address],
      ],
    );

    NostrCalendarEvent.parse(event);

    return event;
  }

  /// Builds an unsigned RSVP (kind 31925).
  NostrEvent generateRsvp({
    required String eventAddress,
    required String dTag,
    required String status,
    String? freeBusy,
    String? eventId,
    String? eventAuthor,
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrRsvp.build(
      eventAddress: eventAddress,
      dTag: dTag,
      status: status,
      freeBusy: freeBusy,
      eventId: eventId,
      eventAuthor: eventAuthor,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses a calendar event, throwing [ArgumentError] when invalid.
  NostrCalendarEvent parseEvent(NostrEvent event) =>
      NostrCalendarEvent.parse(event);

  /// Parses a calendar event, returning `null` when it is not one or invalid.
  NostrCalendarEvent? tryParseEvent(NostrEvent event) {
    final kind = event.kind;
    if (kind == null ||
        (!NostrCalendarKind.isCalendarEvent(kind) &&
            kind != NostrCalendarKind.calendar)) {
      return null;
    }

    return NostrCalendarEvent.tryParse(event);
  }
}
