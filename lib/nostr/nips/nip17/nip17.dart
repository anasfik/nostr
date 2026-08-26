import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip59/nip59.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip17}
/// NIP-17 private direct messages: kind-14 chat messages (as rumors) sealed
/// with NIP-59 and gift-wrapped to each recipient.
///
/// Usage:
/// ```dart
/// final nip17 = NostrNip17(signer: NostrLocalKeySigner(keyPairs));
///
/// // Build a rumor, then wrap it for sending.
/// final rumor = nip17.createChatMessageRumor(
///   content: 'hey!',
///   recipientPubkeys: [theirPubkey],
/// );
/// final giftWrap = await nip17.wrapMessage(rumor, theirPubkey);
/// // publish `giftWrap` via your transport.
/// ```
/// {@endtemplate}
class NostrNip17 {
  /// {@macro nip17}
  NostrNip17({required this.signer});

  final NostrEventSigner signer;

  /// Creates an unsigned kind-14 chat message rumor addressed to
  /// [recipientPubkeys] (one pubkey per `p` tag).
  ///
  /// [subject] maps to the optional `subject` tag; [replyToEventId] and
  /// [replyToRootEventId] produce NIP-17 reply tags.
  NostrEvent createChatMessageRumor({
    required String content,
    required List<String> recipientPubkeys,
    String? subject,
    String? replyToEventId,
    String? replyToRootEventId,
    DateTime? createdAt,
  }) {
    if (recipientPubkeys.isEmpty) {
      throw ArgumentError('at least one recipient is required');
    }

    if (recipientPubkeys.contains(signer.publicKey)) {
      throw ArgumentError(
        'the sender must not be included in recipientPubkeys',
      );
    }

    final tags = <List<String>>[
      for (final recipient in recipientPubkeys) ['p', recipient],
      if (subject != null && subject.isNotEmpty) ...[
        ['subject', subject],
      ],
      // NIP-17 reply scheme: e-tag pairs carry marker + recommended relay.
      if (replyToRootEventId != null) ...[
        ['e', replyToRootEventId, '', 'root'],
      ],
      if (replyToEventId != null) ...[
        ['e', replyToEventId, '', 'reply'],
      ],
    ];

    return Nip59.createRumor(
      kind: 14,
      content: content,
      pubkey: signer.publicKey,
      tags: tags,
      createdAt: createdAt,
    );
  }

  /// Creates an unsigned kind-15 file-message rumor.
  ///
  /// [fileUrl] should point to media hosted out-of-band (e.g. Blossom);
  /// [encryptionKey]/[encryptionNonce]/[decryptionAlt] describe encrypted
  /// payloads per NIP-17's file message section.
  NostrEvent createFileMessageRumor({
    required String fileUrl,
    required List<String> recipientPubkeys,
    required String fileType,
    required int fileSizeBytes,
    String? encryptionAlgorithm,
    String? encryptionKey,
    String? encryptionNonce,
    String? decryptionAlternative,
    String? caption,
    DateTime? createdAt,
  }) {
    if (recipientPubkeys.isEmpty) {
      throw ArgumentError('at least one recipient is required');
    }

    final tags = <List<String>>[
      ['url', fileUrl],
      ['m', fileType],
      ['size', '$fileSizeBytes'],
      for (final recipient in recipientPubkeys) ['p', recipient],
      if (caption != null && caption.isNotEmpty) ...[
        ['alt', caption],
      ],
      if (encryptionAlgorithm != null) ...[
        ['encryption-algorithm', encryptionAlgorithm],
      ],
      if (encryptionKey != null) ...[
        [
          'key',
          encryptionKey,
          if (encryptionNonce != null) 'nonce',
          if (encryptionNonce != null) encryptionNonce,
        ],
      ],
      if (decryptionAlternative != null) ...[
        ['decryption-alt', decryptionAlternative],
      ],
    ];

    return Nip59.createRumor(
      kind: 15,
      content: '',
      pubkey: signer.publicKey,
      tags: tags,
      createdAt: createdAt,
    );
  }

  /// Seals + gift-wraps a rumor for a single [recipientPublicKey], returning
  /// the publishable kind-1059 event.
  ///
  /// For group chats call this once per member.
  Future<NostrEvent> wrapMessage(
    NostrEvent rumor,
    String recipientPublicKey,
  ) {
    return Nip59.giftWrapRumor(
      rumor: rumor,
      signer: signer,
      recipientPublicKey: recipientPublicKey,
    );
  }

  /// Unwraps a received gift wrap into its inner chat/file rumor.
  Future<NostrEvent> unwrapMessage(NostrEvent giftWrap) {
    return Nip59.extractRumor(giftWrap, signer);
  }
}
