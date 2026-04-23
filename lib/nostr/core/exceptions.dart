/// Base typed exception for domain-level Nostr failures.
class NostrCoreException implements Exception {
  const NostrCoreException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'NostrCoreException(message: $message, cause: $cause)';
}

/// {@template relay_not_found_exception}
///  Thrown when a relay is not found/registered.
/// {@endtemplate}
class RelayNotFoundException extends NostrCoreException {
  /// {@macro relay_not_found_exception}
  RelayNotFoundException(this.relayUrl)
      : super('Relay with url "$relayUrl" was not found.');

  /// The url of the relay that was not found.
  final String relayUrl;
}

/// {@template nip05_verification_exception}
/// Thrown when there is an error verifying a nip05 identifier.
/// {@endtemplate}
class Nip05VerificationException extends NostrCoreException {
  /// {@macro nip05_verification_exception}
  const Nip05VerificationException({
    this.parent,
  }) : super(
          'Something went wrong while verifying nip05 identifier.',
          cause: parent,
        );

  /// Cause of the exception
  final Exception? parent;

  @override
  String toString() => '$message Underlying issue was: $parent';
}
