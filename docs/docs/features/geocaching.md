---
title: Geocaching
sidebar_position: 4
description: NIP-CC cache listings, logs, verification events and curation lists through nostr.nips.nipCC.
---

# Geocaching

`nostr.nips.nipCC` implements NIP-CC. Templates are unsigned; `publish` signs
with the bound signer, and a verification event can be signed by a different
key through `publishVerification`.

The four template generators and the ordering helpers are static, so call them
on the class (`NostrNipCC.generateCacheTemplate`, `NostrNipCC.claimWinner`);
`publish` and `publishVerification` are methods on `nostr.nips.nipCC`.

## What the layer provides

| Kind | Purpose | Generator |
| --- | --- | --- |
| 37516 | cache listing (addressable) | `generateCacheTemplate` |
| 7516 | found log | `generateFoundLogTemplate` |
| 1111 | comment log: `dnf`, `note`, `maintenance`, `archived` | `generateCommentTemplate` |
| 7517 | verification of physical presence | `generateVerificationTemplate` |
| 37517 | curation list (addressable) | `generateCurationTemplate` |

Typed parsers: `NostrGeocache`, `NostrGeocacheFoundLog`,
`NostrGeocacheComment`, `NostrGeocacheVerification`, `NostrGeocacheCuration`,
each with `parse` and `tryParse`. Helpers: `sortVerifiedFinds`,
`firstVerifiedFind`, `claimWinner`, `validateVerifiedFind`,
`encodeEventJson`, `decodeEventJson`.

Listing tags are constrained: geohashes are 3–9 characters from the geohash
alphabet and at least one is required, `size` is `micro`, `small`, `regular`,
`large` or `other`, `difficulty` and `terrain` are 1–5, and `type` defaults to
`traditional`. A first-to-find `F` tag requires both the `first-to-find`
modifier and a `verification` key, or the builder throws `ArgumentError`.

## Example: listing, verification and found log

The verification key is not the finder's identity key. Keep it separate and
sign kind 7517 with it.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final ownerKeys = nostr.keys.generateKeyPair();
  final finderKeys = nostr.keys.generateKeyPair();
  final verificationKeys = nostr.keys.generateKeyPair();

  final ownerSigner = NostrLocalKeySigner(ownerKeys);
  final finderSigner = NostrLocalKeySigner(finderKeys);
  final verificationSigner = NostrLocalKeySigner(verificationKeys);

  final connection = await nostr.connect(
    ['wss://relay.damus.io'],
    signer: ownerSigner,
  );

  final failure = connection.failureOrNull;
  if (failure != null) {
    print('${failure.code}: ${failure.message}');
    return;
  }

  final cacheDraft = NostrNipCC.generateCacheTemplate(
    dTag: 'docs-example-cache',
    name: 'Documentation example cache',
    geohashes: ['9q8yyk'],
    difficulty: 2,
    terrain: 3,
    size: 'small',
    hint: 'Under the bench.',
    verificationPubkey: verificationKeys.public,
  );
  final cacheDraftSigned = await nostr.nips.nipCC.publish(cacheDraft);

  final cacheAddress = NostrEventAddress(
    kind: NostrNipCC.cacheKind,
    pubkey: ownerKeys.public,
    identifier: 'docs-example-cache',
  );

  final verificationDraft = NostrNipCC.generateVerificationTemplate(
    finderPubkey: finderKeys.public,
    cache: cacheAddress,
  );
  final verification = await nostr.nips.nipCC.publishVerification(
    verificationDraft,
    verificationSigner: verificationSigner,
  );

  final foundDraft = NostrNipCC.generateFoundLogTemplate(
    cache: cacheAddress,
    content: 'Found it after ten minutes.',
    verification: verification,
  );

  nostr.nips.bindSigner(finderSigner);
  final found = await nostr.nips.nipCC.publish(foundDraft);

  for (final event in [cacheDraftSigned, found]) {
    final result = await nostr.publish(event);
    result.fold(
      (receipt) => print('${event.kind} accepted: ${receipt.isEventAccepted}'),
      (failure) => print('${event.kind} failed: ${failure.message}'),
    );
  }

  final cache = NostrGeocache.parse(cacheDraftSigned);
  final log = NostrGeocacheFoundLog.parse(found);
  final ordered = NostrNipCC.sortVerifiedFinds([log], cache: cache);
  print('verified finds: ${ordered.length}');
  print('winner: ${NostrNipCC.claimWinner(cache: cache, logs: [log])}');

  nostr.nips.bindSigner(null);
  await nostr.disconnect();
}
```

## Example: curation list, comment log and embedded JSON

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final signer = NostrLocalKeySigner(nostr.keys.generateKeyPair());
  nostr.nips.bindSigner(signer);

  final first = NostrEventAddress(
    kind: NostrNipCC.cacheKind,
    pubkey: signer.publicKey,
    identifier: 'first-cache',
  );
  final second = NostrEventAddress(
    kind: NostrNipCC.cacheKind,
    pubkey: signer.publicKey,
    identifier: 'second-cache',
  );

  final curation = NostrNipCC.generateCurationTemplate(
    dTag: 'docs-example-tour',
    title: 'Documentation example tour',
    geocaches: [first, second],
    geohashes: ['9q8yy'],
    theme: 'adventure',
    mapStyle: 'dark',
  );

  final comment = NostrNipCC.generateCommentTemplate(
    cache: first,
    content: 'Searched for twenty minutes and gave up.',
    logType: 'dnf',
  );

  final commentParsed = NostrGeocacheComment.tryParse(comment);
  final embedded = NostrNipCC.encodeEventJson(comment);
  final decoded = NostrNipCC.decodeEventJson(embedded);

  print([curation.kind, commentParsed?.logType, decoded?.kind]);
}
```

Curation geohashes are limited to 3–6 characters, `theme` to `adventure` or
`mojave`, and `map` to `original`, `dark`, `satellite` or `adventure`.
`encodeEventJson` omits `id`, because the embedded form in CC.md carries only
`kind`, `content`, `tags`, `pubkey`, `created_at` and `sig`.

## Limits

- No cryptographic verification happens in `sortVerifiedFinds` or
  `claimWinner`. A find counts as verified when its embedded kind-7517 proof
  parses and its author equals the cache `verificationPubkey`. Call
  `isVerified()` on the verification event for the signature check.
- Winner selection therefore requires the proof author to equal the cache
  verification key. A proof signed by anybody else, including the finder, is
  ignored.
- `NostrGeocacheVerificationRef` checks the `naddr` shape
  (`naddr1` plus bech32 characters) and does not decode its checksum.
  `validateVerifiedFind` does decode it, but only when you ask.
- `decodeEventJson` needs a JSON object with integer `kind` and string
  `pubkey`. Anything else returns `null` rather than throwing.
- The listing does not derive lifecycle state from logs. `archived` is only
  reflected when the `t` tag says so, and `firstToFind` only from an explicit
  `F` tag.
- `NostrGeocacheComment` expects root and parent tags to point at the same
  cache, as CC.md specifies for top-level logs. Nested replies are not modelled.
- Images and relay hints are non-empty strings. The library does not check that
  they resolve.
