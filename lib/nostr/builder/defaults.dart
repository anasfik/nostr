/// {@template nostr_defaults}
/// Default configuration and constants for Nostr.
/// {@endtemplate}
class NostrDefaults {
  /// Default relay URLs to use when none are specified.
  /// These are well-known, stable Nostr relays.
  static const List<String> defaultRelays = [
    'wss://relay.damus.io',
    'wss://relay.nostr.band',
    'wss://nos.lol',
  ];

  /// Default connection timeout in seconds.
  static const int defaultConnectTimeoutSeconds = 30;

  /// Default read timeout in seconds.
  static const int defaultReadTimeoutSeconds = 60;

  /// Default event limit per subscription.
  static const int defaultEventLimit = 100;

  /// Default retry policy for network operations.
  static const String defaultRetryPolicy = 'exponential';

  /// Default logging level.
  static const String defaultLogLevel = 'info';
}
