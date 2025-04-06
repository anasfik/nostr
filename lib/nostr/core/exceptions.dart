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

/// {@template nip05_verification_exception}
/// Thrown when there is an error verifying a nip05 identifier.
/// {@endtemplate}
class Nip05VerificationException implements Exception {
  /// {@macro nip05_verification_exception}
  const Nip05VerificationException({
    this.parent,
  });

  /// Cause of the exception
  final Exception? parent;

  @override
  String toString() {
    return 'Something went wrong while verifying nip05 identifier. '
        'Underlying issue was: $parent';
  }
}
