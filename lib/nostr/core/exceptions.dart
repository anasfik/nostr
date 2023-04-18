class RelayNotFoundException implements Exception {
  final String relayUrl;

  RelayNotFoundException(this.relayUrl);

  @override
  String toString() {
    return 'RelayNotFoundException: Relay with url "$relayUrl" was not found.';
  }
}
