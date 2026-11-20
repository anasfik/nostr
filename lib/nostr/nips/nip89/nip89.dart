import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_handler_reference}
/// NIP-89 `a` tag recommending a kind-31990 handler event.
///
/// Slot 2 is an optional relay hint, slot 3 an optional platform such as
/// `web` or `ios`. The platform slot requires the relay slot, which is emitted
/// empty when only a platform is supplied.
/// {@endtemplate}
class NostrHandlerReference {
  /// {@macro nostr_handler_reference}
  const NostrHandlerReference({
    required this.address,
    this.relay,
    this.platform,
  });

  /// Address of the handler event; must be kind 31990.
  final NostrEventAddress address;

  /// Relay hint for [address].
  final String? relay;

  /// Platform the recommendation applies to.
  final String? platform;

  /// `['a', address, relay?, platform?]`.
  List<String> toTag() {
    if (address.kind != NostrNip89.handlerKind) {
      throw ArgumentError.value(
        address.kind,
        'address',
        'Handler references must point to kind 31990',
      );
    }

    if (platform != null && platform!.trim().isEmpty) {
      throw ArgumentError.value(
        platform,
        'platform',
        'Platform must not be empty',
      );
    }

    return [
      'a',
      address.address,
      if (relay != null || platform != null) relay ?? '',
      if (platform != null) platform!,
    ];
  }

  /// Parses an `a` tag, returning `null` when it is not a handler reference.
  static NostrHandlerReference? tryParse(List<String> tag) {
    if (tag.length < 2 || tag.first != 'a') {
      return null;
    }

    final address = NostrEventAddress.tryParse(tag[1]);
    if (address == null || address.kind != NostrNip89.handlerKind) {
      return null;
    }

    final relay = NostrTags.at(tag, 2);
    final platform = NostrTags.at(tag, 3);

    return NostrHandlerReference(
      address: address,
      relay: relay == null || relay.isEmpty ? null : relay,
      platform: platform == null || platform.isEmpty ? null : platform,
    );
  }
}

/// {@template nostr_app_handler_url}
/// NIP-89 handler URL tag on a kind-31990 event.
///
/// The tag name is the platform (`web`, `ios`, ...), [url] contains a
/// `<bech32>` placeholder and [entity] names the NIP-19 entity a client should
/// substitute. A missing [entity] makes the handler generic.
/// {@endtemplate}
class NostrAppHandlerUrl {
  /// {@macro nostr_app_handler_url}
  const NostrAppHandlerUrl({
    required this.platform,
    required this.url,
    this.entity,
  });

  /// Tag name / platform, such as `web` or `android`.
  final String platform;

  /// Handler URL containing a `<bech32>` placeholder.
  final String url;

  /// NIP-19 entity name, such as `nevent` or `nprofile`.
  final String? entity;

  /// `[platform, url, entity?]`.
  List<String> toTag() {
    if (platform.trim().isEmpty) {
      throw ArgumentError.value(platform, 'platform', 'Platform is empty');
    }

    if (NostrNip89.reservedTags.contains(platform)) {
      throw ArgumentError.value(
        platform,
        'platform',
        'Platform collides with a NIP-89 tag name',
      );
    }

    if (url.trim().isEmpty) {
      throw ArgumentError.value(url, 'url', 'Handler URL is empty');
    }

    if (entity != null && !NostrNip89.entityNames.contains(entity)) {
      throw ArgumentError.value(
        entity,
        'entity',
        'Unknown NIP-19 entity name',
      );
    }

    return [platform, url, if (entity != null) entity!];
  }

  /// Parses a platform tag, returning `null` when it is a generic tag.
  static NostrAppHandlerUrl? tryParse(List<String> tag) {
    if (tag.length < 2 ||
        tag.first.isEmpty ||
        NostrNip89.reservedTags.contains(tag.first)) {
      return null;
    }

    final entity = NostrTags.at(tag, 2);
    if (entity != null && !NostrNip89.entityNames.contains(entity)) {
      return null;
    }

    return NostrAppHandlerUrl(
      platform: tag.first,
      url: tag[1],
      entity: entity,
    );
  }
}

/// {@template nostr_nsite_manifest_ref}
/// NIP-89 `latest`/`next` reference to an nsite manifest event.
///
/// The tag has the same shape as an `a` tag: an address plus an optional relay
/// hint.
/// {@endtemplate}
class NostrNsiteManifestRef {
  /// {@macro nostr_nsite_manifest_ref}
  const NostrNsiteManifestRef({required this.address, this.relay});

  /// Manifest address.
  final NostrEventAddress address;

  /// Relay hint for [address].
  final String? relay;

  /// `[name, address, relay?]`.
  List<String> toTag(String name) {
    if (name != 'latest' && name != 'next') {
      throw ArgumentError.value(
        name,
        'name',
        'Expected latest or next',
      );
    }

    return [name, address.address, if (relay != null) relay!];
  }
}

/// {@template nostr_app_recommendation}
/// Parsed NIP-89 kind-31989 recommendation.
///
/// [supportedKind] comes from the `d` tag and every handler from an `a` tag
/// pointing at a kind-31990 event.
/// {@endtemplate}
class NostrAppRecommendation {
  /// {@macro nostr_app_recommendation}
  const NostrAppRecommendation({
    this.id,
    required this.pubkey,
    required this.supportedKind,
    required this.handlers,
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Recommending user public key.
  final String pubkey;

  /// Event kind this recommendation is for.
  final int supportedKind;

  /// Recommended handler events, in tag order.
  final List<NostrHandlerReference> handlers;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses a kind-31989 event, throwing [ArgumentError] when invalid.
  static NostrAppRecommendation parse(NostrEvent event) {
    if (event.kind != NostrNip89.recommendationKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-89 recommendation',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final supportedKind = NostrValidators.tryInt(
      NostrTags.first(tags, 'd'),
      min: 0,
    );
    if (supportedKind == null) {
      throw ArgumentError('Recommendations require a numeric d tag');
    }

    final handlers = <NostrHandlerReference>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'a') {
        continue;
      }

      final handler = NostrHandlerReference.tryParse(tag);
      if (handler == null) {
        throw ArgumentError.value(
          tag,
          'a',
          'Expected a kind 31990 handler address',
        );
      }
      handlers.add(handler);
    }

    if (handlers.isEmpty) {
      throw ArgumentError('Recommendations require at least one a tag');
    }

    return NostrAppRecommendation(
      id: event.id,
      pubkey: event.pubkey,
      supportedKind: supportedKind,
      handlers: List<NostrHandlerReference>.unmodifiable(handlers),
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrAppRecommendation? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }
}

/// {@template nostr_app_handler}
/// Parsed NIP-89 kind-31990 handler information.
///
/// [kinds] lists every supported event kind and [urls] the platform handlers.
/// [latest]/[next] reference related nsite manifests.
/// {@endtemplate}
class NostrAppHandler {
  /// {@macro nostr_app_handler}
  const NostrAppHandler({
    this.id,
    required this.pubkey,
    required this.dTag,
    required this.kinds,
    this.content = '',
    this.metadata,
    this.urls = const [],
    this.latest = const [],
    this.next = const [],
    this.tags = const [],
  });

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Application public key.
  final String pubkey;

  /// `d` identifier.
  final String dTag;

  /// Event kinds the application handles.
  final List<int> kinds;

  /// Raw metadata JSON, empty when the app uses its kind-0 profile.
  final String content;

  /// Decoded [content] when it is a JSON object.
  final Map<String, dynamic>? metadata;

  /// Platform handler URLs, in tag order.
  final List<NostrAppHandlerUrl> urls;

  /// `latest` nsite manifest references.
  final List<NostrNsiteManifestRef> latest;

  /// `next` nsite manifest references.
  final List<NostrNsiteManifestRef> next;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Parses a kind-31990 event, throwing [ArgumentError] when invalid.
  static NostrAppHandler parse(NostrEvent event) {
    if (event.kind != NostrNip89.handlerKind) {
      throw ArgumentError.value(
        event.kind,
        'event.kind',
        'Not a NIP-89 handler event',
      );
    }

    final tags = event.tags ?? const <List<String>>[];
    final dTag = NostrTags.first(tags, 'd');
    if (dTag == null || dTag.isEmpty) {
      throw ArgumentError('Handler events require a non-empty d tag');
    }

    final kinds = <int>[];
    for (final raw in NostrTags.all(tags, 'k')) {
      final kind = NostrValidators.tryInt(raw, min: 0);
      if (kind == null) {
        throw ArgumentError.value(
          raw,
          'k',
          'Expected a non-negative event kind',
        );
      }
      kinds.add(kind);
    }

    final urls = <NostrAppHandlerUrl>[];
    for (final tag in tags) {
      final url = NostrAppHandlerUrl.tryParse(tag);
      if (url != null) {
        urls.add(url);
      }
    }

    return NostrAppHandler(
      id: event.id,
      pubkey: event.pubkey,
      dTag: dTag,
      kinds: List<int>.unmodifiable(kinds),
      content: event.content ?? '',
      metadata: _decodeMetadata(event.content ?? ''),
      urls: List<NostrAppHandlerUrl>.unmodifiable(urls),
      latest: _parseManifests(tags, 'latest'),
      next: _parseManifests(tags, 'next'),
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrAppHandler? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  static List<NostrNsiteManifestRef> _parseManifests(
    List<List<String>> tags,
    String name,
  ) {
    final result = <NostrNsiteManifestRef>[];

    for (final tag in tags) {
      if (tag.length < 2 || tag.first != name) {
        continue;
      }

      final address = NostrEventAddress.tryParse(tag[1]);
      if (address == null) {
        throw ArgumentError.value(
          tag,
          name,
          'Expected an event address',
        );
      }

      final relay = NostrTags.at(tag, 2);

      result.add(
        NostrNsiteManifestRef(
          address: address,
          relay: relay == null || relay.isEmpty ? null : relay,
        ),
      );
    }

    return List<NostrNsiteManifestRef>.unmodifiable(result);
  }

  static Map<String, dynamic>? _decodeMetadata(String content) {
    if (content.trim().isEmpty) {
      return null;
    }

    return _metadataOrThrow(content);
  }
}

/// Decodes handler metadata, throwing [ArgumentError] when it is not an object.
Map<String, dynamic> _metadataOrThrow(String content) {
  Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    throw ArgumentError.value(
      content,
      'content',
      'Handler metadata must be a JSON object',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw ArgumentError.value(
      content,
      'content',
      'Handler metadata must be a JSON object',
    );
  }

  return decoded;
}

/// {@template nip89}
/// NIP-89 recommended application handlers (kinds 31989/31990).
///
/// [generateRecommendationTemplate] and [generateHandlerTemplate] build
/// unsigned addressable events; [publish] signs through the bound signer.
/// {@endtemplate}
class NostrNip89 {
  /// {@macro nip89}
  NostrNip89({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Recommendation event kind.
  static const int recommendationKind = 31989;

  /// Application handler event kind.
  static const int handlerKind = 31990;

  /// Nsite manifest kind referenced by `latest`/`next`.
  static const int manifestKind = 35128;

  /// NIP-19 entity names accepted as handler URL targets.
  static const Set<String> entityNames = {
    'note',
    'npub',
    'nprofile',
    'nevent',
    'naddr',
    'nrelay',
  };

  /// Tag names with their own NIP-89 meaning, never platform handler tags.
  static const Set<String> reservedTags = {
    'd',
    'k',
    'a',
    'latest',
    'next',
    'alt',
    'p',
    'e',
    't',
    'r',
    'L',
    'l',
    'x',
    'imeta',
    'content-warning',
    'client',
  };

  /// Builds an unsigned kind-31989 recommendation event.
  ///
  /// Throws [ArgumentError] when [supportedKind] is negative, [handlers] is
  /// empty, or a handler does not point at a kind-31990 event.
  static NostrEvent generateRecommendationTemplate({
    required int supportedKind,
    required List<NostrHandlerReference> handlers,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    if (supportedKind < 0) {
      throw ArgumentError.value(
        supportedKind,
        'supportedKind',
        'Kind must not be negative',
      );
    }

    if (handlers.isEmpty) {
      throw ArgumentError.value(
        handlers,
        'handlers',
        'At least one handler is required',
      );
    }

    return NostrEvent(
      id: null,
      kind: recommendationKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', '$supportedKind'],
        for (final handler in handlers) handler.toTag(),
        ...tags,
      ],
    );
  }

  /// Builds an unsigned kind-31990 handler event.
  ///
  /// [content] is optional stringified JSON metadata and must decode to an
  /// object when non-empty. [kinds] must not be empty, and a manifest reference
  /// must be addressable.
  static NostrEvent generateHandlerTemplate({
    required String dTag,
    required List<int> kinds,
    String content = '',
    List<NostrAppHandlerUrl> urls = const [],
    List<NostrNsiteManifestRef> latest = const [],
    List<NostrNsiteManifestRef> next = const [],
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    if (dTag.trim().isEmpty) {
      throw ArgumentError.value(dTag, 'dTag', 'd tag must not be empty');
    }

    if (kinds.isEmpty) {
      throw ArgumentError.value(
        kinds,
        'kinds',
        'At least one supported kind is required',
      );
    }

    for (final kind in kinds) {
      if (kind < 0) {
        throw ArgumentError.value(
          kind,
          'kinds',
          'Kind must not be negative',
        );
      }
    }

    if (content.trim().isNotEmpty) {
      _metadataOrThrow(content);
    }

    final seen = <int>{};
    final uniqueKinds = [
      for (final kind in kinds)
        if (seen.add(kind)) kind,
    ];

    return NostrEvent(
      id: null,
      kind: handlerKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', dTag],
        for (final kind in uniqueKinds) ['k', '$kind'],
        for (final manifest in latest) manifest.toTag('latest'),
        for (final manifest in next) manifest.toTag('next'),
        for (final url in urls) url.toTag(),
        ...tags,
      ],
    );
  }

  /// Signs [event] with the bound signer.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Builds the NIP-89 `client` tag for a published event.
  ///
  /// [name] identifies the client and [address] must point at a kind-31990
  /// handler event. [relay] is an optional hint for finding that event.
  static List<String> clientTag({
    required String name,
    required NostrEventAddress address,
    String? relay,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Client name is empty');
    }

    if (address.kind != handlerKind) {
      throw ArgumentError.value(
        address.kind,
        'address',
        'Client handler must be a kind 31990 event',
      );
    }

    return ['client', name, address.address, if (relay != null) relay];
  }

  /// `#d` filter for recommendations about [kind].
  static NostrFilter buildRecommendationFilter({
    required int kind,
    List<String>? authors,
    int? limit,
  }) {
    return NostrFilter(
      kinds: const [recommendationKind],
      authors: authors,
      limit: limit,
      additionalFilters: {
        '#d': ['$kind'],
      },
    );
  }

  /// `#k` filter for handlers supporting [kind].
  static NostrFilter buildHandlerFilter({
    required int kind,
    List<String>? authors,
    int? limit,
  }) {
    return NostrFilter(
      kinds: const [handlerKind],
      authors: authors,
      limit: limit,
      additionalFilters: {
        '#k': ['$kind'],
      },
    );
  }
}
