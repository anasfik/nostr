import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip92/nip92.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_voice_message}
/// Parsed NIP-A0 voice message (kind 1222) or voice reply (kind 1244).
///
/// [audioUrl] is the event `content`, which the spec requires to be a direct
/// audio URL (A0.md:11-23). [waveform] and [duration] come from the optional
/// NIP-92 `imeta` tag (A0.md:31-38).
///
/// Replies carry the NIP-22 root and parent references in [root] and
/// [parent]. Root messages leave both `null`.
/// {@endtemplate}
class NostrVoiceMessage {
  /// {@macro nostr_voice_message}
  const NostrVoiceMessage({
    required this.kind,
    required this.audioUrl,
    this.waveform = const <int>[],
    this.duration,
    this.root,
    this.parent,
    this.tags = const <List<String>>[],
    this.pubkey = '',
  });

  /// Event kind: [NostrNipA0.rootKind] or [NostrNipA0.replyKind].
  final int kind;

  /// Direct audio URL from the event content.
  final String audioUrl;

  /// `imeta waveform` samples, in order.
  final List<int> waveform;

  /// `imeta duration`, in seconds.
  final int? duration;

  /// NIP-22 root scope, `null` for root voice messages.
  final NostrVoiceReference? root;

  /// NIP-22 parent scope, `null` for root voice messages.
  final NostrVoiceReference? parent;

  /// Every tag except the `imeta` waveform/duration fields consumed for
  /// [waveform]/[duration]; other `imeta` fields are preserved.
  final List<List<String>> tags;

  /// Author public key, when parsed from a signed event.
  final String pubkey;

  /// Whether this is a kind-1244 reply.
  bool get isReply => kind == NostrNipA0.replyKind;

  /// Whether every waveform sample is non-negative.
  ///
  /// The 100-sample ceiling is a rendering recommendation, not a validity
  /// rule: the spec's own example carries 101 samples (A0.md:44-59), so
  /// parsers keep longer waveforms and builders enforce the ceiling.
  bool get hasValidWaveform => waveform.every((sample) => sample >= 0);

  /// Whether the waveform respects the recommended fewer-than-100 samples.
  bool get hasRecommendedWaveformLength =>
      waveform.length < NostrNipA0.maxWaveformSamples;

  /// Whether the duration is a positive number of seconds.
  bool get hasValidDuration => duration == null || duration! > 0;

  /// Whether the parsed event satisfies the NIP-A0 mandatory rules.
  bool get isValid =>
      NostrValidators.tryHttpUrl(audioUrl) != null &&
      hasValidWaveform &&
      hasValidDuration &&
      (kind == NostrNipA0.rootKind || isReply) &&
      (!isReply ||
          (root != null &&
              parent != null &&
              root!.kind != null &&
              parent!.kind != null));
}

/// {@template nostr_voice_reference}
/// One NIP-22 scope referenced by a voice reply: an event id, its author and
/// its kind, captured by the uppercase (root) or lowercase (parent) tags.
/// {@endtemplate}
class NostrVoiceReference {
  /// {@macro nostr_voice_reference}
  const NostrVoiceReference({
    required this.eventId,
    this.authorPubkey = '',
    this.kind,
    this.relayUrl,
  });

  /// Referenced event id.
  final String eventId;

  /// Referenced event author, when present.
  final String authorPubkey;

  /// Referenced event kind, when present.
  final int? kind;

  /// Relay hint in the reference tag, when present.
  final String? relayUrl;
}

/// {@template nipa0}
/// NIP-A0 voice messages (kinds 1222 and 1244).
///
/// Kind 1222 is a root voice message and kind 1244 is a voice reply, which
/// MUST follow the NIP-22 comment structure (A0.md:25-28). Both put the audio
/// URL in `content` and may add an `imeta` tag with `waveform` and `duration`
/// (A0.md:31-38).
///
/// [publish] signs the event through the signer bound to this instance.
/// {@endtemplate}
class NostrNipA0 {
  /// {@macro nipa0}
  NostrNipA0({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind 1222: root voice message.
  static const int rootKind = 1222;

  /// Kind 1244: voice reply.
  static const int replyKind = 1244;

  /// Maximum waveform samples recommended by A0.md:36.
  static const int maxWaveformSamples = 100;

  /// Recommended maximum clip length, in seconds (A0.md:11, 60 seconds).
  static const int recommendedMaxDurationSeconds = 60;

  /// Parses an `imeta` waveform value: space-separated non-negative integers.
  ///
  /// Returns `null` when a value is not an integer or is negative. The sample
  /// count is not limited here; see [NostrVoiceMessage.hasValidWaveform].
  static List<int>? tryParseWaveform(String value) {
    final samples = <int>[];
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    for (final raw in trimmed.split(RegExp(r'\s+'))) {
      final sample = int.tryParse(raw);

      if (sample == null || sample < 0) {
        return null;
      }

      samples.add(sample);
    }

    return samples;
  }

  /// Builds the optional `imeta` tag for [audioUrl].
  ///
  /// Returns `null` when neither [waveform] nor [duration] is provided.
  /// Throws [ArgumentError] for a waveform longer than
  /// [maxWaveformSamples] or a duration that is not positive.
  static List<String>? buildImetaTag({
    required String audioUrl,
    List<int>? waveform,
    int? duration,
  }) {
    if (waveform == null && duration == null) {
      return null;
    }

    if (waveform != null) {
      _validateWaveform(waveform);
    }

    if (duration != null && duration <= 0) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Duration must be a positive number of seconds',
      );
    }

    return [
      NostrNip92.tagName,
      'url $audioUrl',
      if (waveform != null)
        'waveform ${waveform.map((sample) => '$sample').join(' ')}',
      if (duration != null) 'duration $duration',
    ];
  }

  /// Builds an unsigned kind-1222 root voice message.
  ///
  /// [audioUrl] must be an absolute `http`/`https` URL. [extraTags] may add
  /// hashtags or geohashes (A0.md:15-17) but must not contain `imeta`, which
  /// this builder owns.
  static NostrEvent createVoiceMessage({
    required String audioUrl,
    List<int>? waveform,
    int? duration,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    final url = _validateAudioUrl(audioUrl);
    _validateExtraTags(extraTags);
    final imeta = buildImetaTag(
      audioUrl: url,
      waveform: waveform,
      duration: duration,
    );

    return NostrEvent(
      id: null,
      kind: rootKind,
      content: url,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (imeta != null) imeta,
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-1244 voice reply using NIP-22 tags.
  ///
  /// [parentEventId], [parentAuthorPubkey] and [parentKind] describe the event
  /// being replied to. Pass the same values (or [rootEventId],
  /// [rootAuthorPubkey] and [rootKind]) to address a different thread root.
  /// The tag order follows the NIP-22 event-scoped layout used by
  /// `NostrSocialBuilder.createComment`: `K`, `E`, `P`, `k`, `e`, `p`.
  ///
  /// Deviation: `NostrSocialBuilder.createComment` hard-codes kind 1111, so
  /// this builder emits the same tag structure directly rather than
  /// duplicating a generic comment template for one extra kind.
  static NostrEvent createVoiceReply({
    required String audioUrl,
    required String parentEventId,
    required String parentAuthorPubkey,
    required int parentKind,
    String? rootEventId,
    String? rootAuthorPubkey,
    int? rootKind,
    String? relayUrl,
    List<int>? waveform,
    int? duration,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    final url = _validateAudioUrl(audioUrl);

    if (!NostrValidators.isHex64(parentEventId)) {
      throw ArgumentError.value(
        parentEventId,
        'parentEventId',
        'Expected 64 lowercase hex characters',
      );
    }

    if (!NostrValidators.isHex64(parentAuthorPubkey)) {
      throw ArgumentError.value(
        parentAuthorPubkey,
        'parentAuthorPubkey',
        'Expected 64 lowercase hex characters',
      );
    }

    if (rootEventId != null && !NostrValidators.isHex64(rootEventId)) {
      throw ArgumentError.value(
        rootEventId,
        'rootEventId',
        'Expected 64 lowercase hex characters',
      );
    }

    if (rootAuthorPubkey != null &&
        !NostrValidators.isHex64(rootAuthorPubkey)) {
      throw ArgumentError.value(
        rootAuthorPubkey,
        'rootAuthorPubkey',
        'Expected 64 lowercase hex characters',
      );
    }

    _validateExtraTags(extraTags);

    final relay = relayUrl ?? '';
    final resolvedRootId = rootEventId ?? parentEventId;
    final resolvedRootAuthor = rootAuthorPubkey ?? parentAuthorPubkey;
    final resolvedRootKind = rootKind ?? parentKind;
    final imeta = buildImetaTag(
      audioUrl: url,
      waveform: waveform,
      duration: duration,
    );

    return NostrEvent(
      id: null,
      kind: replyKind,
      content: url,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['K', '$resolvedRootKind'],
        ['E', resolvedRootId, relay, resolvedRootAuthor],
        ['P', resolvedRootAuthor, if (relayUrl != null) relay],
        ['k', '$parentKind'],
        ['e', parentEventId, relay, parentAuthorPubkey],
        ['p', parentAuthorPubkey, if (relayUrl != null) relay],
        if (imeta != null) imeta,
        ...extraTags,
      ],
    );
  }

  /// Signs [event] with the bound signer; sending it is up to the caller.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses a kind-1222 or kind-1244 event, returning `null` when invalid.
  ///
  /// Malformed `imeta` entries are ignored rather than rejecting the event;
  /// call [NostrVoiceMessage.isValid] for the strict view.
  static NostrVoiceMessage? tryParse(NostrEvent event) {
    final kind = event.kind ?? 0;

    if (kind != rootKind && kind != replyKind) {
      return null;
    }

    final content = event.content ?? '';
    if (NostrValidators.tryHttpUrl(content) == null) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final keptTags = <List<String>>[];
    var waveform = const <int>[];
    int? duration;

    for (final tag in tags) {
      if (tag.isNotEmpty && tag.first == NostrNip92.tagName) {
        final imeta = NostrImeta.tryParse(tag);

        if (imeta == null) {
          keptTags.add(List<String>.of(tag));
          continue;
        }

        final rawWaveform = imeta['waveform'];
        final rawDuration = imeta['duration'];
        var consumedWaveform = false;
        var consumedDuration = false;

        if (rawWaveform != null) {
          final parsed = tryParseWaveform(rawWaveform);

          if (parsed != null && waveform.isEmpty) {
            waveform = parsed;
            consumedWaveform = true;
          }
        }

        if (rawDuration != null) {
          final parsed = int.tryParse(rawDuration);

          if (parsed != null && duration == null) {
            duration = parsed;
            consumedDuration = true;
          }
        }

        final kept = <String>[tag.first];
        var droppedWaveform = false;
        var droppedDuration = false;

        for (final raw in tag.skip(1)) {
          final separator = raw.indexOf(' ');
          final key = separator < 0 ? raw : raw.substring(0, separator);

          if (key == 'waveform' && consumedWaveform && !droppedWaveform) {
            droppedWaveform = true;
            continue;
          }

          if (key == 'duration' && consumedDuration && !droppedDuration) {
            droppedDuration = true;
            continue;
          }

          kept.add(raw);
        }

        if (kept.length > 1) {
          keptTags.add(kept);
        }

        continue;
      }

      keptTags.add(List<String>.of(tag));
    }

    final root = kind == replyKind ? _parseReference(tags, upper: true) : null;
    final parent =
        kind == replyKind ? _parseReference(tags, upper: false) : null;

    return NostrVoiceMessage(
      kind: kind,
      audioUrl: content,
      waveform: waveform,
      duration: duration,
      root: root,
      parent: parent,
      tags: keptTags,
      pubkey: event.pubkey,
    );
  }

  /// Like [tryParse], but throws [ArgumentError] when the event is invalid.
  static NostrVoiceMessage parse(NostrEvent event) {
    final message = tryParse(event);

    if (message == null || !message.isValid) {
      throw ArgumentError('Invalid NIP-A0 voice message event');
    }

    return message;
  }

  static NostrVoiceReference? _parseReference(
    List<List<String>> tags, {
    required bool upper,
  }) {
    final eName = upper ? 'E' : 'e';
    final pName = upper ? 'P' : 'p';
    final kName = upper ? 'K' : 'k';
    final eTag = NostrTags.tag(tags, eName);

    if (eTag == null || eTag.length < 2) {
      return null;
    }

    final kind = int.tryParse(NostrTags.first(tags, kName) ?? '');

    return NostrVoiceReference(
      eventId: eTag[1],
      authorPubkey:
          eTag.length > 3 ? eTag[3] : NostrTags.first(tags, pName) ?? '',
      kind: kind,
      relayUrl: eTag.length > 2 && eTag[2].isNotEmpty ? eTag[2] : null,
    );
  }

  static String _validateAudioUrl(String value) {
    final uri = NostrValidators.tryHttpUrl(value);

    if (uri == null) {
      throw ArgumentError.value(
        value,
        'audioUrl',
        'Expected an absolute http(s) audio URL',
      );
    }

    return uri.toString();
  }

  static void _validateWaveform(List<int> waveform) {
    if (waveform.length > maxWaveformSamples) {
      throw ArgumentError.value(
        waveform,
        'waveform',
        'NIP-A0 recommends at most $maxWaveformSamples samples',
      );
    }

    for (final sample in waveform) {
      if (sample < 0) {
        throw ArgumentError.value(
          sample,
          'waveform',
          'Waveform samples must not be negative',
        );
      }
    }
  }

  static void _validateExtraTags(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isNotEmpty && tag.first == NostrNip92.tagName) {
        throw ArgumentError.value(
          tag,
          'extraTags',
          'Pass waveform/duration to the builder instead of an imeta tag',
        );
      }
    }
  }
}
