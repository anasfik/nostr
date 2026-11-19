import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/nips/blossom/blossom.dart';
import 'package:dart_nostr/nostr/nips/nip04/nip04.dart';
import 'package:dart_nostr/nostr/nips/nip05/nip05.dart';
import 'package:dart_nostr/nostr/nips/nip06/nip06.dart';
import 'package:dart_nostr/nostr/nips/nip07/nip07.dart';
import 'package:dart_nostr/nostr/nips/nip11/nip11.dart';
import 'package:dart_nostr/nostr/nips/nip17/nip17.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';
import 'package:dart_nostr/nostr/nips/nip21/nip21.dart';
import 'package:dart_nostr/nostr/nips/nip27/nip27.dart';
import 'package:dart_nostr/nostr/nips/nip28/nip28.dart';
import 'package:dart_nostr/nostr/nips/nip29/nip29.dart';
import 'package:dart_nostr/nostr/nips/nip30/nip30.dart';
import 'package:dart_nostr/nostr/nips/nip39/nip39.dart';
import 'package:dart_nostr/nostr/nips/nip42/nip42.dart';
import 'package:dart_nostr/nostr/nips/nip45/nip45.dart';
import 'package:dart_nostr/nostr/nips/nip46/nip46.dart';
import 'package:dart_nostr/nostr/nips/nip47/nip47.dart';
import 'package:dart_nostr/nostr/nips/nip54/nip54.dart';
import 'package:dart_nostr/nostr/nips/nip55/nip55.dart';
import 'package:dart_nostr/nostr/nips/nip57/nip57.dart';
import 'package:dart_nostr/nostr/nips/nip58/nip58.dart';
import 'package:dart_nostr/nostr/nips/nip75/nip75.dart';
import 'package:dart_nostr/nostr/nips/nip77/nip77.dart';
import 'package:dart_nostr/nostr/nips/nip94/nip94.dart';
import 'package:dart_nostr/nostr/nips/nip96/nip96.dart';
import 'package:dart_nostr/nostr/nips/nip98/nip98.dart';
import 'package:dart_nostr/nostr/nips/nip99/nip99.dart';
import 'package:dart_nostr/nostr/nips/nipad/nipad.dart';
import 'package:dart_nostr/nostr/nips/nipb7/nipb7.dart';
import 'package:dart_nostr/nostr/nips/social/social_builder.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';

/// {@template nostr_nips}
/// Per-NIP accessor surface attached to every [Nostr] instance.
///
/// Stateless helpers are created once. Signer-bound helpers are created
/// lazily and rebuilt whenever [bindSigner] receives a different signer.
///
/// NIP-13, NIP-44, NIP-49 and NIP-59 are static-only APIs and stay on
/// [NostrProofOfWork], [Nip44], [NostrNip49] and [Nip59]. NIP-29 group
/// templates are unsigned, so [nip29] needs no signer.
/// {@endtemplate}
class NostrNips {
  /// {@macro nostr_nips}
  NostrNips({required this.logger, NostrBech32? bech32})
      : nip19 = bech32 ?? NostrBech32(logger: logger);

  /// Logger shared with the owning services instance.
  final NostrLogger logger;

  /// NIP-19 bech32 entity encoding/decoding.
  final NostrBech32 nip19;

  /// NIP-21 `nostr:` URI parsing and building.
  late final NostrNip21 nip21 = NostrNip21(bech32: nip19);

  /// NIP-27 text note reference/mention parsing.
  late final NostrNip27 nip27 = NostrNip27(bech32: nip19);

  /// NIP-05 internet identifier validation and resolution.
  late final NostrNip05 nip05 = NostrNip05(logger: logger);

  /// NIP-06 mnemonic derivation helpers.
  late final NostrNip06 nip06 = const NostrNip06();

  /// NIP-11 relay information document fetching.
  late final NostrNip11 nip11 = NostrNip11(logger: logger);

  /// NIP-29 relay-group templates, parsing and validation.
  late final NostrNip29 nip29 = NostrNip29(bech32: nip19);

  /// NIP-30 custom emoji matching, parsing and emoji-set helpers.
  ///
  /// Stateless: the emoji-set builder takes the signer as an argument.
  late final NostrNip30 nip30 = const NostrNip30();

  /// NIP-07 browser-extension bridge helpers.
  ///
  /// Stateless: pass your `window.nostr` bridge to the methods or use
  /// [NostrNip07Signer.connect] and bind the result.
  late final NostrNip07 nip07 = const NostrNip07();

  /// NIP-55 Android signer URI helpers.
  ///
  /// Stateless: intent execution is supplied by the application.
  late final NostrNip55 nip55 = const NostrNip55();

  /// NIP-42 relay authentication event builder.
  ///
  /// Stateless: pass the signer, relay URL and challenge to
  /// [NostrNip42.createAuthEvent]. `NostrRelays` answers challenges
  /// automatically for the connection signer.
  late final NostrNip42 nip42 = const NostrNip42();

  /// NIP-45 COUNT request/response helpers.
  ///
  /// Stateless: `Nostr.count()` sends the request; use [NostrNip45] to build
  /// the event from a filter or parse a relay COUNT payload.
  late final NostrNip45 nip45 = const NostrNip45();

  /// NIP-77 negentropy reconciliation helpers.
  ///
  /// Stateless: pass the storage vector to build a session.
  late final NostrNip77 nip77 = const NostrNip77();

  /// NIP-AD web address pointer resolution.
  late final NostrNipAD nipAD = NostrNipAD();

  NostrEventSigner? _signer;
  NostrNip04? _nip04;
  NostrNip17? _nip17;
  NostrNip28? _nip28;
  NostrNip39? _nip39;
  NostrNip46? _nip46;
  NostrNip47? _nip47;
  NostrNip54? _nip54;
  NostrNip58? _nip58;
  NostrNip75? _nip75;
  NostrNip98? _nip98;
  NostrNip99? _nip99;
  NostrNipB7? _nipB7;
  NostrZaps? _nip57;
  NostrNip94FileMetadata? _nip94;
  NostrNip96Uploader? _nip96;
  NostrBlossomClient? _blossom;
  NostrSocialBuilder? _social;

  /// Binds (or clears) the signer used by signer-bound NIP helpers.
  void bindSigner(NostrEventSigner? signer) {
    if (identical(signer, _signer)) {
      return;
    }
    _signer = signer;
    _nip04 = null;
    _nip17 = null;
    _nip28 = null;
    _nip39 = null;
    _nip46 = null;
    _nip47 = null;
    _nip54 = null;
    _nip58 = null;
    _nip75 = null;
    _nip98 = null;
    _nip99 = null;
    _nipB7 = null;
    _nip57 = null;
    _nip94 = null;
    _nip96 = null;
    _blossom = null;
    _social = null;
  }

  /// Currently bound signer, if any.
  NostrEventSigner? get signer => _signer;

  /// NIP-04 legacy encrypted direct messages.
  ///
  /// Requires a [NostrLocalKeySigner] because kind-4 encryption needs the raw
  /// private key for ECDH.
  NostrNip04 get nip04 =>
      _nip04 ??= NostrNip04.fromSigner(_requireSigner('nip04'));

  /// NIP-17 private direct messages.
  NostrNip17 get nip17 =>
      _nip17 ??= NostrNip17(signer: _requireSigner('nip17'));

  /// NIP-28 public chat channel events.
  NostrNip28 get nip28 =>
      _nip28 ??= NostrNip28(signer: _requireSigner('nip28'));

  /// NIP-39 external identity claims (kind 10011 `i` tags).
  ///
  /// Claim parsing and platform validation are static; publishing and
  /// verification need the bound signer.
  NostrNip39 get nip39 =>
      _nip39 ??= NostrNip39(signer: _requireSigner('nip39'), bech32: nip19);

  /// NIP-46 Nostr Connect (remote signer / bunker) RPC.
  /// Requires a signer because requests are NIP-44 encrypted and kind-24133
  /// events are signed with the client key.
  NostrNip46 get nip46 =>
      _nip46 ??= NostrNip46(signer: _requireSigner('nip46'));

  /// NIP-47 Nostr Wallet Connect request/response helpers.
  ///
  /// Requires a signer because NWC payloads are NIP-44 encrypted and signed
  /// by the client key. For a wallet connection, bind the per-connection
  /// secret with [NostrNip47.forConnection] instead of the identity key.
  NostrNip47 get nip47 =>
      _nip47 ??= NostrNip47(signer: _requireSigner('nip47'));

  /// NIP-98 HTTP authentication tokens.
  NostrNip98 get nip98 =>
      _nip98 ??= NostrNip98(signer: _requireSigner('nip98'));

  /// NIP-54 wiki articles, merge requests, redirects and highlights.
  NostrNip54 get nip54 =>
      _nip54 ??= NostrNip54(signer: _requireSigner('nip54'));

  /// NIP-58 badges: definitions, awards, profile badges and badge sets.
  NostrNip58 get nip58 =>
      _nip58 ??= NostrNip58(signer: _requireSigner('nip58'));

  /// NIP-75 zap goals (kind 9041).
  NostrNip75 get nip75 =>
      _nip75 ??= NostrNip75(signer: _requireSigner('nip75'));

  /// NIP-99 classified listings (kinds 30402/30403).
  NostrNip99 get nip99 =>
      _nip99 ??= NostrNip99(signer: _requireSigner('nip99'));

  /// NIP-B7 Blossom authorization events and URI helpers.
  NostrNipB7 get nipB7 =>
      _nipB7 ??= NostrNipB7(signer: _requireSigner('nipB7'));

  /// NIP-57 Lightning zaps.
  NostrZaps get nip57 => _nip57 ??= NostrZaps(signer: _requireSigner('nip57'));

  /// NIP-94 file metadata events.
  NostrNip94FileMetadata get nip94 =>
      _nip94 ??= NostrNip94FileMetadata(signer: _requireSigner('nip94'));

  /// NIP-96 file storage uploads.
  NostrNip96Uploader get nip96 =>
      _nip96 ??= NostrNip96Uploader(signer: _requireSigner('nip96'));

  /// Blossom media server client.
  NostrBlossomClient get blossom =>
      _blossom ??= NostrBlossomClient(signer: _requireSigner('blossom'));

  /// Signed builders for common social event kinds.
  NostrSocialBuilder get social =>
      _social ??= NostrSocialBuilder(signer: _requireSigner('social'));

  NostrEventSigner _requireSigner(String nip) {
    final bound = _signer;
    if (bound == null) {
      throw StateError(
        'NostrNips.$nip requires a signer. Pass one to '
        'Nostr.connect/addRelays or call nips.bindSigner first.',
      );
    }
    return bound;
  }
}
