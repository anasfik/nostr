import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip60/nip60.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_mint_ref}
/// One mint accepted by a NIP-61 mint recommendation.
///
/// [url] is the mint URL exactly as the recipient wrote it. [units] are the
/// optional unit markers after the URL (`sat`, `usd`, ...). An empty list
/// means the recommendation does not restrict units.
/// {@endtemplate}
class NostrMintRef {
  /// {@macro nostr_mint_ref}
  const NostrMintRef({required this.url, this.units = const []});

  /// Mint URL.
  final String url;

  /// Supported base units.
  final List<String> units;
}

/// {@template nostr_mint_recommendation}
/// Parsed NIP-61 mint recommendation (kind 10019).
///
/// [relayUrl] is the first `relay` tag. [mints] keeps every valid mint tag.
/// [p2pkPubkey] is the `pubkey` tag, falling back to the event author when
/// the tag is absent. [author] is always the event author so callers can
/// distinguish the identity key from the dedicated P2PK key.
/// {@endtemplate}
class NostrMintRecommendation {
  /// {@macro nostr_mint_recommendation}
  const NostrMintRecommendation({
    required this.relayUrl,
    required this.mints,
    required this.p2pkPubkey,
    this.author,
  });

  /// Relay where the recipient reads token events.
  final String relayUrl;

  /// Mints the recipient accepts.
  final List<NostrMintRef> mints;

  /// Public key that MUST be used to P2PK-lock nutzaps.
  final String p2pkPubkey;

  /// Event author public key, when known.
  final String? author;
}

/// {@template nostr_nutzap}
/// Parsed NIP-61 nutzap (kind 9321).
///
/// [proofs] are the P2PK-locked cashu proofs, [mintUrl] is the `u` tag and
/// [recipient] is the `p` tag. [eventId] and [kind] describe the nutzapped
/// event when present. [comment] is the optional content.
/// {@endtemplate}
class NostrNutzap {
  /// {@macro nostr_nutzap}
  const NostrNutzap({
    required this.proofs,
    required this.mintUrl,
    required this.recipient,
    this.unit = 'sat',
    this.eventId,
    this.kind,
    this.comment = '',
  });

  /// P2PK-locked proofs.
  final List<NostrCashuProof> proofs;

  /// Base unit, `sat` by default.
  final String unit;

  /// Mint URL from the `u` tag.
  final String mintUrl;

  /// Recipient Nostr identity public key from the `p` tag.
  final String recipient;

  /// Nutzapped event id from the `e` tag, when present.
  final String? eventId;

  /// Nutzapped event kind from the `k` tag, when present.
  final int? kind;

  /// Optional comment.
  final String comment;
}

/// {@template nostr_nutzap_verification}
/// Structural verification result for a NIP-61 nutzap.
///
/// [valid] is `true` only when [problems] is empty. DLEQ proof validation is
/// deliberately out of scope; this checks the event structure only.
/// {@endtemplate}
class NostrNutzapVerification {
  /// {@macro nostr_nutzap_verification}
  const NostrNutzapVerification({required this.problems});

  /// Human-readable structural problems. Empty when [valid].
  final List<String> problems;

  /// Whether no structural problem was found.
  bool get valid => problems.isEmpty;
}

/// {@template nip61}
/// NIP-61 nutzaps: mint recommendations and P2PK cashu zaps.
///
/// Kind 10019 advertises accepted relays and mints. Kind 9321 carries proofs
/// P2PK-locked to the recipient's advertised `02`-prefixed key. Event signing
/// uses the bound [signer]; parsing and structural verification are static
/// and need no signer.
/// {@endtemplate}
class NostrNip61 {
  /// {@macro nip61}
  NostrNip61({required this.signer});

  /// Signer used to publish recommendations and nutzaps.
  final NostrEventSigner signer;

  /// Mint recommendation kind.
  static const int mintRecommendationKind = 10019;

  /// Nutzap kind.
  static const int nutzapKind = 9321;

  /// Kinds defined by NIP-61.
  static const List<int> kinds = [mintRecommendationKind, nutzapKind];

  /// Builds and signs a kind-10019 mint recommendation.
  ///
  /// [p2pkPubkey] defaults to `02` + the bound signer's x-only public key
  /// (BIP-340 keys are even-y, so the compressed form starts with `02`).
  /// An explicit key must already be a `02`-prefixed 66-character compressed
  /// key. The value is carried in a `pubkey` tag as required by 61.md.
  Future<NostrEvent> createMintRecommendation({
    required String relayUrl,
    required List<NostrMintRef> mints,
    String? p2pkPubkey,
    String content = '',
    DateTime? createdAt,
  }) async {
    if (relayUrl.isEmpty) {
      throw ArgumentError.value(relayUrl, 'relayUrl', 'Relay URL is required');
    }
    if (mints.isEmpty) {
      throw ArgumentError.value(
        mints,
        'mints',
        'At least one mint is required',
      );
    }

    final key = p2pkPubkey ?? '02${signer.publicKey}';
    if (!_isP2pkKey(key)) {
      throw ArgumentError.value(
        key,
        'p2pkPubkey',
        'P2PK key must be a 02-prefixed 66-character compressed secp256k1 '
            'key. Omit p2pkPubkey to derive it from the signer public key.',
      );
    }

    return signer.sign(
      NostrEvent(
        id: null,
        kind: mintRecommendationKind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['relay', relayUrl],
          for (final mint in mints) ['mint', mint.url, ...mint.units],
          ['pubkey', key],
        ],
      ),
    );
  }

  /// Parses a kind-10019 mint recommendation.
  ///
  /// Invalid mint URLs are skipped while the event itself is still returned.
  /// Throws [ArgumentError] for the wrong kind.
  static NostrMintRecommendation parseMintRecommendation(NostrEvent event) {
    final parsed = tryParseMintRecommendation(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-61 mint recommendation event');
    }

    return parsed;
  }

  /// Like [parseMintRecommendation], but returns `null` for invalid events.
  static NostrMintRecommendation? tryParseMintRecommendation(
    NostrEvent event,
  ) {
    if (event.kind != mintRecommendationKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final relayUrl = NostrTags.first(tags, 'relay') ?? '';
    final p2pkPubkey = NostrTags.first(tags, 'pubkey') ?? event.pubkey;

    final mints = <NostrMintRef>[];

    for (final tag in tags) {
      if (tag.length < 2 || tag.first != 'mint') {
        continue;
      }
      if (!_isMintUrl(tag[1])) {
        continue;
      }
      mints.add(
        NostrMintRef(
          url: tag[1],
          units: [
            for (final unit in tag.skip(2))
              if (unit.isNotEmpty) unit,
          ],
        ),
      );
    }

    return NostrMintRecommendation(
      relayUrl: relayUrl,
      mints: mints,
      p2pkPubkey: p2pkPubkey,
      author: event.pubkey,
    );
  }

  /// Builds and signs a kind-9321 nutzap.
  ///
  /// [p2pkKey] must be compressed and `02`-prefixed for nostr<>cashu
  /// compatibility. [mintUrl] is written to the `u` tag exactly as given,
  /// because receivers match it against their own kind-10019 event.
  ///
  /// Every proof MUST carry a NUT-11 P2PK secret locked to [p2pkKey]
  /// (61.md); an unlocked or differently locked proof throws
  /// [ArgumentError] instead of publishing ecash the recipient cannot spend.
  /// Use [p2pkLockForProof] to inspect a proof before building the nutzap.
  Future<NostrEvent> createNutzap({
    required String recipient,
    required String mintUrl,
    required List<NostrCashuProof> proofs,
    required String p2pkKey,
    String unit = 'sat',
    String comment = '',
    String? eventId,
    int? kind,
    DateTime? createdAt,
  }) async {
    if (!_isP2pkKey(p2pkKey)) {
      throw ArgumentError.value(
        p2pkKey,
        'p2pkKey',
        'NIP-61 P2PK keys must be compressed, 02-prefixed and 64 lowercase '
            'hex characters long',
      );
    }
    if (!NostrValidators.isHex64(recipient)) {
      throw ArgumentError.value(
        recipient,
        'recipient',
        'Expected a 64 lowercase hex public key',
      );
    }
    if (mintUrl.isEmpty) {
      throw ArgumentError.value(mintUrl, 'mintUrl', 'Mint URL is required');
    }
    if (unit.isEmpty) {
      throw ArgumentError.value(unit, 'unit', 'Unit is required');
    }
    if (proofs.isEmpty) {
      throw ArgumentError.value(
        proofs,
        'proofs',
        'A nutzap must carry at least one proof',
      );
    }

    final expectedLock = _normalizeP2pkKey(p2pkKey);

    for (var index = 0; index < proofs.length; index++) {
      final lock = p2pkLockForProof(proofs[index]);

      if (lock == null) {
        throw ArgumentError.value(
          proofs[index].secret,
          'proofs',
          'Proof ${index + 1} has no NUT-11 P2PK lock; nutzap proofs must be '
              'locked to the advertised P2PK key',
        );
      }
      if (lock != expectedLock) {
        throw ArgumentError.value(
          proofs[index].secret,
          'proofs',
          'Proof ${index + 1} is locked to $lock, not to $p2pkKey',
        );
      }
    }

    return signer.sign(
      NostrEvent(
        id: null,
        kind: nutzapKind,
        content: comment,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          for (final proof in proofs) ['proof', jsonEncode(proof.toJson())],
          ['u', mintUrl],
          ['p', recipient],
          if (eventId != null) ['e', eventId],
          if (kind != null) ['k', '$kind'],
          ['unit', unit],
        ],
      ),
    );
  }

  /// Parses a kind-9321 nutzap.
  ///
  /// Malformed proof JSON entries are skipped. Throws [ArgumentError] when
  /// the event is not a nutzap or lacks a `p`/`u` tag or valid proofs.
  static NostrNutzap parseNutzap(NostrEvent event) {
    final parsed = tryParseNutzap(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-61 nutzap event');
    }

    return parsed;
  }

  /// Like [parseNutzap], but returns `null` for invalid events.
  static NostrNutzap? tryParseNutzap(NostrEvent event) {
    if (event.kind != nutzapKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final recipient = NostrTags.first(tags, 'p');
    final mintUrl = NostrTags.first(tags, 'u');

    if (recipient == null || recipient.isEmpty) {
      return null;
    }
    if (mintUrl == null || mintUrl.isEmpty) {
      return null;
    }

    final proofs = <NostrCashuProof>[];

    for (final tag in tags) {
      if (tag.length < 2 || tag.first != 'proof') {
        continue;
      }

      try {
        final decoded = jsonDecode(tag[1]);
        if (decoded is Map) {
          proofs.add(
            NostrCashuProof.fromJson(
              decoded.map((key, value) => MapEntry('$key', value)),
            ),
          );
        }
      } on FormatException {
        // Tolerant: a single broken proof does not discard the nutzap.
      }
    }

    if (proofs.isEmpty) {
      return null;
    }

    return NostrNutzap(
      proofs: proofs,
      unit: NostrTags.first(tags, 'unit') ?? 'sat',
      mintUrl: mintUrl,
      recipient: recipient,
      eventId: NostrTags.first(tags, 'e'),
      kind: int.tryParse(NostrTags.first(tags, 'k') ?? ''),
      comment: event.content ?? '',
    );
  }

  /// Checks a nutzap against the recipient's mint recommendation.
  ///
  /// Returns a [NostrNutzapVerification] with every structural problem found:
  /// recipient vs recommendation author, mint/unit coverage, a `02`-prefixed
  /// recommendation P2PK key, a valid `p` tag, and proofs whose NUT-11 P2PK
  /// secret is locked to that same key. DLEQ proof verification is out of
  /// scope.
  static NostrNutzapVerification verifyNutzapStructure({
    required NostrNutzap nutzap,
    required NostrMintRecommendation recommendation,
  }) {
    final problems = <String>[];
    final author = recommendation.author;

    if (author != null && author.isNotEmpty) {
      if (nutzap.recipient != author) {
        problems.add(
          'recipient ${nutzap.recipient} does not match recommendation '
          'author $author',
        );
      }
    }
    // With an unknown author there is nothing to compare the identity
    // recipient against: the P2PK key is a dedicated wallet key and is not
    // the recipient's Nostr identity key (61.md), so skip the comparison.

    if (nutzap.proofs.isEmpty) {
      problems.add('nutzap carries no proofs');
    }

    final p2pkKey = recommendation.p2pkPubkey;
    final expectedLock = _normalizeP2pkKey(p2pkKey);

    if (!p2pkKey.startsWith('02')) {
      problems.add('recommendation P2PK key $p2pkKey is not 02-prefixed');
    } else if (expectedLock == null) {
      // A `02`-shaped but malformed key (truncated, non-hex) must never make
      // the nutzap valid just because there is nothing to compare against.
      problems.add(
        'recommendation P2PK key $p2pkKey is not a valid 02-prefixed '
        '66-character compressed key',
      );
    }

    for (var index = 0; index < nutzap.proofs.length; index++) {
      final proof = nutzap.proofs[index];
      final label = 'proof ${index + 1}';

      if (proof.secret.isEmpty) {
        problems.add('$label is missing a P2PK secret');
        continue;
      }

      final lock = _p2pkLockFromSecret(proof.secret);
      if (lock == null) {
        problems.add('$label has a malformed P2PK secret');
        continue;
      }

      final lockKey = _normalizeP2pkKey(lock);
      if (lockKey == null) {
        problems.add('$label has a malformed P2PK key $lock');
        continue;
      }

      if (expectedLock != null && lockKey != expectedLock) {
        // NUT-11 secrets may carry an x-only key while the recommendation
        // uses the 02-prefixed compressed form; compare normalized values.
        problems.add(
          '$label is locked to $lockKey, not to the recommendation P2PK key '
          '${recommendation.p2pkPubkey}',
        );
      }
    }

    final mints = [
      for (final mint in recommendation.mints)
        if (mint.url == nutzap.mintUrl) mint,
    ];

    if (mints.isEmpty) {
      problems.add(
        'mint ${nutzap.mintUrl} is not listed in the recommendation',
      );
    } else {
      final unitsMatch = mints.any(
        (mint) => mint.units.isEmpty || mint.units.contains(nutzap.unit),
      );

      if (!unitsMatch) {
        problems.add(
          'unit ${nutzap.unit} is not supported by ${nutzap.mintUrl}',
        );
      }
    }

    if (!NostrValidators.isHex64(nutzap.recipient)) {
      problems.add(
        'recipient ${nutzap.recipient} is not a valid p tag public key',
      );
    }

    return NostrNutzapVerification(problems: problems);
  }

  /// Builds the outer tags for a NIP-60 kind-7376 redemption history event.
  ///
  /// 61.md requires the redeemed nutzap id with a `redeemed` marker plus the
  /// nutzap sender's public key. Pass the result as
  /// [NostrNip60.createHistoryEvent] `extraTags`.
  static List<List<String>> buildRedemptionHistoryTags({
    required String nutzapEventId,
    required String senderPubkey,
  }) {
    return [
      ['e', nutzapEventId, '', 'redeemed'],
      ['p', senderPubkey],
    ];
  }

  static bool _isMintUrl(String value) {
    final uri = Uri.tryParse(value);

    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  static bool _isP2pkKey(String key) {
    return key.length == 66 &&
        key.startsWith('02') &&
        NostrValidators.isHex64(key.substring(2));
  }

  /// Extracts a proof's NUT-11 P2PK lock as 32-byte x-only lowercase hex.
  ///
  /// Returns `null` when the proof secret is empty, not JSON, not a
  /// `["P2PK", {"data": ...}]` lock, or the locked key is malformed.
  /// Compressed (`02`/`03`-prefixed) keys are reduced to their x-only form so
  /// they compare equal to the x-only keys wallets commonly store. This is the
  /// same comparison [createNutzap] and [verifyNutzapStructure] use, exposed
  /// so callers can check proofs before building a nutzap.
  static String? p2pkLockForProof(NostrCashuProof proof) {
    final lock = _p2pkLockFromSecret(proof.secret);

    return lock == null ? null : _normalizeP2pkKey(lock);
  }

  /// Extracts the P2PK key from a cashu proof secret.
  ///
  /// NUT-11 P2PK secrets are a JSON string array shaped like
  /// `["P2PK", {"data": "<key>", "nonce": "..."}]`; extra condition keys are
  /// tolerated. Returns `null` when the secret is empty, not JSON, or not a
  /// P2PK lock.
  static String? _p2pkLockFromSecret(String secret) {
    if (!secret.startsWith('[')) {
      return null;
    }

    try {
      final decoded = jsonDecode(secret);

      if (decoded is! List || decoded.length < 2 || decoded.first != 'P2PK') {
        return null;
      }

      final condition = decoded[1];
      if (condition is! Map) {
        return null;
      }

      final data = condition['data'];

      return data is String && data.isNotEmpty ? data : null;
    } on FormatException {
      return null;
    }
  }

  /// Reduces a P2PK key to its 32-byte x-only lowercase hex form.
  ///
  /// Recommendations carry a `02`-prefixed 66-character compressed key
  /// (61.md) while NUT-11 secrets are commonly stored x-only, so both forms
  /// must compare equal. The `03` compressed form is accepted as well. A
  /// compressed key is only stripped when its 64 hex characters are valid;
  /// anything else returns `null` so callers cannot match on garbage.
  static String? _normalizeP2pkKey(String key) {
    final value = key.toLowerCase();

    if (value.length == 66 &&
        (value.startsWith('02') || value.startsWith('03')) &&
        NostrValidators.isHex64(value.substring(2))) {
      return value.substring(2);
    }
    if (NostrValidators.isHex64(value)) {
      return value;
    }

    return null;
  }
}
