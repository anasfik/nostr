import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/common/tags.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nip32_target_type}
/// Kind of object a NIP-32 label points at, and the tag that carries it.
/// {@endtemplate}
enum NostrLabelTargetType {
  /// An event id (`e`).
  event('e'),

  /// A public key (`p`).
  pubkey('p'),

  /// An addressable event address (`a`), `kind:pubkey:d`.
  address('a'),

  /// A relay URL (`r`).
  relay('r'),

  /// A topic / hashtag (`t`).
  topic('t');

  const NostrLabelTargetType(this.tagName);

  /// Tag name used on the wire.
  final String tagName;

  /// Whether the tag takes a relay hint in slot 2.
  ///
  /// NIP-32 recommends relay hints for events and pubkeys only
  /// (32.md:40-41). Never treat slot 2 of other target tags as a relay.
  bool get supportsRelayHint => this == event || this == pubkey;

  /// Resolves a tag name, returning `null` for non-target tags.
  static NostrLabelTargetType? fromTagName(String tagName) {
    for (final type in values) {
      if (type.tagName == tagName) {
        return type;
      }
    }

    return null;
  }
}

/// {@template nip32_label}
/// A NIP-32 `l` tag (label) and the `L` tag (namespace) it belongs to.
///
/// [namespace] defaults to `ugc` ("user generated content"), which is also
/// the namespace implied by an `l` tag without a mark. Namespaces are
/// opaque: a namespace such as `#t` keeps its leading `#` verbatim.
/// {@endtemplate}
class NostrLabel {
  /// {@macro nip32_label}
  const NostrLabel({
    required this.value,
    this.namespace = NostrNip32.defaultNamespace,
  });

  /// Label value, for example `permies` or `VI-hum`.
  final String value;

  /// Label namespace, the value of the matching `L` tag.
  final String namespace;

  /// `['l', value, namespace]`, the label tag to publish.
  List<String> get toTag => ['l', value, namespace];

  /// `['L', namespace]`, the namespace tag to publish.
  List<String> get toNamespaceTag => ['L', namespace];

  @override
  String toString() => '$namespace:$value';
}

/// {@template nip32_target}
/// The object a NIP-32 label event points at.
///
/// [relay] is only emitted for [NostrLabelTargetType.event] and
/// [NostrLabelTargetType.pubkey]; other target tags ignore it, matching
/// 32.md:40-41.
/// {@endtemplate}
class NostrLabelTarget {
  /// {@macro nip32_target}
  const NostrLabelTarget({
    required this.type,
    required this.value,
    this.relay,
  });

  /// What [value] identifies.
  final NostrLabelTargetType type;

  /// Event id, pubkey, address, relay URL or topic.
  final String value;

  /// Optional relay hint for event and pubkey targets.
  final String? relay;

  /// The `e`/`p`/`a`/`r`/`t` tag to publish.
  List<String> get toTag => [
        type.tagName,
        value,
        if (relay != null && type.supportsRelayHint) relay!,
      ];

  @override
  String toString() => '${type.tagName}:$value';
}

/// {@template nip32_event}
/// Parsed NIP-32 label event (kind 1985).
///
/// Labels and targets keep event order. [content] may explain the labels;
/// labels themselves stay short (32.md:46-47).
/// {@endtemplate}
class NostrLabelEvent {
  /// {@macro nip32_event}
  const NostrLabelEvent({
    required this.labels,
    required this.targets,
    this.content = '',
  });

  /// Parsed `l` tags.
  final List<NostrLabel> labels;

  /// Parsed `e`/`p`/`a`/`r`/`t` tags.
  final List<NostrLabelTarget> targets;

  /// Free-form explanation.
  final String content;
}

/// {@template nip32}
/// NIP-32 labeling (kind 1985).
///
/// Kind 1985 is a **regular** kind: not addressable (30000–39999) and not
/// replaceable (0, 3, 10000–19999), so a newer label event does not replace
/// an older one. Bulk corrections are published as NIP-09 deletions plus a
/// replacement (32.md:148-150).
///
/// Shape rules enforced here:
/// - at least one target tag: `e`, `p`, `a`, `r` or `t` (32.md:38-39);
/// - at least one `l` tag;
/// - an `l` mark must match an `L` namespace in the same event when any `L`
///   tag is present (32.md:31-32);
/// - an `l` without a mark implies the `ugc` namespace (32.md:32-33).
///
/// Slot 2 of an `e`/`p` target is a relay hint here (32.md:40-41). NIP-56
/// puts a report type in the same slot of its `e`/`p`/`x` tags, so never
/// share slot-2 parsing between the two modules.
///
/// ```dart
/// final nip32 = NostrNip32(signer: signer);
/// final event = await nip32.publish(
///   labels: [
///     NostrLabel(value: 'MIT', namespace: 'license'),
///   ],
///   targets: [
///     NostrLabelTarget(
///       type: NostrLabelTargetType.event,
///       value: noteId,
///       relay: 'wss://relay.example',
///     ),
///   ],
/// );
/// ```
/// {@endtemplate}
class NostrNip32 {
  /// {@macro nip32}
  NostrNip32({required this.signer});

  /// Signer used by [publish].
  final NostrEventSigner signer;

  /// Kind of a label event.
  static const int labelKind = 1985;

  /// Namespace implied by an `l` tag without a mark.
  static const String defaultNamespace = 'ugc';

  /// Tag names that point at a labeled object.
  static const List<String> targetTagNames = ['e', 'p', 'a', 'r', 't'];

  /// Whether [event] is a valid label event.
  ///
  /// Checks the kind, the presence of a target and an `l` tag, and that every
  /// label mark belongs to an `L` namespace in the same event.
  static bool validateEvent(NostrEvent event) => _tagProblem(event) == null;

  /// Parses [event], returning `null` for anything [validateEvent] rejects.
  static NostrLabelEvent? tryParseEvent(NostrEvent event) {
    if (!validateEvent(event)) {
      return null;
    }

    final labels = <NostrLabel>[];
    final targets = <NostrLabelTarget>[];

    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length < 2) {
        continue;
      }

      if (tag.first == 'l') {
        labels.add(NostrLabel(value: tag[1], namespace: _mark(tag)));
        continue;
      }

      final type = NostrLabelTargetType.fromTagName(tag.first);
      if (type == null) {
        continue;
      }

      targets.add(
        NostrLabelTarget(
          type: type,
          value: tag[1],
          relay: type.supportsRelayHint ? NostrTags.at(tag, 2) : null,
        ),
      );
    }

    return NostrLabelEvent(
      labels: labels,
      targets: targets,
      content: event.content ?? '',
    );
  }

  /// Parses [event], throwing [ArgumentError] when it is not a label event.
  static NostrLabelEvent parseEvent(NostrEvent event) {
    final parsed = tryParseEvent(event);

    if (parsed == null) {
      throw ArgumentError.value(event, 'event', 'Invalid NIP-32 label event');
    }

    return parsed;
  }

  /// Labels in [event] that belong to [namespace].
  static List<NostrLabel> labelsForNamespace(
    NostrLabelEvent event,
    String namespace,
  ) {
    return [
      for (final label in event.labels)
        if (label.namespace == namespace) label,
    ];
  }

  /// Builds an unsigned kind-1985 label event.
  ///
  /// One `L` tag is emitted per distinct label namespace, followed by the `l`
  /// tags and then [targets]. Throws [ArgumentError] when [labels] or
  /// [targets] are empty, when a label value or namespace is empty, or when
  /// more than one namespace is used without [allowMultipleNamespaces]
  /// (32.md:150-151).
  ///
  /// [content] is free-form and does not change the labels.
  static NostrEvent generateEventTemplate({
    required List<NostrLabel> labels,
    required List<NostrLabelTarget> targets,
    String content = '',
    DateTime? createdAt,
    bool allowMultipleNamespaces = false,
  }) {
    if (labels.isEmpty) {
      throw ArgumentError.value(
        labels,
        'labels',
        'Label events require at least one label',
      );
    }

    if (targets.isEmpty) {
      throw ArgumentError.value(
        targets,
        'targets',
        'Label events require at least one target',
      );
    }

    final namespaces = <String>[];
    for (final label in labels) {
      if (label.value.isEmpty) {
        throw ArgumentError.value(
          label.value,
          'labels',
          'Label value must not be empty',
        );
      }
      if (label.namespace.isEmpty) {
        throw ArgumentError.value(
          label.namespace,
          'labels',
          'Label namespace must not be empty',
        );
      }
      if (!namespaces.contains(label.namespace)) {
        namespaces.add(label.namespace);
      }
    }

    if (namespaces.length > 1 && !allowMultipleNamespaces) {
      throw ArgumentError.value(
        namespaces,
        'labels',
        'Use a single namespace per event, or allowMultipleNamespaces',
      );
    }

    for (final target in targets) {
      if (target.value.isEmpty) {
        throw ArgumentError.value(
          target.value,
          'targets',
          'Label target must not be empty',
        );
      }
    }

    final tags = <List<String>>[
      for (final namespace in namespaces) ['L', namespace],
      for (final label in labels) label.toTag,
      for (final target in targets) target.toTag,
    ];

    final event = NostrEvent(
      id: null,
      kind: labelKind,
      content: content,
      sig: null,
      pubkey: '',
      createdAt: createdAt ?? DateTime.now(),
      tags: tags,
    );

    final problem = _tagProblem(event);
    if (problem != null) {
      throw ArgumentError(problem);
    }

    return event;
  }

  /// Builds and signs a kind-1985 label event.
  Future<NostrEvent> publish({
    required List<NostrLabel> labels,
    required List<NostrLabelTarget> targets,
    String content = '',
    DateTime? createdAt,
    bool allowMultipleNamespaces = false,
  }) {
    return signer.sign(
      generateEventTemplate(
        labels: labels,
        targets: targets,
        content: content,
        createdAt: createdAt,
        allowMultipleNamespaces: allowMultipleNamespaces,
      ),
    );
  }

  /// Namespace implied by an `l` tag: its mark, or `ugc` when absent.
  static String _mark(List<String> tag) {
    final mark = NostrTags.at(tag, 2);
    return mark == null || mark.isEmpty ? defaultNamespace : mark;
  }

  static String? _tagProblem(NostrEvent event) {
    if (event.kind != labelKind) {
      return 'Expected kind $labelKind';
    }

    final tags = event.tags ?? const <List<String>>[];
    final namespaces = <String>{};
    var hasLabel = false;
    var hasTarget = false;

    for (final tag in tags) {
      if (tag.isEmpty) {
        continue;
      }

      final name = tag.first;
      final isLabelTag = name == 'l';
      final isNamespaceTag = name == 'L';
      final isTargetTag = targetTagNames.contains(name);

      if (!isLabelTag && !isNamespaceTag && !isTargetTag) {
        continue;
      }

      if (tag.length < 2 || tag[1].isEmpty) {
        return 'Missing value in "$name" tag';
      }

      if (isNamespaceTag) {
        namespaces.add(tag[1]);
      } else if (isLabelTag) {
        hasLabel = true;
      } else {
        hasTarget = true;
      }
    }

    if (!hasTarget) {
      return 'Label events require at least one e, p, a, r or t tag';
    }

    if (!hasLabel) {
      return 'Label events require at least one l tag';
    }

    if (namespaces.isNotEmpty) {
      for (final tag in tags) {
        if (tag.length < 2 || tag.first != 'l') {
          continue;
        }

        final mark = _mark(tag);
        if (!namespaces.contains(mark)) {
          return 'Label mark "$mark" is not an L namespace';
        }
      }
    }

    return null;
  }
}
