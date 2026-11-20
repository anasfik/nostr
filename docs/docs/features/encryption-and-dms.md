---
sidebar_position: 2
description: NIP-44 payload encryption, the NIP-17 private message flow, NIP-59 seal and gift wrap primitives, and the signer capabilities they require.
---

# Encryption and DMs

Private messages in Nostr are built from three layers:

- **NIP-44** encrypts one payload between two keys.
- **NIP-59** wraps an unsigned event in a signed seal and an anonymous gift wrap.
- **NIP-17** defines the chat event kinds that travel inside those wraps.

## NIP-44

`Nip44` is a static utility. It does not need a `Nostr` instance or a bound
signer when you supply key material directly.

| Method | Returns | Purpose |
| --- | --- | --- |
| `Nip44.encryptMessage({plaintext, senderPrivateKeyHex, recipientPublicKeyHex})` | `String` | One-shot encrypt from hex keys |
| `Nip44.decryptMessage({payload, recipientPrivateKeyHex, senderPublicKeyHex})` | `String` | One-shot decrypt from hex keys |
| `Nip44.getConversationKey({privateKeyHex, publicKeyHex})` | `Uint8List` | Reusable 32-byte key for a pair |
| `Nip44.encrypt({plaintext, conversationKey})` | `String` | Encrypt with an existing conversation key |
| `Nip44.decrypt({payload, conversationKey})` | `String` | Decrypt with an existing conversation key |

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final alice = NostrKeyPairs.generate();
  final bob = NostrKeyPairs.generate();

  final payload = Nip44.encryptMessage(
    plaintext: 'meet at seven',
    senderPrivateKeyHex: alice.private,
    recipientPublicKeyHex: bob.public,
  );

  final plaintext = Nip44.decryptMessage(
    payload: payload,
    recipientPrivateKeyHex: bob.private,
    senderPublicKeyHex: alice.public,
  );

  print(plaintext);
}
```

The conversation key is symmetric: Alice's private key with Bob's public key
produces the same key as Bob's private key with Alice's public key. Reusing it
avoids repeating ECDH for every message.

```dart
import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final alice = NostrKeyPairs.generate();
  final bob = NostrKeyPairs.generate();

  final conversationKey = Nip44.getConversationKey(
    privateKeyHex: alice.private,
    publicKeyHex: bob.public,
  );

  final payload = Nip44.encrypt(
    plaintext: 'hello',
    conversationKey: conversationKey,
  );

  print(Nip44.decrypt(payload: payload, conversationKey: conversationKey));
}
```

Payloads are versioned strings, not raw ciphertext. `Nip44.decodePayload`
validates the framing without decrypting; a malformed payload throws rather than
returning empty text.

## NIP-17 direct messages

`nostr.nips.nip17` is signer-bound and builds kind-14 chat rumors. A rumor has an
id but no signature. It is encrypted into a seal and then into a gift wrap before
it reaches a relay.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final aliceKeys = NostrKeyPairs.generate();
  final bobKeys = NostrKeyPairs.generate();

  final alice = NostrNip17(signer: NostrLocalKeySigner(aliceKeys));

  final rumor = alice.createChatMessageRumor(
    content: 'see you at seven',
    recipientPubkeys: [bobKeys.public],
    subject: 'dinner',
  );

  final giftWrap = await alice.wrapMessage(rumor, bobKeys.public);
  print(giftWrap.kind); // 1059

  final bob = NostrNip17(signer: NostrLocalKeySigner(bobKeys));
  final received = await bob.unwrapMessage(giftWrap);
  print(received.kind);    // 14
  print(received.content); // see you at seven
}
```

`createChatMessageRumor` throws `ArgumentError` when the recipient list is empty
or contains the sender's own pubkey. `subject` becomes a `subject` tag;
`replyToEventId` and `replyToRootEventId` produce reply tags.

Publishing the gift wrap requires a connection, and so does a normal event:

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final aliceKeys = nostr.keys.generateKeyPair();
  final bobKeys = NostrKeyPairs.generate();

  await nostr.connect(
    const ['wss://relay.damus.io'],
    signer: NostrLocalKeySigner(aliceKeys),
  );

  final rumor = nostr.nips.nip17.createChatMessageRumor(
    content: 'see you at seven',
    recipientPubkeys: [bobKeys.public],
  );
  final giftWrap = await nostr.nips.nip17.wrapMessage(rumor, bobKeys.public);

  final result = await nostr.publish(giftWrap);
  print(result.valueOrNull?.isEventAccepted);
}
```

For a group, wrap the same rumor once per recipient and publish each gift wrap.
A gift wrap is addressed to one pubkey, so other members cannot read it.

## NIP-59 primitives

`Nip59` exposes the layers individually when you need control.

| Method | Returns | Purpose |
| --- | --- | --- |
| `Nip59.createRumor({kind, content, pubkey, tags, createdAt, now})` | `NostrEvent` | Unsigned event with an id |
| `Nip59.createSeal({rumor, signer, recipientPublicKey})` | `Future<NostrEvent>` | Kind 13, signed, content encrypted to the recipient |
| `Nip59.createGiftWrap({seal, recipientPublicKey})` | `Future<NostrEvent>` | Kind 1059, encrypted under a fresh ephemeral key |
| `Nip59.giftWrapRumor({rumor, signer, recipientPublicKey})` | `Future<NostrEvent>` | Seal plus gift wrap in one call |
| `Nip59.unwrap(event, signer)` | `Future<NostrEvent>` | Peels one layer |
| `Nip59.extractRumor(giftWrap, signer)` | `Future<NostrEvent>` | Peels gift wrap and seal |

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final aliceKeys = NostrKeyPairs.generate();
  final bobKeys = NostrKeyPairs.generate();
  final aliceSigner = NostrLocalKeySigner(aliceKeys);

  final rumor = Nip59.createRumor(
    kind: 14,
    content: 'hello',
    pubkey: aliceKeys.public,
    tags: [
      ['p', bobKeys.public],
    ],
  );

  final seal = await Nip59.createSeal(
    rumor: rumor,
    signer: aliceSigner,
    recipientPublicKey: bobKeys.public,
  );

  final giftWrap = await Nip59.createGiftWrap(
    seal: seal,
    recipientPublicKey: bobKeys.public,
  );

  final bobSigner = NostrLocalKeySigner(bobKeys);
  final unwrapped = await Nip59.extractRumor(giftWrap, bobSigner);
  print(unwrapped.content);
}
```

`createSeal` refuses a rumor that already has a signature. `unwrap` verifies the
signature of the layer it is given before decrypting it; `extractRumor` also
checks that the outer event is kind 1059. `createGiftWrap` signs with a fresh
ephemeral key pair, which is why it does not take a signer: the wrap is not
attributable to the sender's key. When `createdAt` is omitted, `createRumor`
randomizes it within the previous day.

## Self-addressed encryption

Some flows encrypt to the signer's own pubkey:

| Flow | Call |
| --- | --- |
| NIP-37 drafts | `signer.nip44Encrypt(json, signer.publicKey)` |
| NIP-60 wallet and history | `signer.nip44Encrypt(json, signer.publicKey)` |
| NIP-17 copy of an outgoing DM | `wrapMessage(rumor, signer.publicKey)` |

A local key signer handles this because it holds the private key. A remote signer
must implement self-addressed `nip44_encrypt` and `nip44_decrypt`; NIP-37 and
NIP-60 call those methods and rethrow a failure as `StateError` naming the
missing capability. No plaintext event is produced when encryption fails, so a
signer that cannot do this fails closed instead of publishing readable content.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final signer = NostrLocalKeySigner(NostrKeyPairs.generate());

  final payload = await signer.nip44Encrypt(
    'draft body',
    signer.publicKey,
  );
  final plaintext = await signer.nip44Decrypt(payload, signer.publicKey);

  print(plaintext);
}
```

## NIP-04 legacy messages

NIP-04 kind-4 messages are still readable by older clients, but the scheme needs
the raw private key for ECDH. `nostr.nips.nip04` therefore throws
`ArgumentError` unless the bound signer is a `NostrLocalKeySigner`. Prefer NIP-17
for new messages.

Related: [Signers](./signers.md),
[NIP coverage](../reference/nip-coverage.md), and
[Publishing events](../usage/relays-and-events/publishing-events.md).
