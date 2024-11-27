import 'package:bip32_bip44/dart_bip32_bip44.dart' as bip32_bip44;
import 'package:bip39/bip39.dart' as bip39;
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/dart_nostr.dart';

/// {@template nostr_keys}
/// This class is responsible for generating key pairs and deriving public keys from private keys..
/// {@endtemplate}
class NostrKeys {
  NostrKeys({
    required this.logger,
  });

  /// {@macro nostr_client_utils}
  final NostrLogger logger;

  /// A caching system for the key pairs, so we don't have to generate them again.
  /// A cache key is the private key, and the value is the [NostrKeyPairs] instance.
  static final _keyPairsCache = <String, NostrKeyPairs>{};

  /// Derives a public key from a [privateKey] directly, use this if you want a quick way to get a public key from a private key.
  ///
  ///
  /// ```dart
  /// final publicKey = Nostr.instance.services.keys.derivePublicKey(privateKey: yourPrivateKey);
  /// print(publicKey); // ...
  /// ```

  String derivePublicKey({required String privateKey}) {
    final nostrKeyPairs = _keyPairFrom(privateKey);

    logger.log(
      "derived public key from private key, with it's value is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs.public;
  }

  /// You can use this method to generate a key pair for your end users.
  ///
  ///
  /// ```dart
  /// final keyPair = Nostr.instance.services.keys.generateKeyPair();
  /// print(keyPair.public); // ...
  /// print(keyPair.private); // ...
  /// ```

  NostrKeyPairs generateKeyPair() {
    final nostrKeyPairs = _generateKeyPair();

    logger.log(
      "generated key pairs, with it's public key is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs;
  }

  /// Generates a key pair from an existing [privateKey], use this if you want to generate a key pair from an existing private key.
  ///
  /// ```dart
  /// final keyPair = Nostr.instance.services.keys.generateKeyPairFromExistingPrivateKey(yourPrivateKey);
  /// print(keyPair.public); // ...
  /// print(keyPair.private); // ...
  /// ```

  NostrKeyPairs generateKeyPairFromExistingPrivateKey(
    String privateKey,
  ) {
    return _keyPairFrom(privateKey);
  }

  /// You can use this method to generate a key pair for your end users.
  /// it returns the private key of the generated key pair.
  ///
  /// ```dart
  /// final privateKey = Nostr.instance.services.keys.generatePrivateKey();
  /// print(privateKey); // ...
  /// ```

  String generatePrivateKey() {
    return _generateKeyPair().private;
  }

  /// You can use this method to sign a [message] with a [privateKey].
  ///
  /// ```dart
  /// final signature = Nostr.instance.services.keys.sign(
  ///  privateKey: yourPrivateKey,
  /// message: yourMessage,
  /// );
  ///
  /// print(signature); // ...
  /// ```

  String sign({
    required String privateKey,
    required String message,
  }) {
    final nostrKeyPairs = _keyPairFrom(privateKey);

    final hexEncodedMessage =
        Nostr.instance.services.utils.hexEncodeString(message);

    final signature = nostrKeyPairs.sign(hexEncodedMessage);

    logger.log(
      "signed message with private key, with it's value is: $signature",
    );

    return signature;
  }

  /// You can use this method to verify a [message] with a [publicKey] and it's [signature].
  /// it returns a [bool] that indicates if the [message] is verified or not.
  ///
  /// ```dart
  /// final isVerified = Nostr.instance.services.keys.verify(
  /// publicKey: yourPublicKey,
  /// message: yourMessage,
  /// signature: yourSignature,
  /// );
  ///
  /// print(isVerified); // ...
  /// ```
  bool verify({
    required String publicKey,
    required String message,
    required String signature,
  }) {
    final hexEncodedMessage =
        Nostr.instance.services.utils.hexEncodeString(message);
    final isVerified =
        NostrKeyPairs.verify(publicKey, hexEncodedMessage, signature);

    logger.log(
      "verified message with public key: $publicKey, with it's value is: $isVerified",
    );

    return isVerified;
  }

  /// Weither the [key] is a valid Nostr private key or not.
  ///
  /// ```dart
  /// Nostr.instance.services.keys.isValidPrivateKey('something that is not a key'); // false
  /// ```

  bool isValidPrivateKey(String key) {
    return NostrKeyPairs.isValidPrivateKey(key);
  }

  /// Wether the given [text] is a valid mnemonic or not.
  ///
  /// ```dart
  ///  final isValid = Nostr.instance.services.keys.isMnemonicValid('your mnemonic');
  ///  print(isValid); // ...
  /// ```
  static bool isMnemonicValid(String text) {
    return bip39.validateMnemonic(text);
  }

  /// Derives a private key from a [mnemonic] directly, use this if you want a quick way to get a private key from a mnemonic.
  ///
  /// ```dart
  /// final privateKey = Nostr.instance.services.keys.getPrivateKeyFromMnemonic('your mnemonic');
  /// print(privateKey); // ...
  /// ```
  static String getPrivateKeyFromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeedHex(mnemonic);
    final chain = bip32_bip44.Chain.seed(seed);

    final key =
        chain.forPath("m/44'/1237'/0'/0") as bip32_bip44.ExtendedPrivateKey;

    final childKey = bip32_bip44.deriveExtendedPrivateChildKey(key, 0);

    var hexChildKey = '';

    if (childKey.key != null) {
      hexChildKey = childKey.key!.toRadixString(16);
    }

    return hexChildKey;
  }

  /// Clears all the cached key pairs.
  Future<bool> freeAllResources() async {
    _keyPairsCache.clear();

    return true;
  }

  /// Creates a [NostrKeyPairs] from a [privateKey] if it's not already cached, and returns it.
  /// if it's already cached, it returns the cached [NostrKeyPairs] instance and saves the regeneration time and resources.
  NostrKeyPairs _keyPairFrom(String privateKey) {
    if (_keyPairsCache[privateKey] != null) {
      return _keyPairsCache[privateKey]!;
    } else {
      _keyPairsCache[privateKey] = NostrKeyPairs(private: privateKey);

      return _keyPairsCache[privateKey]!;
    }
  }

  /// Generates a [NostrKeyPairs] and caches it, and returns it.
  NostrKeyPairs _generateKeyPair() {
    final keyPair = NostrKeyPairs.generate();
    _keyPairsCache[keyPair.private] = keyPair;

    return keyPair;
  }
}
