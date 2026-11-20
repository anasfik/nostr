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
import 'package:dart_nostr/nostr/nips/nip24/nip24.dart';
import 'package:dart_nostr/nostr/nips/nip27/nip27.dart';
import 'package:dart_nostr/nostr/nips/nip28/nip28.dart';
import 'package:dart_nostr/nostr/nips/nip29/nip29.dart';
import 'package:dart_nostr/nostr/nips/nip30/nip30.dart';
import 'package:dart_nostr/nostr/nips/nip32/nip32.dart';
import 'package:dart_nostr/nostr/nips/nip34/nip34.dart';
import 'package:dart_nostr/nostr/nips/nip35/nip35.dart';
import 'package:dart_nostr/nostr/nips/nip36/nip36.dart';
import 'package:dart_nostr/nostr/nips/nip37/nip37.dart';
import 'package:dart_nostr/nostr/nips/nip38/nip38.dart';
import 'package:dart_nostr/nostr/nips/nip39/nip39.dart';
import 'package:dart_nostr/nostr/nips/nip42/nip42.dart';
import 'package:dart_nostr/nostr/nips/nip43/nip43.dart';
import 'package:dart_nostr/nostr/nips/nip45/nip45.dart';
import 'package:dart_nostr/nostr/nips/nip46/nip46.dart';
import 'package:dart_nostr/nostr/nips/nip47/nip47.dart';
import 'package:dart_nostr/nostr/nips/nip48/nip48.dart';
import 'package:dart_nostr/nostr/nips/nip52/nip52.dart';
import 'package:dart_nostr/nostr/nips/nip53/nip53.dart';
import 'package:dart_nostr/nostr/nips/nip54/nip54.dart';
import 'package:dart_nostr/nostr/nips/nip55/nip55.dart';
import 'package:dart_nostr/nostr/nips/nip56/nip56.dart';
import 'package:dart_nostr/nostr/nips/nip57/nip57.dart';
import 'package:dart_nostr/nostr/nips/nip58/nip58.dart';
import 'package:dart_nostr/nostr/nips/nip5a/nip5a.dart';
import 'package:dart_nostr/nostr/nips/nip60/nip60.dart';
import 'package:dart_nostr/nostr/nips/nip61/nip61.dart';
import 'package:dart_nostr/nostr/nips/nip62/nip62.dart';
import 'package:dart_nostr/nostr/nips/nip64/nip64.dart';
import 'package:dart_nostr/nostr/nips/nip66/nip66.dart';
import 'package:dart_nostr/nostr/nips/nip68/nip68.dart';
import 'package:dart_nostr/nostr/nips/nip69/nip69.dart';
import 'package:dart_nostr/nostr/nips/nip70/nip70.dart';
import 'package:dart_nostr/nostr/nips/nip71/nip71.dart';
import 'package:dart_nostr/nostr/nips/nip73/nip73.dart';
import 'package:dart_nostr/nostr/nips/nip75/nip75.dart';
import 'package:dart_nostr/nostr/nips/nip77/nip77.dart';
import 'package:dart_nostr/nostr/nips/nip78/nip78.dart';
import 'package:dart_nostr/nostr/nips/nip7d/nip7d.dart';
import 'package:dart_nostr/nostr/nips/nip85/nip85.dart';
import 'package:dart_nostr/nostr/nips/nip86/nip86.dart';
import 'package:dart_nostr/nostr/nips/nip87/nip87.dart';
import 'package:dart_nostr/nostr/nips/nip88/nip88.dart';
import 'package:dart_nostr/nostr/nips/nip89/nip89.dart';
import 'package:dart_nostr/nostr/nips/nip92/nip92.dart';
import 'package:dart_nostr/nostr/nips/nip94/nip94.dart';
import 'package:dart_nostr/nostr/nips/nip96/nip96.dart';
import 'package:dart_nostr/nostr/nips/nip98/nip98.dart';
import 'package:dart_nostr/nostr/nips/nip99/nip99.dart';
import 'package:dart_nostr/nostr/nips/nipa0/nipa0.dart';
import 'package:dart_nostr/nostr/nips/nipa3/nipa3.dart';
import 'package:dart_nostr/nostr/nips/nipa4/nipa4.dart';
import 'package:dart_nostr/nostr/nips/nipad/nipad.dart';
import 'package:dart_nostr/nostr/nips/nipb0/nipb0.dart';
import 'package:dart_nostr/nostr/nips/nipb7/nipb7.dart';
import 'package:dart_nostr/nostr/nips/nipc0/nipc0.dart';
import 'package:dart_nostr/nostr/nips/nipc7/nipc7.dart';
import 'package:dart_nostr/nostr/nips/nipcc/nipcc.dart';
import 'package:dart_nostr/nostr/nips/nipcd/nipcd.dart';
import 'package:dart_nostr/nostr/nips/nipf4/nipf4.dart';
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
/// templates are unsigned, so [nip29] needs no signer. NIP-60 and NIP-61 are
/// signer-bound because wallet state and nutzap recommendations are encrypted
/// or signed by the bound key.
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

  /// NIP-24 extra metadata fields and tags.
  late final NostrNip24 nip24 = const NostrNip24();

  /// NIP-35 torrent indexes and comments.
  ///
  /// Stateless: templates are unsigned, so no signer is needed.
  late final NostrNip35 nip35 = const NostrNip35();

  /// NIP-36 sensitive content / content warnings.
  late final NostrNip36 nip36 = const NostrNip36();

  /// NIP-37 draft wraps, checkpoints and private relay lists.
  ///
  /// Requires a signer that can NIP-44 encrypt and decrypt to its own public
  /// key. Remote signers must support self-addressed NIP-44 operations.
  NostrNip37 get nip37 =>
      _nip37 ??= NostrNip37(signer: _requireSigner('nip37'));

  /// NIP-38 user statuses (kind 30315).
  NostrNip38 get nip38 =>
      _nip38 ??= NostrNip38(signer: _requireSigner('nip38'));

  /// NIP-43 relay access metadata and join/leave requests.
  ///
  /// Stateless: relay keys are not user keys, so nothing is signer-bound.
  /// Publishing a join or leave request takes the signer as an argument.
  late final NostrNip43 nip43 = const NostrNip43();

  /// NIP-70 protected events (`['-']` tag).
  late final NostrNip70 nip70 = const NostrNip70();

  /// NIP-73 external content ids (`i`/`k` tags).
  ///
  /// Stateless: tag helpers and filters take no signer.
  late final NostrNip73 nip73 = const NostrNip73();

  /// NIP-92 media attachment metadata (`imeta` tags).
  late final NostrNip92 nip92 = const NostrNip92();

  /// NIP-66 relay liveness monitoring.
  ///
  /// Stateless and read-only: monitoring data never gates relay connections.
  late final NostrNip66 nip66 = const NostrNip66();

  /// NIP-AD web address pointer resolution.
  late final NostrNipAD nipAD = NostrNipAD();

  NostrEventSigner? _signer;
  NostrNip04? _nip04;
  NostrNip17? _nip17;
  NostrNip28? _nip28;
  NostrNip32? _nip32;
  NostrNip37? _nip37;
  NostrNip38? _nip38;
  NostrNip39? _nip39;
  NostrNip46? _nip46;
  NostrNip47? _nip47;
  NostrNip52? _nip52;
  NostrNip53? _nip53;
  NostrNip54? _nip54;
  NostrNip56? _nip56;
  NostrNip58? _nip58;
  NostrNip60? _nip60;
  NostrNip61? _nip61;
  NostrNip62? _nip62;
  NostrNip64? _nip64;
  NostrNip68? _nip68;
  NostrNip69? _nip69;
  NostrNip71? _nip71;
  NostrNip75? _nip75;
  NostrNip78? _nip78;
  NostrNip85? _nip85;
  NostrNip87? _nip87;
  NostrNip88? _nip88;
  NostrNip89? _nip89;
  NostrNip98? _nip98;
  NostrNip99? _nip99;
  NostrNipA4? _nipA4;
  NostrNipB0? _nipB0;
  NostrNipB7? _nipB7;
  NostrNipCC? _nipCC;
  NostrNip34? _nip34;
  NostrNip86? _nip86;
  NostrNipA0? _nipA0;
  NostrNipCd? _nipCD;
  NostrNipF4? _nipF4;
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
    _nip32 = null;
    _nip37 = null;
    _nip38 = null;
    _nip39 = null;
    _nip46 = null;
    _nip47 = null;
    _nip52 = null;
    _nip53 = null;
    _nip54 = null;
    _nip56 = null;
    _nip58 = null;
    _nip60 = null;
    _nip61 = null;
    _nip62 = null;
    _nip64 = null;
    _nip68 = null;
    _nip69 = null;
    _nip71 = null;
    _nip75 = null;
    _nip78 = null;
    _nip85 = null;
    _nip87 = null;
    _nip88 = null;
    _nip89 = null;
    _nip98 = null;
    _nip99 = null;
    _nipA4 = null;
    _nipB0 = null;
    _nipB7 = null;
    _nipCC = null;
    _nip34 = null;
    _nip86 = null;
    _nipA0 = null;
    _nipCD = null;
    _nipF4 = null;
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

  /// NIP-32 kind 1985 label events.
  NostrNip32 get nip32 =>
      _nip32 ??= NostrNip32(signer: _requireSigner('nip32'));

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

  /// NIP-48 `proxy` tags on bridged events.
  ///
  /// Stateless: the tag helper works on any event kind and takes no signer.
  late final NostrNip48 nip48 = const NostrNip48();

  /// NIP-98 HTTP authentication tokens.
  NostrNip98 get nip98 =>
      _nip98 ??= NostrNip98(signer: _requireSigner('nip98'));

  /// NIP-52 calendar events, calendars and RSVPs.
  NostrNip52 get nip52 =>
      _nip52 ??= NostrNip52(signer: _requireSigner('nip52'));

  /// NIP-53 live activities: streams, chat, rooms, meetings and presence.
  NostrNip53 get nip53 =>
      _nip53 ??= NostrNip53(signer: _requireSigner('nip53'));

  /// NIP-5A static website manifests and snapshots.
  ///
  /// Stateless: pass the signer to [NostrNip5a.publish] per call.
  late final NostrNip5a nip5a = const NostrNip5a();

  /// NIP-54 wiki articles, merge requests, redirects and highlights.
  NostrNip54 get nip54 =>
      _nip54 ??= NostrNip54(signer: _requireSigner('nip54'));

  /// NIP-56 kind 1984 reports.
  NostrNip56 get nip56 =>
      _nip56 ??= NostrNip56(signer: _requireSigner('nip56'));

  /// NIP-58 badges: definitions, awards, profile badges and badge sets.
  NostrNip58 get nip58 =>
      _nip58 ??= NostrNip58(signer: _requireSigner('nip58'));

  /// NIP-60 cashu wallet state.
  ///
  /// Requires a signer that can NIP-44 encrypt and decrypt to its own public
  /// key. Remote signers must support self-addressed NIP-44 operations.
  NostrNip60 get nip60 =>
      _nip60 ??= NostrNip60(signer: _requireSigner('nip60'));

  /// NIP-61 mint recommendations and nutzaps.
  NostrNip61 get nip61 =>
      _nip61 ??= NostrNip61(signer: _requireSigner('nip61'));

  /// NIP-62 requests to vanish (kind 62).
  NostrNip62 get nip62 =>
      _nip62 ??= NostrNip62(signer: _requireSigner('nip62'));

  /// NIP-64 chess games as PGN notes (kind 64).
  NostrNip64 get nip64 =>
      _nip64 ??= NostrNip64(signer: _requireSigner('nip64'));

  /// NIP-68 picture-first feeds (kind 20).
  NostrNip68 get nip68 =>
      _nip68 ??= NostrNip68(signer: _requireSigner('nip68'));

  /// NIP-69 peer-to-peer order events (kind 38383).
  NostrNip69 get nip69 =>
      _nip69 ??= NostrNip69(signer: _requireSigner('nip69'));

  /// NIP-71 video events (kinds 21/22/34235/34236).
  NostrNip71 get nip71 =>
      _nip71 ??= NostrNip71(signer: _requireSigner('nip71'));

  /// NIP-75 zap goals (kind 9041).
  NostrNip75 get nip75 =>
      _nip75 ??= NostrNip75(signer: _requireSigner('nip75'));

  /// NIP-78 custom app data (kinds 78/30078).
  NostrNip78 get nip78 =>
      _nip78 ??= NostrNip78(signer: _requireSigner('nip78'));

  /// NIP-7D forum threads (kind 11).
  ///
  /// Stateless: templates are unsigned, so no signer is needed.
  late final NostrNip7d nip7d = const NostrNip7d();

  /// NIP-C7 chat messages (kind 9).
  ///
  /// Stateless: templates are unsigned, so no signer is needed.
  late final NostrNipC7 nipc7 = const NostrNipC7();

  /// NIP-B0 web bookmarks (kind 39701).
  NostrNipB0 get nipB0 =>
      _nipB0 ??= NostrNipB0(signer: _requireSigner('nipB0'));

  /// NIP-CC geocaching (kinds 37516/37517/7516/7517/1111).
  NostrNipCC get nipCC =>
      _nipCC ??= NostrNipCC(signer: _requireSigner('nipCC'), bech32: nip19);

  /// NIP-34 git repositories, patches, pull requests, issues and statuses.
  NostrNip34 get nip34 =>
      _nip34 ??= NostrNip34(signer: _requireSigner('nip34'));

  /// NIP-86 relay management JSON-RPC client.
  ///
  /// Requires a signer because every request is authorized with NIP-98.
  NostrNip86 get nip86 =>
      _nip86 ??= NostrNip86(signer: _requireSigner('nip86'));

  /// NIP-A0 voice messages and voice replies.
  NostrNipA0 get nipa0 =>
      _nipA0 ??= NostrNipA0(signer: _requireSigner('nipa0'));

  /// NIP-CD slash commands, lists and invocations.
  NostrNipCd get nipcd => _nipCD ??= NostrNipCd(
        signer: _requireSigner('nipcd'),
        bech32: nip19,
      );

  /// NIP-F4 podcasts: metadata, authored lists and episodes.
  NostrNipF4 get nipf4 =>
      _nipF4 ??= NostrNipF4(signer: _requireSigner('nipf4'));

  /// NIP-A3 payment targets (kind 10133).
  ///
  /// Stateless: templates are unsigned, so no signer is needed.
  late final NostrNipA3 nipa3 = const NostrNipA3();

  /// NIP-C0 code snippets (kind 1337).
  ///
  /// Stateless: templates are unsigned, so no signer is needed.
  late final NostrNipC0 nipc0 = const NostrNipC0();

  /// NIP-A4 public messages (kind 24).
  NostrNipA4 get nipa4 =>
      _nipA4 ??= NostrNipA4(signer: _requireSigner('nipa4'));

  /// NIP-85 trusted assertions and provider recommendations.
  NostrNip85 get nip85 =>
      _nip85 ??= NostrNip85(signer: _requireSigner('nip85'));

  /// NIP-87 cashu and fedimint discoverability (kinds 38000/38172/38173).
  NostrNip87 get nip87 =>
      _nip87 ??= NostrNip87(signer: _requireSigner('nip87'));

  /// NIP-88 polls (kinds 1068/1018).
  NostrNip88 get nip88 =>
      _nip88 ??= NostrNip88(signer: _requireSigner('nip88'));

  /// NIP-89 recommended application handlers (kinds 31989/31990).
  NostrNip89 get nip89 =>
      _nip89 ??= NostrNip89(signer: _requireSigner('nip89'));

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
