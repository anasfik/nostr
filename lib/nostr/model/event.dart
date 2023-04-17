// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import '../core/key_pairs.dart';

class NostrEvent extends Equatable {
  final String id;
  final int kind;
  final String content;
  final String sig;
  final String pubkey;
  final DateTime createdAt;
  final List<List<String>> tags;
  final String? subscriptionId;
  final String? ots;

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

    return decoded.first == "EVENT";
  }

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

  String serialized() {
    return jsonEncode(["EVENT", _toMap()]);
  }

  String uniqueTag() {
    // make a unique tag for this event.

    return "$id$createdAt$subscriptionId$pubkey";
  }

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
