import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_poll_option}
/// A NIP-88 poll option: alphanumeric [id] plus display [label].
/// {@endtemplate}
class NostrPollOption {
  /// {@macro nostr_poll_option}
  const NostrPollOption({required this.id, required this.label});

  /// Option id referenced by `response` tags.
  final String id;

  /// Human-readable option label.
  final String label;
}

/// {@template nostr_poll}
/// Parsed NIP-88 poll (kind 1068).
///
/// [pollType] is [NostrNip88.singleChoice] when the tag is absent or unknown,
/// matching the spec default. [endsAt] is the response cutoff in UNIX seconds.
/// {@endtemplate}
class NostrPoll {
  /// {@macro nostr_poll}
  const NostrPoll({
    required this.id,
    required this.content,
    required this.options,
    required this.pollType,
    this.relays = const [],
    this.endsAt,
  });

  /// Poll event id, or `null` for an unsigned template.
  final String? id;

  /// Poll label.
  final String content;

  /// Declared options, in tag order.
  final List<NostrPollOption> options;

  /// `singlechoice` or `multiplechoice`.
  final String pollType;

  /// Relays expected to carry responses.
  final List<String> relays;

  /// Response cutoff as a UNIX timestamp in seconds.
  final int? endsAt;
}

/// {@template nostr_poll_tally}
/// Result counts computed from NIP-88 response events.
///
/// [counts] is keyed by option id and includes declared options with zero
/// votes. [voters] holds the pubkeys whose vote was counted.
/// {@endtemplate}
class NostrPollTally {
  /// {@macro nostr_poll_tally}
  const NostrPollTally({required this.counts, required this.voters});

  /// Computes the tally for [poll] from [responses].
  ///
  /// Applies the NIP-88 rules:
  /// - only kind-1018 events referencing [poll] by `e` tag count;
  /// - responses created after the poll `endsAt` are ignored;
  /// - one vote per pubkey, keeping the largest `created_at`;
  /// - `singlechoice` counts only the first `response` tag;
  /// - `multiplechoice` counts the first tag per option id;
  /// - option ids not declared by the poll are ignored.
  ///
  /// Throws [ArgumentError] when [poll] has no id or is not a poll event.
  factory NostrPollTally.compute({
    required NostrEvent poll,
    required Iterable<NostrEvent> responses,
  }) {
    final parsed = NostrNip88.parsePoll(poll);
    final pollId = poll.id;

    if (pollId == null) {
      throw ArgumentError.value(poll, 'poll', 'Poll event must have an id');
    }

    final latestByPubkey = <String, NostrEvent>{};
    for (final response in responses) {
      if (response.kind != NostrNip88.responseKind) {
        continue;
      }

      if (!NostrTags.all(response.tags, 'e').contains(pollId)) {
        continue;
      }

      final seconds = _createdAtSeconds(response);
      final endsAt = parsed.endsAt;
      if (seconds == null || (endsAt != null && seconds > endsAt)) {
        continue;
      }

      final existing = latestByPubkey[response.pubkey];
      if (existing == null || seconds > (_createdAtSeconds(existing) ?? -1)) {
        latestByPubkey[response.pubkey] = response;
      }
    }

    final counts = <String, int>{
      for (final option in parsed.options) option.id: 0,
    };
    final voters = <String>{};

    for (final entry in latestByPubkey.entries) {
      final selected = NostrTags.all(entry.value.tags, 'response');
      final ids = parsed.pollType == NostrNip88.multipleChoice
          ? selected.toSet()
          : selected.take(1).toSet();

      var voted = false;
      for (final id in ids) {
        final current = counts[id];
        if (current == null) {
          continue;
        }

        counts[id] = current + 1;
        voted = true;
      }

      if (voted) {
        voters.add(entry.key);
      }
    }

    return NostrPollTally(
      counts: Map<String, int>.unmodifiable(counts),
      voters: Set<String>.unmodifiable(voters),
    );
  }

  /// Votes per declared option id.
  final Map<String, int> counts;

  /// Pubkeys that cast a valid counted vote.
  final Set<String> voters;

  /// Number of counted voters.
  int get totalVoters => voters.length;

  /// Votes for [optionId], or zero when the option is unknown.
  int countFor(String optionId) => counts[optionId] ?? 0;

  static int? _createdAtSeconds(NostrEvent event) {
    final createdAt = event.createdAt;

    return createdAt == null ? null : createdAt.millisecondsSinceEpoch ~/ 1000;
  }
}

/// {@template nip88}
/// NIP-88 polls (kind 1068) and responses (kind 1018).
///
/// Templates and tallying are static; [createPoll] and [createResponse] sign
/// through the bound signer. Results should be published to the relays
/// declared by the poll.
/// {@endtemplate}
class NostrNip88 {
  /// {@macro nip88}
  NostrNip88({required this.signer});

  /// Signer used by [createPoll] and [createResponse].
  final NostrEventSigner signer;

  /// Poll event kind.
  static const int pollKind = 1068;

  /// Response event kind.
  static const int responseKind = 1018;

  /// Default poll type: only the first response tag counts.
  static const String singleChoice = 'singlechoice';

  /// Poll type where every first-per-option response tag counts.
  static const String multipleChoice = 'multiplechoice';

  /// Poll types defined by NIP-88.
  static const List<String> pollTypes = [singleChoice, multipleChoice];

  /// Builds an unsigned kind-1068 poll event.
  ///
  /// [options] must have non-empty, unique ids. [relays] become `relay` tags,
  /// [pollType] is validated against [pollTypes] and [endsAt] is a UNIX
  /// timestamp in seconds.
  static NostrEvent generatePollTemplate({
    required String content,
    required List<NostrPollOption> options,
    List<String> relays = const [],
    String pollType = singleChoice,
    int? endsAt,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    if (!pollTypes.contains(pollType)) {
      throw ArgumentError.value(
        pollType,
        'pollType',
        'Expected $singleChoice or $multipleChoice',
      );
    }

    final seen = <String>{};
    for (final option in options) {
      if (option.id.isEmpty) {
        throw ArgumentError.value(option.id, 'options', 'Option id is empty');
      }

      if (!seen.add(option.id)) {
        throw ArgumentError.value(
          option.id,
          'options',
          'Duplicate option id',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: pollKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final option in options) ['option', option.id, option.label],
        for (final relay in relays) ['relay', relay],
        ['polltype', pollType],
        if (endsAt != null) ['endsAt', '$endsAt'],
        ...tags,
      ],
    );
  }

  /// Builds and signs a kind-1068 poll event.
  Future<NostrEvent> createPoll({
    required String content,
    required List<NostrPollOption> options,
    List<String> relays = const [],
    String pollType = singleChoice,
    int? endsAt,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    return signer.sign(
      generatePollTemplate(
        content: content,
        options: options,
        relays: relays,
        pollType: pollType,
        endsAt: endsAt,
        tags: tags,
        createdAt: createdAt,
      ),
    );
  }

  /// Builds an unsigned kind-1018 response event.
  ///
  /// [pollEventId] is the poll's 64-char hex id; [responses] are option ids
  /// emitted as `response` tags in order.
  static NostrEvent generateResponseTemplate({
    required String pollEventId,
    required List<String> responses,
    String content = '',
    DateTime? createdAt,
  }) {
    if (!NostrValidators.isHex64(pollEventId)) {
      throw ArgumentError.value(
        pollEventId,
        'pollEventId',
        'Expected 64 lowercase hex characters',
      );
    }

    if (responses.isEmpty || responses.any((id) => id.isEmpty)) {
      throw ArgumentError.value(
        responses,
        'responses',
        'At least one non-empty option id is required',
      );
    }

    return NostrEvent(
      id: null,
      kind: responseKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['e', pollEventId],
        for (final response in responses) ['response', response],
      ],
    );
  }

  /// Builds and signs a kind-1018 response event.
  Future<NostrEvent> createResponse({
    required String pollEventId,
    required List<String> responses,
    String content = '',
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateResponseTemplate(
        pollEventId: pollEventId,
        responses: responses,
        content: content,
        createdAt: createdAt,
      ),
    );
  }

  /// Filter for the responses to [pollEventId].
  ///
  /// [authors] narrows the tally to specific voters (for example a follow
  /// set), [until] caps `created_at` in UNIX seconds and [limit] caps results.
  static NostrFilter buildResponseFilter({
    required String pollEventId,
    List<String>? authors,
    int? until,
    int? limit,
  }) {
    return NostrFilter(
      kinds: const [responseKind],
      e: [pollEventId],
      authors: authors,
      until: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until * 1000, isUtc: true),
      limit: limit,
    );
  }

  /// Parses a kind-1068 [event] into [NostrPoll].
  ///
  /// Throws [ArgumentError] when [event] is not a poll.
  static NostrPoll parsePoll(NostrEvent event) {
    if (event.kind != pollKind) {
      throw ArgumentError.value(event.kind, 'event', 'Not a poll event');
    }

    final options = <NostrPollOption>[];
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length >= 3 && tag.first == 'option') {
        options.add(NostrPollOption(id: tag[1], label: tag[2]));
      }
    }

    final pollType = NostrTags.first(event.tags, 'polltype');

    return NostrPoll(
      id: event.id,
      content: event.content ?? '',
      options: options,
      pollType: pollTypes.contains(pollType) ? pollType! : singleChoice,
      relays: NostrTags.all(event.tags, 'relay'),
      endsAt: NostrValidators.tryUnixSeconds(
        NostrTags.first(event.tags, 'endsAt'),
      ),
    );
  }
}
