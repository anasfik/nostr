import 'dart:convert';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip17/nip17.dart';
import 'package:dart_nostr/nostr/nips/nip59/nip59.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:test/test.dart';

void main() {
  late NostrEventSigner alice;
  late NostrEventSigner bob;

  setUp(() {
    alice = NostrLocalKeySigner(NostrKeyPairs.generate());
    bob = NostrLocalKeySigner(NostrKeyPairs.generate());
  });

  group('NostrLocalKeySigner', () {
    test('signs an unsigned event with id and sig set', () async {
      final event = await alice.sign(
        NostrEvent(
          id: null,
          kind: 1,
          content: 'hello',
          sig: null,
          pubkey: alice.publicKey,
          createdAt: DateTime.now(),
          tags: [],
        ),
      );

      expect(event.id, hasLength(64));
      expect(event.sig, hasLength(128));
      expect(event.isVerified(), isTrue);
    });

    test('nip44 encrypt/decrypt roundtrip between two parties', () async {
      final encrypted = await alice.nip44Encrypt('secret msg', bob.publicKey);
      final decrypted = await bob.nip44Decrypt(encrypted, alice.publicKey);

      expect(decrypted, 'secret msg');
    });
  });

  group('Nip59 rumor/seal/gift wrap', () {
    test('rumor is unsigned but carries an id', () {
      final rumor = Nip59.createRumor(
        kind: 14,
        content: 'hi',
        pubkey: alice.publicKey,
        now: DateTime.now(),
      );

      expect(rumor.sig, isNull);
      expect(rumor.id, hasLength(64));
    });

    test('refuses to seal signed events', () async {
      final signed = await alice.sign(
        NostrEvent(
          id: null,
          kind: 14,
          content: 'hi',
          sig: null,
          pubkey: alice.publicKey,
          createdAt: DateTime.now(),
          tags: [],
        ),
      );

      expect(
        () => Nip59.createSeal(
          rumor: signed,
          signer: alice,
          recipientPublicKey: bob.publicKey,
        ),
        throwsArgumentError,
      );
    });

    test('full gift wrap roundtrip between alice and bob', () async {
      final rumor = Nip59.createRumor(
        kind: 14,
        content: 'meet me at the park',
        pubkey: alice.publicKey,
        tags: [
          ['p', bob.publicKey],
        ],
        now: DateTime.now(),
      );

      final giftWrap = await Nip59.giftWrapRumor(
        rumor: rumor,
        signer: alice,
        recipientPublicKey: bob.publicKey,
      );

      // Gift wrap shape per spec.
      expect(giftWrap.kind, 1059);
      expect(giftWrap.pubkey, isNot(alice.publicKey)); // ephemeral author
      expect(
        giftWrap.tags!.any(
            (t) => t.isNotEmpty && t.first == 'p' && t[1] == bob.publicKey),
        isTrue,
      );
      expect(giftWrap.isVerified(), isTrue);

      // Bob unwraps both layers.
      final extracted = await Nip59.extractRumor(giftWrap, bob);

      expect(extracted.content, 'meet me at the park');
      expect(extracted.pubkey, alice.publicKey);
      expect(extracted.kind, 14);
      expect(extracted.id, rumor.id);
    });

    test('unwrap fails for a third party without the key', () async {
      final carol = NostrLocalKeySigner(NostrKeyPairs.generate());

      final rumor = Nip59.createRumor(
        kind: 14,
        content: 'private',
        pubkey: alice.publicKey,
        now: DateTime.now(),
      );

      final giftWrap = await Nip59.giftWrapRumor(
        rumor: rumor,
        signer: alice,
        recipientPublicKey: bob.publicKey,
      );

      expect(
        () => Nip59.unwrap(giftWrap, carol),
        throwsArgumentError,
      );
    });
  });

  group('NostrNip17', () {
    test('chat message rumor has p tags and no sender p tag', () {
      final nip17 = NostrNip17(signer: alice);

      final rumor = nip17.createChatMessageRumor(
        content: 'hello bob',
        recipientPubkeys: [bob.publicKey],
        subject: 'greetings',
        createdAt: DateTime.now(),
      );

      expect(rumor.kind, 14);
      expect(
        rumor.tags!.any(
            (t) => t.isNotEmpty && t.first == 'p' && t[1] == bob.publicKey),
        isTrue,
      );
      expect(rumor.tags!.where((t) => t.first == 'subject'), isNotEmpty);
      expect(rumor.tags!.map((t) => t[1]), isNot(contains(alice.publicKey)));
    });

    test('rejects empty recipients or self-recipients', () {
      final nip17 = NostrNip17(signer: alice);

      expect(
        () => nip17.createChatMessageRumor(content: 'x', recipientPubkeys: []),
        throwsArgumentError,
      );
      expect(
        () => nip17.createChatMessageRumor(
          content: 'x',
          recipientPubkeys: [alice.publicKey],
        ),
        throwsArgumentError,
      );
    });

    test('reply rumors carry root and reply e tags', () {
      final nip17 = NostrNip17(signer: alice);

      final rumor = nip17.createChatMessageRumor(
        content: 'replying',
        recipientPubkeys: [bob.publicKey],
        replyToRootEventId: 'a' * 64,
        replyToEventId: 'b' * 64,
        createdAt: DateTime.now(),
      );

      expect(
        rumor.tags!.any((t) => t.length >= 4 && t[3] == 'root'),
        isTrue,
      );
      expect(
        rumor.tags!.any((t) => t.length >= 4 && t[3] == 'reply'),
        isTrue,
      );
    });

    test('wrap/unwrap roundtrip via NIP-17 service', () async {
      final alice17 = NostrNip17(signer: alice);
      final bob17 = NostrNip17(signer: bob);

      final rumor = alice17.createChatMessageRumor(
        content: jsonEncode({'msg': 'hey'}),
        recipientPubkeys: [bob.publicKey],
        createdAt: DateTime.now(),
      );

      final giftWrap = await alice17.wrapMessage(rumor, bob.publicKey);
      final unwrapped = await bob17.unwrapMessage(giftWrap);

      expect(unwrapped.id, rumor.id);
      expect(unwrapped.pubkey, alice.publicKey);
      expect(unwrapped.content, jsonEncode({'msg': 'hey'}));
    });

    test('file message rumor carries url/m/size tags', () {
      final nip17 = NostrNip17(signer: alice);

      final rumor = nip17.createFileMessageRumor(
        fileUrl: 'https://example.com/cat.png',
        recipientPubkeys: [bob.publicKey],
        fileType: 'image/png',
        fileSizeBytes: 12345,
        caption: 'a cat',
        createdAt: DateTime.now(),
      );

      expect(rumor.kind, 15);
      bool hasTag(String a, String b) =>
          rumor.tags!.any((t) => t.length >= 2 && t[0] == a && t[1] == b);

      expect(hasTag('url', 'https://example.com/cat.png'), isTrue);
      expect(hasTag('m', 'image/png'), isTrue);
      expect(hasTag('size', '12345'), isTrue);
      expect(hasTag('alt', 'a cat'), isTrue);
    });
  });
}
