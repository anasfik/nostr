// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:equatable/equatable.dart';

import '../core/key_pairs.dart';
import 'nostr_event_key.dart';

/// {@template nostr_event}
/// This represents a low level Nostr event that requires setting all fields manually, which requires you to doo all encodings...
/// You can use [NostrEvent.fromPartialData] to create an event with less fields and lower complexity..
/// {@endtemplate}
class NostrEvent extends Equatable {
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

  /// The subscription id of the event
  /// This is meant for events that are got from the relays, and not for events that are created by you.
  final String? subscriptionId;

  /// The ots of the event.
  final String? ots;

  /// {@macro nostr_event}
  const NostrEvent({
    required this.id,
    required this.kind,
    required this.content,
    required this.sig,
    required this.pubkey,
    required this.createdAt,
    required this.tags,
    this.subscriptionId,
    this.ots,
  });

  @override
  List<Object?> get props => [
        id,
        kind,
        content,
        sig,
        pubkey,
        createdAt,
        tags,
        subscriptionId,
        ots,
      ];

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

  /// Creates a new [NostrEvent] with the given [content].
  factory NostrEvent.deleteEvent({
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

    return NostrEvent.fromPartialData(
      kind: 5,
      content: reasonOfDeletion,
      keyPairs: keyPairs,
      tags: eventIdsToBeDeleted.map((eventId) => ["e", eventId]).toList(),
      createdAt: createdAt,
    );
  }

  /// Creates a new [NostrEvent] with less fields and lower complexity.
  /// it requires only to set the fields which can be used
  factory NostrEvent.fromPartialData({
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

    final id = getEventId(
      kind: kind,
      content: content,
      createdAt: createdAtToUse,
      tags: tagsToUse,
      pubkey: pubkey,
    );

    final sig = keyPairs.sign(id);

    return NostrEvent(
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

  /// This represents a nostr event that is received from the relays,
  /// it takes directly the relay message which is serialized, and handles all internally
  factory NostrEvent.fromRelayMessage(String data) {
    assert(canBeDeserializedEvent(data));
    final decoded = jsonDecode(data) as List;

    final event = decoded.last as Map<String, dynamic>;
    return NostrEvent(
      id: event['id'] as String,
      kind: event['kind'] as int,
      content: event['content'] as String,
      sig: event['sig'] as String,
      pubkey: event['pubkey'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        event['created_at'] * 1000,
      ),
      tags: List<List<String>>.from((event['tags'] as List)
          .map(
            (nestedElem) => (nestedElem as List)
                .map(
                  (nestedElemContent) => nestedElemContent.toString(),
                )
                .toList(),
          )
          .toList()),
      subscriptionId: decoded.length == 3 ? decoded[1] as String : null,
      ots: event['ots'] as String?,
    );
  }
  static bool canBeDeserializedEvent(String dataFromRelay) {
    final decoded = jsonDecode(dataFromRelay) as List;

    return decoded.first == NostrConstants.event;
  }

  /// Creates the [id] of an event, based on Nostr specs.
  static String getEventId({
    required int kind,
    required String content,
    required DateTime createdAt,
    required List tags,
    required String pubkey,
  }) {
    List data = [
      0,
      pubkey,
      createdAt.millisecondsSinceEpoch ~/ 1000,
      kind,
      tags,
      content
    ];

    final serializedEvent = jsonEncode(data);
    final bytes = utf8.encode(serializedEvent);
    final digest = sha256.convert(bytes);
    final id = hex.encode(digest.bytes);

    return id;
  }

  /// Returns a serialized [NostrEvent] from this event.
  String serialized() {
    return jsonEncode(["EVENT", _toMap()]);
  }

  /// Returns a deserialized [NostrEvent] from the given [serialized] string.
  static NostrEvent deserialized(String serialized) {
    return NostrEvent.fromRelayMessage(serialized);
  }

  /// Returns a unique tag for this event that you can use to identify it.
  NostrEventKey uniqueKey() {
    assert(
        subscriptionId != null,
        "This event is created by you, "
        "so it doesn't have a subscription id, "
        "this ùmethod is meant for events that are received from the relays.");

    return NostrEventKey(
      eventId: id,
      sourceSubscriptionId: subscriptionId!,
      originalSourceEvent: this,
    );
  }

  /// {@macro nostr_event}
  NostrEvent copyWith({
    String? id,
    int? kind,
    String? content,
    String? sig,
    String? pubkey,
    DateTime? createdAt,
    List<List<String>>? tags,
    String? subscriptionId,
    String? ots,
  }) {
    return NostrEvent(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      sig: sig ?? this.sig,
      pubkey: pubkey ?? this.pubkey,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      ots: ots ?? this.ots,
    );
  }
}
