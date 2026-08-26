import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_nostr/nostr/core/secp256k1.dart';
import 'package:dart_nostr/nostr/nips/nip44/nip44.dart';
import 'package:test/test.dart';

/// Official NIP-44 vectors:
/// https://github.com/paulmillr/nip44/blob/main/nip44.vectors.json
void main() {
  final file = File('test/nip44.vectors.json');
  final vectors = jsonDecode(file.readAsStringSync())['v2'];
  final valid = vectors['valid'] as Map<String, dynamic>;
  final invalid = vectors['invalid'] as Map<String, dynamic>;

  group('Nip44 getConversationKey', () {
    for (final entry in (valid['get_conversation_key'] as List)) {
      test('sec1=${(entry as Map)['sec1'].substring(0, 8)}...', () {
        final convKey = Nip44.getConversationKey(
          privateKeyHex: entry['sec1'] as String,
          publicKeyHex: entry['pub2'] as String,
        );
        expect(
          NostrSecp256k1.bytesToHex(convKey),
          entry['conversation_key'],
        );
      });
    }

    for (final badInput in invalid['get_conversation_key'] as List) {
      final bad = badInput as Map;
      test('rejects ${bad['note'] ?? bad['sec1'].substring(0, 16)}', () {
        expect(
          () => Nip44.getConversationKey(
            privateKeyHex: bad['sec1'] as String,
            publicKeyHex: bad['pub2'] as String,
          ),
          throwsArgumentError,
        );
      });
    }
  });

  group('Nip44 getMessageKeys', () {
    final spec = valid['get_message_keys'];
    final conversationKey = Uint8List.fromList(
      NostrSecp256k1.hexToBytes(spec['conversation_key'] as String),
    );

    for (final entry in spec['keys'] as List) {
      test('nonce=${(entry as Map)['nonce'].substring(0, 12)}...', () {
        final nonce = NostrSecp256k1.hexToBytes(entry['nonce'] as String);
        final (chachaKey, chachaNonce, hmacKey) =
            Nip44.getMessageKeys(conversationKey, Uint8List.fromList(nonce));

        expect(NostrSecp256k1.bytesToHex(chachaKey), entry['chacha_key']);
        expect(NostrSecp256k1.bytesToHex(chachaNonce), entry['chacha_nonce']);
        expect(NostrSecp256k1.bytesToHex(hmacKey), entry['hmac_key']);
      });
    }
  });

  group('Nip44 calcPaddedLen', () {
    for (final pair in valid['calc_padded_len'] as List) {
      test('${(pair as List)[0]} -> ${pair[1]}', () {
        expect(Nip44.calcPaddedLen(pair[0] as int), pair[1]);
      });
    }
  });

  group('Nip44 encrypt/decrypt roundtrip', () {
    for (var i = 0; i < (valid['encrypt_decrypt'] as List).length; i++) {
      final entry = valid['encrypt_decrypt'][i] as Map;
      test('#$i plaintext len ${(entry['plaintext'] as String).length}', () {
        // Encrypt with fixed nonce and compare to expected payload.
        final payload = Nip44.encryptWithNonce(
          plaintext: entry['plaintext'] as String,
          conversationKey: Uint8List.fromList(
            NostrSecp256k1.hexToBytes(entry['conversation_key'] as String),
          ),
          nonce: Uint8List.fromList(
            NostrSecp256k1.hexToBytes(entry['nonce'] as String),
          ),
        );
        expect(payload, entry['payload']);

        // Decrypt the expected payload back to the plaintext.
        final decrypted = Nip44.decrypt(
          payload: entry['payload'] as String,
          conversationKey: Uint8List.fromList(
            NostrSecp256k1.hexToBytes(entry['conversation_key'] as String),
          ),
        );
        expect(decrypted, entry['plaintext']);
      });
    }
  });

  group('Nip44 symmetric conversation key', () {
    test('conv(a,B) == conv(b,A)', () {
      const a =
          '0000000000000000000000000000000000000000000000000000000000000003';
      const b =
          '0000000000000000000000000000000000000000000000000000000000000005';

      final ab = Nip44.getConversationKey(
        privateKeyHex: a,
        publicKeyHex: NostrSecp256k1.derivePublicKey(b),
      );
      final ba = Nip44.getConversationKey(
        privateKeyHex: b,
        publicKeyHex: NostrSecp256k1.derivePublicKey(a),
      );

      expect(NostrSecp256k1.bytesToHex(ab), NostrSecp256k1.bytesToHex(ba));
    });
  });

  group('Nip44 invalid decryption', () {
    for (final entry in invalid['decrypt'] as List) {
      final bad = entry as Map;
      final payloadPreview = (bad['payload'] as String).substring(
        0,
        (bad['payload'] as String).length < 20
            ? (bad['payload'] as String).length
            : 20,
      );
      test('payload=$payloadPreview...', () {
        expect(
          () => Nip44.decrypt(
            payload: bad['payload'] as String,
            conversationKey: Uint8List.fromList(
              NostrSecp256k1.hexToBytes(bad['conversation_key'] as String),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    }
  });

  group('Nip44 message length validation', () {
    test('empty plaintext rejected', () {
      expect(
        () => Nip44.pad([]),
        throwsArgumentError,
      );
    });
  });

  group('Nip44 random encrypt/decrypt roundtrip', () {
    for (final length in [1, 15, 32, 100, 1000, 65535]) {
      test(
        'length=$length',
        () {
          final privA = NostrSecp256k1.bytesToHex(
            Uint8List.fromList(List.generate(32, (_) => 7)),
          ).padLeft(64, '0');
          final privB = NostrSecp256k1.bytesToHex(
            Uint8List.fromList(List.generate(32, (i) => i + 9)),
          );

          final plaintext = 'x' * length;

          final encrypted = Nip44.encryptMessage(
            plaintext: plaintext,
            senderPrivateKeyHex: privA,
            recipientPublicKeyHex: NostrSecp256k1.derivePublicKey(privB),
          );

          final decrypted = Nip44.decryptMessage(
            payload: encrypted,
            recipientPrivateKeyHex: privB,
            senderPublicKeyHex: NostrSecp256k1.derivePublicKey(privA),
          );

          expect(decrypted, plaintext);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }

    test('tampered payload fails MAC check', () {
      final privA = '11' * 32;
      final privB = '22' * 32;
      final pubB = NostrSecp256k1.derivePublicKey(privB);

      var payload = Nip44.encryptMessage(
        plaintext: 'hello',
        senderPrivateKeyHex: privA,
        recipientPublicKeyHex: pubB,
      );

      // Flip a character in the ciphertext region.
      final chars = payload.split('');
      chars[chars.length - 10] = chars[chars.length - 10] == 'A' ? 'B' : 'A';
      payload = chars.join();

      expect(
        () => Nip44.decryptMessage(
          payload: payload,
          recipientPrivateKeyHex: privB,
          senderPublicKeyHex: NostrSecp256k1.derivePublicKey(privA),
        ),
        throwsArgumentError,
      );
    });
  });
}
