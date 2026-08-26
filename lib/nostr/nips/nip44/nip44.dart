import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dart_nostr/nostr/core/secp256k1.dart';
import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithIV;
import 'package:pointycastle/stream/chacha7539.dart';

/// {@template nip44}
/// NIP-44 v2 encrypted payloads for Nostr.
///
/// Implements the versioned encryption scheme: secp256k1 ECDH →
/// HKDF-extract conversation key → HKDF-expand message keys →
/// ChaCha20 encryption with HMAC-SHA256 authentication, wrapped in a
/// base64url (unpadded) payload with a `0x02` version byte.
///
/// Verified against the official vectors at
/// https://github.com/paulmillr/nip44/blob/main/nip44.vectors.json
/// {@endtemplate}
class Nip44 {
  Nip44._();

  static const int _version = 2;

  static const int minPlaintextSize = 1;
  static const int maxPlaintextSize = 0xffffffff;
  static const int extendedPrefixThreshold = 65536;

  /// Computes the long-term conversation key between two parties.
  /// `conversationKey(aPriv, bPub) == conversationKey(bPriv, aPub)`.
  ///
  /// Returns raw 32 bytes. Use [Nip44.hex] to hex-encode if needed.
  static Uint8List getConversationKey({
    required String privateKeyHex,
    required String publicKeyHex,
  }) {
    final sharedX = NostrSecp256k1.ecdhSharedX(
      privateKeyHex: privateKeyHex,
      publicKeyHex: publicKeyHex,
    );

    return hkdfExtract(
      ikm: Uint8List.fromList(sharedX),
      salt: utf8.encode('nip44-v2'),
    );
  }

  /// Derives the per-message `(chachaKey, chachaNonce, hmacKey)` from a
  /// conversation key and a 32-byte nonce.
  static (Uint8List, Uint8List, Uint8List) getMessageKeys(
    Uint8List conversationKey,
    Uint8List nonce,
  ) {
    if (conversationKey.length != 32) {
      throw ArgumentError('invalid conversation key length');
    }
    if (nonce.length != 32) {
      throw ArgumentError('nonce must be exactly 32 bytes');
    }

    final okm = hkdfExpand(prk: conversationKey, info: nonce, length: 76);

    return (
      Uint8List.sublistView(okm, 0, 32),
      Uint8List.sublistView(okm, 32, 44),
      Uint8List.sublistView(okm, 44, 76),
    );
  }

  /// Encrypts [plaintext] with a random nonce, returning the standard
  /// unpadded base64url payload string.
  static String encrypt({
    required String plaintext,
    required Uint8List conversationKey,
  }) {
    final random = Random.secure();
    final nonce = Uint8List(32)..forEach((_) {});
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = random.nextInt(256);
    }

    return encryptWithNonce(
      plaintext: plaintext,
      conversationKey: conversationKey,
      nonce: nonce,
    );
  }

  /// Encrypts [plaintext] using an explicit [nonce]. Useful for deterministic
  /// tests; production code should prefer [encrypt].
  static String encryptWithNonce({
    required String plaintext,
    required Uint8List conversationKey,
    required Uint8List nonce,
  }) {
    final plaintextBytes = utf8.encode(plaintext);

    final (chachaKey, chachaNonce, hmacKey) =
        getMessageKeys(conversationKey, nonce);

    final padded = pad(plaintextBytes);
    final ciphertext = chacha20(chachaKey, chachaNonce, padded);
    final mac = hmacSha256(hmacKey, [...nonce, ...ciphertext]);

    final payload = BytesBuilder()
      ..addByte(_version)
      ..add(nonce)
      ..add(ciphertext)
      ..add(mac);

    return base64Encode(payload.toBytes());
  }

  /// Decrypts a NIP-44 v2 payload produced by any conforming implementation.
  static String decrypt({
    required String payload,
    required Uint8List conversationKey,
  }) {
    final data = decodePayload(payload);

    final (chachaKey, chachaNonce, hmacKey) =
        getMessageKeys(conversationKey, data.nonce);

    final calculatedMac =
        hmacSha256(hmacKey, [...data.nonce, ...data.ciphertext]);

    if (!_constantTimeEquals(calculatedMac, data.mac)) {
      throw ArgumentError('invalid MAC');
    }

    final padded = chacha20(chachaKey, chachaNonce, data.ciphertext);

    return utf8.decode(unpad(padded), allowMalformed: false);
  }

  /// Convenience one-shot encrypt from raw key material (hex strings).
  static String encryptMessage({
    required String plaintext,
    required String senderPrivateKeyHex,
    required String recipientPublicKeyHex,
  }) {
    return encrypt(
      plaintext: plaintext,
      conversationKey: getConversationKey(
        privateKeyHex: senderPrivateKeyHex,
        publicKeyHex: recipientPublicKeyHex,
      ),
    );
  }

  /// Convenience one-shot decrypt from raw key material (hex strings).
  static String decryptMessage({
    required String payload,
    required String recipientPrivateKeyHex,
    required String senderPublicKeyHex,
  }) {
    return decrypt(
      payload: payload,
      conversationKey: getConversationKey(
        privateKeyHex: recipientPrivateKeyHex,
        publicKeyHex: senderPublicKeyHex,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payload framing
  // ---------------------------------------------------------------------------

  static ({Uint8List nonce, Uint8List ciphertext, Uint8List mac}) decodePayload(
      String payload) {
    if (payload.isEmpty || payload.startsWith('#')) {
      throw ArgumentError('unknown version');
    }

    if (payload.length < 132) {
      throw ArgumentError('invalid payload size');
    }

    final Uint8List data;

    try {
      // Accept both padded and unpadded base64 (some implementations strip
      // the trailing '=' characters).
      data = base64Decode(base64.normalize(payload));
    } on FormatException {
      throw ArgumentError('payload is not valid base64');
    }

    if (data.isEmpty) {
      throw ArgumentError('empty payload');
    }
    if (data[0] != _version) {
      throw ArgumentError('unknown version ${data[0]}');
    }
    if (data.length < 99 || data.length > maxPlaintextSize + 7 + 65) {
      throw ArgumentError('invalid payload size');
    }

    final nonce = Uint8List.sublistView(data, 1, 33);
    final ciphertext = Uint8List.sublistView(data, 33, data.length - 32);
    final mac = Uint8List.sublistView(data, data.length - 32, data.length);

    return (nonce: nonce, ciphertext: ciphertext, mac: mac);
  }

  /// Pads per spec: `[prefix][plaintext][zeros]` where the prefix is either
  /// a big-endian u16 (<65536) or `00 00` + big-endian u32 for extended
  /// lengths.
  static Uint8List pad(List<int> plaintextBytes) {
    final unpaddedLen = plaintextBytes.length;

    if (unpaddedLen < minPlaintextSize || unpaddedLen > maxPlaintextSize) {
      throw ArgumentError('invalid plaintext length');
    }

    final paddedLen = calcPaddedLen(unpaddedLen);
    final prefixLen = unpaddedLen >= extendedPrefixThreshold ? 6 : 2;
    final result = Uint8List(prefixLen + paddedLen);

    if (prefixLen == 6) {
      result[0] = 0;
      result[1] = 0;
      result[2] = (unpaddedLen >> 24) & 0xff;
      result[3] = (unpaddedLen >> 16) & 0xff;
      result[4] = (unpaddedLen >> 8) & 0xff;
      result[5] = unpaddedLen & 0xff;
    } else {
      result[0] = (unpaddedLen >> 8) & 0xff;
      result[1] = unpaddedLen & 0xff;
    }

    result.setAll(prefixLen, plaintextBytes);
    return result;
  }

  /// Reverses [pad], returning the original plaintext bytes.
  static List<int> unpad(Uint8List padded) {
    if (padded.length < 2) {
      throw ArgumentError('invalid padding');
    }

    final firstTwo = (padded[0] << 8) | padded[1];

    int unpaddedLen;
    int prefixLen;

    if (firstTwo == 0) {
      if (padded.length < 6) {
        throw ArgumentError('invalid padding');
      }
      unpaddedLen =
          (padded[2] << 24) | (padded[3] << 16) | (padded[4] << 8) | padded[5];
      if (unpaddedLen < extendedPrefixThreshold) {
        throw ArgumentError('invalid padding');
      }
      prefixLen = 6;
    } else {
      unpaddedLen = firstTwo;
      prefixLen = 2;
    }

    if (unpaddedLen <= 0 ||
        prefixLen + unpaddedLen > padded.length ||
        padded.length != prefixLen + calcPaddedLen(unpaddedLen)) {
      throw ArgumentError('invalid padding');
    }

    return padded.sublist(prefixLen, prefixLen + unpaddedLen);
  }

  /// Calculates the padded content length per the spec's power-of-two chunk
  /// scheme (minimum 32 bytes).
  static int calcPaddedLen(int unpaddedLen) {
    if (unpaddedLen < 1) {
      throw ArgumentError('length must be positive');
    }

    if (unpaddedLen <= 32) {
      return 32;
    }

    // next power of two >= unpadded_len: floor(log2(len-1)) + 1 exponent.
    final nextPower = 1 << ((log(unpaddedLen - 1) / ln2).floor() + 1);

    final int chunk;
    if (nextPower <= 256) {
      chunk = 32;
    } else {
      chunk = nextPower ~/ 8;
    }

    return chunk * (((unpaddedLen - 1) ~/ chunk) + 1);
  }

  // ---------------------------------------------------------------------------
  // Crypto primitives
  // ---------------------------------------------------------------------------

  static Uint8List chacha20(Uint8List key, Uint8List nonce, Uint8List data) {
    if (key.length != 32) {
      throw ArgumentError('chacha20 key must be 32 bytes');
    }
    if (nonce.length != 12) {
      throw ArgumentError('chacha20 nonce must be 12 bytes');
    }

    // NIP-44 uses the IETF ChaCha20 construction: 32-byte key, 12-byte
    // nonce, 32-bit block counter — pointycastle's ChaCha7539Engine.
    final cipher = ChaCha7539Engine()
      ..init(
        true,
        ParametersWithIV<KeyParameter>(KeyParameter(key), nonce),
      );

    final out = Uint8List(data.length);
    cipher.processBytes(data, 0, data.length, out, 0);
    return out;
  }

  static Uint8List hmacSha256(List<int> key, List<int> data) {
    final hmac = crypto.Hmac(crypto.sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  /// HKDF-Extract step (RFC 5869): PRK = HMAC-SHA256(salt, IKM).
  static Uint8List hkdfExtract({
    required List<int> ikm,
    required List<int> salt,
  }) {
    return hmacSha256(salt, ikm);
  }

  /// HKDF-Expand step (RFC 5869): OKM = T(1) | T(2) | ...
  static Uint8List hkdfExpand({
    required Uint8List prk,
    required List<int> info,
    required int length,
  }) {
    if (length > 255 * 32) {
      throw ArgumentError('HKDF output too long');
    }

    final result = BytesBuilder();
    var t = <int>[];
    var counter = 1;

    while (result.length < length) {
      t = hmacSha256(prk, [...t, ...info, counter]);
      result.add(t);
      counter++;
    }

    return Uint8List.sublistView(result.toBytes(), 0, length);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }

    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
