/// {@template relay_not_found_exception}
///  Thrown when a relay is not found/registered.
/// {@endtemplate}
class RelayNotFoundException implements Exception {
  /// The url of the relay that was not found.
  final String relayUrl;

  /// {@macro relay_not_found_exception}
  RelayNotFoundException(this.relayUrl);

  @override
  String toString() {
    return 'RelayNotFoundException: Relay with url "$relayUrl" was not found.';
  }
}
