import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';

/// {@template nostr_snippet_license}
/// NIP-C0 `license` tag value.
///
/// [id] must be an SPDX short identifier (C0.md:26); [text] optionally
/// references the full license text. This library validates the shape only;
/// it does not ship or verify the SPDX list.
/// {@endtemplate}
class NostrSnippetLicense {
  /// {@macro nostr_snippet_license}
  const NostrSnippetLicense(this.id, {this.text = ''});

  /// SPDX short identifier, for example `MIT` or `GPL-3.0-or-later`.
  final String id;

  /// Optional reference to the full license text.
  final String text;

  /// This license as `['license', id]` or `['license', id, text]`.
  List<String> get tag => ['license', id, if (text.isNotEmpty) text];
}

/// {@template nostr_snippet_repo}
/// NIP-C0 `repo` tag value: an https URL or a NIP-34 repository address.
///
/// The address form is `30617:<pubkey>:<d>` with an optional relay hint
/// (C0.md:28).
/// {@endtemplate}
class NostrCodeSnippetRepo {
  /// {@macro nostr_snippet_repo}
  const NostrCodeSnippetRepo.url(String this.url)
      : address = null,
        relay = '';

  /// {@macro nostr_snippet_repo}
  const NostrCodeSnippetRepo.event(
    NostrEventAddress this.address, {
    this.relay = '',
  }) : url = null;

  /// https URL, set for the URL form.
  final String? url;

  /// NIP-34 kind-30617 address, set for the address form.
  final NostrEventAddress? address;

  /// Optional relay hint for the address form.
  final String relay;

  /// Kind of the NIP-34 repository announcement referenced by the address.
  static const int repositoryKind = 30617;

  /// SPDX short identifiers are case-sensitive, so the first character must be
  /// an uppercase letter or a digit (`MIT`, `Apache-2.0`, `0BSD`) and `mit` is
  /// not a license id.
  static final RegExp _spdxId = RegExp(r'^[0-9A-Z][A-Za-z0-9.+-]*$');

  /// This repository as `['repo', value]` or `['repo', value, relay]`.
  List<String> get tag => [
        'repo',
        url ?? address!.address,
        if (address != null && relay.isNotEmpty) relay,
      ];

  /// Whether [value] has the shape of a canonical SPDX short identifier.
  static bool isValidLicenseId(String value) => _spdxId.hasMatch(value);

  /// Parses a `repo` tag, or returns `null` when it is not a valid reference.
  ///
  /// URL references must be `https`; address references must be kind 30617
  /// with a 64-character hex pubkey and a non-empty `d` value. An optional
  /// third slot must be a relay URL.
  static NostrCodeSnippetRepo? tryParse(List<String>? tag) {
    if (tag == null || tag.length < 2 || tag.first != 'repo') {
      return null;
    }

    final value = tag[1].trim();
    if (value.isEmpty) {
      return null;
    }

    final relay = tag.length > 2 ? tag[2].trim() : '';
    if (relay.isNotEmpty && !NostrValidators.isRelayUrl(relay)) {
      return null;
    }

    final normalized = NostrValidators.normalizeUrl(value);
    if (normalized != null) {
      if (!normalized.startsWith('https://')) {
        return null;
      }

      return NostrCodeSnippetRepo.url(normalized);
    }

    final address = NostrEventAddress.tryParse(value);
    if (address == null || address.kind != repositoryKind) {
      return null;
    }

    return NostrCodeSnippetRepo.event(address, relay: relay);
  }
}

/// {@template nostr_code_snippet}
/// Parsed NIP-C0 code snippet (kind 1337).
///
/// Every metadata field is optional (C0.md:19-28); missing tags stay `null`
/// and repeated `dep`/`license` tags are kept in event order.
/// {@endtemplate}
class NostrCodeSnippet {
  /// {@macro nostr_code_snippet}
  const NostrCodeSnippet({
    required this.content,
    this.language,
    this.name,
    this.extension,
    this.description,
    this.runtime,
    this.licenses = const <NostrSnippetLicense>[],
    this.dependencies = const <String>[],
    this.repo,
    this.tags = const <List<String>>[],
    this.pubkey = '',
  });

  /// Snippet text, as stored in `content`.
  final String content;

  /// `l` tag value: lowercase programming language.
  final String? language;

  /// `name` tag value: usually the filename.
  final String? name;

  /// `extension` tag value, without the leading dot.
  final String? extension;

  /// `description` tag value.
  final String? description;

  /// `runtime` tag value.
  final String? runtime;

  /// Every `license` tag, in event order.
  final List<NostrSnippetLicense> licenses;

  /// Every `dep` tag value, in event order.
  final List<String> dependencies;

  /// `repo` tag value, when present.
  final NostrCodeSnippetRepo? repo;

  /// Tags not decoded into a typed field, preserved verbatim.
  final List<List<String>> tags;

  /// Author public key, when parsed from a signed event.
  final String pubkey;

  /// Whether this snippet carries an extension tag.
  bool get hasExtension => extension != null;
}

/// {@template nipc0}
/// NIP-C0 code snippets (kind 1337).
///
/// The code lives in `content` and every tag is optional (C0.md:17-28):
/// `l` (lowercase language), `name`, `extension` (no leading dot),
/// `description`, `runtime`, repeatable `license` (SPDX short identifier),
/// repeatable `dep` and `repo` (https URL or `30617:<pubkey>:<d>` address with
/// an optional relay).
///
/// Templates carry no `pubkey`/`id`/`sig`; sign them before publishing.
///
/// Usage:
/// ```dart
/// final event = await signer.sign(
///   NostrNipC0.generateSnippetTemplate(
///     content: 'void main() {}',
///     language: 'dart',
///     extension: 'dart',
///   ),
/// );
/// ```
/// {@endtemplate}
class NostrNipC0 {
  /// {@macro nipc0}
  const NostrNipC0();

  /// Kind 1337: code snippet.
  static const int snippetKind = 1337;

  static final RegExp _extension = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]*$');

  /// Tag names this class decodes into typed fields.
  static const Set<String> _managedTags = {
    'l',
    'name',
    'extension',
    'description',
    'runtime',
    'license',
    'dep',
    'repo',
  };

  /// Builds an unsigned kind-1337 snippet.
  ///
  /// [language] must be lowercase and [extension] must not start with a dot.
  /// [licenses] and [dependencies] become repeatable `license`/`dep` tags.
  /// [extraTags] are appended after the typed tags, except for names this
  /// builder already manages.
  ///
  /// Throws [ArgumentError] when [content] is blank, when [language] is not
  /// lowercase, when [extension] has a leading dot, when a license id is not
  /// SPDX-shaped, or when a dependency is blank.
  static NostrEvent generateSnippetTemplate({
    required String content,
    String? language,
    String? name,
    String? extension,
    String? description,
    String? runtime,
    List<NostrSnippetLicense> licenses = const <NostrSnippetLicense>[],
    List<String> dependencies = const <String>[],
    NostrCodeSnippetRepo? repo,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (content.trim().isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Snippet content must not be empty',
      );
    }

    if (language != null) {
      _checkLanguage(language);
    }

    if (extension != null) {
      _checkExtension(extension);
    }

    for (final license in licenses) {
      if (!NostrCodeSnippetRepo.isValidLicenseId(license.id)) {
        throw ArgumentError.value(
          license.id,
          'licenses',
          'Expected an SPDX short identifier',
        );
      }
    }

    for (final dependency in dependencies) {
      if (dependency.trim().isEmpty) {
        throw ArgumentError.value(
          dependency,
          'dependencies',
          'Dependency must not be empty',
        );
      }
    }

    if (repo != null && NostrCodeSnippetRepo.tryParse(repo.tag) == null) {
      throw ArgumentError.value(
        repo.tag,
        'repo',
        'Repository must be an https URL or a 30617 address',
      );
    }

    return NostrEvent(
      id: null,
      kind: snippetKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (language != null) ['l', language],
        if (extension != null) ['extension', extension],
        if (name != null) ['name', name],
        if (description != null) ['description', description],
        if (runtime != null) ['runtime', runtime],
        for (final license in licenses) license.tag,
        for (final dependency in dependencies) ['dep', dependency],
        if (repo != null) repo.tag,
        for (final tag in extraTags)
          if (tag.isEmpty || !_managedTags.contains(tag.first)) tag,
      ],
    );
  }

  /// Validates a kind-1337 snippet.
  ///
  /// Checks the kind, non-blank content, a lowercase `l` tag, an `extension`
  /// tag without a leading dot, SPDX-shaped `license` ids and well-formed
  /// `repo` references.
  static bool validateSnippet(NostrEvent event) => tryParse(event) != null;

  /// Parses [event] into [NostrCodeSnippet], or returns `null` when it is not
  /// a valid kind-1337 snippet.
  ///
  /// Missing optional tags stay `null`. Tags that violate the spec (uppercase
  /// `l`, an extension with a leading dot, a non-SPDX license id or a
  /// malformed `repo`) make the event invalid. Unknown tags are kept in
  /// [NostrCodeSnippet.tags].
  static NostrCodeSnippet? tryParse(NostrEvent event) {
    if (event.kind != snippetKind) {
      return null;
    }

    final content = event.content ?? '';
    if (content.trim().isEmpty) {
      return null;
    }

    final language = NostrTags.first(event.tags, 'l');
    final extension = NostrTags.first(event.tags, 'extension');

    // Every occurrence must be valid, not just the first: a later uppercase
    // `l` or dotted `extension` tag would slip past a first-tag-only check.
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length < 2) {
        continue;
      }
      if (tag.first == 'l' && !_isValidLanguage(tag[1])) {
        return null;
      }
      if (tag.first == 'extension' && !_isValidExtension(tag[1])) {
        return null;
      }
    }

    final licenses = <NostrSnippetLicense>[];
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length > 1 && tag.first == 'license') {
        if (!NostrCodeSnippetRepo.isValidLicenseId(tag[1])) {
          return null;
        }

        licenses.add(
          NostrSnippetLicense(
            tag[1],
            text: tag.length > 2 ? tag[2] : '',
          ),
        );
      }
    }

    NostrCodeSnippetRepo? repo;
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isNotEmpty && tag.first == 'repo') {
        repo = NostrCodeSnippetRepo.tryParse(tag);
        if (repo == null) {
          return null;
        }
        break;
      }
    }

    return NostrCodeSnippet(
      content: content,
      language: language,
      name: NostrTags.first(event.tags, 'name'),
      extension: extension,
      description: NostrTags.first(event.tags, 'description'),
      runtime: NostrTags.first(event.tags, 'runtime'),
      licenses: licenses,
      dependencies: NostrTags.all(event.tags, 'dep'),
      repo: repo,
      pubkey: event.pubkey,
      tags: [
        for (final tag in event.tags ?? const <List<String>>[])
          if (tag.isEmpty || !_managedTags.contains(tag.first))
            List<String>.of(tag),
      ],
    );
  }

  /// Like [tryParse], but throws [ArgumentError] for invalid events.
  static NostrCodeSnippet parse(NostrEvent event) {
    final snippet = tryParse(event);

    if (snippet == null) {
      throw ArgumentError('Invalid NIP-C0 code snippet event');
    }

    return snippet;
  }

  static bool _isValidLanguage(String language) {
    final trimmed = language.trim();

    return trimmed.isNotEmpty &&
        trimmed == trimmed.toLowerCase() &&
        !trimmed.contains(RegExp(r'\s'));
  }

  static bool _isValidExtension(String extension) {
    final trimmed = extension.trim();

    return trimmed.isNotEmpty && _extension.hasMatch(trimmed);
  }

  static void _checkLanguage(String language) {
    if (!_isValidLanguage(language)) {
      throw ArgumentError.value(
        language,
        'language',
        'Language must be a non-empty lowercase name',
      );
    }
  }

  static void _checkExtension(String extension) {
    if (!_isValidExtension(extension)) {
      throw ArgumentError.value(
        extension,
        'extension',
        'Extension must not start with a dot',
      );
    }
  }
}
