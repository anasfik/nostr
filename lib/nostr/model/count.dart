import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:equatable/equatable.dart';

class NostrCountEvent extends Equatable {
  const NostrCountEvent({
    required this.eventsFilter,
    required this.subscriptionId,
  });

  final NostrFilter eventsFilter;
  final String subscriptionId;

  static NostrCountEvent fromPartialData({
    required NostrFilter eventsFilter,
  }) {
    final createdSubscriptionId =
        Nostr.instance.utilsService.consistent64HexChars(
      eventsFilter.toMap().toString(),
    );

    return NostrCountEvent(
      eventsFilter: eventsFilter,
      subscriptionId: createdSubscriptionId,
    );
  }

  String serialized() {
    return jsonEncode([
      NostrConstants.count,
      subscriptionId,
      eventsFilter.toMap(),
    ]);
  }

  @override
  List<Object?> get props => [
        eventsFilter,
        subscriptionId,
      ];
}

class NostrCountResponse extends Equatable {
  const NostrCountResponse({
    required this.subscriptionId,
    required this.count,
  });

  factory NostrCountResponse.deserialized(String data) {
    final decodedData = jsonDecode(data);
    assert(decodedData is List);

    final countMap = decodedData[2];
    assert(countMap is Map);

    return NostrCountResponse(
      subscriptionId: decodedData[1] as String,
      count: int.parse(countMap['count'] as String),
    );
  }
  final String subscriptionId;
  final int count;
  @override
  List<Object?> get props => throw UnimplementedError();

  static bool canBeDeserialized(String data) {
    final decodedData = jsonDecode(data);

    assert(decodedData is List);

    if (decodedData[0] != NostrConstants.count) {
      return false;
    }

    final countMap = decodedData[2];
    if (countMap is Map<String, dynamic>) {
      return countMap
          .map((key, value) => MapEntry(key.toUpperCase(), value))
          .containsKey(NostrConstants.count);
    } else {
      return false;
    }
  }
}
