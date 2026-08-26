import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip44/nip44.dart';

/// {@template nostr_event_signer}
/// Pluggable event-signing interface.
///
/// Implementations provided by this package:
/// - [NostrLocalKeySigner]: signs locally from a key pair.
///
/// Applications can implement this interface to delegate signing to external
/// providers such as NIP-07 browser extensions, NIP-46 remote signers
/// (bunkers) or NIP-55 Android signer apps, without giving the library direct
/// access to private keys.
/// {@endtemplate}
abstract interface class NostrEventSigner {
  /// The public key that events will be attributed to (64-char hex).
  String get publicKey;

  /// Signs an event: computes its `id` if missing and returns a fully signed
  /// event (id + sig set).
  Future<NostrEvent> sign(NostrEvent event);

  /// NIP-44 v2 encrypt [plaintext] for [recipientPublicKey].
  Future<String> nip44Encrypt(
    String plaintext,
    String recipientPublicKey,
  );

  /// NIP-44 v2 decrypt [payload] sent by [senderPublicKey].
  Future<String> nip44Decrypt(String payload, String senderPublicKey);
}

/// {@template nostr_local_key_signer}
/// Signs events locally using an in-memory [NostrKeyPairs]. Use only in
/// trusted environments; prefer remote signers when the user's keys are
/// managed elsewhere.
/// {@endtemplate}
class NostrLocalKeySigner implements NostrEventSigner {
  NostrLocalKeySigner(this.keyPairs);

  final NostrKeyPairs keyPairs;

  @override
  String get publicKey => keyPairs.public;

  @override
  Future<NostrEvent> sign(NostrEvent event) async {
    final id = event.id ??
        NostrEvent.getEventId(
          kind: event.kind!,
          content: event.content ?? '',
          createdAt: event.createdAt!,
          tags: event.tags ?? [],
          pubkey: publicKey,
        );

    final sig = keyPairs.sign(id);

    return NostrEvent(
      id: id,
      kind: event.kind,
      content: event.content,
      sig: sig,
      pubkey: publicKey,
      createdAt: event.createdAt,
      tags: event.tags,
      subscriptionId: event.subscriptionId,
      ots: event.ots,
    );
  }

  @override
  Future<String> nip44Encrypt(
    String plaintext,
    String recipientPublicKey,
  ) {
    return Future.value(
      Nip44.encryptMessage(
        plaintext: plaintext,
        senderPrivateKeyHex: keyPairs.private,
        recipientPublicKeyHex: recipientPublicKey,
      ),
    );
  }

  @override
  Future<String> nip44Decrypt(String payload, String senderPublicKey) {
    return Future.value(
      Nip44.decryptMessage(
        payload: payload,
        recipientPrivateKeyHex: keyPairs.private,
        senderPublicKeyHex: senderPublicKey,
      ),
    );
  }
}
