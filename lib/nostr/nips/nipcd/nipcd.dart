import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// Argument types defined by NIP-CD (CD.md:83-95).
enum NostrSlashArgumentType {
  /// 64-char hex, `nostr:npub1…` or `nostr:nprofile1…`.
  pubkey('pubkey'),

  /// 64-char hex, `nostr:note1…` or `nostr:nevent1…`.
  event('event'),

  /// `nostr:naddr1…`.
  address('address'),

  /// Websocket URL.
  relay('relay'),

  /// Decimal digits.
  number('number'),

  /// `true|false|yes|no|1|0|t|f|y|n`.
  boolean('bool'),

  /// One of the choices declared on the `arg` tag.
  enumeration('enum'),

  /// Any run of non-whitespace characters.
  word('word'),

  /// The remainder of the content, including whitespace.
  text('text');

  const NostrSlashArgumentType(this.wireName);

  /// Name used in an `arg` tag.
  final String wireName;

  /// Parses a wire name, returning `null` for unknown types.
  static NostrSlashArgumentType? tryParse(String value) {
    for (final type in values) {
      if (type.wireName == value) {
        return type;
      }
    }

    return null;
  }
}

/// {@template nostr_slash_argument}
/// One ordered `arg` tag of a NIP-CD command definition.
///
/// The tag is `['arg', name, type, 'required'|'optional', label, ...choices]`
/// and choices only apply to [NostrSlashArgumentType.enumeration]
/// (CD.md:17-19).
/// {@endtemplate}
class NostrSlashArgument {
  /// {@macro nostr_slash_argument}
  const NostrSlashArgument({
    required this.name,
    required this.type,
    required this.required,
    required this.label,
    this.choices = const <String>[],
  });

  /// Argument name, used in documentation and autocomplete.
  final String name;

  /// Argument type.
  final NostrSlashArgumentType type;

  /// Whether the argument must be supplied.
  final bool required;

  /// Human-readable label.
  final String label;

  /// Allowed values for [NostrSlashArgumentType.enumeration].
  final List<String> choices;

  /// Serializes to an `arg` tag.
  List<String> toTag() => [
        'arg',
        name,
        type.wireName,
        if (required) 'required' else 'optional',
        label,
        ...choices,
      ];

  /// Parses an `arg` tag, returning `null` when it is malformed.
  static NostrSlashArgument? tryParse(List<String> tag) {
    if (tag.length < 5 || tag.first != 'arg') {
      return null;
    }

    final type = NostrSlashArgumentType.tryParse(tag[2]);
    final requirement = tag[3];

    if (type == null ||
        (requirement != 'required' && requirement != 'optional') ||
        tag[1].isEmpty ||
        tag[4].isEmpty) {
      return null;
    }

    final choices = tag.sublist(5);

    if (type == NostrSlashArgumentType.enumeration && choices.isEmpty) {
      return null;
    }

    if (type != NostrSlashArgumentType.enumeration && choices.isNotEmpty) {
      return null;
    }

    return NostrSlashArgument(
      name: tag[1],
      type: type,
      required: requirement == 'required',
      label: tag[4],
      choices: choices,
    );
  }
}

/// Scope types defined by NIP-CD (CD.md:24-30).
enum NostrSlashScopeType {
  /// `kind:<kind>`: the invocation event kind must match.
  kind('kind'),

  /// `relay:<url>`: the executor only listens on that relay.
  relay('relay'),

  /// `author:<pubkey>`: the invocation author must match.
  author('author'),

  /// `tag:<tag>` or `tag:<tag>:<value>`.
  tag('tag');

  const NostrSlashScopeType(this.wireName);

  /// Prefix used in an `s` tag value.
  final String wireName;

  /// Parses a prefix, returning `null` for unknown scope types.
  static NostrSlashScopeType? tryParse(String value) {
    for (final type in values) {
      if (type.wireName == value) {
        return type;
      }
    }

    return null;
  }
}

/// {@template nostr_slash_scope}
/// One `s` scope of a NIP-CD command definition.
///
/// A scope is `kind:<kind>`, `relay:<url>`, `author:<pubkey>`, `tag:<tag>` or
/// `tag:<tag>:<value>`. Scopes combine like a filter: same-type scopes are
/// alternatives, different types must all match, and an absent type is
/// unrestricted (CD.md:26-28).
/// {@endtemplate}
class NostrSlashScope {
  /// {@macro nostr_slash_scope}
  const NostrSlashScope({
    required this.type,
    required this.value,
    this.tagValue,
  });

  /// Scope type.
  final NostrSlashScopeType type;

  /// Kind number, relay URL, author pubkey or tag name.
  final String value;

  /// Required tag value for `tag:<tag>:<value>`, otherwise `null`.
  final String? tagValue;

  /// Serializes to an `s` tag.
  List<String> toTag() => [
        's',
        switch (type) {
          NostrSlashScopeType.tag when tagValue != null =>
            'tag:$value:$tagValue',
          _ => '${type.wireName}:$value',
        },
      ];

  /// Parses an `s` tag, returning `null` when malformed.
  static NostrSlashScope? tryParseTag(List<String> tag) {
    if (tag.length < 2 || tag.first != 's') {
      return null;
    }

    return tryParse(tag[1]);
  }

  /// Parses a scope value such as `kind:9`, returning `null` when malformed.
  static NostrSlashScope? tryParse(String raw) {
    final separator = raw.indexOf(':');

    if (separator <= 0) {
      return null;
    }

    final type = NostrSlashScopeType.tryParse(raw.substring(0, separator));
    final rest = raw.substring(separator + 1);

    if (type == null || rest.isEmpty) {
      return null;
    }

    switch (type) {
      case NostrSlashScopeType.kind:
        if (int.tryParse(rest) == null) {
          return null;
        }
        return NostrSlashScope(type: type, value: rest);
      case NostrSlashScopeType.relay:
        if (!NostrValidators.isRelayUrl(rest)) {
          return null;
        }
        return NostrSlashScope(type: type, value: rest);
      case NostrSlashScopeType.author:
        if (!NostrValidators.isHex64(rest)) {
          return null;
        }
        return NostrSlashScope(type: type, value: rest);
      case NostrSlashScopeType.tag:
        final split = rest.indexOf(':');

        if (split < 0) {
          return NostrSlashScope(type: type, value: rest);
        }

        final name = rest.substring(0, split);
        final tagValue = rest.substring(split + 1);

        if (name.isEmpty || tagValue.isEmpty) {
          return null;
        }

        return NostrSlashScope(
          type: type,
          value: name,
          tagValue: tagValue,
        );
    }
  }

  /// Whether this scope accepts an invocation event.
  bool matches({
    int? kind,
    String? relayUrl,
    String? authorPubkey,
    List<List<String>>? tags,
  }) {
    switch (type) {
      case NostrSlashScopeType.kind:
        return kind != null && value == '$kind';
      case NostrSlashScopeType.relay:
        return relayUrl == value;
      case NostrSlashScopeType.author:
        return authorPubkey == value;
      case NostrSlashScopeType.tag:
        final wanted = tagValue;
        for (final tag in tags ?? const <List<String>>[]) {
          if (tag.length > 1 && tag.first == value) {
            if (wanted == null || tag[1] == wanted) {
              return true;
            }
          }
        }
        return false;
    }
  }
}

/// {@template nostr_slash_command_definition}
/// Parsed NIP-CD slash command definition (kind 31992).
///
/// [identifier] is the `d` tag used in the event address, [command] the
/// trigger without a leading slash. [arguments] stay ordered.
/// {@endtemplate}
class NostrSlashCommandDefinition {
  /// {@macro nostr_slash_command_definition}
  const NostrSlashCommandDefinition({
    required this.identifier,
    required this.command,
    required this.title,
    required this.description,
    this.arguments = const <NostrSlashArgument>[],
    this.scopes = const <NostrSlashScope>[],
    this.pubkey = '',
    this.tags = const <List<String>>[],
  });

  /// `d` tag: replaceable identifier.
  final String identifier;

  /// Trigger without a leading slash.
  final String command;

  /// Short human-readable name.
  final String title;

  /// Usage description.
  final String description;

  /// Ordered arguments.
  final List<NostrSlashArgument> arguments;

  /// Scopes in which the command applies.
  final List<NostrSlashScope> scopes;

  /// Executor public key, when parsed from an event.
  final String pubkey;

  /// Remaining tags, preserved verbatim.
  final List<List<String>> tags;

  /// Address of the definition: `31992:<pubkey>:<identifier>`.
  String get address => '31992:$pubkey:$identifier';

  /// Whether the mandatory tags are present and the argument list is legal.
  bool get isValid =>
      identifier.isNotEmpty &&
      command.isNotEmpty &&
      title.isNotEmpty &&
      description.isNotEmpty &&
      _hasLegalArgumentOrder(arguments);

  /// Parses a kind-31992 event, returning `null` when invalid.
  static NostrSlashCommandDefinition? tryParse(NostrEvent event) {
    if (event.kind != NostrNipCd.definitionKind) {
      return null;
    }

    final identifier = NostrTags.first(event.tags, 'd');
    final command = NostrTags.first(event.tags, 'command');
    final title = NostrTags.first(event.tags, 'title');
    final description = NostrTags.first(event.tags, 'description');

    if (identifier == null ||
        command == null ||
        title == null ||
        description == null ||
        command.startsWith('/') ||
        command.contains(RegExp(r'[\s@]'))) {
      return null;
    }

    final arguments = <NostrSlashArgument>[];
    final scopes = <NostrSlashScope>[];
    final tags = <List<String>>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isEmpty) {
        continue;
      }

      switch (tag.first) {
        case 'arg':
          final argument = NostrSlashArgument.tryParse(tag);
          if (argument == null) {
            return null;
          }
          arguments.add(argument);
        case 's':
          final scope = NostrSlashScope.tryParseTag(tag);
          if (scope == null) {
            return null;
          }
          scopes.add(scope);
        case 'd':
        case 'command':
        case 'title':
        case 'description':
          continue;
        default:
          tags.add(List<String>.of(tag));
      }
    }

    final definition = NostrSlashCommandDefinition(
      identifier: identifier,
      command: command,
      title: title,
      description: description,
      arguments: arguments,
      scopes: scopes,
      pubkey: event.pubkey,
      tags: tags,
    );

    return definition.isValid ? definition : null;
  }

  /// Like [tryParse], but throws [ArgumentError] when invalid.
  static NostrSlashCommandDefinition parse(NostrEvent event) {
    final definition = tryParse(event);

    if (definition == null) {
      throw ArgumentError('Invalid NIP-CD slash command definition event');
    }

    return definition;
  }

  /// Whether an invocation event falls inside [scopes].
  ///
  /// Same-type scopes are alternatives. `tag` scopes are grouped by tag name,
  /// so `tag:h:a` and `tag:h:b` are alternatives while `tag:h` and `tag:t`
  /// must both match (CD.md:26-28).
  bool appliesTo({
    required int kind,
    String? relayUrl,
    String? authorPubkey,
    List<List<String>>? tags,
  }) {
    final alternatives = <String, List<NostrSlashScope>>{};

    for (final scope in scopes) {
      final key = scope.type == NostrSlashScopeType.tag
          ? 'tag:${scope.value}'
          : scope.type.wireName;
      (alternatives[key] ??= <NostrSlashScope>[]).add(scope);
    }

    for (final group in alternatives.values) {
      final matched = group.any(
        (scope) => scope.matches(
          kind: kind,
          relayUrl: relayUrl,
          authorPubkey: authorPubkey,
          tags: tags,
        ),
      );

      if (!matched) {
        return false;
      }
    }

    return true;
  }
}

/// {@template nostr_slash_command_address}
/// One `a` tag of a NIP-CD installed-command list.
/// {@endtemplate}
class NostrSlashCommandAddress {
  /// {@macro nostr_slash_command_address}
  const NostrSlashCommandAddress({
    required this.pubkey,
    required this.identifier,
    this.relayUrl,
  });

  /// Executor public key.
  final String pubkey;

  /// Command definition identifier (`d` tag).
  final String identifier;

  /// Relay hint where the definition can be found.
  final String? relayUrl;

  /// Address string: `31992:<pubkey>:<identifier>`.
  String get address => '31992:$pubkey:$identifier';

  /// Serializes to an `a` tag.
  List<String> toTag() => [
        'a',
        address,
        if (relayUrl != null) relayUrl!,
      ];

  /// Parses an `a` tag, returning `null` when it is not a 31992 address.
  static NostrSlashCommandAddress? tryParseTag(List<String> tag) {
    if (tag.length < 2 || tag.first != 'a') {
      return null;
    }

    final parsed = NostrEventAddress.tryParse(tag[1]);

    if (parsed == null || parsed.kind != NostrNipCd.definitionKind) {
      return null;
    }

    return NostrSlashCommandAddress(
      pubkey: parsed.pubkey,
      identifier: parsed.identifier,
      relayUrl: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
    );
  }
}

/// {@template nostr_slash_command_list}
/// Parsed NIP-CD installed-command list (kind 10992).
/// {@endtemplate}
class NostrSlashCommandList {
  /// {@macro nostr_slash_command_list}
  const NostrSlashCommandList({
    this.commands = const <NostrSlashCommandAddress>[],
    this.pubkey = '',
  });

  /// Commands in list order.
  final List<NostrSlashCommandAddress> commands;

  /// List author, when parsed from an event.
  final String pubkey;
}

/// {@template nostr_slash_value}
/// One parsed invocation argument.
///
/// [raw] is the token as written, [value] the typed value after normalizing
/// (for example an `int` for [NostrSlashArgumentType.number]).
/// {@endtemplate}
class NostrSlashValue {
  /// {@macro nostr_slash_value}
  const NostrSlashValue({
    required this.name,
    required this.type,
    required this.raw,
    this.value,
  });

  /// Argument name from the definition.
  final String name;

  /// Declared argument type.
  final NostrSlashArgumentType type;

  /// Token as written in the invocation.
  final String raw;

  /// Typed value, or `null` when the token did not match [type].
  final Object? value;
}

/// {@template nostr_slash_invocation}
/// Parsed NIP-CD invocation.
///
/// The grammar is `/<command>[@nostr:<pubkey>] [<arg>...] [<text>]`, starting
/// at index 0 of an event content (CD.md:35-53). Parsing needs the matching
/// [NostrSlashCommandDefinition] because argument count and types live in the
/// definition, not in the invocation.
/// {@endtemplate}
class NostrSlashInvocation {
  /// {@macro nostr_slash_invocation}
  const NostrSlashInvocation({
    required this.raw,
    required this.command,
    this.targetNpub,
    this.targetPubkey,
    this.arguments = const <NostrSlashValue>[],
    this.text,
  });

  /// Trigger without the leading slash.
  final String command;

  /// Qualifier as written, without an optional `nostr:` prefix.
  final String? targetNpub;

  /// Qualifier decoded to hex when a bech32 decoder was supplied.
  final String? targetPubkey;

  /// Parsed positional arguments.
  final List<NostrSlashValue> arguments;

  /// Remaining `text` argument, verbatim.
  final String? text;

  /// Original content.
  final String raw;

  /// Value of the named argument, or `null`.
  NostrSlashValue? argument(String name) {
    for (var index = 0; index < arguments.length; index++) {
      if (arguments[index].name == name) {
        return arguments[index];
      }
    }

    return null;
  }

  /// Parses [content] against [definition], returning `null` when it does not
  /// match.
  ///
  /// [bech32] is optional and only used to normalize `npub`/`nprofile`
  /// qualifiers and arguments to hex. Without it the bech32 value is kept
  /// verbatim.
  static NostrSlashInvocation? tryParse(
    String content, {
    required NostrSlashCommandDefinition definition,
    NostrBech32? bech32,
  }) {
    if (!content.startsWith('/')) {
      return null;
    }

    final commandMatch = RegExp(r'^/([^\s@]+)').firstMatch(content);

    if (commandMatch == null || commandMatch.group(1) != definition.command) {
      return null;
    }

    var qualifierEnd = commandMatch.end;
    String? targetNpub;
    String? targetPubkey;

    if (qualifierEnd < content.length && content[qualifierEnd] == '@') {
      var cursor = qualifierEnd + 1;

      if (content.startsWith('nostr:', cursor)) {
        cursor += 6;
      }

      if (!content.startsWith('npub1', cursor)) {
        return null;
      }

      final start = cursor;
      cursor += 5;
      while (cursor < content.length &&
          _bech32DataCharset.hasMatch(content[cursor])) {
        cursor++;
      }

      targetNpub = content.substring(start, cursor);

      if (!_isBech32Entity(targetNpub, const ['npub'])) {
        return null;
      }

      targetPubkey = _decodeNpub(targetNpub, bech32);
      if (bech32 != null && targetPubkey == null) {
        return null;
      }

      qualifierEnd = cursor;
    }

    final rest = content.substring(qualifierEnd);
    var cursor = _skipWhitespace(rest, 0);
    String? cursorText;
    final values = <NostrSlashValue>[];

    for (final argument in definition.arguments) {
      if (argument.type == NostrSlashArgumentType.text) {
        if (cursor >= rest.length) {
          if (argument.required) {
            return null;
          }
          break;
        }

        cursorText = rest.substring(cursor);
        cursor = rest.length;
        break;
      }

      if (cursor >= rest.length) {
        if (argument.required) {
          return null;
        }
        break;
      }

      final start = cursor;
      while (cursor < rest.length && !_isWhitespace(rest[cursor])) {
        cursor++;
      }

      final token = rest.substring(start, cursor);
      final value = _parseValue(token, argument, bech32);

      if (value == null) {
        return null;
      }

      values.add(value);
      cursor = _skipWhitespace(rest, cursor);
    }

    // Anything left after the declared arguments makes the invocation invalid.
    if (cursor < rest.length) {
      return null;
    }

    return NostrSlashInvocation(
      command: definition.command,
      targetNpub: targetNpub,
      targetPubkey: targetPubkey,
      arguments: values,
      text: cursorText,
      raw: content,
    );
  }

  /// Like [tryParse], but throws [FormatException] when it does not match.
  static NostrSlashInvocation parse(
    String content, {
    required NostrSlashCommandDefinition definition,
    NostrBech32? bech32,
  }) {
    final invocation = tryParse(
      content,
      definition: definition,
      bech32: bech32,
    );

    if (invocation == null) {
      throw FormatException(
        'Content is not a valid /${definition.command} invocation',
      );
    }

    return invocation;
  }

  static NostrSlashValue? _parseValue(
    String token,
    NostrSlashArgument argument,
    NostrBech32? bech32,
  ) {
    final type = argument.type;
    final raw = token;
    Object? value;

    switch (type) {
      case NostrSlashArgumentType.pubkey:
        final candidate = _stripNostr(token);
        if (NostrValidators.isHex64(candidate)) {
          value = candidate;
        } else if (bech32 == null) {
          value = _isBech32Entity(candidate, const ['npub', 'nprofile'])
              ? candidate
              : null;
        } else {
          value = _decodeNpub(candidate, bech32);
        }
      case NostrSlashArgumentType.event:
        final candidate = _stripNostr(token);
        if (NostrValidators.isHex64(candidate)) {
          value = candidate;
        } else if (bech32 == null) {
          value = _isBech32Entity(candidate, const ['note', 'nevent'])
              ? candidate
              : null;
        } else {
          value = _decodeNevent(candidate, bech32);
        }
      case NostrSlashArgumentType.address:
        final candidate = _stripNostr(token);
        if (!_isBech32Entity(candidate, const ['naddr'])) {
          value = null;
        } else if (bech32 == null) {
          value = candidate;
        } else {
          value = _decodeNaddr(candidate, bech32);
        }
      case NostrSlashArgumentType.relay:
        value = NostrValidators.isRelayUrl(token) ? token : null;
      case NostrSlashArgumentType.number:
        value =
            RegExp(r'^[0-9]+$').hasMatch(token) ? int.tryParse(token) : null;
      case NostrSlashArgumentType.boolean:
        value = _parseBool(token);
      case NostrSlashArgumentType.enumeration:
        value = argument.choices.contains(token) ? token : null;
      case NostrSlashArgumentType.word:
        value = token;
      case NostrSlashArgumentType.text:
        value = token;
    }

    if (value == null) {
      return null;
    }

    return NostrSlashValue(
      name: argument.name,
      type: type,
      raw: raw,
      value: value,
    );
  }

  static String _stripNostr(String value) =>
      value.startsWith('nostr:') ? value.substring(6) : value;

  static bool? _parseBool(String value) {
    switch (value.toLowerCase()) {
      case 'true':
      case 'yes':
      case '1':
      case 't':
      case 'y':
        return true;
      case 'false':
      case 'no':
      case '0':
      case 'f':
      case 'n':
        return false;
      default:
        return null;
    }
  }

  static String? _decodeNpub(String value, NostrBech32? bech32) {
    if (bech32 == null) {
      return null;
    }

    try {
      if (value.startsWith('npub1')) {
        return bech32.decodeNpubKeyToPublicKey(value);
      }

      if (value.startsWith('nprofile1')) {
        return bech32.decodeNprofileToMap(value)['pubkey'] as String?;
      }
    } on Object {
      return null;
    }

    return null;
  }

  static String? _decodeNevent(String value, NostrBech32? bech32) {
    if (bech32 == null) {
      return null;
    }

    try {
      if (value.startsWith('note1')) {
        final decoded = bech32.decodeBech32(value);

        return decoded[1] == 'note' && decoded[0].length == 64
            ? decoded[0]
            : null;
      }

      if (value.startsWith('nevent1')) {
        return bech32.decodeNeventToMap(value)['eventId'] as String?;
      }
    } on Object {
      return null;
    }

    return null;
  }

  static String? _decodeNaddr(String value, NostrBech32? bech32) {
    if (bech32 == null) {
      return null;
    }

    try {
      final decoded = bech32.decodeNaddrToMap(value);
      return '${decoded['kind']}:${decoded['pubkey']}:${decoded['identifier']}';
    } on Object {
      return null;
    }
  }

  static bool _isWhitespace(String character) =>
      RegExp(r'\s').hasMatch(character);

  static int _skipWhitespace(String value, int cursor) {
    var index = cursor;

    while (index < value.length && _isWhitespace(value[index])) {
      index++;
    }

    return index;
  }

  static final RegExp _bech32Charset =
      RegExp(r'^[023456789acdefghjklmnpqrstuvwxyz]+$');

  /// One character of the bech32 data charset, used to terminate a qualifier.
  static final RegExp _bech32DataCharset =
      RegExp(r'[023456789acdefghjklmnpqrstuvwxyz]');

  static bool _isBech32Entity(String value, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (value.startsWith('${prefix}1')) {
        return _bech32Charset.hasMatch(value.substring(prefix.length + 1));
      }
    }

    return false;
  }
}

/// {@template nipcd}
/// NIP-CD slash commands: kind 31992 definitions, kind 10992 installed lists
/// and invocation parsing.
///
/// [publish] signs events through the signer bound to this instance.
/// {@endtemplate}
class NostrNipCd {
  /// {@macro nipcd}
  NostrNipCd({required this.signer, this.bech32});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Optional bech32 helper used to decode invocation arguments to hex.
  final NostrBech32? bech32;

  /// Kind 31992: replaceable slash command definition.
  static const int definitionKind = 31992;

  /// Kind 10992: replaceable installed-command list.
  static const int listKind = 10992;

  /// Maximum number of waveform-like arguments is not defined; this limit
  /// only guards the definition builder against unbounded argument lists.
  static const int maxArguments = 32;

  /// Builds an unsigned kind-31992 command definition.
  ///
  /// [command] is the trigger without a leading slash; it may not contain
  /// whitespace or `@`, because an invocation is split at `@` for its pubkey
  /// qualifier and such a name could never match. Arguments must be
  /// ordered with every required argument before the optional ones, at most
  /// one optional non-text argument, at most one `text` argument and `text`
  /// last.
  static NostrEvent createDefinition({
    required String identifier,
    required String command,
    required String title,
    required String description,
    List<NostrSlashArgument> arguments = const <NostrSlashArgument>[],
    List<NostrSlashScope> scopes = const <NostrSlashScope>[],
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    if (identifier.trim().isEmpty) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Command identifier is required',
      );
    }

    if (command.isEmpty ||
        command.startsWith('/') ||
        command.contains(RegExp(r'[\s@]'))) {
      throw ArgumentError.value(
        command,
        'command',
        'Command must be a trigger without a leading slash, whitespace or @',
      );
    }

    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Command title is required');
    }

    if (description.trim().isEmpty) {
      throw ArgumentError.value(
        description,
        'description',
        'Command description is required',
      );
    }

    if (arguments.length > maxArguments) {
      throw ArgumentError.value(
        arguments,
        'arguments',
        'At most $maxArguments arguments are supported',
      );
    }

    _validateArguments(arguments);

    for (final argument in arguments) {
      final hasInvalidChoices =
          argument.type != NostrSlashArgumentType.enumeration &&
              argument.choices.isNotEmpty;
      if (hasInvalidChoices) {
        throw ArgumentError.value(
          argument.choices,
          'arguments',
          'Choices only apply to enum arguments',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: definitionKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        ['d', identifier],
        ['command', command],
        ['title', title],
        ['description', description],
        for (final argument in arguments) argument.toTag(),
        for (final scope in scopes) scope.toTag(),
        ...extraTags,
      ],
    );
  }

  /// Builds an unsigned kind-10992 installed-command list.
  static NostrEvent createCommandList({
    required List<NostrSlashCommandAddress> commands,
    List<List<String>> extraTags = const <List<String>>[],
    DateTime? createdAt,
  }) {
    for (final command in commands) {
      if (!NostrValidators.isHex64(command.pubkey) ||
          command.identifier.isEmpty) {
        throw ArgumentError.value(
          command.address,
          'commands',
          'Expected a 31992 address with a valid pubkey and identifier',
        );
      }
    }

    return NostrEvent(
      id: null,
      kind: listKind,
      content: '',
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        for (final command in commands) command.toTag(),
        ...extraTags,
      ],
    );
  }

  /// Signs [event] with the bound signer; sending it is up to the caller.
  Future<NostrEvent> publish(NostrEvent event) => signer.sign(event);

  /// Parses a kind-10992 installed-command list, returning `null` on bad
  /// input.
  static NostrSlashCommandList? tryParseCommandList(NostrEvent event) {
    if (event.kind != listKind) {
      return null;
    }

    final commands = <NostrSlashCommandAddress>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.isEmpty || tag.first != 'a') {
        continue;
      }

      final command = NostrSlashCommandAddress.tryParseTag(tag);

      if (command == null) {
        return null;
      }

      commands.add(command);
    }

    return NostrSlashCommandList(
      commands: commands,
      pubkey: event.pubkey,
    );
  }

  /// Like [tryParseCommandList], but throws [ArgumentError] when invalid.
  static NostrSlashCommandList parseCommandList(NostrEvent event) {
    final list = tryParseCommandList(event);

    if (list == null) {
      throw ArgumentError('Invalid NIP-CD slash command list event');
    }

    return list;
  }

  static void _validateArguments(List<NostrSlashArgument> arguments) {
    var sawOptional = false;
    var sawText = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];

      if (argument.name.isEmpty || argument.label.isEmpty) {
        throw ArgumentError.value(
          argument.name,
          'arguments',
          'Argument name and label must not be empty',
        );
      }

      if (argument.type == NostrSlashArgumentType.text) {
        if (sawText) {
          throw ArgumentError('At most one text argument is allowed');
        }

        if (index != arguments.length - 1) {
          throw ArgumentError('The text argument must be last');
        }

        if (argument.required && sawOptional) {
          throw ArgumentError(
            'Required arguments must come before optional arguments',
          );
        }

        sawText = true;
        continue;
      }

      if (!argument.required) {
        if (sawOptional) {
          throw ArgumentError('At most one optional argument is allowed');
        }
        sawOptional = true;
      } else if (sawOptional) {
        throw ArgumentError(
          'Required arguments must come before optional arguments',
        );
      }

      if (argument.type == NostrSlashArgumentType.enumeration &&
          argument.choices.isEmpty) {
        throw ArgumentError.value(
          argument.name,
          'arguments',
          'Enum arguments need at least one choice',
        );
      }
    }
  }
}

bool _hasLegalArgumentOrder(List<NostrSlashArgument> arguments) {
  var sawOptional = false;
  var sawText = false;

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];

    if (argument.name.isEmpty || argument.label.isEmpty) {
      return false;
    }

    if (argument.type == NostrSlashArgumentType.text) {
      if (sawText || index != arguments.length - 1) {
        return false;
      }
      if (argument.required && sawOptional) {
        return false;
      }
      sawText = true;
      continue;
    }

    if (!argument.required) {
      if (sawOptional) {
        return false;
      }
      sawOptional = true;
    } else if (sawOptional) {
      return false;
    }

    if (argument.type == NostrSlashArgumentType.enumeration &&
        argument.choices.isEmpty) {
      return false;
    }
  }

  return true;
}
