import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip75}
/// NIP-75 zap goals (kind 9041).
///
/// A goal advertises a fundraising target in millisats and the relays where
/// zaps should be sent so they can be tallied. The goal itself is immutable;
/// set `closed_at` to stop counting later zaps.
///
/// Unknown optional tags are preserved through the `zapTags` escape hatch,
/// matching `nostr-tools`.
/// {@endtemplate}
class NostrNip75 {
  /// {@macro nip75}
  NostrNip75({required this.signer});

  /// Signer used by [createGoal].
  final NostrEventSigner signer;

  /// Kind of a zap goal event.
  static const int goalKind = 9041;

  /// Tags every goal must carry.
  static const List<String> requiredTags = ['amount', 'relays'];

  /// Builds an unsigned kind-9041 goal event.
  ///
  /// [amount] is a string of millisats. [closedAt] is a UNIX timestamp in
  /// seconds; [zapTags] are appended verbatim after the standard tags.
  static NostrEvent generateGoalTemplate({
    required String content,
    required String amount,
    required List<String> relays,
    int? closedAt,
    String? image,
    String? summary,
    String? r,
    String? a,
    List<List<String>> zapTags = const [],
    DateTime? createdAt,
  }) {
    return NostrEvent(
      id: null,
      kind: goalKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['amount', amount],
        ['relays', ...relays],
        if (closedAt != null) ['closed_at', '$closedAt'],
        if (image != null) ['image', image],
        if (summary != null) ['summary', summary],
        if (r != null) ['r', r],
        if (a != null) ['a', a],
        ...zapTags,
      ],
    );
  }

  /// Builds and signs a kind-9041 goal event.
  Future<NostrEvent> createGoal({
    required String content,
    required String amount,
    required List<String> relays,
    int? closedAt,
    String? image,
    String? summary,
    String? r,
    String? a,
    List<List<String>> zapTags = const [],
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateGoalTemplate(
        content: content,
        amount: amount,
        relays: relays,
        closedAt: closedAt,
        image: image,
        summary: summary,
        r: r,
        a: a,
        zapTags: zapTags,
        createdAt: createdAt,
      ),
    );
  }

  /// Returns `true` when [event] is a kind-9041 event with `amount` and
  /// `relays` tags.
  static bool validateGoalEvent(NostrEvent event) {
    if (event.kind != goalKind) {
      return false;
    }

    final tags = event.tags ?? const <List<String>>[];

    return requiredTags.every(
      (required) => tags.any((tag) => tag.isNotEmpty && tag.first == required),
    );
  }
}
