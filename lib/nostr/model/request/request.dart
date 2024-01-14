// ignore_for_file: public_member_api_docs, sort_constructors_first, avoid_dynamic_calls, argument_type_not_assignable

import 'dart:convert';

import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:equatable/equatable.dart';

/// {@template nostr_request}
/// NostrRequest is a request to subscribe to a set of events that match a set of filters with a given [subscriptionId].
/// {@endtemplate}

// ignore: must_be_immutable
class NostrRequest extends Equatable {
  /// The subscription ID of the request.
  String? subscriptionId;

  /// A list of filters that the request will match.
  final List<NostrFilter> filters;

  /// {@macro nostr_request}
  NostrRequest({
    required this.filters, this.subscriptionId,
  });

  /// Serialize the request to send it to the remote relays websockets.
  String serialized({String? subscriptionId}) {
    this.subscriptionId = subscriptionId ??
        this.subscriptionId ??
        Nostr.instance.utilsService.consistent64HexChars(
          filters
              .map((e) => e.toMap().toString())
              .reduce((value, element) => value + element),
        );

    final decodedFilters =
        jsonEncode(filters.map((item) => item.toMap()).toList());

    final header = jsonEncode([NostrConstants.request, subscriptionId]);

    final result =
        '${header.substring(0, header.length - 1)},${decodedFilters.substring(1, decodedFilters.length)}';

    return result;
  }

  /// Deserialize a request
  factory NostrRequest.deserialized(input) {
    final haveThreeElements = input is List && input.length >= 3;

    assert(
      haveThreeElements,
      'Invalid request, must have at least 3 elements',
    );

    assert(
      input[0] == NostrConstants.request,
      'Invalid request, must start with ${NostrConstants.request}',
    );

    final subscriptionId = input[1] as String;

    return NostrRequest(
      subscriptionId: subscriptionId,
      filters: List.generate(
        input.length - 2,
        (index) => NostrFilter.fromJson(
          input[index + 2],
        ),
      ),
    );
  }

  @override
  List<Object?> get props => [subscriptionId, filters];

  NostrRequest copyWith({
    String? subscriptionId,
    List<NostrFilter>? filters,
  }) {
    return NostrRequest(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      filters: filters ?? this.filters,
    );
  }
}
