class NostrDebugOptions {
  NostrDebugOptions({
    required this.tag,
    this.isLogsEnabled = true,
  });

  factory NostrDebugOptions.general() {
    return NostrDebugOptions(
      tag: 'Nostr',
    );
  }
  factory NostrDebugOptions.generate() {
    return NostrDebugOptions(
      tag: _incrementallyGenerateTag(),
    );
  }

  static var _incrementalNumber = 0;

  bool isLogsEnabled = true;

  final String tag;

  static String _incrementallyGenerateTag() {
    _incrementalNumber++;

    return '$_incrementalNumber - Nostr';
  }

  NostrDebugOptions copyWith({
    bool? isLogsEnabled,
  }) {
    return NostrDebugOptions(
      tag: tag,
      isLogsEnabled: isLogsEnabled ?? this.isLogsEnabled,
    );
  }
}
