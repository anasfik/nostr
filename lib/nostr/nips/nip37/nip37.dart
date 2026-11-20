import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_draft_wrap}
/// Parsed NIP-37 draft wrap (kind 31234).
///
/// [identifier] is the `d` tag and [draftKind] the `k` tag of the wrapped
/// draft event (37.md:13, 20). [expiresAt] comes from the optional
/// `expiration` tag (37.md:21) and is `null` when absent or unparseable.
///
/// [content] is the NIP-44 encrypted draft. An empty content marks a deleted
/// draft (37.md:28), which [isDeleted] reports.
/// {@endtemplate}
class NostrDraftWrap {
  /// {@macro nostr_draft_wrap}
  const NostrDraftWrap({
    required this.identifier,
    required this.draftKind,
    this.content = '',
    this.expiresAt,
    this.pubkey = '',
  });

  /// `d` tag: draft identifier.
  final String identifier;

  /// `k` tag: kind of the wrapped draft event.
  final int draftKind;

  /// Encrypted draft payload.
  final String content;

  /// `expiration` tag as a date-time, or `null`.
  final DateTime? expiresAt;

  /// Author public key, when parsed from a signed event.
  final String pubkey;

  /// Whether the draft was deleted (blank `content`, 37.md:28).
  bool get isDeleted => content.isEmpty;
}

/// {@template nip37}
/// NIP-37 draft wraps (kinds 31234/1234) and private relay lists (kind 10013).
///
/// A draft wrap stores an unsigned event of any kind as a NIP-44
/// self-encrypted JSON string in `.content`; the `d` tag identifies the draft
/// and the required `k` tag its kind (37.md:9-26). Checkpoints (kind 1234)
/// point at a parent wrap with an `a` tag and hold a revision of the same
/// encrypted payload (37.md:34-45). Kind 10013 carries the user's private
/// relay list as encrypted tag pairs in `.content` (37.md:47-66).
///
/// The bound [signer] must therefore be able to NIP-44 encrypt and decrypt to
/// its own public key. Local signers do; remote signers must expose
/// `nip44_encrypt`/`nip44_decrypt` self operations, otherwise [StateError] is
/// thrown with an actionable message.
///
/// Usage:
/// ```dart
/// final wrap = await nips.nip37.createDraftWrap(
///   identifier: 'note-1',
///   draftKind: 1,
///   draft: {'kind': 1, 'content': 'GM', 'tags': []},
/// );
/// ```
/// {@endtemplate}
class NostrNip37 {
  /// {@macro nip37}
  NostrNip37({required this.signer});

  /// Signer used for NIP-44 self encryption and event signing.
  final NostrEventSigner signer;

  /// Kind 31234: encrypted storage for an unsigned draft event.
  static const int draftKind = 31234;

  /// Kind 1234: draft checkpoint belonging to a parent kind-31234 event.
  static const int checkpointKind = 1234;

  /// Kind 10013: private relay list for draft wraps.
  static const int relayListKind = 10013;

  /// Tag names [generateDraftWrapTemplate] emits itself.
  static const Set<String> _wrapTagNames = {'d', 'k', 'expiration'};

  /// Builds an unsigned kind-31234 draft wrap.
  ///
  /// [identifier] must not be blank and becomes `['d', identifier]`;
  /// [draftKind] must be non-negative and becomes `['k', '<kind>']`
  /// (37.md:18-20). [encryptedContent] is the NIP-44 payload; leave it empty
  /// to signal a deleted draft (37.md:28). [expiresAt] is UNIX seconds and
  /// must not be negative; NIP-40 `expiration` is recommended (37.md:21, 30).
  ///
  /// Throws [ArgumentError] for a blank identifier, a negative [draftKind] or
  /// a negative [expiresAt].
  static NostrEvent generateDraftWrapTemplate({
    required String identifier,
    required int draftKind,
    String encryptedContent = '',
    int? expiresAt,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    if (identifier.trim().isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Draft identifier must not be empty',
      );
    }

    if (draftKind < 0) {
      throw ArgumentError.value(
        draftKind,
        'draftKind',
        'Draft kind must not be negative',
      );
    }

    if (expiresAt != null && expiresAt < 0) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'Expiration must be a non-negative UNIX timestamp',
      );
    }

    return NostrEvent(
      id: null,
      kind: NostrNip37.draftKind,
      content: encryptedContent,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', identifier],
        ['k', '$draftKind'],
        if (expiresAt != null) ['expiration', '$expiresAt'],
        for (final tag in extraTags)
          if (tag.isEmpty || !_wrapTagNames.contains(tag.first)) tag,
      ],
    );
  }

  /// Builds an unsigned kind-1234 checkpoint for a parent draft wrap.
  ///
  /// [address] must be a valid `31234:<pubkey>:<identifier>` event address
  /// (37.md:41) and becomes the single `a` tag. [encryptedContent] is the
  /// NIP-44 payload holding the revision.
  ///
  /// Throws [ArgumentError] when [address] is malformed or not a kind-31234
  /// address.
  static NostrEvent generateCheckpointTemplate({
    required String address,
    String encryptedContent = '',
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    final parent = NostrEventAddress.tryParse(address);

    if (parent == null || parent.kind != NostrNip37.draftKind) {
      throw ArgumentError.value(
        address,
        'address',
        'Expected a 31234:<pubkey>:<identifier> event address',
      );
    }

    return NostrEvent(
      id: null,
      kind: NostrNip37.checkpointKind,
      content: encryptedContent,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['a', address],
        for (final tag in extraTags)
          if (tag.isEmpty || tag.first != 'a') tag,
      ],
    );
  }

  /// Builds an unsigned kind-10013 private relay list.
  ///
  /// The relay list lives encrypted in `.content` (37.md:51);
  /// [encryptedContent] is that NIP-44 payload and the plaintext tag list
  /// stays empty. Any `relay` tag in [extraTags] is dropped so the list does
  /// not leak unencrypted.
  static NostrEvent generateRelayListTemplate({
    String encryptedContent = '',
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return NostrEvent(
      id: null,
      kind: NostrNip37.relayListKind,
      content: encryptedContent,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final tag in extraTags)
          if (tag.isEmpty || tag.first != 'relay') tag,
      ],
    );
  }

  /// Encrypts and signs a kind-31234 draft wrap.
  ///
  /// [draft] is JSON-stringified and NIP-44 encrypted to the signer's public
  /// key (37.md:11).
  Future<NostrEvent> createDraftWrap({
    required String identifier,
    required int draftKind,
    required Map<String, dynamic> draft,
    int? expiresAt,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) async {
    return signer.sign(
      generateDraftWrapTemplate(
        identifier: identifier,
        draftKind: draftKind,
        encryptedContent: await _encryptSelf(jsonEncode(draft)),
        expiresAt: expiresAt,
        extraTags: extraTags,
        createdAt: createdAt,
      ),
    );
  }

  /// Encrypts and signs a kind-31234 wrap with blank content, marking the
  /// draft as deleted (37.md:28).
  Future<NostrEvent> createDraftDeletion({
    required String identifier,
    required int draftKind,
    int? expiresAt,
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateDraftWrapTemplate(
        identifier: identifier,
        draftKind: draftKind,
        expiresAt: expiresAt,
        createdAt: createdAt,
      ),
    );
  }

  /// Encrypts and signs a kind-1234 checkpoint of the draft [identifier].
  ///
  /// The `a` tag is built from the signer's public key, so the checkpoint is
  /// authored by and points at the same key (37.md:41).
  Future<NostrEvent> createCheckpoint({
    required String identifier,
    required Map<String, dynamic> draft,
    DateTime? createdAt,
  }) async {
    if (identifier.trim().isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Draft identifier must not be empty',
      );
    }

    return signer.sign(
      generateCheckpointTemplate(
        address: NostrEventAddress.build(
          kind: draftKind,
          pubkey: signer.publicKey,
          identifier: identifier,
        ),
        encryptedContent: await _encryptSelf(jsonEncode(draft)),
        createdAt: createdAt,
      ),
    );
  }

  /// Encrypts and signs a kind-10013 private relay list.
  ///
  /// [relays] must not be empty and every entry must use a `ws://` or
  /// `wss://` URL (37.md:49-51). The list is encoded as encrypted
  /// `['relay', url]` tag pairs.
  Future<NostrEvent> createRelayList({
    required List<String> relays,
    DateTime? createdAt,
  }) async {
    if (relays.isEmpty) {
      throw ArgumentError.value(
        relays,
        'relays',
        'A private relay list must contain at least one relay',
      );
    }

    for (final relay in relays) {
      if (!relay.startsWith('ws://') && !relay.startsWith('wss://')) {
        throw ArgumentError.value(
          relay,
          'relays',
          'invalid relay url, expected ws:// or wss:// scheme',
        );
      }
    }

    final content = await _encryptSelf(
      jsonEncode([
        for (final relay in relays) ['relay', relay],
      ]),
    );

    return signer.sign(
      generateRelayListTemplate(
        encryptedContent: content,
        createdAt: createdAt,
      ),
    );
  }

  /// Decrypts a kind-10013 relay list, in event order.
  ///
  /// Throws [ArgumentError] for the wrong kind, [FormatException] when the
  /// decrypted payload is not a tag-pair list, and [StateError] when the
  /// signer cannot self-decrypt.
  Future<List<String>> parseRelayList(NostrEvent event) async {
    if (event.kind != relayListKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Expected a NIP-37 private relay list (kind 10013)',
      );
    }

    final decoded = jsonDecode(await _decryptSelf(event));

    if (decoded is! List) {
      throw const FormatException('Relay list content must be a tag list');
    }

    final relays = <String>[];
    for (final pair in decoded) {
      if (pair is! List || pair.length < 2) {
        continue;
      }

      final name = pair[0];
      final value = pair[1];
      if (name == 'relay' && value is String && value.isNotEmpty) {
        relays.add(value);
      }
    }

    return relays;
  }

  /// Like [parseRelayList], but returns `null` for the wrong kind or malformed
  /// content. [StateError] from a signer that cannot self-decrypt is rethrown.
  Future<List<String>?> tryParseRelayList(NostrEvent event) async {
    if (event.kind != relayListKind) {
      return null;
    }

    try {
      return await parseRelayList(event);
    } on FormatException {
      return null;
    }
  }

  /// Parses [event] into [NostrDraftWrap], or returns `null` when it is not a
  /// kind-31234 event with a non-empty `d` tag and a numeric `k` tag.
  static NostrDraftWrap? tryParseDraftWrap(NostrEvent event) {
    if (event.kind != draftKind) {
      return null;
    }

    final identifier = NostrTags.first(event.tags, 'd');
    if (identifier == null || identifier.isEmpty) {
      return null;
    }

    final kind =
        NostrValidators.tryInt(NostrTags.first(event.tags, 'k'), min: 0);
    if (kind == null) {
      return null;
    }

    final expiration = NostrValidators.tryUnixSeconds(
      NostrTags.first(event.tags, 'expiration'),
    );

    return NostrDraftWrap(
      identifier: identifier,
      draftKind: kind,
      content: event.content ?? '',
      expiresAt: expiration == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiration * 1000),
      pubkey: event.pubkey,
    );
  }

  /// Like [tryParseDraftWrap], but throws [ArgumentError] for invalid events.
  static NostrDraftWrap parseDraftWrap(NostrEvent event) {
    final wrap = tryParseDraftWrap(event);

    if (wrap == null) {
      throw ArgumentError('Invalid NIP-37 draft wrap event');
    }

    return wrap;
  }

  /// Parent draft address of a kind-1234 checkpoint, or `null`.
  ///
  /// The `a` tag must address a kind-31234 event (37.md:41).
  static NostrEventAddress? tryParseCheckpoint(NostrEvent event) {
    if (event.kind != checkpointKind) {
      return null;
    }

    final parent = NostrEventAddress.tryParse(
      NostrTags.first(event.tags, 'a'),
    );

    if (parent == null || parent.kind != draftKind) {
      return null;
    }

    return parent;
  }

  /// Like [tryParseCheckpoint], but throws [ArgumentError] for invalid events.
  static NostrEventAddress parseCheckpoint(NostrEvent event) {
    final parent = tryParseCheckpoint(event);

    if (parent == null) {
      throw ArgumentError('Invalid NIP-37 checkpoint event');
    }

    return parent;
  }

  /// Decrypts the draft stored in a wrap or checkpoint.
  ///
  /// Throws [ArgumentError] for other kinds, [FormatException] when the
  /// payload is not a JSON object, and [StateError] when the signer cannot
  /// self-decrypt.
  Future<Map<String, dynamic>> decryptDraft(NostrEvent event) async {
    if (event.kind != draftKind && event.kind != checkpointKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Expected a NIP-37 draft wrap (31234) or checkpoint (1234)',
      );
    }

    final decoded = jsonDecode(await _decryptSelf(event));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Draft content must be a JSON object');
    }

    return decoded;
  }

  /// Like [decryptDraft], but returns `null` for the wrong kind or malformed
  /// content. [StateError] from a signer that cannot self-decrypt is rethrown.
  Future<Map<String, dynamic>?> tryDecryptDraft(NostrEvent event) async {
    if (event.kind != draftKind && event.kind != checkpointKind) {
      return null;
    }

    try {
      return await decryptDraft(event);
    } on FormatException {
      return null;
    }
  }

  Future<String> _encryptSelf(String plaintext) async {
    try {
      return await signer.nip44Encrypt(plaintext, signer.publicKey);
    } catch (error) {
      throw StateError(
        'NIP-37 requires a signer able to NIP-44 encrypt to its own public '
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

    try {
      return await signer.nip44Decrypt(content, signer.publicKey);
    } catch (error) {
      throw StateError(
        'NIP-37 requires a signer able to NIP-44 decrypt to its own public '
        'key (${signer.publicKey}). Remote signers must support '
        'nip44_decrypt for self-addressed payloads. Original error: $error',
      );
    }
  }
}
