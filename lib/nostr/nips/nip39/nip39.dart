import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/nips/nip19/nip19.dart';
import 'package:dart_nostr/nostr/signers/signer.dart';
import 'package:http/http.dart' as http;

/// {@template nip39_claim}
/// One `["i", "<platform>:<identity>", "<proof>"]` claim (NIP-39).
/// {@endtemplate}
class Nip39IdentityClaim {
  /// {@macro nip39_claim}
  const Nip39IdentityClaim({
    required this.platform,
    required this.identity,
    required this.proof,
  });

  /// Parses `platform:identity` and a proof.
  ///
  /// Returns `null` when the value has no `platform:identity` shape.
  static Nip39IdentityClaim? tryParse(String platformIdentity, String proof) {
    final separator = platformIdentity.indexOf(':');
    if (separator <= 0 || separator == platformIdentity.length - 1) {
      return null;
    }
    return Nip39IdentityClaim(
      platform: platformIdentity.substring(0, separator),
      identity: platformIdentity.substring(separator + 1),
      proof: proof,
    );
  }

  /// Platform name (`github`, `twitter`, `mastodon`, ...).
  final String platform;

  /// Identity on that platform (username, `instance/@user`, user id).
  final String identity;

  /// Proof pointing at the published verification text.
  final String proof;

  /// `platform:identity` value used in the `i` tag.
  String get platformIdentity => '$platform:$identity';

  @override
  String toString() => 'Nip39IdentityClaim($platformIdentity, $proof)';
}

/// {@template nip39}
/// NIP-39 external identity claims ("linking profiles to other platforms").
///
/// Claims are `i` tags of the form
/// `["i", "<platform>:<identity>", "<proof>"]` published in a kind 10011
/// event (older drafts used kind 0; [parseClaims] accepts any event carrying
/// `i` tags, so both keep working).
///
/// Implemented:
/// - claim parsing/serialization and platform-name validation
/// - proof URLs for github, twitter, mastodon, telegram, bluesky, discord
/// - GitHub verification against the gist raw URL
///
/// Not implemented (gaps): live verification for twitter, mastodon, telegram,
/// bluesky and discord is left to the caller — [verifyClaim] throws an
/// [UnsupportedError] for them, and those platforms' APIs need auth or
/// scraping. Proof text only carries the npub form, as the spec requires.
///
/// ```dart
/// final nip39 = NostrNip39(signer: signer, bech32: Nostr.instance.nips.nip19);
/// final ok = await nip39.verifyGithub(
///   npub: 'npub1...',
///   username: 'alice',
///   proof: 'abc123',
/// );
/// ```
/// {@endtemplate}
class NostrNip39 {
  /// {@macro nip39}
  ///
  /// [bech32] encodes the pubkey into npub for [verificationText]. Without it
  /// hex pubkeys are used, which the spec does not recommend.
  NostrNip39({
    required this.signer,
    NostrBech32? bech32,
    http.Client? httpClient,
  })  : _bech32 = bech32,
        _httpClient = httpClient;

  /// Signer used to publish the identity list.
  final NostrEventSigner signer;

  final NostrBech32? _bech32;
  final http.Client? _httpClient;

  /// Kind of the identity proofs event (NIP-51 list).
  static const int kind = 10011;

  /// Provider names only allow `a-z`, `0-9` and `._-/`, and never `:`.
  static final RegExp platformRegex = RegExp(r'^[a-z0-9._\-/]+$');

  /// Whether [platform] is a valid NIP-39 provider name.
  static bool isValidPlatform(String platform) =>
      platformRegex.hasMatch(platform);

  /// Parses every well-formed `i` tag of [event].
  static List<Nip39IdentityClaim> parseClaims(NostrEvent event) {
    final claims = <Nip39IdentityClaim>[];
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length < 3 || tag[0] != 'i') {
        continue;
      }
      final claim = Nip39IdentityClaim.tryParse(tag[1], tag[2]);
      if (claim != null) {
        claims.add(claim);
      }
    }
    return claims;
  }

  /// The exact verification text for [npub].
  static String verificationText(String npub) =>
      'Verifying that I control the following Nostr public key: $npub';

  /// Whether [proofText] contains the published npub.
  ///
  /// Per the spec clients accept any proof by `<identity>` that contains the
  /// user's npub, since earlier versions used different wording.
  static bool containsVerificationText(String proofText, String npub) =>
      proofText.contains(npub);

  /// Public URL where the proof for [claim] is published, if known.
  static Uri? proofUrl(Nip39IdentityClaim claim) {
    switch (claim.platform) {
      case 'github':
        return Uri.parse(
          'https://gist.github.com/${claim.identity}/${claim.proof}',
        );
      case 'twitter':
        return Uri.parse(
          'https://twitter.com/${claim.identity}/status/${claim.proof}',
        );
      case 'mastodon':
        return Uri.parse('https://${claim.identity}/${claim.proof}');
      case 'telegram':
        return Uri.parse('https://t.me/${claim.proof}');
      case 'bluesky':
        return Uri.parse(
          'https://bsky.app/profile/${claim.identity}/post/${claim.proof}',
        );
      case 'discord':
        return Uri.parse('https://discord.com/channels/${claim.proof}');
      default:
        return null;
    }
  }

  /// Builds the `i` tag for [claim].
  static List<String> identityTag(Nip39IdentityClaim claim) =>
      ['i', claim.platformIdentity, claim.proof];

  /// npub (or hex) representation of [pubkey] used in verification text.
  String npubOf(String pubkey) {
    final bech32 = _bech32;
    if (bech32 == null || pubkey.startsWith('npub')) {
      return pubkey;
    }
    return bech32.encodePublicKeyToNpub(pubkey);
  }

  /// Builds and signs a kind 10011 identity proofs event.
  Future<NostrEvent> publishIdentityProofs({
    required List<Nip39IdentityClaim> claims,
    List<List<String>> extraTags = const [],
    DateTime? createdAt,
  }) {
    return signer.sign(
      NostrEvent(
        id: null,
        kind: kind,
        content: '',
        sig: null,
        pubkey: signer.publicKey,
        createdAt: createdAt ?? DateTime.now(),
        tags: [
          for (final claim in claims) identityTag(claim),
          ...extraTags,
        ],
      ),
    );
  }

  /// Fetches a GitHub gist and checks the verification text for [pubkey].
  ///
  /// The proof is accepted when the gist body contains the user's npub, which
  /// matches both the current and the legacy verification wording.
  Future<bool> verifyGithub({
    required String pubkey,
    required String username,
    required String proof,
  }) async {
    final uri = Uri.parse('https://gist.github.com/$username/$proof/raw');
    try {
      final response = await (_httpClient?.get(uri) ?? http.get(uri));
      if (response.statusCode != 200) {
        return false;
      }
      return containsVerificationText(response.body, npubOf(pubkey));
    } on Object catch (_) {
      return false;
    }
  }

  /// Verifies [claim] for [pubkey].
  ///
  /// Only `github` is supported; other platforms throw [UnsupportedError].
  Future<bool> verifyClaim({
    required Nip39IdentityClaim claim,
    required String pubkey,
  }) {
    switch (claim.platform) {
      case 'github':
        return verifyGithub(
          pubkey: pubkey,
          username: claim.identity,
          proof: claim.proof,
        );
      default:
        throw UnsupportedError(
          'NIP-39 verification for "${claim.platform}" is not implemented; '
          'use proofUrl() and verify out of band.',
        );
    }
  }
}
