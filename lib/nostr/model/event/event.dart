import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:equatable/equatable.dart';

import '../../core/constants.dart';
import '../nostr_event_key.dart';

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

  /// The ots of the event.
  final String? ots;

  /// The subscription id of the event
  /// This is meant for events that are got from the relays, and not for events that are created by you.
  final String subscriptionId;

  /// Wether the given [dataFromRelay] can be deserialized into a [NostrEvent].
  static bool canBeDeserialized(String dataFromRelay) {
    final decoded = jsonDecode(dataFromRelay) as List;

    return decoded.first == NostrConstants.event;
  }

  NostrEvent({
    required this.subscriptionId,
    required this.content,
    required this.createdAt,
    required this.id,
    required this.kind,
    required this.ots,
    required this.pubkey,
    required this.sig,
    required this.tags,
  });

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

  /// {@macro nostr_event_from_partial_data}
  ///
  /// This requires only to set the fields which can be used & showed to the user directly.
  static NostrEvent fromPartialData({
    required int kind,
    required String content,
    required NostrKeyPairs keyPairs,
    List<List<String>>? tags,
    DateTime? createdAt,
    String? ots,
  }) {
    return NostrEvent.fromPartialData(
      kind: kind,
      content: content,
      keyPairs: keyPairs,
      createdAt: createdAt,
      ots: ots,
      tags: tags,
    );
  }

  /// Creates a new [NostrEvent] with the given [content].
  static NostrEvent deleteEvent({
    required NostrKeyPairs keyPairs,
    required List<String> eventIdsToBeDeleted,
    String reasonOfDeletion = "",
    DateTime? createdAt,
  }) {
    return NostrEvent.deleteEvent(
      keyPairs: keyPairs,
      eventIdsToBeDeleted: eventIdsToBeDeleted,
      createdAt: createdAt,
      reasonOfDeletion: reasonOfDeletion,
    );
  }

  /// Returns a unique tag for this event that you can use to identify it.
  NostrEventKey uniqueKey() {
    return NostrEventKey(
      eventId: id,
      sourceSubscriptionId: subscriptionId,
      originalSourceEvent: this,
    );
  }

  /// This represents a nostr event that is received from the relays,
  /// it takes directly the relay message which is serialized, and handles all internally
  factory NostrEvent.deserialized(String data) {
    assert(NostrEvent.canBeDeserialized(data));
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
      subscriptionId: decoded[1],
      ots: event['ots'] as String?,
    );
  }

  /// Returns a serialized [NostrEvent] from this event.
  String serialized() {
    return jsonEncode([NostrConstants.event, _toMap()]);
  }

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
        subscriptionId,
      ];
}
