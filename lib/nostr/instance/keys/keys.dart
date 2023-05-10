import 'package:bech32/bech32.dart';
import 'package:dart_nostr/nostr/core/constants.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:hex/hex.dart';

import '../../core/utils.dart';
import '../../dart_nostr.dart';
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

  /// Encodes a Nostr [publicKey] to an npub key (bech32 encoding).
  ///
  /// ```dart
  /// final npubString = Nostr.instance.keysService.encodePublicKeyToNpub(yourPublicKey);
  /// print(npubString); // ...
  /// ```
  @override
  String encodePublicKeyToNpub(String publicKey) {
    return encodeBech32(publicKey, NostrConstants.npub);
  }

  /// Encodes a Nostr [privateKey] to an nsec key (bech32 encoding).
  /// ```dart
  /// final nsecString = Nostr.instance.keysService.encodePrivateKeyToNsec(yourPrivateKey);
  /// print(nsecString); // ...
  ///
  @override
  String encodePrivateKeyToNsec(String privateKey) {
    return encodeBech32(privateKey, NostrConstants.nsec);
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

    final List<String> decodedKeyComponents = decodeBech32(npubKey);
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
    final List<String> decodedKeyComponents = decodeBech32(nsecKey);
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

  /// Encodes a [hex] string into a bech32 string with a [hrp] human readable part.
  ///
  /// ```dart
  /// final npubString = Nostr.instance.keysService.encodeBech32(yourHexString, 'npub');
  /// print(npubString); // ...
  /// ```
  String encodeBech32(String hex, String hrp) {
    final bytes = HEX.decode(hex);
    final fiveBitWords = _convertBits(bytes, 8, 5, true);
    return bech32.encode(Bech32(hrp, fiveBitWords), hex.length + hrp.length);
  }

  /// Decodes a bech32 string into a [hex] string and a [hrp] human readable part.
  ///
  /// ```dart
  /// final decodedHexString = Nostr.instance.keysService.decodeBech32(npubString);
  /// print(decodedHexString); // ...
  /// ```
  List<String> decodeBech32(String bech32String) {
    final Bech32Codec codec = const Bech32Codec();
    final Bech32 bech32 = codec.decode(bech32String, bech32String.length);
    final eightBitWords = _convertBits(bech32.data, 5, 8, false);
    return [HEX.encode(eightBitWords), bech32.hrp];
  }

  /// Convert bits from one base to another
  /// [data] - the data to convert
  /// [fromBits] - the number of bits per input value
  /// [toBits] - the number of bits per output value
  /// [pad] - whether to pad the output if there are not enough bits
  /// If pad is true, and there are remaining bits after the conversion, then the remaining bits are left-shifted and added to the result
  /// [return] - the converted data
  List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    int acc = 0;
    int bits = 0;
    List<int> result = [];

    for (int value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;

      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & ((1 << toBits) - 1));
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & ((1 << toBits) - 1));
      }
    } else if (bits >= fromBits || (acc & ((1 << bits) - 1)) != 0) {
      throw Exception('Invalid padding');
    }

    return result;
  }
}
