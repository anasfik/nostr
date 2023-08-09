// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:equatable/equatable.dart';

abstract class NostrWebSocketMessage extends Equatable {
  final String object;

  NostrWebSocketMessage({
    required this.object,
  });
}

abstract class ReceivedNostrWebSocketMessage extends NostrWebSocketMessage {
  final DateTime receievedAt;

  ReceivedNostrWebSocketMessage({
    required this.receievedAt,
    required super.object,
  });
}

abstract class SentNostrWebSocketMessage extends NostrWebSocketMessage {
  final DateTime sentAt;

  SentNostrWebSocketMessage({
    required this.sentAt,
    required super.object,
  });
}
