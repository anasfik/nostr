import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

/// Iteration 9 — hostile input & boundary conditions a real client meets:
/// unicode, relay-added fields, extreme timestamps, degenerate filters.
void main() {
  group('edge-case hardening', () {
    test('unicode/emoji/CJK content survives serialization roundtrips', () {
      const content = 'héllo 🌍 世界 \u{1F600} مرحبا \\ "quotes" \n newline';
      final keyPairs = NostrKeyPairs.generate();

      final event = NostrEvent.fromPartialData(
        content: content,
        kind: 1,
        keyPairs: keyPairs,
      );

      // Relay-style decode of our own serialized form.
      final decoded = NostrEvent.deserialized(
        jsonEncode(['EVENT', 'sub', event.toMap()]),
      );

      expect(decoded.content, content);
      // Id must remain stable across unicode payloads.
      final recomputed = NostrEvent.getEventId(
        kind: 1,
        content: content,
        createdAt: event.createdAt!,
        tags: event.tags!,
        pubkey: event.pubkey,
      );
      expect(recomputed, decoded.id);
    });

    test('relay-added unknown JSON fields are ignored gracefully', () {
      final map = <String, dynamic>{
        'id': 'aa' * 32,
        'pubkey': 'bb' * 32,
        'created_at': 1700000000,
        'kind': 1,
        'tags': <List<String>>[],
        'content': 'hello',
        'sig': 'cc' * 64,
        // Fields some relays inject:
        '__size': 42,
        'cached': true,
      };

      final event = NostrEvent.deserialized(
        jsonEncode(['EVENT', 'sub', map]),
      );
      expect(event.content, 'hello');
    });

    test('future and ancient timestamps do not explode', () {
      final future = DateTime.now().add(const Duration(days: 3650));
      final ancient = DateTime.fromMillisecondsSinceEpoch(0);

      for (final ts in [future, ancient]) {
        final event = NostrEvent.fromPartialData(
          content: 'ts test',
          kind: 1,
          keyPairs: NostrKeyPairs.generate(),
          createdAt: ts,
        );
        expect(event.isVerified(), isTrue);
      }
    });

    test('degenerate filters are rejected or clamped, never crash', () {
      // limit above protocol max should still construct; relays enforce.
      const huge = NostrFilter(kinds: [1], limit: 999999);
      expect(huge.limit, 999999);

      // Zero/negative limits are invalid per validation.
      const zero = NostrFilter(kinds: [1], limit: 0);
      expect(zero.validate(), isNotEmpty);

      // since/until are DateTime? on this filter model; inverted ranges
      // are semantically odd but structurally constructible.
      final inverted = NostrFilter(
        kinds: [1],
        since: DateTime.fromMillisecondsSinceEpoch(200000),
        until: DateTime.fromMillisecondsSinceEpoch(100000),
      );
      expect(inverted.toMap(), isA<Map<String, dynamic>>());
    });

    test('empty tag lists and single-element tags serialize per spec', () {
      final id = NostrEvent.getEventId(
        kind: 1,
        content: 'x',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        tags: <List<String>>[<String>[]],
        pubkey: 'dd' * 32,
      );
      expect(id, hasLength(64));

      // Single-element tag (malformed-ish but seen in the wild).
      final id2 = NostrEvent.getEventId(
        kind: 1,
        content: 'x',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        tags: [
          ['e'],
        ],
        pubkey: 'dd' * 32,
      );
      expect(id2, hasLength(64));
    });

    test('large content payloads (100 KB) work end-to-end', () {
      final content = 'a' * 100 * 1024;
      final event = NostrEvent.fromPartialData(
        content: content,
        kind: 1,
        keyPairs: NostrKeyPairs.generate(),
      );

      expect(event.sig, hasLength(128));
      final decoded =
          NostrEvent.deserialized(jsonEncode(['EVENT', 's', event.toMap()]));
      expect(decoded.content?.length, content.length);
    });

    test('NIP-44 handles multibyte plaintext boundaries', () async {
      // Already spec-vector tested; here verify multibyte UTF-8 content
      // through encrypt/decrypt with random nonces.
      const message = '🌍🌍🌍 emoji padding';
      final alice = NostrLocalKeySigner(NostrKeyPairs.generate());
      final bob = NostrLocalKeySigner(NostrKeyPairs.generate());

      final encrypted = await alice.nip44Encrypt(message, bob.publicKey);
      final decrypted = await bob.nip44Decrypt(encrypted, alice.publicKey);
      expect(decrypted, message);
    });

    test('subscription id edge values serialize safely', () {
      final request = NostrRequest(
        subscriptionId: 'id-with-dashes_and_underscores',
        filters: const [
          NostrFilter(kinds: [1])
        ],
      );
      final serialized = request.serialized();
      expect(serialized, contains('id-with-dashes_and_underscores'));

      // Very long subscription ids (some relays cap at 64 chars; we don't).
      final long = NostrRequest(
        subscriptionId: 'x' * 200,
        filters: const [
          NostrFilter(kinds: [1])
        ],
      );
      expect(long.serialized(), contains('x' * 200));
    });
  });
}
