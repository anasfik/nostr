import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/received_event.dart';
import 'package:dart_nostr/nostr/model/event/send_event.dart';
import 'package:equatable/equatable.dart';

import '../../core/constants.dart';

/// {@template nostr_event}
/// This represents a low level Nostr event that requires setting all fields manually, which requires you to doo all encodings...
/// You can use [NostrEvent.fromPartialData] to create an event with less fields and lower complexity..
/// {@endtemplate}
abstract class NostrEvent extends Equatable {
  /// Wether the given [dataFromRelay] can be deserialized into a [ReceivedNostrEvent].
  static bool canBeDeserialized(String dataFromRelay) {
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

  /// {@macro nostr_event_from_partial_data}
  ///
  /// This requires only to set the fields which can be used & showed to the user directly.
  static SentNostrEvent fromPartialData({
    required int kind,
    required String content,
    required NostrKeyPairs keyPairs,
    List<List<String>>? tags,
    DateTime? createdAt,
    String? ots,
  }) {
    return SentNostrEvent.fromPartialData(
      kind: kind,
      content: content,
      keyPairs: keyPairs,
      createdAt: createdAt,
      ots: ots,
      tags: tags,
    );
  }

  /// Creates a new [NostrEvent] with the given [content].
  static SentNostrEvent deleteEvent({
    required NostrKeyPairs keyPairs,
    required List<String> eventIdsToBeDeleted,
    String reasonOfDeletion = "",
    DateTime? createdAt,
  }) {
    return SentNostrEvent.deleteEvent(
      keyPairs: keyPairs,
      eventIdsToBeDeleted: eventIdsToBeDeleted,
      createdAt: createdAt,
      reasonOfDeletion: reasonOfDeletion,
    );
  }
}
