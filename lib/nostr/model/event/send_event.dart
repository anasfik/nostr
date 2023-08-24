import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';

import '../../core/key_pairs.dart';
import 'event.dart';

class SentNostrEvent extends NostrEvent {
  /// The id of the event.
  final String id;

  /// The kind of the event.
  final int kind;

  /// The content of the event.
  final String content;

  /// The signature of the event.
  final String sig;

  /// The public key of the event creator.
  final String pubkey;

  /// The creation date of the event.
  final DateTime createdAt;

  /// The tags of the event.
  final List<List<String>> tags;

  /// The ots of the event.
  final String? ots;

  /// {@macro nostr_event}
  SentNostrEvent({
    required this.id,
    required this.kind,
    required this.content,
    required this.sig,
    required this.pubkey,
    required this.createdAt,
    required this.tags,
    this.ots,
  });

  /// Returns a map representation of this event.
  Map<String, dynamic> _toMap() {
    return {
      'id': id,
      'kind': kind,
      'content': content,
      'sig': sig,
      'pubkey': pubkey,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'tags': tags,
      if (ots != null) 'ots': ots,
    };
  }

  factory SentNostrEvent.deleteEvent({
    required NostrKeyPairs keyPairs,
    required List<String> eventIdsToBeDeleted,
    String reasonOfDeletion = "",
    DateTime? createdAt,
  }) {
    assert(
      eventIdsToBeDeleted.isNotEmpty,
      "the list of event ids is empty, "
      "you must provide at least one event id to be deleted.",
    );

    return SentNostrEvent.fromPartialData(
      kind: 5,
      content: reasonOfDeletion,
      keyPairs: keyPairs,
      tags: eventIdsToBeDeleted.map((eventId) => ["e", eventId]).toList(),
      createdAt: createdAt,
    );
  }

  factory SentNostrEvent.fromPartialData({
    required int kind,
    required String content,
    required NostrKeyPairs keyPairs,
    List<List<String>>? tags,
    DateTime? createdAt,
    String? ots,
  }) {
    final pubkey = keyPairs.public;
    final tagsToUse = tags ?? [];
    final createdAtToUse = createdAt ?? DateTime.now();

    final id = NostrEvent.getEventId(
      kind: kind,
      content: content,
      createdAt: createdAtToUse,
      tags: tagsToUse,
      pubkey: pubkey,
    );

    final sig = keyPairs.sign(id);

    return SentNostrEvent(
      id: id,
      kind: kind,
      content: content,
      sig: sig,
      pubkey: pubkey,
      createdAt: createdAtToUse,
      tags: tagsToUse,
      ots: ots,
    );
  }

  /// Returns a serialized [NostrEvent] from this event.
  String serialized() {
    return jsonEncode([NostrConstants.event, _toMap()]);
  }

  @override
  List<Object?> get props => [
        id,
        kind,
        content,
        sig,
        pubkey,
        createdAt,
        tags,
        ots,
      ];

  /// {@macro nostr_event}
  SentNostrEvent copyWith({
    String? id,
    int? kind,
    String? content,
    String? sig,
    String? pubkey,
    DateTime? createdAt,
    List<List<String>>? tags,
    String? ots,
  }) {
    return SentNostrEvent(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      sig: sig ?? this.sig,
      pubkey: pubkey ?? this.pubkey,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      ots: ots ?? this.ots,
    );
  }
}
