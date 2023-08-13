import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';

import '../../core/utils.dart';
import '../../dart_nostr.dart';
import 'base/keys.dart';
import 'package:bip32_bip44/dart_bip32_bip44.dart' as bip32_bip44;
import 'package:bip39/bip39.dart' as bip39;

/// {@template nostr_keys}
/// This class is responsible for generating key pairs and deriving public keys from private keys..
/// {@endtemplate}
class NostrKeys implements NostrKeysBase {
  /// Derives a public key from a [privateKey] directly, use this if you want a quick way to get a public key from a private key.
  ///
  ///
  /// ```dart
  /// final publicKey = Nostr.instance.keysService.derivePublicKey(privateKey: yourPrivateKey);
  /// print(publicKey); // ...
  /// ```
  @override
  String derivePublicKey({required String privateKey}) {
    final nostrKeyPairs = NostrKeyPairs(private: privateKey);
    NostrClientUtils.log(
      "derived public key from private key, with it's value is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs.public;
  }

  /// You can use this method to generate a key pair for your end users.
  ///
  ///
  /// ```dart
  /// final keyPair = Nostr.instance.keysService.generateKeyPair();
  /// print(keyPair.public); // ...
  /// print(keyPair.private); // ...
  /// ```
  @override
  NostrKeyPairs generateKeyPair() {
    final nostrKeyPairs = NostrKeyPairs.generate();

    NostrClientUtils.log(
      "generated key pairs, with it's public key is: ${nostrKeyPairs.public}",
    );

    return nostrKeyPairs;
  }

  /// Generates a key pair from an existing [privateKey], use this if you want to generate a key pair from an existing private key.
  ///
  /// ```dart
  /// final keyPair = Nostr.instance.keysService.generateKeyPairFromExistingPrivateKey(yourPrivateKey);
  /// print(keyPair.public); // ...
  /// print(keyPair.private); // ...
  /// ```
  @override
  NostrKeyPairs generateKeyPairFromExistingPrivateKey(
    String privateKey,
  ) {
    return NostrKeyPairs(private: privateKey);
  }

  /// You can use this method to generate a key pair for your end users.
  /// it returns the private key of the generated key pair.
  ///
  /// ```dart
  /// final privateKey = Nostr.instance.keysService.generatePrivateKey();
  /// print(privateKey); // ...
  /// ```
  @override
  String generatePrivateKey() {
    return generateKeyPair().private;
  }

  /// Encodes a Nostr [publicKey] to an npub key (bech32 encoding).
  ///
  /// ```dart
  /// final npubString = Nostr.instance.keysService.encodePublicKeyToNpub(yourPublicKey);
  /// print(npubString); // ...
  /// ```
  @override
  String encodePublicKeyToNpub(String publicKey) {
    return Nostr.instance.utilsService
        .encodeBech32(publicKey, NostrConstants.npub);
  }

  /// Encodes a Nostr [privateKey] to an nsec key (bech32 encoding).
  /// ```dart
  /// final nsecString = Nostr.instance.keysService.encodePrivateKeyToNsec(yourPrivateKey);
  /// print(nsecString); // ...
  ///
  @override
  String encodePrivateKeyToNsec(String privateKey) {
    return Nostr.instance.utilsService
        .encodeBech32(privateKey, NostrConstants.nsec);
  }

  /// Decodes a Nostr [npubKey] to a public key.
  ///
  /// ```dart
  /// final publicKey = Nostr.instance.keysService.decodeNpubKeyToPublicKey(yourNpubKey);
  /// print(publicKey); // ...
  /// ```
  @override
  String decodeNpubKeyToPublicKey(String npubKey) {
    assert(npubKey.startsWith(NostrConstants.npub));

    final List<String> decodedKeyComponents =
        Nostr.instance.utilsService.decodeBech32(npubKey);
    return decodedKeyComponents.first;
  }

  /// Decodes a Nostr [nsecKey] to a private key.
  ///
  /// ```dart
  /// final privateKey = Nostr.instance.keysService.decodeNsecKeyToPrivateKey(yourNsecKey);
  /// print(privateKey); // ...
  /// ```
  @override
  String decodeNsecKeyToPrivateKey(String nsecKey) {
    assert(nsecKey.startsWith(NostrConstants.nsec));
    final List<String> decodedKeyComponents =
        Nostr.instance.utilsService.decodeBech32(nsecKey);
    return decodedKeyComponents.first;
  }

  /// You can use this method to sign a [message] with a [privateKey].
  ///
  /// ```dart
  /// final signature = Nostr.instance.keysService.sign(
  ///  privateKey: yourPrivateKey,
  /// message: yourMessage,
  /// );
  ///
  /// print(signature); // ...
  /// ```
  @override
  String sign({
    required String privateKey,
    required String message,
  }) {
    final nostrKeyPairs = NostrKeyPairs(private: privateKey);
    final hexEncodedMessage =
        Nostr.instance.utilsService.hexEncodeString(message);
    final signature = nostrKeyPairs.sign(hexEncodedMessage);
    NostrClientUtils.log(
      "signed message with private key, with it's value is: $signature",
    );

    return signature;
  }

  /// You can use this method to verify a [message] with a [publicKey] and it's [signature].
  /// it returns a [bool] that indicates if the [message] is verified or not.
  ///
  /// ```dart
  /// final isVerified = Nostr.instance.keysService.verify(
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
        Nostr.instance.utilsService.hexEncodeString(message);
    final isVerified =
        NostrKeyPairs.verify(publicKey, hexEncodedMessage, signature);
    NostrClientUtils.log(
      "verified message with public key: $publicKey, with it's value is: $isVerified",
    );

    return isVerified;
  }

  /// Weither the [key] is a valid Nostr private key or not.
  ///
  /// ```dart
  /// Nostr.instance.keysService.isValidPrivateKey('something that is not a key'); // false
  /// ```
  @override
  bool isValidPrivateKey(String key) {
    return NostrKeyPairs.isValidPrivateKey(key);
  }

  /// Wether the given [text] is a valid mnemonic or not.
  ///
  /// ```dart
  ///  final isValid = Nostr.instance.keysService.isMnemonicValid('your mnemonic');
  ///  print(isValid); // ...
  /// ```
  static bool isMnemonicValid(String text) {
    return bip39.validateMnemonic(text);
  }

  static String getPrivateKeyFromMnemonic(String mnemonic) {
    String seed = bip39.mnemonicToSeedHex(mnemonic);
    bip32_bip44.Chain chain = bip32_bip44.Chain.seed(seed);

    bip32_bip44.ExtendedPrivateKey key =
        chain.forPath("m/44'/1237'/0'/0") as bip32_bip44.ExtendedPrivateKey;

    bip32_bip44.ExtendedPrivateKey? childKey =
        bip32_bip44.deriveExtendedPrivateChildKey(key, 0);

    String hexChildKey = "";

    if (childKey.key != null) {
      hexChildKey = childKey.key!.toRadixString(16);
    }

    return hexChildKey;
  }
}
