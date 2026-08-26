import 'dart:convert';
import 'dart:math';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip59}
/// NIP-59 gift wrap pipeline: rumor → seal → gift wrap.
///
/// - **Rumor**: an unsigned event (the actual payload, e.g. a NIP-17 chat
///   message of kind 14).
/// - **Seal** (kind 13): the rumor JSON encrypted to the recipient with
///   NIP-44 and signed by the sender. Seals have randomized timestamps.
/// - **Gift wrap** (kind 1059): the seal encrypted with NIP-44 using a fresh
///   *ephemeral* key pair so the relay cannot correlate sender and message,
///   tagged `p` with the recipient pubkey.
/// {@endtemplate}
class Nip59 {
  Nip59._();

  /// Maximum age spread (in seconds) applied when randomizing seal/gift-wrap
  /// timestamps: two days back plus up to 12 hours in the future.
  static const int _twoDays = 172800;

  static final Random _random = Random.secure();

  /// Creates an unsigned rumor event from partial data. The rumor carries an
  /// id (so it can be referenced) but **never a signature**.
  ///
  /// If [createdAt] is omitted, it is randomized within the last day to
  /// reduce metadata leakage even before sealing.
  static NostrEvent createRumor({
    required int kind,
    required String content,
    required String pubkey,
    List<List<String>> tags = const [],
    DateTime? createdAt,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final effectiveCreatedAt = createdAt ??
        reference.subtract(
          Duration(seconds: _random.nextInt(86400)),
        );

    final id = NostrEvent.getEventId(
      kind: kind,
      content: content,
      createdAt: effectiveCreatedAt,
      tags: tags,
      pubkey: pubkey,
    );

    return NostrEvent(
      id: id,
      kind: kind,
      content: content,
      sig: null,
      pubkey: pubkey,
      createdAt: effectiveCreatedAt,
      tags: tags,
    );
  }

  /// Wraps a [rumor] into a sealed (kind 13), signed event addressed to
  /// [recipientPublicKey].
  static Future<NostrEvent> createSeal({
    required NostrEvent rumor,
    required NostrEventSigner signer,
    required String recipientPublicKey,
  }) async {
    if (rumor.sig != null) {
      throw ArgumentError(
        'a rumor must be unsigned; refusing to seal signed events',
      );
    }

    final encryptedRumor = await signer.nip44Encrypt(
      jsonEncode(rumor.toMap()),
      recipientPublicKey,
    );

    // Randomize timestamp per spec to frustrate timing correlation.
    final randomized = DateTime.now().subtract(
      Duration(seconds: _random.nextInt(_twoDays)),
    );

    return signer.sign(
      NostrEvent(
        id: null,
        kind: 13,
        content: encryptedRumor,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: randomized,
        tags: const [],
      ),
    );
  }

  /// Wraps a [seal] into an anonymous gift wrap event (kind 1059) addressed
  /// to [recipientPublicKey], encrypted under a fresh ephemeral key pair.
  ///
  /// Returns the publishable gift-wrapped event.
  static Future<NostrEvent> createGiftWrap({
    required NostrEvent seal,
    required String recipientPublicKey,
  }) async {
    // Fresh ephemeral identity for every gift wrap: breaks sender linkage.
    final ephemeral = NostrLocalKeySigner(NostrKeyPairs.generate());

    final encryptedSeal = await ephemeral.nip44Encrypt(
      jsonEncode(seal.toMap()),
      recipientPublicKey,
    );

    final randomized = DateTime.now().subtract(
      Duration(seconds: _random.nextInt(_twoDays)),
    );

    return ephemeral.sign(
      NostrEvent(
        id: null,
        kind: 1059,
        content: encryptedSeal,
        sig: null,
        pubkey: ephemeral.publicKey,
        createdAt: randomized,
        tags: [
          ['p', recipientPublicKey],
        ],
      ),
    );
  }

  /// One-shot helper: rumor → seal → gift wrap.
  static Future<NostrEvent> giftWrapRumor({
    required NostrEvent rumor,
    required NostrEventSigner signer,
    required String recipientPublicKey,
  }) async {
    final seal = await createSeal(
      rumor: rumor,
      signer: signer,
      recipientPublicKey: recipientPublicKey,
    );

    return createGiftWrap(seal: seal, recipientPublicKey: recipientPublicKey);
  }

  /// Peels one layer: decrypts a kind-13 seal or kind-1059 gift wrap sent to
  /// this signer's key, returning the inner event map as a [NostrEvent].
  ///
  /// For gift wraps the inner event is the seal (still encrypted content);
  /// pass its decrypted result through again to reach the rumor:
  /// ```dart
  /// final seal = await nip59.unwrap(giftWrap);
  /// final rumor = await nip59.unwrap(seal);
  /// ```
  static Future<NostrEvent> unwrap(
    NostrEvent wrappedEvent,
    NostrEventSigner recipientSigner,
  ) async {
    final innerPubkey = _innerSender(wrappedEvent);

    final decrypted = await recipientSigner.nip44Decrypt(
      wrappedEvent.content ?? '',
      innerPubkey,
    );

    final decoded = jsonDecode(decrypted) as Map<String, dynamic>;

    return NostrEvent(
      id: decoded['id'] as String?,
      kind: decoded['kind'] as int?,
      content: decoded['content'] as String?,
      sig: decoded['sig'] as String?,
      pubkey: decoded['pubkey'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((decoded['created_at'] as int?) ?? 0) * 1000,
      ),
      tags: [
        for (final tag in (decoded['tags'] as List?) ?? [])
          [for (final part in (tag as List)) part.toString()],
      ],
    );
  }

  /// Full unwrap: gift wrap → seal → rumor in one call. Throws if [event]
  /// is not a gift wrap.
  static Future<NostrEvent> extractRumor(
    NostrEvent giftWrapEvent,
    NostrEventSigner recipientSigner,
  ) async {
    final seal = await unwrap(giftWrapEvent, recipientSigner);

    if (seal.kind != 13) {
      throw ArgumentError(
        'expected a kind-13 seal inside the gift wrap, got kind ${seal.kind}',
      );
    }

    return unwrap(seal, recipientSigner);
  }

  /// The NIP-44 conversation peer of a wrapped event is always its own
  /// author: an ephemeral key for gift wraps, the real sender for seals.
  static String _innerSender(NostrEvent wrappedEvent) {
    return wrappedEvent.pubkey;
  }
}
