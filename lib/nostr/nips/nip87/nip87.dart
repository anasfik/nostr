import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_ecash_url}
/// NIP-87 `u` tag: one way to connect to an ecash mint.
///
/// The first value is the mint URL or fedimint invite code, the optional
/// [type] labels it (`cashu`, `fedimint`) as some clients do.
/// {@endtemplate}
class NostrEcashUrl {
  /// {@macro nostr_ecash_url}
  const NostrEcashUrl({required this.value, this.type});

  /// Mint URL or invite code.
  final String value;

  /// Optional `cashu`/`fedimint` label.
  final String? type;

  /// `['u', value, type?]`.
  List<String> toTag() => ['u', value, if (type != null) type!];

  /// Parses a `u` tag, or returns `null` when it has no value.
  static NostrEcashUrl? tryParse(List<String> tag) {
    if (tag.length < 2 || tag.first != 'u' || tag[1].trim().isEmpty) {
      return null;
    }

    final type = NostrTags.at(tag, 2);

    return NostrEcashUrl(
      value: tag[1],
      type: type == null || type.isEmpty ? null : type,
    );
  }
}

/// {@template nostr_ecash_mint_address}
/// NIP-87 `a` tag pointing at a kind-38172/38173 mint announcement.
///
/// [relay] is the optional relay hint in slot 2 and [type] the optional
/// `cashu`/`fedimint` label in slot 3. A label requires the relay slot.
/// {@endtemplate}
class NostrEcashMintAddress {
  /// {@macro nostr_ecash_mint_address}
  const NostrEcashMintAddress({
    required this.address,
    this.relay,
    this.type,
  });

  /// Address of the mint announcement.
  final NostrEventAddress address;

  /// Relay hint for [address].
  final String? relay;

  /// Optional `cashu`/`fedimint` label.
  final String? type;

  /// `['a', address, relay?, type?]`.
  List<String> toTag() {
    if (address.kind != NostrNip87.cashuMintKind &&
        address.kind != NostrNip87.fedimintKind) {
      throw ArgumentError.value(
        address.kind,
        'address',
        'Mint references must point to kind 38172 or 38173',
      );
    }

    return [
      'a',
      address.address,
      if (relay != null || type != null) relay ?? '',
      if (type != null) type!,
    ];
  }

  /// Parses an `a` tag, returning `null` when it is not a mint reference.
  static NostrEcashMintAddress? tryParse(List<String> tag) {
    if (tag.length < 2 || tag.first != 'a') {
      return null;
    }

    final address = NostrEventAddress.tryParse(tag[1]);
    if (address == null ||
        (address.kind != NostrNip87.cashuMintKind &&
            address.kind != NostrNip87.fedimintKind)) {
      return null;
    }

    final relay = NostrTags.at(tag, 2);
    final type = NostrTags.at(tag, 3);

    return NostrEcashMintAddress(
      address: address,
      relay: relay == null || relay.isEmpty ? null : relay,
      type: type == null || type.isEmpty ? null : type,
    );
  }
}

/// {@template nostr_ecash_recommendation}
/// Parsed NIP-87 recommendation (kind 38000).
///
/// [recommendedKind] is the `k` tag and must be [NostrNip87.cashuMintKind] or
/// [NostrNip87.fedimintKind]. [dTag] names the recommended mint event, [urls]
/// are the optional connection hints and [addresses] the `a` references that
/// disambiguate duplicate mint announcements. Malformed `u`/`a` tags are
/// skipped rather than discarding the whole recommendation.
///
/// This is deliberately distinct from NIP-61's `NostrMintRecommendation`
/// (kind 10019): NIP-61 advertises where a user receives nutzaps, NIP-87
/// publishes a public review of an ecash mint.
/// {@endtemplate}
class NostrEcashRecommendation {
  /// {@macro nostr_ecash_recommendation}
  const NostrEcashRecommendation({
    this.id,
    required this.pubkey,
    required this.dTag,
    required this.recommendedKind,
    this.urls = const [],
    this.addresses = const [],
    this.content = '',
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Recommending user public key.
  final String pubkey;

  /// `d` tag naming the recommended mint event.
  final String dTag;

  /// `k` tag: 38172 for cashu mints, 38173 for fedimints.
  final int recommendedKind;

  /// `u` tags, in event order.
  final List<NostrEcashUrl> urls;

  /// `a` tags, in event order.
  final List<NostrEcashMintAddress> addresses;

  /// Review text.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses a kind-38000 event, throwing [ArgumentError] when invalid.
  static NostrEcashRecommendation parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-87 recommendation event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrEcashRecommendation? tryParse(NostrEvent event) {
    if (event.kind != NostrNip87.recommendationKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    final recommendedKind = int.tryParse(NostrTags.first(tags, 'k') ?? '');

    if (dTag == null || dTag.isEmpty) {
      return null;
    }

    if (recommendedKind != NostrNip87.cashuMintKind &&
        recommendedKind != NostrNip87.fedimintKind) {
      return null;
    }

    final urls = <NostrEcashUrl>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'u') {
        continue;
      }

      final url = NostrEcashUrl.tryParse(tag);
      if (url != null) {
        urls.add(url);
      }
    }

    final addresses = <NostrEcashMintAddress>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'a') {
        continue;
      }

      final address = NostrEcashMintAddress.tryParse(tag);
      if (address != null) {
        addresses.add(address);
      }
    }

    return NostrEcashRecommendation(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      recommendedKind: recommendedKind!,
      urls: List<NostrEcashUrl>.unmodifiable(urls),
      addresses: List<NostrEcashMintAddress>.unmodifiable(addresses),
      content: event.content ?? '',
      tags: tags,
    );
  }
}

/// {@template nostr_cashu_mint_info}
/// Parsed NIP-87 cashu mint information (kind 38172).
///
/// [dTag] is the cashu mint pubkey from `/v1/info`, [url] the mint URL and
/// [nuts] the supported NUT numbers. `d` is a SHOULD in 87.md, so parsing
/// accepts any non-empty value; use [NostrNip87.isCashuMintKey] for the strict
/// check. [metadata] is the optional kind-0-style JSON object in `content`.
/// {@endtemplate}
class NostrCashuMintInfo {
  /// {@macro nostr_cashu_mint_info}
  const NostrCashuMintInfo({
    this.id,
    required this.pubkey,
    required this.dTag,
    this.url,
    this.nuts = const [],
    this.network,
    this.content = '',
    this.metadata,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Application public key that announced the mint.
  final String pubkey;

  /// `d` tag: cashu mint pubkey.
  final String dTag;

  /// `u` tag: mint URL.
  final String? url;

  /// Supported NUT numbers, in tag order.
  final List<String> nuts;

  /// `n` tag: network the mint runs on.
  final String? network;

  /// Raw content.
  final String content;

  /// Decoded [content] when it is a JSON object.
  final Map<String, dynamic>? metadata;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses a kind-38172 event, throwing [ArgumentError] when invalid.
  static NostrCashuMintInfo parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-87 cashu mint event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrCashuMintInfo? tryParse(NostrEvent event) {
    if (event.kind != NostrNip87.cashuMintKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.trim().isEmpty) {
      return null;
    }

    final url = NostrNip87.firstMintUrl(tags);
    final metadata = NostrNip87.decodeMetadata(event.content ?? '');

    return NostrCashuMintInfo(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      url: url,
      nuts: NostrNip87.parseNuts(tags),
      network: NostrTags.first(tags, 'n'),
      content: event.content ?? '',
      metadata: metadata,
      tags: tags,
    );
  }
}

/// {@template nostr_fedimint_info}
/// Parsed NIP-87 fedimint information (kind 38173).
///
/// [dTag] is the federation id, [inviteCodes] every `u` invite code and
/// [modules] the supported module names.
/// {@endtemplate}
class NostrFedimintInfo {
  /// {@macro nostr_fedimint_info}
  const NostrFedimintInfo({
    this.id,
    required this.pubkey,
    required this.dTag,
    this.inviteCodes = const [],
    this.modules = const [],
    this.network,
    this.content = '',
    this.metadata,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Application public key that announced the federation.
  final String pubkey;

  /// `d` tag: federation id.
  final String dTag;

  /// `u` tags: known fedimint invite codes.
  final List<String> inviteCodes;

  /// `modules` tag values, comma-split.
  final List<String> modules;

  /// `n` tag: network the federation runs on.
  final String? network;

  /// Raw content.
  final String content;

  /// Decoded [content] when it is a JSON object.
  final Map<String, dynamic>? metadata;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses a kind-38173 event, throwing [ArgumentError] when invalid.
  static NostrFedimintInfo parse(NostrEvent event) {
    final parsed = tryParse(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-87 fedimint event');
    }

    return parsed;
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrFedimintInfo? tryParse(NostrEvent event) {
    if (event.kind != NostrNip87.fedimintKind) {
      return null;
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.trim().isEmpty) {
      return null;
    }

    final metadata = NostrNip87.decodeMetadata(event.content ?? '');

    return NostrFedimintInfo(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      inviteCodes: NostrTags.all(tags, 'u'),
      modules: NostrNip87.splitValues(NostrTags.all(tags, 'modules')),
      network: NostrTags.first(tags, 'n'),
      content: event.content ?? '',
      metadata: metadata,
      tags: tags,
    );
  }
}

/// {@template nip87}
/// NIP-87 cashu and fedimint discoverability.
///
/// - kind 38000: a parameterized-replaceable recommendation. `k` selects the
///   recommended kind and must be 38172 (cashu) or 38173 (fedimint).
/// - kind 38172: cashu mint information, `d` = mint pubkey, `u` = mint URL,
///   `nuts` = supported NUT numbers.
/// - kind 38173: fedimint information, `d` = federation id, `u` = invite
///   codes, `modules` = supported modules.
///
/// These types are separate from NIP-61's kind-10019 mint recommendation:
/// NIP-87 is public discoverability and review, NIP-61 is private nutzap
/// routing.
/// {@endtemplate}
class NostrNip87 {
  /// {@macro nip87}
  NostrNip87({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Recommendation kind.
  static const int recommendationKind = 38000;

  /// Cashu mint information kind.
  static const int cashuMintKind = 38172;

  /// Fedimint information kind.
  static const int fedimintKind = 38173;

  /// Kinds this NIP defines.
  static const List<int> kinds = [
    recommendationKind,
    cashuMintKind,
    fedimintKind,
  ];

  /// Networks allowed by the `n` tag.
  static const Set<String> networks = {
    'mainnet',
    'testnet',
    'signet',
    'regtest',
  };

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _compressedKey = RegExp(r'^0[23][0-9a-f]{64}$');

  /// Whether [value] is a 64-hex x-only or 66-hex compressed mint key.
  static bool isCashuMintKey(String? value) {
    if (value == null) {
      return false;
    }

    return _hex64.hasMatch(value) || _compressedKey.hasMatch(value);
  }

  /// Decodes optional metadata content, or `null` when absent/not an object.
  static Map<String, dynamic>? decodeMetadata(String content) {
    if (content.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(content);

      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Splits comma-separated tag values (`"1,2,3"` → `1`, `2`, `3`).
  static List<String> splitValues(List<String> values) {
    return [
      for (final value in values)
        for (final part in value.split(','))
          if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// First `u` value that is a mint URL, ignoring `nuts/...` markers.
  static String? firstMintUrl(List<List<String>> tags) {
    for (final value in NostrTags.all(tags, 'u')) {
      if (value.startsWith('nuts/')) {
        continue;
      }

      return value;
    }

    return null;
  }

  /// Supported NUT numbers from `nuts` tags or `nuts/...` `u` slots.
  static List<String> parseNuts(List<List<String>> tags) {
    final nuts = <String>[];

    for (final tag in tags) {
      if (tag.length < 2) {
        continue;
      }

      if (tag.first == 'nuts') {
        nuts.addAll(splitValues([tag[1]]));
        continue;
      }

      if (tag.first != 'u') {
        continue;
      }

      for (final slot in tag.skip(1)) {
        if (slot.startsWith('nuts/')) {
          nuts.addAll(splitValues([slot.substring('nuts/'.length)]));
        }
      }
    }

    return List<String>.unmodifiable(nuts);
  }

  /// Builds an unsigned kind-38000 recommendation.
  ///
  /// Throws [ArgumentError] when [recommendedKind] is not 38172/38173, [dTag]
  /// is empty, a URL is blank, or an `a` reference points at another kind.
  /// References may cover both mint kinds in one recommendation, as the
  /// 87.md example does.
  static NostrEvent generateRecommendationTemplate({
    required int recommendedKind,
    required String dTag,
    List<NostrEcashUrl> urls = const [],
    List<NostrEcashMintAddress> addresses = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    if (recommendedKind != cashuMintKind && recommendedKind != fedimintKind) {
      throw ArgumentError.value(
        recommendedKind,
        'recommendedKind',
        'Recommendations must point to kind 38172 or 38173',
      );
    }

    if (dTag.trim().isEmpty) {
      throw ArgumentError.value(dTag, 'dTag', 'd tag must not be empty');
    }

    for (final url in urls) {
      if (url.value.trim().isEmpty) {
        throw ArgumentError.value(url.value, 'urls', 'Mint URL is empty');
      }
    }

    for (final address in addresses) {
      if (address.address.kind != cashuMintKind &&
          address.address.kind != fedimintKind) {
        throw ArgumentError.value(
          address.address.kind,
          'addresses',
          'References must point to kind 38172 or 38173',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: recommendationKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['k', '$recommendedKind'],
        ['d', dTag],
        for (final url in urls) url.toTag(),
        for (final address in addresses) address.toTag(),
      ],
    );
  }

  /// Builds an unsigned kind-38172 cashu mint announcement.
  ///
  /// [mintPubkey] is the cashu mint pubkey and becomes the `d` tag. [nuts]
  /// are emitted as one comma-separated `nuts` tag, matching the 87.md
  /// example. [content] is optional kind-0-style JSON metadata.
  static NostrEvent generateCashuMintTemplate({
    required String mintPubkey,
    required String url,
    List<String> nuts = const [],
    String network = 'mainnet',
    String content = '',
    DateTime? createdAt,
  }) {
    if (!isCashuMintKey(mintPubkey)) {
      throw ArgumentError.value(
        mintPubkey,
        'mintPubkey',
        'Expected a 64-hex x-only or 66-hex compressed mint pubkey',
      );
    }

    if (NostrValidators.tryHttpUrl(url) == null) {
      throw ArgumentError.value(url, 'url', 'Expected an http(s) mint URL');
    }

    if (!networks.contains(network)) {
      throw ArgumentError.value(network, 'network', 'Unknown network');
    }

    if (content.trim().isNotEmpty && decodeMetadata(content) == null) {
      throw ArgumentError.value(
        content,
        'content',
        'Metadata must be a JSON object',
      );
    }

    return NostrEvent(
      id: null,
      kind: cashuMintKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', mintPubkey],
        ['u', url],
        if (nuts.isNotEmpty) ['nuts', nuts.join(',')],
        ['n', network],
      ],
    );
  }

  /// Builds an unsigned kind-38173 fedimint announcement.
  ///
  /// [federationId] becomes the `d` tag and every invite code one `u` tag.
  /// [modules] are emitted as one comma-separated `modules` tag.
  static NostrEvent generateFedimintTemplate({
    required String federationId,
    required List<String> inviteCodes,
    List<String> modules = const [],
    String network = 'mainnet',
    String content = '',
    DateTime? createdAt,
  }) {
    if (federationId.trim().isEmpty) {
      throw ArgumentError.value(
        federationId,
        'federationId',
        'Federation id must not be empty',
      );
    }

    if (inviteCodes.isEmpty) {
      throw ArgumentError.value(
        inviteCodes,
        'inviteCodes',
        'At least one invite code is required',
      );
    }

    for (final code in inviteCodes) {
      if (code.trim().isEmpty) {
        throw ArgumentError.value(
          code,
          'inviteCodes',
          'Invite code is empty',
        );
      }
    }

    if (!networks.contains(network)) {
      throw ArgumentError.value(network, 'network', 'Unknown network');
    }

    if (content.trim().isNotEmpty && decodeMetadata(content) == null) {
      throw ArgumentError.value(
        content,
        'content',
        'Metadata must be a JSON object',
      );
    }

    return NostrEvent(
      id: null,
      kind: fedimintKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', federationId],
        for (final code in inviteCodes) ['u', code],
        if (modules.isNotEmpty) ['modules', modules.join(',')],
        ['n', network],
      ],
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);
}
