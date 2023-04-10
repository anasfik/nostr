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
    final signature = nostrKeyPairs.sign(message);
    NostrClientUtils.log(
      "signed message with private key, with it's value is: $signature",
    );

    return signature;
  }
}
