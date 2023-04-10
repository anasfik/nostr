import 'package:equatable/equatable.dart';

/// {@template nostr_filter}
/// NostrFilter is a filter that can be used to match events.
/// {@endtemplate}
class NostrFilter extends Equatable {
  /// a list of event ids to filter with.
  final List<String>? ids;

  /// a list of pubkeys or prefixes to filter with.
  final List<String>? authors;

  /// a list of a kind numbers to filter with.
  final List<int>? kinds;

  /// a list of event ids that are referenced in an "e" tag to filter with.
  final List<String>? e;

  /// a list of event ids that are referenced in an "e" tag to filter with.
  final List<String>? t;

  /// a list of pubkeys that are referenced in a "p" tag to filter with.
  final List<String>? p;

  /// the DateTime to start the filtering from
  final DateTime? since;

  /// the DateTime to end the filtering at
  final DateTime? until;

  /// the maximum number of events to return
  final int? limit;

  /// {@macro nostr_filter}
  NostrFilter({
    this.ids,
    this.authors,
    this.kinds,
    this.e,
    this.p,
    this.t,
    this.since,
    this.until,
    this.limit,
  });

  /// Deserialize aNpstrFilter from a JSON
  factory NostrFilter.fromJson(Map<String, dynamic> json) {
    final ids = json['ids'] == null ? null : List<String>.from(json['ids']);
    final authors =
        json['authors'] == null ? null : List<String>.from(json['authors']);
    final kinds = json['kinds'] == null ? null : List<int>.from(json['kinds']);
    final e = json['#e'] == null ? null : List<String>.from(json['#e']);
    final p = json['#p'] == null ? null : List<String>.from(json['#p']);
    final t = json['#t'] == null ? null : List<String>.from(json['#t']);
    final since = DateTime.fromMillisecondsSinceEpoch(json['since'] * 1000);
    final until = DateTime.fromMillisecondsSinceEpoch(json['until'] * 1000);
    final limit = json['limit'];

    return NostrFilter(
      ids: ids,
      authors: authors,
      kinds: kinds,
      e: e,
      p: p,
      t: t,
      since: since,
      until: until,
      limit: limit,
    );
  }

  /// Serialize a [NostrFilter] to a [Map<String, dynamic>]
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (ids != null) 'ids': ids,
      if (authors != null) 'authors': authors,
      if (kinds != null) 'kinds': kinds,
      if (e != null) '#e': e,
      if (p != null) '#p': p,
      if (t != null) '#t': t,
      if (since != null) 'since': since!.millisecondsSinceEpoch ~/ 1000,
      if (until != null) 'until': until!.millisecondsSinceEpoch ~/ 1000,
      if (limit != null) 'limit': limit,
    };
  }

  @override
  List<Object?> get props => [
        ids,
        authors,
        kinds,
        e,
        p,
        since,
        until,
        limit,
      ];
}
