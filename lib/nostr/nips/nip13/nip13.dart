import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip13}
/// NIP-13 proof-of-work helpers: difficulty counting, target checking and a
/// simple miner that adjusts timestamps until the event id meets a target.
/// {@endtemplate}
class NostrProofOfWork {
  NostrProofOfWork._();

  /// Counts the number of leading zero bits of an event id (hex, 64 chars).
  static int getDifficulty(String eventIdHex) {
    var difficulty = 0;

    for (var i = 0; i < eventIdHex.length; i++) {
      final nibble = int.parse(eventIdHex[i], radix: 16);

      if (nibble == 0) {
        difficulty += 4;
        continue;
      }

      if (nibble < 2) {
        difficulty += 3;
      } else if (nibble < 4) {
        difficulty += 2;
      } else if (nibble < 8) {
        difficulty += 1;
      }
      break;
    }

    return difficulty;
  }

  /// Whether [eventIdHex] meets [targetDifficulty].
  static bool meetsTarget(String eventIdHex, int targetDifficulty) {
    return getDifficulty(eventIdHex) >= targetDifficulty;
  }

  /// Mines an event to reach [targetDifficulty] leading zero bits.
  ///
  /// Strategy per NIP-13: iterate over timestamp adjustments first (one
  /// second at a time), then fall back to incrementing a `nonce` tag. Returns
  /// the signed event whose id satisfies the target.
  ///
  /// Warning: mining is CPU-bound; use small targets (< 24 bits) in UI code,
  /// or call from an isolate.
  static Future<NostrEvent> mineEvent({
    required NostrEventSigner signer,
    required int kind,
    required String content,
    required List<List<String>> tags,
    DateTime? createdAt,
    int targetDifficulty = 20,
    Duration? timeout,
  }) async {
    final deadline = timeout == null ? null : DateTime.now().add(timeout);

    var baseTime = (createdAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    var nonceCounter = 0;
    var attempt = 0;

    while (true) {
      // Alternate between time shifts and nonce tags so both strategies are
      // exercised without unbounded timestamp drift.
      final List<List<String>> attemptTags;
      final DateTime attemptCreatedAt;

      if (attempt % 2 == 0) {
        attemptCreatedAt = DateTime.fromMillisecondsSinceEpoch(
            (baseTime + (attempt ~/ 2)) * 1000);
        attemptTags = tags;
      } else {
        attemptCreatedAt = DateTime.fromMillisecondsSinceEpoch(baseTime * 1000);
        attemptTags = [
          ...tags,
          ['nonce', '$nonceCounter', '$targetDifficulty'],
        ];
        nonceCounter++;
      }

      final id = NostrEvent.getEventId(
        kind: kind,
        content: content,
        createdAt: attemptCreatedAt,
        tags: attemptTags,
        pubkey: signer.publicKey,
      );

      if (meetsTarget(id, targetDifficulty)) {
        return signer.sign(
          NostrEvent(
            id: id,
            kind: kind,
            content: content,
            sig: null,
            pubkey: signer.publicKey,
            createdAt: attemptCreatedAt,
            tags: attemptTags,
          ),
        );
      }

      attempt++;

      if (deadline != null && DateTime.now().isAfter(deadline)) {
        throw StateError(
          'failed to mine $targetDifficulty bits within the timeout',
        );
      }
    }
  }
}
