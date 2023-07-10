import 'package:bip340/bip340.dart' as bip340;
import 'package:equatable/equatable.dart';

import '../dart_nostr.dart';

/// {@template nostr_key_pairs}
/// This class is responsible for generating, handling and signing keys.
/// It is used by the [NostrClient] to sign messages.
/// {@endtemplate}
class NostrKeyPairs extends Equatable {
  /// A caching system for the key pairs, so we don't have to generate them again.
  /// A cache key is the private key, and the value is the [NostrKeyPairs] instance.
  static final _keyPairsCache = <String, NostrKeyPairs>{};

  /// This is the private generate Key, hex-encoded (64 chars)
  final String private;

  /// This is the public generate Key, hex-encoded (64 chars)
  late final String public;

  /// {@macro nostr_key_pairs}
  NostrKeyPairs._({required this.private}) {
    assert(
      private.length == 64,
      "Private key should be 64 chars length (32 bytes hex encoded)",
    );

    public = bip340.getPublicKey(private);
  }

  /// {@macro nostr_key_pairs}
  factory NostrKeyPairs({
    required String private,
  }) {
    final possibleKeyPair = _keyPairsCache[private];

    if (possibleKeyPair != null) {
      return possibleKeyPair;
    } else {
      final keyPair = NostrKeyPairs._(private: private);

      _keyPairsCache[private] = keyPair;

      return keyPair;
    }
  }

  /// {@macro nostr_key_pairs}
  /// Instantiate a [NostrKeyPairs] from random bytes.
  factory NostrKeyPairs.generate() {
    return NostrKeyPairs(
      private: Nostr.instance.utilsService.random64HexChars(),
    );
  }

  /// This will sign a [message] with the [private] key and return the signature.
  String sign(String message) {
    String aux = Nostr.instance.utilsService.random64HexChars();
    return bip340.sign(private, message, aux);
  }

  /// This will verify a [signature] for a [message] with the [public] key.
  static bool verify(
    String? pubkey,
    String message,
    String signature,
  ) {
    return bip340.verify(pubkey, message, signature);
  }

  static bool isValidPrivateKey(String privateKey) {
    try {
      NostrKeyPairs(private: privateKey);

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  List<Object?> get props => [private, public];
}
