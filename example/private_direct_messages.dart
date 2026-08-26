import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_nostr/nostr/nips/nip17/nip17.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// End-to-end private message flow: wrap for Bob, publish, then unwrap on
/// Bob's side.
Future<void> main() async {
  final nostr = Nostr();

  // Alice logs in with her keys; in real apps this may come from secure
  // storage or an external signer.
  final aliceKeyPair = NostrKeyPairs.generate();
  final aliceSigner = NostrLocalKeySigner(aliceKeyPair);
  final alice = NostrNip17(signer: aliceSigner);

  await nostr.connect(['wss://relay.damus.io', 'wss://nos.lol']);

  // Bob's public key — you always need the recipient's npub-decoded pubkey.
  final bobPubkey = NostrKeyPairs.generate().public;

  // 1. Build the unsigned chat message (rumor).
  final rumor = alice.createChatMessageRumor(
    content: 'hey bob! 👋',
    recipientPubkeys: [bobPubkey],
    subject: 'greetings',
  );

  // 2. Seal + gift wrap it for Bob (kind 1059).
  final giftWrap = await alice.wrapMessage(rumor, bobPubkey);

  // 3. Publish. Relays only see an anonymous wrapper.
  final ok = await nostr.publish(giftWrap);
  ok.fold(
    (receipt) => print('delivered: ${receipt.isEventAccepted}'),
    (failure) => print('failed: ${failure.message}'),
  );

  // ── On Bob's side, receiving:
  final bobSigner = NostrLocalKeySigner(NostrKeyPairs.generate());
  final bob = NostrNip17(signer: bobSigner);
  final unwrapped = await bob.unwrapMessage(giftWrap);
  print('${unwrapped.pubkey.substring(0, 8)}… says: ${unwrapped.content}');

  await nostr.disconnect();
}
