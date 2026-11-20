import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_app_data}
/// Parsed NIP-78 application data.
///
/// [kind] is 78 for plain events and 30078 for addressable ones. [identifier]
/// is the optional `d` tag used to group data by app and context.
/// {@endtemplate}
class NostrAppData {
  /// {@macro nostr_app_data}
  const NostrAppData({
    required this.kind,
    required this.content,
    required this.tags,
    this.identifier,
  });

  /// Event kind (78 or 30078).
  final int kind;

  /// Free-form payload.
  final String content;

  /// Optional `d` tag value.
  final String? identifier;

  /// Remaining event tags.
  final List<List<String>> tags;

  /// Whether this is the addressable kind 30078.
  bool get isAddressable => kind == NostrNip78.addressableKind;
}

/// {@template nip78}
/// NIP-78 arbitrary custom app data (kinds 78 and 30078).
///
/// Kind 30078 is addressable and needs a `d` tag identifying the app context;
/// kind 78 is a normal event that apps may group with their own tags.
///
/// Templates and parsing are static; [publish] signs through the bound signer.
/// {@endtemplate}
class NostrNip78 {
  /// {@macro nip78}
  NostrNip78({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Plain app data kind.
  static const int appDataKind = 78;

  /// Addressable app data kind.
  static const int addressableKind = 30078;

  /// Both app data kinds.
  static const List<int> kinds = [appDataKind, addressableKind];

  /// Whether [kind] is a NIP-78 kind.
  static bool isAppDataKind(int? kind) => kinds.contains(kind);

  /// Builds an unsigned app data event.
  ///
  /// [kind] must be [appDataKind] or [addressableKind]. [addressableKind]
  /// requires a non-empty [dTag]. [tags] are appended after the `d` tag.
  static NostrEvent generateAppDataTemplate({
    required String content,
    int kind = appDataKind,
    String? dTag,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    if (!isAppDataKind(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Expected kind 78 or 30078');
    }

    if (kind == addressableKind && (dTag == null || dTag.isEmpty)) {
      throw ArgumentError.value(
        dTag,
        'dTag',
        'Kind 30078 requires a non-empty d tag',
      );
    }

    return NostrEvent(
      id: null,
      kind: kind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: [
        if (dTag != null) ['d', dTag],
        ...tags,
      ],
    );
  }

  /// Builds and signs an app data event.
  Future<NostrEvent> publish({
    required String content,
    int kind = appDataKind,
    String? dTag,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    return signer.sign(
      generateAppDataTemplate(
        content: content,
        kind: kind,
        dTag: dTag,
        tags: tags,
        createdAt: createdAt,
      ),
    );
  }

  /// Parses [event] into [NostrAppData].
  ///
  /// Throws [ArgumentError] for other kinds or a kind-30078 event without a
  /// non-empty `d` tag.
  static NostrAppData parseAppData(NostrEvent event) {
    final parsed = tryParseAppData(event);

    if (parsed == null) {
      throw ArgumentError('Invalid NIP-78 app data event');
    }

    return parsed;
  }

  /// Like [parseAppData], but returns `null` for invalid events.
  static NostrAppData? tryParseAppData(NostrEvent event) {
    final kind = event.kind;
    if (!isAppDataKind(kind)) {
      return null;
    }

    final identifier = NostrTags.first(event.tags, 'd');
    if (kind == addressableKind && (identifier == null || identifier.isEmpty)) {
      return null;
    }

    return NostrAppData(
      kind: kind!,
      content: event.content ?? '',
      identifier: identifier,
      tags: [
        for (final tag in event.tags ?? const <List<String>>[])
          if (tag.isEmpty || tag.first != 'd') List<String>.of(tag),
      ],
    );
  }
}
