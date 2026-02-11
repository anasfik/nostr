import 'package:dart_nostr/nostr/model/request/filter.dart';

/// {@template nostr_filter_builder}
/// Builder for creating NostrFilter instances with a fluent API.
/// {@endtemplate}
class NostrFilterBuilder {
  /// Kinds of events to filter.
  final Set<int> _kinds = {};

  /// Author public keys to filter.
  final Set<String> _authors = {};

  /// Referenced event IDs to filter.
  final Set<String> _e = {};

  /// Referenced pubkeys to filter.
  final Set<String> _p = {};

  /// Since timestamp for filtering.
  DateTime? _since;

  /// Until timestamp for filtering.
  DateTime? _until;

  /// Limit for number of events.
  int? _limit;

  /// Additional tags to filter.
  final Map<String, Set<String>> _tags = {};

  /// {@macro nostr_filter_builder}
  NostrFilterBuilder();

  /// Add kinds to the filter.
  NostrFilterBuilder withKinds(List<int> kinds) {
    _kinds.addAll(kinds);
    return this;
  }

  /// Add a single kind to the filter.
  NostrFilterBuilder withKind(int kind) {
    _kinds.add(kind);
    return this;
  }

  /// Add authors to the filter.
  NostrFilterBuilder withAuthors(List<String> authors) {
    _authors.addAll(authors);
    return this;
  }

  /// Add a single author to the filter.
  NostrFilterBuilder withAuthor(String author) {
    _authors.add(author);
    return this;
  }

  /// Add referenced event IDs to the filter.
  NostrFilterBuilder withEventIds(List<String> eventIds) {
    _e.addAll(eventIds);
    return this;
  }

  /// Add a single referenced event ID to the filter.
  NostrFilterBuilder withEventId(String eventId) {
    _e.add(eventId);
    return this;
  }

  /// Add referenced pubkeys to the filter.
  NostrFilterBuilder withPubkeys(List<String> pubkeys) {
    _p.addAll(pubkeys);
    return this;
  }

  /// Add a single referenced pubkey to the filter.
  NostrFilterBuilder withPubkey(String pubkey) {
    _p.add(pubkey);
    return this;
  }

  /// Set the since timestamp.
  NostrFilterBuilder since(DateTime since) {
    _since = since;
    return this;
  }

  /// Set the until timestamp.
  NostrFilterBuilder until(DateTime until) {
    _until = until;
    return this;
  }

  /// Set the limit.
  NostrFilterBuilder withLimit(int limit) {
    _limit = limit;
    return this;
  }

  /// Add a custom tag filter.
  NostrFilterBuilder withTag(String tagName, List<String> values) {
    _tags.putIfAbsent(tagName, () => {}).addAll(values);
    return this;
  }

  /// Add a single custom tag filter.
  NostrFilterBuilder addTag(String tagName, String value) {
    _tags.putIfAbsent(tagName, () => {}).add(value);
    return this;
  }

  /// Build the NostrFilter.
  NostrFilter build() {
    return NostrFilter(
      kinds: _kinds.isEmpty ? null : _kinds.toList(),
      authors: _authors.isEmpty ? null : _authors.toList(),
      e: _e.isEmpty ? null : _e.toList(),
      p: _p.isEmpty ? null : _p.toList(),
      since: _since,
      until: _until,
      limit: _limit,
    );
  }

  /// Reset the builder to default state.
  NostrFilterBuilder reset() {
    _kinds.clear();
    _authors.clear();
    _e.clear();
    _p.clear();
    _since = null;
    _until = null;
    _limit = null;
    _tags.clear();
    return this;
  }
}
