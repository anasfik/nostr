import 'package:dart_nostr/nostr/core/key_pairs.dart';

import '../../core/utils.dart';
import 'base/keys.dart';

/// {@template nostr_keys}
/// This class is responsible for generating key pairs and deriving public keys from private keys..
/// {@endtemplate}
class NostrKeys implements NostrKeysBase {
  @override
  String derivePublicKey({required String privateKey}) {
    final nostrKeyPairs = NostrKeyPairs(private: privateKey);
    NostrClientUtils.log(
      "derived public key from private key, with it's value is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs.public;
  }

  /// You can use this method to generate a key pair for your end users.
  @override
  NostrKeyPairs generateKeyPair() {
    final nostrKeyPairs = NostrKeyPairs.generate();
    NostrClientUtils.log(
      "generated key pairs, with it's public key is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs;
  }

  @override
  NostrKeyPairs generateKeyPairFromExistingPrivateKey(
    String privateKey,
  ) {
    return NostrKeyPairs(private: privateKey);
  }

  /// You can use this method to generate a key pair for your end users.
  /// it returns the private key of the generated key pair.
  @override
  String generatePrivateKey() {
    return generateKeyPair().private;
  }

  /// You can use this method to sign a [message] with a [privateKey].
  @override
  String sign({
    required String privateKey,
    required String message,
  }) {
    final nostrKeyPairs = NostrKeyPairs(private: privateKey);
    final hexEncodedMessage = NostrClientUtils.hexEncode(message);
    final signature = nostrKeyPairs.sign(hexEncodedMessage);
    NostrClientUtils.log(
      "signed message with private key, with it's value is: $signature",
    );

    return signature;
  }

  /// You can use this method to verify a [message] with a [publicKey] and it's [signature].
  /// it returns a [bool] that indicates if the [message] is verified or not.
  bool verify({
    required String publicKey,
    required String message,
    required String signature,
  }) {
    final hexEncodedMessage = NostrClientUtils.hexEncode(message);
    final isVerified =
        NostrKeyPairs.verify(publicKey, hexEncodedMessage, signature);
    NostrClientUtils.log(
      "verified message with public key: $publicKey, with it's value is: $isVerified",
    );

    return isVerified;
  }

  bool isValidPrivateKey(String key) {
    return NostrKeyPairs.isValidPrivateKey(key);
  }
}
