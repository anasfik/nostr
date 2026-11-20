/// NIP-67 EOSE completeness hints.
///
/// A relay may append a third element to `EOSE`:
///
/// ```text
/// ["EOSE", <subscription_id>, [<hint>, ...]]
/// ```
///
/// Defined hints are `finish`, `more` and `auth`. Unknown values are ignored,
/// and relays that do not implement the NIP keep sending two-element `EOSE`
/// messages, so callers must fall back to the legacy `until` pagination
/// heuristic when neither `finish` nor `more` is present.
class NostrNip67 {
  /// Creates a NIP-67 helper set. All members are static.
  const NostrNip67();

  /// The relay sent every stored event matching the subscription's filters.
  static const String finish = 'finish';

  /// The relay holds more stored events than it has sent.
  static const String more = 'more';

  /// More stored events may be available after a NIP-42 `AUTH`.
  static const String auth = 'auth';

  /// Every hint value defined by NIP-67.
  static const Set<String> knownHints = {finish, more, auth};

  /// Extracts the known hint tokens from an already-decoded EOSE message.
  ///
  /// Tolerates a missing or non-list third element and drops unknown tokens,
  /// so this never throws on legacy or forward-compatible messages.
  static List<String> hintsOf(List<dynamic> decoded) {
    if (decoded.length < 3) {
      return const [];
    }

    final raw = decoded[2];

    if (raw is! List) {
      return const [];
    }

    return [
      for (final token in raw)
        if (token is String && knownHints.contains(token)) token,
    ];
  }

  /// Whether the relay reported that every stored event was sent.
  static bool isComplete(List<String> hints) => hints.contains(finish);

  /// Whether the relay reported more stored events than it sent.
  static bool needsPagination(List<String> hints) => hints.contains(more);

  /// Whether more stored events may require NIP-42 authentication.
  static bool needsAuth(List<String> hints) => hints.contains(auth);
}
