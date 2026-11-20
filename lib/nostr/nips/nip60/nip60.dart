import 'dart:collection';
import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip44/nip44.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_cashu_proof}
/// A cashu proof as stored in NIP-60 token events.
///
/// The JSON shape follows the default cashu proof format:
/// `{"id": "...", "amount": 1, "secret": "...", "C": "..."}`.
/// [unblindedSignature] and [dleq] are optional and preserved when present.
///
/// The `C` point keeps its spec spelling through [C]; [c] is a lower-case
/// alias for callers that prefer idiomatic Dart field names.
/// {@endtemplate}
class NostrCashuProof {
  /// {@macro nostr_cashu_proof}
  const NostrCashuProof({
    required this.id,
    required this.amount,
    required this.secret,
    required this.C,
    this.unblindedSignature,
    this.dleq,
  });

  /// Parses a cashu proof, tolerating missing or stringly-typed fields.
  ///
  /// Unknown keys are ignored. A missing amount becomes `0` and missing
  /// string fields become empty strings, so callers can inspect the proof
  /// before deciding whether it is usable.
  factory NostrCashuProof.fromJson(Map<String, dynamic> json) {
    final rawDleq = json['dleq'];

    return NostrCashuProof(
      id: '${json['id'] ?? ''}',
      amount: _parseAmount(json['amount']),
      // NUT-11 secrets are JSON strings; some wallets hand back the decoded
      // array instead, so re-encode it rather than calling `toString()`.
      secret: switch (json['secret']) {
        final String value => value,
        null => '',
        final value => jsonEncode(value),
      },
      C: '${json['C'] ?? ''}',
      unblindedSignature: switch (
          json['unblindedSignature'] ?? json['unblinded_signature']) {
        final String value => value,
        null => null,
        final value => '$value',
      },
      dleq: rawDleq is Map
          ? {
              for (final entry in rawDleq.entries)
                '${entry.key}': '${entry.value}',
            }
          : null,
    );
  }

  /// Cashu keyset id.
  final String id;

  /// Proof amount in [NostrCashuTokenEvent.unit].
  final int amount;

  /// Cashu secret, which may be a NUT-11 P2PK locking condition.
  final String secret;

  /// Cashu `C` point (unblinded signature).
  final String C;

  /// Optional unblinded signature kept by some wallets.
  final String? unblindedSignature;

  /// Optional DLEQ proof (`e`, `s`, `r`).
  final Map<String, String>? dleq;

  /// Lower-case alias for [C].
  String get c => C;

  /// Serializes back to the cashu proof JSON shape.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'secret': secret,
      'C': C,
      if (unblindedSignature != null) 'unblindedSignature': unblindedSignature,
      if (dleq != null) 'dleq': dleq,
    };
  }

  static int _parseAmount(Object? rawAmount) {
    if (rawAmount is int) {
      return rawAmount;
    }
    if (rawAmount is num) {
      return rawAmount.toInt();
    }
    if (rawAmount is String) {
      return int.tryParse(rawAmount) ?? 0;
    }

    return 0;
  }
}

/// {@template nostr_cashu_token_event}
/// Decrypted payload of a NIP-60 token event (kind 7375).
///
/// [del] lists token event ids replaced by this one. The event itself is
/// encrypted; [toContentMap] returns the value that goes into `.content`
/// before NIP-44 encryption.
/// {@endtemplate}
class NostrCashuTokenEvent {
  /// {@macro nostr_cashu_token_event}
  const NostrCashuTokenEvent({
    required this.mint,
    required this.proofs,
    this.unit = 'sat',
    this.del = const [],
  });

  /// Parses the decrypted token payload.
  factory NostrCashuTokenEvent.fromContentMap(Map<String, dynamic> json) {
    final rawProofs = json['proofs'];

    return NostrCashuTokenEvent(
      mint: '${json['mint'] ?? ''}',
      unit: '${json['unit'] ?? 'sat'}',
      proofs: [
        for (final proof in rawProofs is List ? rawProofs : const [])
          if (proof is Map)
            NostrCashuProof.fromJson(
              proof.map((key, value) => MapEntry('$key', value)),
            ),
      ],
      del: [
        for (final id in (json['del'] is List ? json['del'] as List : const []))
          '$id',
      ],
    );
  }

  /// Mint the proofs belong to.
  final String mint;

  /// Base unit, `sat` by default.
  final String unit;

  /// Unspent proofs.
  final List<NostrCashuProof> proofs;

  /// Token event ids destroyed by this token.
  final List<String> del;

  /// Value to NIP-44 encrypt into a kind-7375 event.
  Map<String, dynamic> toContentMap() {
    return {
      'mint': mint,
      'unit': unit,
      'proofs': [for (final proof in proofs) proof.toJson()],
      if (del.isNotEmpty) 'del': del,
    };
  }
}

/// {@template nostr_cashu_history_entry}
/// One `e` reference in a NIP-60 spending history event (kind 7376).
///
/// 60.md stores the content as tag pairs:
/// `[["direction", "out"], ["amount", "4"], ["unit", "sat"],
/// ["e", id, "", "created"]]`.
/// [kind] is the `e` marker: [created] or [destroyed]. [direction] is
/// [incoming] or [outgoing]. The older flat tuple form
/// `[direction, amount, unit, event-id, '', kind]` is still parsed for
/// backwards compatibility.
/// {@endtemplate}
class NostrCashuHistoryEntry {
  /// {@macro nostr_cashu_history_entry}
  const NostrCashuHistoryEntry({
    required this.direction,
    required this.amount,
    required this.eventId,
    required this.kind,
    this.unit = 'sat',
  });

  /// Parses one legacy flat history tuple, tolerating extra items.
  factory NostrCashuHistoryEntry.fromJson(List<dynamic> json) {
    return NostrCashuHistoryEntry(
      direction: '${json[0] ?? ''}',
      amount: int.tryParse('${json[1] ?? ''}') ?? 0,
      unit: '${json[2] ?? 'sat'}',
      eventId: '${json[3] ?? ''}',
      kind: '${json[5] ?? ''}',
    );
  }

  /// `in` when funds were received.
  static const String incoming = 'in';

  /// `out` when funds were sent.
  static const String outgoing = 'out';

  /// Marker for a newly created token event.
  static const String created = 'created';

  /// Marker for a destroyed token event.
  static const String destroyed = 'destroyed';

  /// [incoming] or [outgoing].
  final String direction;

  /// Amount moved, in [unit].
  final int amount;

  /// Base unit, `sat` by default.
  final String unit;

  /// Referenced token event id.
  final String eventId;

  /// [created] or [destroyed].
  final String kind;

  /// Legacy flat tuple representation.
  ///
  /// Kind 7376 content is emitted as tag pairs; this form is kept for callers
  /// and parsers that still use the old tuple layout.
  List<String> toJson() => [direction, '$amount', unit, eventId, '', kind];
}

/// {@template nostr_cashu_history}
/// Parsed NIP-60 spending history event (kind 7376).
///
/// Acts as the decrypted [NostrCashuHistoryEntry] list, so existing callers
/// keep working, and additionally exposes the event's unencrypted
/// [outerTags]. 60.md keeps `redeemed` `e` markers public, so [redemptions]
/// returns those nutzap ids.
/// {@endtemplate}
class NostrCashuHistory extends ListBase<NostrCashuHistoryEntry> {
  /// {@macro nostr_cashu_history}
  NostrCashuHistory({
    required List<NostrCashuHistoryEntry> entries,
    this.outerTags = const <List<String>>[],
  }) : _entries = List.unmodifiable(entries);

  final List<NostrCashuHistoryEntry> _entries;

  /// Outer plaintext tags of the event, verbatim and in event order.
  final List<List<String>> outerTags;

  /// Nutzap ids marked `redeemed` on the event
  /// (`['e', <nutzap-id>, '', 'redeemed']`, 60.md).
  List<String> get redemptions => [
        for (final tag in outerTags)
          if (tag.length >= 4 &&
              tag.first == 'e' &&
              tag[1].isNotEmpty &&
              tag[3] == 'redeemed')
            tag[1],
      ];

  @override
  NostrCashuHistoryEntry operator [](int index) => _entries[index];

  @override
  int get length => _entries.length;

  @override
  set length(int newLength) => throw UnsupportedError(
        'Cannot change the length of a parsed history event',
      );

  @override
  void operator []=(int index, NostrCashuHistoryEntry value) =>
      throw UnsupportedError('Cannot modify a parsed history event');
}

/// {@template nostr_cashu_wallet}
/// Decrypted NIP-60 wallet state (kind 17375).
///
/// [privateKey] is a wallet-only key used to unlock P2PK ecash for NIP-61
/// nutzaps. It is not the user's Nostr key. [mints] holds one or more mint
/// URLs accepted by the wallet.
/// {@endtemplate}
class NostrCashuWallet {
  /// {@macro nostr_cashu_wallet}
  const NostrCashuWallet({required this.privateKey, required this.mints});

  /// Wallet-only private key, hex encoded.
  final String privateKey;

  /// Mint URLs accepted by the wallet.
  final List<String> mints;

  /// Tag pairs stored, encrypted, in the wallet event content.
  List<List<String>> toContentTags() {
    return [
      ['privkey', privateKey],
      for (final mint in mints) ['mint', mint],
    ];
  }
}

/// {@template nostr_cashu_quote}
/// Decrypted NIP-60 quote event (kind 7374).
///
/// Quote ids are local state; the event only exists to sync an in-flight
/// mint quote across devices. [expiresAt] comes from the `expiration` tag.
/// {@endtemplate}
class NostrCashuQuote {
  /// {@macro nostr_cashu_quote}
  const NostrCashuQuote({
    required this.quoteId,
    required this.mintUrl,
    required this.expiresAt,
  });

  /// Mint quote id.
  final String quoteId;

  /// Mint URL from the `mint` tag.
  final String mintUrl;

  /// Expiration from the `expiration` tag.
  final DateTime expiresAt;
}

/// {@template nostr_cashu_spend_plan}
/// Result of [NostrNip60.planSpend].
///
/// [spent] holds the proofs selected for spending, [change] the proofs that
/// stay in the wallet and [insufficient] is `true` when the available proofs
/// could not cover the requested amount.
/// {@endtemplate}
class NostrCashuSpendPlan {
  /// {@macro nostr_cashu_spend_plan}
  const NostrCashuSpendPlan({
    required this.spent,
    required this.change,
    required this.insufficient,
  });

  /// Proofs selected to send.
  final List<NostrCashuProof> spent;

  /// Proofs left in the wallet.
  final List<NostrCashuProof> change;

  /// Whether [spent] could not cover the requested amount.
  final bool insufficient;

  /// Whether the plan fully covers the requested amount.
  bool get sufficient => !insufficient;
}

/// {@template nip60}
/// NIP-60 cashu wallet state.
///
/// Wallets (kind 17375), token events (kind 7375), spending history
/// (kind 7376) and optional mint quotes (kind 7374) are stored as
/// NIP-44 self-encrypted events. The bound [signer] must therefore be able
/// to NIP-44 encrypt and decrypt to its own public key. Local signers do;
/// remote signers must expose `nip44_encrypt`/`nip44_decrypt` self
/// operations, otherwise [StateError] is thrown with an actionable message.
///
/// Token deletion follows NIP-09 with kind 5 and the NIP-60 requirement of a
/// `['k', '7375']` tag. Kind 7375 is a regular kind, so no `a` tag is used.
/// {@endtemplate}
class NostrNip60 {
  /// {@macro nip60}
  NostrNip60({required this.signer});

  /// Signer used for NIP-44 self encryption and event signing.
  final NostrEventSigner signer;

  /// Replaceable wallet event kind.
  static const int walletKind = 17375;

  /// Unspent proofs token event kind.
  static const int tokenKind = 7375;

  /// Spending history event kind.
  static const int historyKind = 7376;

  /// Mint quote event kind.
  static const int quoteKind = 7374;

  /// NIP-09 deletion event kind used to delete token events.
  static const int deleteKind = 5;

  /// Kinds defined by NIP-60.
  static const List<int> kinds = [
    walletKind,
    tokenKind,
    historyKind,
    quoteKind,
  ];

  /// Builds and signs a kind-17375 wallet event.
  ///
  /// The content is the NIP-44 self-encrypted tag-pair array.
  /// [NostrCashuWallet] must carry a private key and at least one mint.
  Future<NostrEvent> createWalletEvent({
    required NostrCashuWallet wallet,
    DateTime? createdAt,
  }) async {
    if (wallet.privateKey.isEmpty) {
      throw ArgumentError.value(
        wallet.privateKey,
        'wallet.privateKey',
        'Wallet private key must not be empty',
      );
    }
    if (wallet.mints.isEmpty) {
      throw ArgumentError.value(
        wallet.mints,
        'wallet.mints',
        'A wallet event must list at least one mint',
      );
    }

    final content = await _encryptSelf(
      jsonEncode(wallet.toContentTags()),
    );

    return signer.sign(
      NostrEvent(
        id: null,
        kind: walletKind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: const [],
      ),
    );
  }

  /// Decrypts and parses a kind-17375 wallet event.
  ///
  /// Throws [StateError] when the signer cannot NIP-44 decrypt to its own
  /// public key, [ArgumentError] for the wrong kind and [FormatException]
  /// for malformed content.
  Future<NostrCashuWallet> parseWalletEvent(NostrEvent event) async {
    if (event.kind != walletKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Expected a NIP-60 wallet event (kind 17375)',
      );
    }

    final decoded = jsonDecode(await _decryptSelf(event));

    if (decoded is! List) {
      throw const FormatException('Wallet content must be a list of tag pairs');
    }

    final pairs = _tagPairs(decoded);
    final privateKey = _firstValue(pairs, 'privkey');
    final mints = [
      for (final pair in pairs)
        if (pair[0] == 'mint' && pair[1].isNotEmpty) pair[1],
    ];

    if (privateKey == null || privateKey.isEmpty) {
      throw const FormatException('Wallet event is missing a private key');
    }
    if (mints.isEmpty) {
      throw const FormatException('Wallet event is missing mint tags');
    }

    return NostrCashuWallet(privateKey: privateKey, mints: mints);
  }

  /// Like [parseWalletEvent], but returns `null` for invalid events.
  ///
  /// [StateError] from a signer that cannot self-encrypt is rethrown: it is
  /// a configuration problem, not an invalid event.
  Future<NostrCashuWallet?> tryParseWalletEvent(NostrEvent event) async {
    if (event.kind != walletKind) {
      return null;
    }

    try {
      return await parseWalletEvent(event);
    } on FormatException {
      return null;
    }
  }

  /// Builds and signs a kind-7375 token event.
  Future<NostrEvent> createTokenEvent({
    required NostrCashuTokenEvent token,
    DateTime? createdAt,
  }) async {
    if (token.mint.isEmpty) {
      throw ArgumentError.value(
        token.mint,
        'token.mint',
        'Token event must reference a mint',
      );
    }
    if (token.proofs.isEmpty) {
      throw ArgumentError.value(
        token.proofs,
        'token.proofs',
        'Token event must contain at least one proof',
      );
    }
    for (final proof in token.proofs) {
      if (proof.secret.isEmpty) {
        throw ArgumentError.value(
          proof.secret,
          'token.proofs',
          'Every proof must carry a non-empty cashu secret',
        );
      }
    }

    final content = await _encryptSelf(jsonEncode(token.toContentMap()));

    return signer.sign(
      NostrEvent(
        id: null,
        kind: tokenKind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: const [],
      ),
    );
  }

  /// Decrypts and parses a kind-7375 token event.
  Future<NostrCashuTokenEvent> parseTokenEvent(NostrEvent event) async {
    if (event.kind != tokenKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Expected a NIP-60 token event (kind 7375)',
      );
    }

    final decoded = jsonDecode(await _decryptSelf(event));

    if (decoded is! Map) {
      throw const FormatException('Token content must be a JSON object');
    }

    final token = NostrCashuTokenEvent.fromContentMap(
      decoded.map((key, value) => MapEntry('$key', value)),
    );

    if (token.mint.isEmpty) {
      throw const FormatException('Token event is missing a mint');
    }
    if (token.proofs.isEmpty) {
      throw const FormatException('Token event is missing proofs');
    }

    return token;
  }

  /// Like [parseTokenEvent], but returns `null` for invalid events.
  Future<NostrCashuTokenEvent?> tryParseTokenEvent(NostrEvent event) async {
    if (event.kind != tokenKind) {
      return null;
    }

    try {
      return await parseTokenEvent(event);
    } on FormatException {
      return null;
    }
  }

  /// Builds and signs a kind-7376 spending history event.
  ///
  /// Every entry is encrypted into the content as 60.md tag pairs:
  /// `[["direction", "out"], ["amount", "4"], ["unit", "sat"],
  /// ["e", id, "", "created"]]`.
  /// Consecutive entries sharing direction, amount and unit are folded into
  /// one tag block, so a spend emits the single `destroyed`/`created` block
  /// from the 60.md example. The outer plaintext tags are exactly [extraTags]:
  /// 60.md only defines outer `e` tags for redemptions
  /// (`['e', <nutzap-id>, '', 'redeemed']`, 60.md:106-108) plus the sender `p`
  /// tag, so `created`/`destroyed` markers stay inside the encrypted content
  /// and must not be mirrored on the event. Pass redemption tags from
  /// `NostrNip61.buildRedemptionHistoryTags` in [extraTags].
  Future<NostrEvent> createHistoryEvent({
    required List<NostrCashuHistoryEntry> entries,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) async {
    if (entries.isEmpty && extraTags.isEmpty) {
      throw ArgumentError(
        'History event must contain at least one entry or extra tag',
      );
    }
    for (final entry in entries) {
      if (entry.eventId.isEmpty) {
        throw ArgumentError.value(
          entry.eventId,
          'entries',
          'History entry must reference the token event id it describes',
        );
      }
    }

    final content = entries.isEmpty
        ? await _encryptSelf('[]')
        : await _encryptSelf(jsonEncode(_historyContentTags(entries)));

    return signer.sign(
      NostrEvent(
        id: null,
        kind: historyKind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          for (final tag in extraTags) [...tag],
        ],
      ),
    );
  }

  /// Decrypts and parses a kind-7376 spending history event.
  ///
  /// The returned [NostrCashuHistory] is the entry list plus the outer
  /// plaintext tags, which are otherwise discarded; [NostrCashuHistory.
  /// redemptions] derives the nutzap ids marked `redeemed` there.
  Future<NostrCashuHistory> parseHistoryEvent(NostrEvent event) async {
    if (event.kind != historyKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Expected a NIP-60 history event (kind 7376)',
      );
    }

    final decoded = jsonDecode(await _decryptSelf(event));

    if (decoded is! List) {
      throw const FormatException('History content must be a list of tags');
    }

    return NostrCashuHistory(
      entries: _parseHistoryContent(decoded),
      outerTags: [
        for (final tag in event.tags ?? const <List<String>>[])
          List<String>.of(tag),
      ],
    );
  }

  /// Like [parseHistoryEvent], but returns `null` for invalid events.
  Future<NostrCashuHistory?> tryParseHistoryEvent(
    NostrEvent event,
  ) async {
    if (event.kind != historyKind) {
      return null;
    }

    try {
      return await parseHistoryEvent(event);
    } on FormatException {
      return null;
    }
  }

  /// Builds and signs an optional kind-7374 mint quote event.
  ///
  /// The quote id is NIP-44 encrypted into the content. The event carries an
  /// `expiration` tag plus the `mint` URL, as specified in 60.md.
  Future<NostrEvent> createQuoteEvent({
    required String quoteId,
    required String mintUrl,
    required DateTime expiresAt,
    DateTime? createdAt,
  }) async {
    if (quoteId.isEmpty) {
      throw ArgumentError.value(quoteId, 'quoteId', 'Quote id is required');
    }
    if (mintUrl.isEmpty) {
      throw ArgumentError.value(mintUrl, 'mintUrl', 'Mint URL is required');
    }

    final content = await _encryptSelf(quoteId);

    return signer.sign(
      NostrEvent(
        id: null,
        kind: quoteKind,
        content: content,
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['expiration', '${expiresAt.millisecondsSinceEpoch ~/ 1000}'],
          ['mint', mintUrl],
        ],
      ),
    );
  }

  /// Decrypts and parses a kind-7374 quote event.
  Future<NostrCashuQuote> parseQuoteEvent(NostrEvent event) async {
    if (event.kind != quoteKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Expected a NIP-60 quote event (kind 7374)',
      );
    }

    final mintUrl = _firstTagValue(event.tags, 'mint');
    final expiration = NostrValidators.tryUnixSeconds(
      _firstTagValue(event.tags, 'expiration'),
    );

    if (mintUrl == null || mintUrl.isEmpty) {
      throw const FormatException('Quote event is missing a mint tag');
    }
    if (expiration == null) {
      throw const FormatException('Quote event is missing an expiration tag');
    }

    return NostrCashuQuote(
      quoteId: await _decryptSelf(event),
      mintUrl: mintUrl,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiration * 1000,
        isUtc: true,
      ),
    );
  }

  /// Like [parseQuoteEvent], but returns `null` for invalid events.
  Future<NostrCashuQuote?> tryParseQuoteEvent(NostrEvent event) async {
    if (event.kind != quoteKind) {
      return null;
    }

    try {
      return await parseQuoteEvent(event);
    } on FormatException {
      return null;
    }
  }

  /// Builds an unsigned NIP-09 kind-5 deletion event for token events.
  ///
  /// 60.md requires the delete event to include `['k', '7375']`; kind 7375
  /// is not addressable, so no `a` tag is added. Sign the returned template
  /// before publishing.
  static NostrEvent createDeleteTemplate({
    required List<String> tokenEventIds,
    String content = '',
    DateTime? createdAt,
  }) {
    if (tokenEventIds.isEmpty) {
      throw ArgumentError.value(
        tokenEventIds,
        'tokenEventIds',
        'At least one token event id is required',
      );
    }

    return NostrEvent(
      id: null,
      kind: deleteKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final id in tokenEventIds) ['e', id],
        const ['k', '$tokenKind'],
      ],
    );
  }

  /// Plans a spend without signing anything.
  ///
  /// The planner is mint- and unit-agnostic: it only looks at [amount] and
  /// ignores each proof's key-set id, so callers must group proofs per mint
  /// and unit before planning and must publish the resulting token/deletion
  /// events themselves.
  ///
  /// The planner prefers an exact proof when one matches [amount], then
  /// greedily takes the largest remaining proofs until the amount is
  /// covered. [NostrCashuSpendPlan.insufficient] is `true` when the total is
  /// below [amount]; in that case [NostrCashuSpendPlan.spent] is empty and
  /// all proofs are returned as change.
  static NostrCashuSpendPlan planSpend({
    required List<NostrCashuProof> proofs,
    required int amount,
  }) {
    if (amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must not be negative',
      );
    }
    if (amount == 0) {
      return NostrCashuSpendPlan(
        spent: const [],
        change: List.unmodifiable(proofs),
        insufficient: false,
      );
    }

    final exactIndex = proofs.indexWhere((proof) => proof.amount == amount);
    if (exactIndex >= 0) {
      return NostrCashuSpendPlan(
        spent: [proofs[exactIndex]],
        change: [
          for (var index = 0; index < proofs.length; index++)
            if (index != exactIndex) proofs[index],
        ],
        insufficient: false,
      );
    }

    final ordered = [
      for (var index = 0; index < proofs.length; index++) index,
    ]..sort((a, b) => proofs[b].amount.compareTo(proofs[a].amount));

    final selected = <int>{};
    var total = 0;

    for (final index in ordered) {
      if (total >= amount) {
        break;
      }
      selected.add(index);
      total += proofs[index].amount;
    }

    if (total < amount) {
      return NostrCashuSpendPlan(
        spent: const [],
        change: List.unmodifiable(proofs),
        insufficient: true,
      );
    }

    return NostrCashuSpendPlan(
      spent: [
        for (final index in selected.toList()..sort())
          if (index < proofs.length) proofs[index],
      ],
      change: [
        for (var index = 0; index < proofs.length; index++)
          if (!selected.contains(index)) proofs[index],
      ],
      insufficient: false,
    );
  }

  /// Rolls unspent proofs into a new kind-7375 event.
  ///
  /// [spentProofs] are removed by secret (cashu secrets are unique per
  /// proof). The new token keeps the source [token]'s mint and unit and
  /// records [previousEventId] in `del`. Throws [ArgumentError] when no
  /// proof remains.
  ///
  /// This method is mint/unit-agnostic and only builds the replacement token.
  /// Rolling over a spend is not complete until the caller also signs and
  /// publishes a NIP-09 deletion for [previousEventId], for example with
  /// [createDeleteTemplate]. NIP-60 requires the old token to be deleted so
  /// the same proofs are not counted twice (60.md, token events).
  Future<NostrEvent> rolloverTokenEvent({
    required String previousEventId,
    required NostrCashuTokenEvent token,
    required List<NostrCashuProof> spentProofs,
    DateTime? createdAt,
  }) async {
    final spentSecrets = {
      for (final proof in spentProofs) proof.secret,
    };

    final unspent = [
      for (final proof in token.proofs)
        if (!spentSecrets.contains(proof.secret)) proof,
    ];

    if (unspent.isEmpty) {
      throw ArgumentError(
        'Cannot roll over a token event without unspent proofs',
      );
    }

    return createTokenEvent(
      token: NostrCashuTokenEvent(
        mint: token.mint,
        unit: token.unit,
        proofs: unspent,
        del: [previousEventId],
      ),
      createdAt: createdAt,
    );
  }

  Future<String> _encryptSelf(String plaintext) async {
    try {
      return await signer.nip44Encrypt(plaintext, signer.publicKey);
    } catch (error) {
      throw StateError(
        'NIP-60 requires a signer able to NIP-44 encrypt to its own public '
        'key (${signer.publicKey}). Remote signers must support '
        'nip44_encrypt for self-addressed payloads. Original error: $error',
      );
    }
  }

  Future<String> _decryptSelf(NostrEvent event) async {
    final content = event.content ?? '';
    if (content.isEmpty) {
      throw const FormatException('Event content is empty');
    }

    // Reject malformed NIP-44 framing before involving the signer: version
    // byte, base64 body and minimum size (NIP-44 payload framing, 44.md).
    // Without this check a broken payload would reach the signer and its
    // failure would be misreported as a signer-capability problem
    // ([StateError]) instead of bad content ([FormatException]).
    try {
      Nip44.decodePayload(content);
    } catch (error) {
      // decodePayload reports framing problems only, so anything here is bad
      // content rather than a missing signer capability.
      throw FormatException('Malformed NIP-44 payload: $error');
    }

    try {
      return await signer.nip44Decrypt(content, signer.publicKey);
    } catch (error) {
      // A signer rejects a well-framed but undecryptable payload (bad MAC,
      // bad padding) with FormatException or ArgumentError; that is a content
      // problem. Anything else means the signer cannot self-decrypt at all.
      if (error is FormatException || error is ArgumentError) {
        throw FormatException('Unable to decrypt NIP-44 payload: $error');
      }
      throw StateError(
        'NIP-60 requires a signer able to NIP-44 decrypt to its own public '
        'key (${signer.publicKey}). Remote signers must support '
        'nip44_decrypt for self-addressed payloads. Original error: $error',
      );
    }
  }

  /// Encodes entries as 60.md tag pairs for the encrypted kind-7376 content.
  static List<List<String>> _historyContentTags(
    List<NostrCashuHistoryEntry> entries,
  ) {
    final tags = <List<String>>[];
    NostrCashuHistoryEntry? head;

    for (final entry in entries) {
      if (head == null ||
          head.direction != entry.direction ||
          head.amount != entry.amount ||
          head.unit != entry.unit) {
        head = entry;
        tags
          ..add(['direction', entry.direction])
          ..add(['amount', '${entry.amount}'])
          ..add(['unit', entry.unit]);
      }
      tags.add(['e', entry.eventId, '', entry.kind]);
    }

    return tags;
  }

  /// Parses 60.md tag pairs, falling back to the legacy flat tuple form.
  static List<NostrCashuHistoryEntry> _parseHistoryContent(
    List<dynamic> decoded,
  ) {
    final entries = <NostrCashuHistoryEntry>[];
    String? direction;
    var amount = 0;
    var unit = 'sat';

    for (final item in decoded) {
      if (item is! List || item.isEmpty) {
        continue;
      }

      // Legacy form: [direction, amount, unit, event-id, '', kind].
      if (item.length >= 6) {
        entries.add(NostrCashuHistoryEntry.fromJson(item));
        continue;
      }

      final name = '${item[0]}';
      final value = item.length > 1 ? '${item[1]}' : '';

      if (name == 'direction') {
        direction = value;
        amount = 0;
        unit = 'sat';
      } else if (name == 'amount') {
        amount = int.tryParse(value) ?? 0;
      } else if (name == 'unit') {
        unit = value.isEmpty ? 'sat' : value;
      } else if (name == 'e' && direction != null) {
        entries.add(
          NostrCashuHistoryEntry(
            direction: direction,
            amount: amount,
            unit: unit,
            eventId: value,
            kind: item.length > 3 ? '${item[3]}' : '',
          ),
        );
      }
    }

    return entries;
  }

  static List<List<String>> _tagPairs(List<dynamic> decoded) {
    final pairs = <List<String>>[];

    for (final item in decoded) {
      if (item is List && item.length >= 2) {
        pairs.add(['${item[0]}', '${item[1]}']);
      }
    }

    return pairs;
  }

  static String? _firstValue(List<List<String>> pairs, String name) {
    for (final pair in pairs) {
      if (pair[0] == name && pair[1].isNotEmpty) {
        return pair[1];
      }
    }

    return null;
  }

  static String? _firstTagValue(List<List<String>>? tags, String name) {
    return NostrTags.first(tags, name);
  }
}
