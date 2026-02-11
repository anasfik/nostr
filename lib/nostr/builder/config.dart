/// {@template debug_level}
/// Logging severity levels for configuration.
/// {@endtemplate}
enum DebugLevel {
  /// Silent - no logs.
  silent,

  /// Error level only.
  error,

  /// Warning level and above.
  warning,

  /// Info level and above.
  info,

  /// Debug level and above.
  debug,

  /// Verbose - all logs.
  verbose,
}
