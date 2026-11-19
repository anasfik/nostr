import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip28}
/// NIP-28 public chat channels.
///
/// Covers channel creation (kind 40), channel metadata (kind 41), channel
/// messages (kind 42), message hiding (kind 43) and user muting (kind 44).
/// Every method returns a signed [NostrEvent] ready to publish.
///
/// Usage:
/// ```dart
/// final nip28 = NostrNip28(signer: signer);
/// final channel = await nip28.createChannel(
///   metadata: {'name': 'dart', 'about': 'Dart chat'},
/// );
/// final message = await nip28.sendChannelMessage(
///   channelId: channel.id!,
///   relayUrl: 'wss://relay.example',
///   content: 'hello',
/// );
/// ```
/// {@endtemplate}
class NostrNip28 {
  /// {@macro nip28}
  NostrNip28({required this.signer});

  /// Signer used to sign channel events.
  final NostrEventSigner signer;

  /// Kind 40: creates a public channel.
  ///
  /// [metadata] is serialized as JSON (`{name, about, picture}` per NIP-28).
  Future<NostrEvent> createChannel({
    required Map<String, dynamic> metadata,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(40, jsonEncode(metadata), extraTags, createdAt);
  }

  /// Kind 41: replaces the metadata of the channel [channelId].
  Future<NostrEvent> updateChannelMetadata({
    required String channelId,
    required Map<String, dynamic> metadata,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      41,
      jsonEncode(metadata),
      [
        ['e', channelId],
        ...extraTags,
      ],
      createdAt,
    );
  }

  /// Kind 42: posts [content] to the channel [channelId].
  ///
  /// Set [replyToEventId] to thread the message under an existing kind-42
  /// event. Both `e` tags carry [relayUrl] and a `root`/`reply` marker.
  Future<NostrEvent> sendChannelMessage({
    required String channelId,
    required String relayUrl,
    required String content,
    String? replyToEventId,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      42,
      content,
      [
        ['e', channelId, relayUrl, 'root'],
        if (replyToEventId != null) ['e', replyToEventId, relayUrl, 'reply'],
        ...extraTags,
      ],
      createdAt,
    );
  }

  /// Kind 43: hides the kind-42 [messageEventId] from the channel.
  ///
  /// [reason] is optional and encoded as `{"reason": ...}` in the content.
  Future<NostrEvent> hideChannelMessage({
    required String messageEventId,
    String? reason,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      43,
      reason == null ? '' : jsonEncode({'reason': reason}),
      [
        ['e', messageEventId],
        ...extraTags,
      ],
      createdAt,
    );
  }

  /// Kind 44: mutes [pubkey] in the channel.
  ///
  /// [reason] is optional and encoded as `{"reason": ...}` in the content.
  Future<NostrEvent> muteChannelUser({
    required String pubkey,
    String? reason,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return _sign(
      44,
      reason == null ? '' : jsonEncode({'reason': reason}),
      [
        ['p', pubkey],
        ...extraTags,
      ],
      createdAt,
    );
  }

  Future<NostrEvent> _sign(
    int kind,
    String content,
    List<List<String>> tags,
    DateTime? createdAt,
  ) {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: kind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: tags,
      ),
    );
  }
}
