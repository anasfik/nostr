/// {@template relay_not_found_exception}
///  Thrown when a relay is not found/registered.
/// {@endtemplate}
class RelayNotFoundException implements Exception {

  /// {@macro relay_not_found_exception}
  RelayNotFoundException(this.relayUrl);
  /// The url of the relay that was not found.
  final String relayUrl;

  @override
  String toString() {
    return 'RelayNotFoundException: Relay with url "$relayUrl" was not found.';
  }
}
