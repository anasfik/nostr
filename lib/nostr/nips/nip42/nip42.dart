import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_nip42}
/// NIP-42 relay authentication.
///
/// Builds the kind-22242 event a client sends after a relay answers a REQ,
/// EVENT or COUNT with `["AUTH", <challenge>]`. The event is signed by
/// [signer] and carries the relay's websocket URL plus the challenge.
///
/// `NostrRelays` answers challenges automatically for the signer passed to
/// `Nostr.connect`/`init`; these helpers are for manual auth flows and for
/// signing with a different key than the connection signer.
/// {@endtemplate}
class NostrNip42 {
  /// {@macro nostr_nip42}
  const NostrNip42();

  /// Kind of a NIP-42 authentication event.
  static const int authKind = 22242;

  /// Builds and signs a kind-22242 auth event for [relay] and [challenge].
  ///
  /// [relay] must be the websocket URL (`ws://` / `wss://`), as the spec
  /// requires, not its HTTP equivalent.
  Future<NostrEvent> createAuthEvent({
    required NostrEventSigner signer,
    required String relay,
    required String challenge,
    DateTime? createdAt,
  }) {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: authKind,
        content: '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          ['relay', relay],
          ['challenge', challenge],
        ],
      ),
    );
  }
}
