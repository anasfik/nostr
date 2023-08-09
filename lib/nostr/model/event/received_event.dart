// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/model/event/send_event.dart';

import '../../core/key_pairs.dart';
import '../nostr_event_key.dart';
import 'event.dart';

class ReceivedNostrEvent extends SentNostrEvent {
  /// The subscription id of the event
  /// This is meant for events that are got from the relays, and not for events that are created by you.
  final String subscriptionId;

  ReceivedNostrEvent({
    required this.subscriptionId,
    required super.content,
    required super.createdAt,
    required super.id,
    required super.kind,
    required super.ots,
    required super.pubkey,
    required super.sig,
    required super.tags,
  });

  /// This represents a nostr event that is received from the relays,
  /// it takes directly the relay message which is serialized, and handles all internally
  factory ReceivedNostrEvent.deserialized(String data) {
    assert(NostrEvent.canBeDeserialized(data));
    final decoded = jsonDecode(data) as List;

    final event = decoded.last as Map<String, dynamic>;
    return ReceivedNostrEvent(
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

  /// Returns a unique tag for this event that you can use to identify it.
  NostrEventKey uniqueKey() {
    return NostrEventKey(
      eventId: id,
      sourceSubscriptionId: subscriptionId,
      originalSourceEvent: this,
    );
  }

  /// {@macro nostr_event}
  ReceivedNostrEvent copyWith({
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
    return ReceivedNostrEvent(
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
