import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart' as pc;
// ignore: unused_import
import 'package:pointycastle/key_derivators/api.dart' as kdf_api;

/// {@template nip49}
/// NIP-49 private key encryption (`ncryptsec`).
///
/// Pipeline per spec: scrypt(password) → XChaCha20-Poly1305(key,
/// 24-byte nonce, associated data = key-security byte) → bech32.
/// Payload layout (91 bytes): `version(1) || log_n(1) || salt(16) ||
/// nonce(24) || key_security_byte(1) || ciphertext(48)` where the
/// ciphertext embeds the 16-byte Poly1305 tag.
///
/// Verified against the spec's published decryption test vector.
/// {@endtemplate}
class NostrNip49 {
  NostrNip49._();

  static const int _currentVersion = 0x02;
  static const String _hrp = 'ncryptsec';
  static const int _payloadLength = 91;

  /// Decrypts an `ncryptsec` string into the raw 64-char hex private key.
  ///
  /// [expectedLogNFold] is optional; when provided it must match the stored
  /// value (the spec's test flow uses this to pin the KDF cost).
  static String decryptKey({
    required String ncryptsec,
    required String password,
    int? expectedLogNFold,
  }) {
    final payload = _bech32Decode(ncryptsec);

    if (payload.length != _payloadLength) {
      throw ArgumentError(
        'invalid ncryptsec payload length ${payload.length}',
      );
    }

    var offset = 0;
    final version = payload[offset++];
    if (version != _currentVersion) {
      throw ArgumentError('unsupported ncryptsec version $version');
    }

    final logNFold = payload[offset++];

    if (expectedLogNFold != null && logNFold != expectedLogNFold) {
      throw ArgumentError(
        'log_n mismatch: payload says $logNFold',
      );
    }

    final salt = Uint8List.fromList(payload.sublist(offset, offset + 16));
    offset += 16;
    final nonce = Uint8List.fromList(payload.sublist(offset, offset + 24));
    offset += 24;
    final keySecurityByte = payload[offset++];
    final ciphertext = payload.sublist(offset);

    final symmetricKey = _scryptKey(utf8.encode(password), salt, logNFold);

    final plaintext = _xchacha20Poly1305Decrypt(
      symmetricKey,
      nonce,
      Uint8List.fromList([keySecurityByte]),
      Uint8List.fromList(ciphertext),
    );

    if (plaintext.length != 32) {
      throw ArgumentError('decrypted key has invalid length');
    }

    return hex.encode(plaintext);
  }

  /// Encrypts a 64-char hex [privateKeyHex] under [password], returning an
  /// `ncryptsec` string.
  ///
  /// [logNFold] defaults to 18 (262144 scrypt rounds). [keyWasHandledInsecurely]
  /// sets the NIP-49 key-security byte.
  static String encryptKey({
    required String privateKeyHex,
    required String password,
    int logNFold = 18,
    bool keyWasHandledInsecurely = false,
  }) {
    final normalizedKey = privateKeyHex.trim().toLowerCase();

    if (normalizedKey.length != 64 ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(normalizedKey)) {
      throw ArgumentError('private key must be 32 bytes hex encoded');
    }

    final privateKey = hex.decode(normalizedKey);
    if (logNFold < 1 || logNFold > 255) {
      throw ArgumentError.value(logNFold, 'logNFold', 'must fit in one byte');
    }

    final random = Random.secure();
    Uint8List randomBytes(int n) =>
        Uint8List.fromList(List.generate(n, (_) => random.nextInt(256)));

    final salt = randomBytes(16);
    final nonce = randomBytes(24);
    final keySecurityByte = keyWasHandledInsecurely ? 0x00 : 0x01;

    final symmetricKey = _scryptKey(utf8.encode(password), salt, logNFold);

    final ciphertext = _xchacha20Poly1305Encrypt(
      symmetricKey,
      nonce,
      Uint8List.fromList([keySecurityByte]),
      Uint8List.fromList(privateKey),
    );

    return _bech32Encode([
      _currentVersion,
      logNFold,
      ...salt,
      ...nonce,
      keySecurityByte,
      ...ciphertext,
    ]);
  }

  // ---------------------------------------------------------------------------
  // Primitives
  // ---------------------------------------------------------------------------

  static Uint8List _scryptKey(
      List<int> password, List<int> salt, int logNFold) {
    final derivator = pc.Scrypt()
      ..init(
        kdf_api.ScryptParameters(
          1 << logNFold,
          8,
          1,
          32,
          Uint8List.fromList(salt),
        ),
      );

    return derivator.process(Uint8List.fromList(password));
  }

  /// HChaCha20: derives a 32-byte subkey from a 32-byte key and the first
  /// 16 bytes of an XChaCha20 nonce (no output mixing of constants).
  static Uint8List _hchacha20(Uint8List key, Uint8List nonce16) {
    // "expand 32-byte k"
    const state0 = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574];

    Uint8List le32(List<int> b, int off) {
      final out = Uint8List(4);
      for (var i = 0; i < 4; i++) {
        out[i] = b[off + i];
      }
      return out;
    }

    int loadLE(Uint8List b) => b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24);

    final state = <int>[
      ...state0,
      for (var i = 0; i < 8; i++) loadLE(le32(key, i * 4)),
      for (var i = 0; i < 4; i++) loadLE(le32(nonce16, i * 4)),
    ];

    void quarterRound(List<int> x, int a, int b, int c, int d) {
      x[a] = (x[a] + x[b]) & 0xffffffff;
      x[d] = _rotl(x[d] ^ x[a], 16);
      x[c] = (x[c] + x[d]) & 0xffffffff;
      x[b] = _rotl(x[b] ^ x[c], 12);
      x[a] = (x[a] + x[b]) & 0xffffffff;
      x[d] = _rotl(x[d] ^ x[a], 8);
      x[c] = (x[c] + x[d]) & 0xffffffff;
      x[b] = _rotl(x[b] ^ x[c], 7);
    }

    final x = [...state];
    for (var round = 0; round < 20; round += 2) {
      quarterRound(x, 0, 4, 8, 12);
      quarterRound(x, 1, 5, 9, 13);
      quarterRound(x, 2, 6, 10, 14);
      quarterRound(x, 3, 7, 11, 15);
      quarterRound(x, 0, 5, 10, 15);
      quarterRound(x, 1, 6, 11, 12);
      quarterRound(x, 2, 7, 8, 13);
      quarterRound(x, 3, 4, 9, 14);
    }

    // Per draft-irtf-cfrg-xchacha §2.2.1, HChaCha20 emits words 0..3 and
    // 12..15 of the FINAL state directly — no feed-forward addition of the
    // initial state (that step belongs to the ChaCha block function only).
    final out = BytesBuilder();
    for (final i in [0, 1, 2, 3]) {
      out.add(_u32le(x[i]));
    }
    for (final i in [12, 13, 14, 15]) {
      out.add(_u32le(x[i]));
    }

    return out.toBytes();
  }

  static int _rotl(int v, int c) =>
      ((v << c) & 0xffffffff) | ((v & 0xffffffff) >> (32 - c));

  static Uint8List _u32le(int v) => Uint8List.fromList([
        v & 0xff,
        (v >> 8) & 0xff,
        (v >> 16) & 0xff,
        (v >> 24) & 0xff,
      ]);

  /// XChaCha20-Poly1305 AEAD encrypt (draft-irtf-cfrg-xchacha): HChaCha20
  /// subkey from nonce[0..16], then IETF ChaCha20-Poly1305 with nonce
  /// `00000000 || nonce[16..24]`.
  static Uint8List _xchacha20Poly1305Encrypt(
    Uint8List key,
    Uint8List nonce24,
    Uint8List aad,
    Uint8List plaintext,
  ) {
    final subkey = _hchacha20(key, Uint8List.sublistView(nonce24, 0, 16));
    final ietfNonce = Uint8List(12)
      ..[0] = 0
      ..[1] = 0
      ..[2] = 0
      ..[3] = 0
      ..setAll(4, Uint8List.sublistView(nonce24, 16, 24));

    final engine = pc.ChaCha20Poly1305(
      pc.ChaCha7539Engine(),
      pc.Poly1305(),
    )..init(
        true, pc.AEADParameters(pc.KeyParameter(subkey), 128, ietfNonce, aad));

    final out = Uint8List(engine.getOutputSize(plaintext.length));
    var written = engine.processBytes(plaintext, 0, plaintext.length, out, 0);
    written += engine.doFinal(out, written);

    return Uint8List.sublistView(out, 0, written);
  }

  static Uint8List _xchacha20Poly1305Decrypt(
    Uint8List key,
    Uint8List nonce24,
    Uint8List aad,
    Uint8List ciphertextAndTag,
  ) {
    final subkey = _hchacha20(key, Uint8List.sublistView(nonce24, 0, 16));
    final ietfNonce = Uint8List(12)
      ..[0] = 0
      ..[1] = 0
      ..[2] = 0
      ..[3] = 0
      ..setAll(4, Uint8List.sublistView(nonce24, 16, 24));

    final engine = pc.ChaCha20Poly1305(
      pc.ChaCha7539Engine(),
      pc.Poly1305(),
    )..init(
        false, pc.AEADParameters(pc.KeyParameter(subkey), 128, ietfNonce, aad));

    final out = Uint8List(engine.getOutputSize(ciphertextAndTag.length));
    var written = engine.processBytes(
        ciphertextAndTag, 0, ciphertextAndTag.length, out, 0);
    written += engine.doFinal(out, written);

    return Uint8List.sublistView(out, 0, written);
  }

  // ---------------------------------------------------------------------------
  // Bech32
  // ---------------------------------------------------------------------------

  static String _bech32Encode(List<int> bytes) {
    final fiveBit = _convertBits(bytes, 8, 5, true);
    return const Bech32Codec().encode(Bech32(_hrp, fiveBit), 1023);
  }

  static List<int> _bech32Decode(String value) {
    final Bech32 decoded;

    try {
      decoded = const Bech32Codec().decode(value, 1023);
    } catch (e) {
      throw ArgumentError('invalid ncryptsec encoding: $e');
    }

    if (decoded.hrp != _hrp) {
      throw ArgumentError('expected ncryptsec prefix, got ${decoded.hrp}');
    }

    return _convertBits(decoded.data, 5, 8, false);
  }

  static List<int> _convertBits(
      List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      acc = ((acc << fromBits) | value) & 0xffffffffffff;
      bits += fromBits;

      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad && bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    } else if (!pad &&
        (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0)) {
      throw ArgumentError('invalid padding');
    }

    return result;
  }
}
