import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/ecc_fp.dart' as fp;

/// Minimal secp256k1 helpers built on top of pointycastle's curve
/// implementation. Used for ECDH shared-secret computation (NIP-44, NIP-59).
class NostrSecp256k1 {
  NostrSecp256k1._();

  static final ECDomainParameters _domain = ECDomainParameters('secp256k1');

  static BigInt _parseScalar(String hexScalar) {
    final d = BigInt.parse(hexScalar, radix: 16);

    if (d.sign <= 0) {
      throw ArgumentError('scalar must be a positive integer');
    }

    if (d >= _domain.n) {
      throw ArgumentError('scalar is not less than the curve order');
    }

    return d;
  }

  /// Parses a compressed (33-byte, `02`/`03` prefixed) or x-only (32-byte hex)
  /// public key into a curve point. X-only keys are always decoded with the
  /// even-Y candidate first, matching BIP-340 semantics.
  ///
  /// Note: disambiguation is by LENGTH, not prefix — an x-only key can start
  /// with `02` or `03` just like a compressed key.
  static ECPoint parsePublicKey(String publicKeyHex) {
    final hex = publicKeyHex.trim().toLowerCase();

    if ((hex.startsWith('02') || hex.startsWith('03')) && hex.length == 66) {
      final p = _domain.curve.decodePoint(hexToBytes(hex));
      if (p == null) {
        throw ArgumentError('invalid public key point');
      }
      return p;
    }

    if (hex.length != 64) {
      throw ArgumentError(
        'public key must be 64 chars (x-only) or 66 chars (compressed)',
      );
    }

    final x = BigInt.parse(hex, radix: 16);
    return _liftX(x);
  }

  /// Lifts an x coordinate to the corresponding curve point (BIP-340 lift_x).
  static ECPoint _liftX(BigInt x) {
    final p = (_domain.curve as fp.ECCurve).q!;
    final c = _domain.curve;
    final three = BigInt.from(3);
    final seven = BigInt.from(7);

    if (x.compareTo(BigInt.zero) < 0 || x.compareTo(p) >= 0) {
      throw ArgumentError('x coordinate out of field range');
    }

    // y^2 = x^3 + 7 (mod p)
    final alpha = (x.modPow(three, p) + seven) % p;

    // y = alpha^((p+1)/4) mod p  (valid only for p ≡ 3 mod 4)
    var y = alpha.modPow((p + BigInt.one) >> 2, p);

    if ((y * y) % p != alpha) {
      throw ArgumentError('x coordinate is not on the secp256k1 curve');
    }

    if (y.isOdd) {
      y = p - y;
    }

    return c.createPoint(x, y);
  }

  /// Computes the ECDH shared secret and returns the raw big-endian 32-byte
  /// x coordinate of the shared point — exactly what NIP-44 expects.
  ///
  /// [privateKeyHex] is a 64-char hex scalar; [publicKeyHex] may be x-only or
  /// compressed.
  static List<int> ecdhSharedX({
    required String privateKeyHex,
    required String publicKeyHex,
  }) {
    final d = _parseScalar(privateKeyHex);
    final publicPoint = parsePublicKey(publicKeyHex);

    final shared = publicPoint * d;

    if (shared == null || shared.isInfinity) {
      throw ArgumentError('ECDH produced an invalid shared point');
    }

    final xBytes = bigIntToBytes(shared.x!.toBigInteger()!);

    // Left-pad to exactly 32 bytes.
    return List<int>.generate(32 - xBytes.length, (_) => 0)..addAll(xBytes);
  }

  /// Encodes a public key point as a 66-char compressed hex string.
  static String pointToCompressedHex(ECPoint point) {
    return bytesToHex(point.getEncoded(true));
  }

  /// Derives the compressed public key hex for a private key hex scalar.
  static String derivePublicKey(String privateKeyHex) {
    final d = _parseScalar(privateKeyHex);
    final publicPoint = _domain.G * d;

    if (publicPoint == null) {
      throw ArgumentError('failed to derive public key');
    }

    return bytesToHex(publicPoint.getEncoded(true));
  }

  static bool isValidPrivateKeyHex(String hex) {
    try {
      _parseScalar(hex);
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<int> hexToBytes(String hex) {
    if (hex.length.isOdd) {
      throw FormatException('odd-length hex string');
    }

    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }

  static String bytesToHex(List<int> bytes) => [
        for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
      ].join();

  static List<int> bigIntToBytes(BigInt number) {
    if (number == BigInt.zero) {
      return [0];
    }

    var n = number;
    final bytes = <int>[];

    while (n.sign > 0) {
      bytes.insert(0, (n & BigInt.from(0xff)).toInt());
      n >>= 8;
    }

    return bytes;
  }
}
