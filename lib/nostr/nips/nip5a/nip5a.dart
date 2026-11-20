import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_site_kind}
/// NIP-5A static website kinds.
/// {@endtemplate}
class NostrSiteKind {
  const NostrSiteKind._();

  /// Root site manifest (replaceable, no `d` tag).
  static const int root = 15128;

  /// Named site manifest (addressable, `d` tag required).
  static const int named = 35128;

  /// Manifest snapshot (regular event).
  static const int snapshot = 5128;

  /// Every kind defined by NIP-5A.
  static const List<int> values = [root, named, snapshot];

  /// Whether [kind] is a root or named site manifest.
  static bool isManifest(int? kind) => kind == root || kind == named;
}

/// {@template nostr_site_app}
/// NIP-5A `app` tag: `["app", "<kind>:<pubkey>:<d>", "<relay>"]`.
///
/// The referenced app descriptor must be addressable (`5A.md:151-159`). The
/// tag always has exactly three slots (`5A.md:106`); a missing relay is
/// written as an empty string.
/// {@endtemplate}
class NostrSiteApp {
  /// {@macro nostr_site_app}
  const NostrSiteApp({required this.address, this.relay, this.tag = const []});

  /// Addressable `kind:pubkey:d` app descriptor address.
  final String address;

  /// Optional relay hint.
  final String? relay;

  /// Raw `app` tag.
  final List<String> tag;

  /// Parsed address of [address].
  NostrEventAddress? get parsedAddress => NostrEventAddress.tryParse(address);

  /// Builds the `app` tag with all three slots (`5A.md:106`).
  List<String> toTag() => ['app', address, relay ?? ''];

  /// Parses an `app` tag, returning `null` when it is invalid.
  static NostrSiteApp? tryParseTag(List<String>? tag) {
    if (tag == null || tag.length != 3 || tag.first != 'app') {
      return null;
    }

    final address = NostrEventAddress.tryParse(tag[1]);
    if (address == null || !address.isAddressable) {
      return null;
    }

    final relay = NostrTags.at(tag, 2);

    return NostrSiteApp(
      address: address.address,
      relay: relay == null || relay.isEmpty ? null : relay,
      tag: tag,
    );
  }
}

/// {@template nostr_site_manifest}
/// Parsed NIP-5A site manifest (kinds 15128, 35128 and 5128).
///
/// [paths] maps absolute request paths to lowercase SHA-256 blob hashes.
/// [aggregateHash] is the optional `x` tag of a manifest and the required `x`
/// tag of a snapshot. [parentAddress] is the lowercase `a` tag: the immediate
/// copy parent, or the snapshotted site for kind 5128; both reference either a
/// 15128 root site or a 35128 named site (`5A.md:65,120`). [originAddress] is
/// the uppercase `A` tag preserving the copy lineage.
/// {@endtemplate}
class NostrSiteManifest {
  /// {@macro nostr_site_manifest}
  const NostrSiteManifest({
    this.id,
    required this.pubkey,
    required this.kind,
    this.dTag,
    this.paths = const {},
    this.aggregateHash,
    this.servers = const [],
    this.title,
    this.description,
    this.source,
    this.apps = const [],
    this.parentAddress,
    this.originAddress,
    this.content = '',
    this.tags = const [],
  });

  /// Canonical named-site identifier pattern (`5A.md:35`).
  static final RegExp namedIdentifier = RegExp(r'^[a-z0-9-]{1,13}$');

  /// Event id, or `null` for an unsigned template.
  final String? id;

  /// Author public key.
  final String pubkey;

  /// [NostrSiteKind.root], [NostrSiteKind.named] or [NostrSiteKind.snapshot].
  final int kind;

  /// `d` identifier for named sites; `null` when the event has none.
  final String? dTag;

  /// Absolute path to SHA-256 hash mapping.
  final Map<String, String> paths;

  /// Declared `x` aggregate hash, or `null` when absent.
  final String? aggregateHash;

  /// `server` hints.
  final List<String> servers;

  /// Optional `title`.
  final String? title;

  /// Optional `description`.
  final String? description;

  /// Optional `source` repository or archive URL.
  final String? source;

  /// `app` descriptor references.
  final List<NostrSiteApp> apps;

  /// Lowercase `a` tag address.
  final String? parentAddress;

  /// Uppercase `A` tag address.
  final String? originAddress;

  /// Event content, usually empty.
  final String content;

  /// Raw tag list.
  final List<List<String>> tags;

  /// Whether this is a root site manifest.
  bool get isRoot => kind == NostrSiteKind.root;

  /// Whether this is a named site manifest.
  bool get isNamed => kind == NostrSiteKind.named;

  /// Whether this is a manifest snapshot.
  bool get isSnapshot => kind == NostrSiteKind.snapshot;

  /// Whether the manifest records a copy lineage.
  bool get isCopy => parentAddress != null;

  /// Computes the NIP-5A aggregate hash from `path` tags (`5A.md:126-142`).
  ///
  /// Lines are `<sha256hash> <absolute-path>\n`, sorted lexicographically as
  /// whole lines, concatenated as UTF-8 and hashed with SHA-256.
  static String computeAggregateHash(List<List<String>> tags) {
    final lines = <String>[];
    for (final tag in tags) {
      if (tag.length == 3 && tag.first == 'path') {
        lines.add('${tag[2]} ${tag[1]}\n');
      }
    }

    lines.sort();

    return sha256.convert(utf8.encode(lines.join())).toString();
  }

  /// Whether exactly one aggregate `x` tag is present and matches the paths.
  static bool verifyAggregateHash(List<List<String>> tags) {
    final declared = _declaredAggregateHash(tags);

    return declared != null && declared == computeAggregateHash(tags);
  }

  /// Normalizes [requestPath] to an absolute path.
  ///
  /// Paths without a filename fall back to `index.html`: `/` becomes
  /// `/index.html` and `/blog/` becomes `/blog/index.html` (`5A.md:232-236`).
  static String resolvePath(String requestPath) {
    final path = requestPath.startsWith('/') ? requestPath : '/$requestPath';

    return path.endsWith('/') ? '${path}index.html' : path;
  }

  /// Hash serving [requestPath], or `null` when no `path` tag matches.
  String? hashForPath(String requestPath) => paths[resolvePath(requestPath)];

  /// Parses [event], throwing [ArgumentError] when it is invalid.
  static NostrSiteManifest parse(NostrEvent event) {
    final kind = event.kind;
    if (!NostrSiteKind.values.contains(kind)) {
      throw ArgumentError.value(kind, 'event.kind', 'Not a NIP-5A site event');
    }

    final tags = event.tags ?? const <List<String>>[];
    final declaredD = NostrTags.first(tags, 'd');

    if (kind == NostrSiteKind.root) {
      if (NostrTags.has(tags, 'd')) {
        throw ArgumentError('Root site manifests must not carry a d tag');
      }
    } else if (kind == NostrSiteKind.named) {
      if (declaredD == null ||
          !namedIdentifier.hasMatch(declaredD) ||
          declaredD.endsWith('-')) {
        throw ArgumentError.value(
          declaredD,
          'd',
          'Named sites require a d tag matching ^[a-z0-9-]{1,13}\$ '
              'without a trailing hyphen',
        );
      }
    }

    final paths = <String, String>{};
    var pathTagCount = 0;
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'path') {
        continue;
      }

      pathTagCount++;
      if (tag.length != 3) {
        throw ArgumentError.value(
          tag,
          'path',
          'Expected ["path", "/absolute/path", "<sha256>"]',
        );
      }

      final path = tag[1];
      final hash = tag[2];
      if (!path.startsWith('/') || path.endsWith('/') || path.isEmpty) {
        throw ArgumentError.value(
          path,
          'path',
          'Expected an absolute file path',
        );
      }

      if (!NostrValidators.isHex64(hash)) {
        throw ArgumentError.value(
          hash,
          'path',
          'Expected a 64-character lowercase hex SHA-256',
        );
      }

      final existing = paths[path];
      if (existing != null && existing != hash) {
        throw ArgumentError.value(
          path,
          'path',
          'Conflicting hashes for one path',
        );
      }

      paths[path] = hash;
    }

    if (pathTagCount == 0) {
      throw ArgumentError('Site manifests require at least one path tag');
    }

    final computedHash = computeAggregateHash(tags);
    final declaredX = NostrTags.all(tags, 'x');
    final aggregateTags = _aggregateTags(tags);

    if (kind == NostrSiteKind.snapshot) {
      if (!NostrTags.hasExactly(tags, 'x', 1) ||
          aggregateTags.length != 1 ||
          aggregateTags.first[1] != computedHash) {
        throw ArgumentError.value(
          declaredX,
          'x',
          'Snapshots require exactly one aggregate x tag matching the paths',
        );
      }

      if (!NostrTags.hasExactly(tags, 'a', 1)) {
        throw ArgumentError('Snapshots require exactly one a tag');
      }

      if (NostrTags.all(tags, 'A').length > 1) {
        throw ArgumentError('Snapshots allow at most one A tag');
      }
    } else if (NostrTags.has(tags, 'x') &&
        (!NostrTags.hasExactly(tags, 'x', 1) ||
            aggregateTags.length != 1 ||
            aggregateTags.first[1] != computedHash)) {
      throw ArgumentError.value(
        declaredX,
        'x',
        'A declared x tag must be the matching aggregate hash',
      );
    }

    final parentAddress = _optionalAddress(tags, 'a');
    final originAddress = _optionalAddress(tags, 'A');

    if (kind == NostrSiteKind.snapshot) {
      if (parentAddress == null) {
        throw ArgumentError('Snapshots require a valid a tag');
      }
    } else if (NostrTags.all(tags, 'a').length > 1 ||
        NostrTags.all(tags, 'A').length > 1) {
      throw ArgumentError('Copied sites allow one a and one A tag');
    }

    final source = NostrTags.first(tags, 'source');
    if (source != null && !_isValidSource(source)) {
      throw ArgumentError.value(
        source,
        'source',
        'Expected an https:// or nostr:// git URL',
      );
    }

    final apps = <NostrSiteApp>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'app') {
        continue;
      }

      final app = NostrSiteApp.tryParseTag(tag);
      if (app == null) {
        throw ArgumentError.value(
          tag,
          'app',
          'Expected ["app", "<kind:pubkey:d>", "<relay>"]',
        );
      }

      apps.add(app);
    }

    return NostrSiteManifest(
      id: event.id,
      pubkey: event.pubkey,
      kind: kind!,
      dTag: declaredD,
      paths: Map<String, String>.unmodifiable(paths),
      aggregateHash: aggregateTags.length == 1 ? aggregateTags.first[1] : null,
      servers: NostrTags.all(tags, 'server'),
      title: NostrTags.first(tags, 'title'),
      description: NostrTags.first(tags, 'description'),
      source: source,
      apps: apps,
      parentAddress: parentAddress,
      originAddress: originAddress,
      content: event.content ?? '',
      tags: tags,
    );
  }

  /// Like [parse], returning `null` for invalid events.
  static NostrSiteManifest? tryParse(NostrEvent event) {
    try {
      return parse(event);
    } on ArgumentError {
      return null;
    }
  }

  /// Whether [event] is a valid site event.
  static bool validate(NostrEvent event) => tryParse(event) != null;

  /// Builds an unsigned NIP-5A site event and validates it.
  ///
  /// [aggregateHash] defaults to the hash computed from [paths]; a supplied
  /// value must match it. Snapshots always include the aggregate `x` tag.
  ///
  /// [parentAddress] and [originAddress] reference a 15128 root site or a
  /// 35128 named site, so copies of root sites are supported.
  static NostrEvent build({
    required int kind,
    required Map<String, String> paths,
    String? dTag,
    String? parentAddress,
    String? originAddress,
    List<String> servers = const [],
    String? title,
    String? description,
    String? source,
    List<NostrSiteApp> apps = const [],
    String? aggregateHash,
    bool includeAggregateHash = true,
    String content = '',
    DateTime? createdAt,
  }) {
    final pathTags = [
      for (final entry in paths.entries) ['path', entry.key, entry.value],
    ];
    final computedHash = computeAggregateHash(pathTags);
    if (aggregateHash != null && aggregateHash != computedHash) {
      throw ArgumentError.value(
        aggregateHash,
        'aggregateHash',
        'Declared aggregate hash does not match the path tags',
      );
    }

    final event = NostrEvent(
      id: null,
      kind: kind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (dTag != null) ['d', dTag],
        if (parentAddress != null) ['a', parentAddress],
        if (originAddress != null) ['A', originAddress],
        ...pathTags,
        if (includeAggregateHash)
          ['x', aggregateHash ?? computedHash, 'aggregate'],
        for (final app in apps) app.toTag(),
        for (final server in servers) ['server', server],
        if (title != null) ['title', title],
        if (description != null) ['description', description],
        if (source != null) ['source', source],
      ],
    );

    parse(event);

    return event;
  }

  static List<List<String>> _aggregateTags(List<List<String>> tags) => [
        for (final tag in tags)
          if (tag.length >= 3 && tag.first == 'x' && tag[2] == 'aggregate') tag,
      ];

  static String? _declaredAggregateHash(List<List<String>> tags) {
    final aggregate = _aggregateTags(tags);

    return aggregate.length == 1 ? aggregate.first[1] : null;
  }

  static String? _optionalAddress(List<List<String>> tags, String name) {
    final value = NostrTags.first(tags, name);
    if (value == null) {
      return null;
    }

    final address = NostrEventAddress.tryParse(value);
    if (address == null ||
        (address.kind != NostrSiteKind.root &&
            address.kind != NostrSiteKind.named)) {
      throw ArgumentError.value(
        value,
        name,
        'Expected a 15128 or 35128 site address',
      );
    }

    return address.address;
  }

  static bool _isValidSource(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    if (uri.scheme == 'nostr') {
      return value.startsWith('nostr://') && uri.path.isNotEmpty;
    }

    return uri.scheme == 'https' && uri.hasAuthority;
  }
}

/// {@template nip5a}
/// NIP-5A static websites hosted from Blossom assets.
///
/// The API is stateless and const: pass a signer to [publish] per call.
/// {@endtemplate}
class NostrNip5a {
  /// {@macro nip5a}
  const NostrNip5a();

  /// Root site manifest kind.
  static const int rootKind = NostrSiteKind.root;

  /// Named site manifest kind.
  static const int namedKind = NostrSiteKind.named;

  /// Manifest snapshot kind.
  static const int snapshotKind = NostrSiteKind.snapshot;

  /// Computes the NIP-5A aggregate hash from `path` tags.
  String computeAggregateHash(List<List<String>> tags) =>
      NostrSiteManifest.computeAggregateHash(tags);

  /// Whether exactly one aggregate `x` tag is present and matches the paths.
  bool verifyAggregateHash(List<List<String>> tags) =>
      NostrSiteManifest.verifyAggregateHash(tags);

  /// Normalizes a request path, falling back to `index.html`.
  String resolvePath(String requestPath) =>
      NostrSiteManifest.resolvePath(requestPath);

  /// Builds an unsigned root site manifest (kind 15128).
  NostrEvent generateRootManifest({
    required Map<String, String> paths,
    List<String> servers = const [],
    String? title,
    String? description,
    String? source,
    List<NostrSiteApp> apps = const [],
    String? aggregateHash,
    bool includeAggregateHash = true,
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrSiteManifest.build(
      kind: NostrSiteKind.root,
      paths: paths,
      servers: servers,
      title: title,
      description: description,
      source: source,
      apps: apps,
      aggregateHash: aggregateHash,
      includeAggregateHash: includeAggregateHash,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned named site manifest (kind 35128).
  NostrEvent generateNamedManifest({
    required String dTag,
    required Map<String, String> paths,
    List<String> servers = const [],
    String? title,
    String? description,
    String? source,
    List<NostrSiteApp> apps = const [],
    String? aggregateHash,
    bool includeAggregateHash = true,
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrSiteManifest.build(
      kind: NostrSiteKind.named,
      dTag: dTag,
      paths: paths,
      servers: servers,
      title: title,
      description: description,
      source: source,
      apps: apps,
      aggregateHash: aggregateHash,
      includeAggregateHash: includeAggregateHash,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Builds an unsigned manifest snapshot (kind 5128).
  NostrEvent generateSnapshot({
    required String parentAddress,
    required Map<String, String> paths,
    String? originAddress,
    List<String> servers = const [],
    String? title,
    String? description,
    String? source,
    List<NostrSiteApp> apps = const [],
    String content = '',
    DateTime? createdAt,
  }) {
    return NostrSiteManifest.build(
      kind: NostrSiteKind.snapshot,
      paths: paths,
      parentAddress: parentAddress,
      originAddress: originAddress,
      servers: servers,
      title: title,
      description: description,
      source: source,
      apps: apps,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Signs [event] with [signer].
  Future<NostrEvent> publish(
    NostrEvent event,
    NostrEventSigner signer,
  ) =>
      signer.sign(event);

  /// Parses a site manifest, throwing [ArgumentError] when invalid.
  NostrSiteManifest parseManifest(NostrEvent event) =>
      NostrSiteManifest.parse(event);

  /// Parses a site manifest, returning `null` when invalid.
  NostrSiteManifest? tryParseManifest(NostrEvent event) =>
      NostrSiteManifest.tryParse(event);
}
