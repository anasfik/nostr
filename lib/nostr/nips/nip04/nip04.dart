import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/core/secp256k1.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:pointycastle/api.dart'
    show KeyParameter, PaddedBlockCipherParameters, ParametersWithIV;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

/// {@template nip04}
/// NIP-04 legacy encrypted direct messages (kind 4).
///
/// Encryption is secp256k1 ECDH → AES-256-CBC with PKCS#7 padding, a random
/// 16-byte IV, and the wire format `<base64 ciphertext>?iv=<base64 iv>` —
/// byte-compatible with `nostr-tools`' `nip04.encrypt/decrypt`.
///
/// NIP-04 is deprecated in favour of NIP-17/NIP-44; it is provided for
/// interoperability with clients that still use kind-4 messages.
///
/// Usage:
/// ```dart
/// final nip04 = NostrNip04(privateKeyHex: myPrivateKey);
/// final ciphertext = nip04.encrypt('hello', theirPublicKey);
/// final plaintext = nip04.decrypt(ciphertext, theirPublicKey);
/// ```
/// {@endtemplate}
class NostrNip04 {
  /// {@macro nip04}
  ///
  /// [privateKeyHex] is the 64-char hex secret key of the local party.
  NostrNip04({required String privateKeyHex})
      : _keyPairs = NostrKeyPairs(private: privateKeyHex);

  /// Creates a NIP-04 helper from an existing [NostrKeyPairs].
  NostrNip04.fromKeyPairs(this._keyPairs);

  /// Creates a NIP-04 helper from a signer that holds local key material.
  ///
  /// NIP-04 needs the raw private key for ECDH, so only
  /// [NostrLocalKeySigner] is supported. Remote signers (NIP-07/NIP-46)
  /// cannot perform kind-4 encryption through these helpers.
  factory NostrNip04.fromSigner(NostrEventSigner signer) {
    if (signer is! NostrLocalKeySigner) {
      throw ArgumentError.value(
        signer,
        'signer',
        'NIP-04 requires local key material (NostrLocalKeySigner)',
      );
    }
    return NostrNip04.fromKeyPairs(signer.keyPairs);
  }

  final NostrKeyPairs _keyPairs;

  /// Public key (64-char hex) of the local party.
  String get publicKey => _keyPairs.public;

  /// Encrypts [plaintext] for [recipientPublicKey] using AES-256-CBC.
  ///
  /// Returns `<base64 ciphertext>?iv=<base64 iv>`.
  String encrypt(String plaintext, String recipientPublicKey) {
    final key = _sharedX(recipientPublicKey);
    final iv = _randomIv();
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    final Uint8List ciphertext;
    if (plaintextBytes.isEmpty) {
      // PaddedBlockCipherImpl cannot process zero-length input; PKCS#7 pads
      // empty plaintext to a single block of 0x10, as noble/other clients do.
      final padded = Uint8List(16)..fillRange(0, 16, 16);
      ciphertext = Uint8List(16);
      _cbc(true, key, iv).processBlock(padded, 0, ciphertext, 0);
    } else {
      ciphertext = _aesCbc(true, key, iv).process(plaintextBytes);
    }

    return '${base64.encode(ciphertext)}?iv=${base64.encode(iv)}';
  }

  /// Decrypts a NIP-04 payload produced by [encrypt] or any NIP-04 client.
  ///
  /// [senderPublicKey] is the author of the kind-4 event.
  String decrypt(String payload, String senderPublicKey) {
    final separator = payload.indexOf('?iv=');
    if (separator < 0) {
      throw ArgumentError.value(
        payload,
        'payload',
        'missing ?iv= separator',
      );
    }

    final ctB64 = payload.substring(0, separator);
    final ivB64 = payload.substring(separator + '?iv='.length);

    final Uint8List ciphertext;
    final Uint8List iv;
    try {
      ciphertext = base64.decode(ctB64);
      iv = base64.decode(ivB64);
    } on FormatException {
      throw ArgumentError.value(payload, 'payload', 'invalid base64 payload');
    }

    if (iv.length != 16) {
      throw ArgumentError.value(ivB64, 'iv', 'iv must be 16 bytes');
    }

    final key = _sharedX(senderPublicKey);
    final cipher = _aesCbc(false, key, iv);

    return utf8.decode(cipher.process(ciphertext));
  }

  /// Creates and signs a kind-4 direct message event addressed to
  /// [recipientPublicKey].
  ///
  /// The event content is the encrypted payload from [encrypt], tagged with
  /// a `p` tag for the recipient.
  NostrEvent createDirectMessage({
    required String plaintext,
    required String recipientPublicKey,
    DateTime? createdAt,
  }) {
    return NostrEvent.fromPartialData(
      kind: 4,
      content: encrypt(plaintext, recipientPublicKey),
      keyPairs: _keyPairs,
      tags: [
        ['p', recipientPublicKey],
      ],
      createdAt: createdAt,
    );
  }

  Uint8List _sharedX(String counterpartyPublicKey) {
    return Uint8List.fromList(
      NostrSecp256k1.ecdhSharedX(
        privateKeyHex: _keyPairs.private,
        publicKeyHex: counterpartyPublicKey,
      ),
    );
  }

  static Uint8List _randomIv() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  static CBCBlockCipher _cbc(
    bool forEncryption,
    Uint8List key,
    Uint8List iv,
  ) {
    return CBCBlockCipher(AESEngine())
      ..init(
        forEncryption,
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
      );
  }

  static PaddedBlockCipherImpl _aesCbc(
    bool forEncryption,
    Uint8List key,
    Uint8List iv,
  ) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        forEncryption,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return cipher;
  }
}
