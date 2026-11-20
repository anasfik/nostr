---
title: Social events
sidebar_position: 1
description: Build and sign notes, replies, profiles, follow lists, reactions, reposts and comments with nostr.nips.social.
---

# Social events

`nostr.nips.social` is a `NostrSocialBuilder`. Every method returns a signed
`NostrEvent`; nothing is published for you. The builder is signer-bound, so it
exists only after `nostr.connect(..., signer: ...)` or `nostr.nips.bindSigner`.

## What the layer provides

| Method | Kind | NIP |
| --- | --- | --- |
| `createTextNote` | 1 | 01, 10, 14, 27 |
| `updateProfile` | 0 | 01, 24 |
| `updateFollowList` | 3 | 02 |
| `createDeletionRequest` | 5 | 09 |
| `createRepost` | 6 | 18 |
| `createReaction` | 7 | 25 |
| `createComment` | 1111 | 22 |
| `updateRelayList` | 10002 | 65 |
| `createLongFormArticle` | 30023 | 23 |
| `createListEvent` | caller-supplied | 51 |

Threading follows NIP-10: `createTextNote` writes `e` tags marked `root` and
`reply` plus a `p` tag for the author you answer. Mentions are `p` tags only —
you put the `nostr:` URI in the content yourself. `createReaction` defaults to
`+` and accepts a `k` tag through `targetKind`. `createDeletionRequest` accepts
`kind:pubkey:d` coordinates for addressable events in addition to event ids.

## Example: a short thread

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final signer = NostrLocalKeySigner(nostr.keys.generateKeyPair());

  final connection = await nostr.connect(
    ['wss://relay.damus.io'],
    signer: signer,
  );

  final failure = connection.failureOrNull;
  if (failure != null) {
    print('${failure.code}: ${failure.message}');
    return;
  }

  final note = await nostr.nips.social.createTextNote(
    'A note written by the documentation example.',
    subject: 'Docs example',
  );

  final reply = await nostr.nips.social.createTextNote(
    'A reply to the note above.',
    replyTo: (
      eventId: note.id!,
      authorPubkey: note.pubkey,
      rootEventId: note.id,
    ),
  );

  final comment = await nostr.nips.social.createComment(
    content: 'A kind 1111 comment on the note.',
    targetEventId: note.id,
    targetAuthorPubkey: note.pubkey,
    targetKind: 1,
    relayUrl: 'wss://relay.damus.io',
  );

  final reaction = await nostr.nips.social.createReaction(
    targetEventId: note.id!,
    targetAuthorPubkey: note.pubkey,
    targetKind: '1',
  );

  final repost = await nostr.nips.social.createRepost(
    note: note,
    relayUrl: 'wss://relay.damus.io',
  );

  for (final event in [note, reply, comment, reaction, repost]) {
    final result = await nostr.publish(event);
    result.fold(
      (receipt) => print('${event.kind} accepted: ${receipt.isEventAccepted}'),
      (failure) => print('${event.kind} failed: ${failure.message}'),
    );
  }

  final parsed = NostrComment.tryParse(comment);
  print('${parsed?.rootEventId} ${parsed?.parentEventId}');

  nostr.nips.bindSigner(null);
  await nostr.disconnect();
}
```

## Example: profile, follows, article and lists

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final signer = NostrLocalKeySigner(nostr.keys.generateKeyPair());
  nostr.nips.bindSigner(signer);

  final profile = await nostr.nips.social.updateProfile(
    name: 'docs-example',
    displayName: 'Docs Example',
    about: 'Account used by the documentation.',
    lud16: 'example@getalby.com',
  );

  final follows = await nostr.nips.social.updateFollowList(
    followedPubkeys: [signer.publicKey],
    relayHints: {'wss://relay.damus.io': 'wss://relay.damus.io'},
  );

  final article = await nostr.nips.social.createLongFormArticle(
    content: 'The body of the article.',
    dTagIdentifier: 'docs-example-article',
    title: 'Docs example article',
    summary: 'One paragraph of context.',
    hashtags: ['nostr', 'dart'],
  );

  final relays = await nostr.nips.social.updateRelayList(
    relays: {
      'wss://relay.damus.io': (read: true, write: true),
      'wss://nos.lol': (read: true, write: false),
    },
  );

  final muteList = await nostr.nips.social.createListEvent(
    kind: 10000,
    entries: [
      ['p', signer.publicKey],
    ],
  );

  print([profile.kind, follows.kind, article.kind, relays.kind, muteList.kind]);
}
```

## Comments and the kind 1111 migration

`createComment` builds NIP-22 comments. Pass exactly one root family:

- event scope: `rootEventId` (optional when commenting directly on a target),
  `rootAuthorPubkey`, `rootKind`
- address scope: `rootAddress` and/or `parentAddress` as `kind:pubkey:d`
- external scope: `rootExternalId` and/or `parentExternalId` plus `externalKind`

Mixing families throws `ArgumentError`, and empty content throws
`ArgumentError`. Root values land in uppercase tags (`K`/`E`/`A`/`I`) and the
direct parent in lowercase (`k`/`e`/`a`/`i`). Comments were kind 22 in older
versions of this package and of NIP-22; the current kind is 1111, so filter on
1111 and read the `K`/`E` root tags rather than assuming the parent is the
root. `NostrComment.tryParse` returns `null` for the wrong kind or for a
mixture of root families; `NostrComment.parse` throws `ArgumentError`.

## Limits

- The builder signs; it does not send. You call `nostr.publish`, and a relay
  may still reject the event.
- `updateFollowList` writes the list you pass. It does not read your previous
  kind-3 event and merge it, so a partial list silently unfollows everyone you
  left out.
- `updateProfile` replaces the whole kind-0 document. Fields you omit
  disappear from your profile.
- `createDeletionRequest` is a request. Relays may keep the event; NIP-09 has
  no enforcement.
- `createRepost` serialises the event you pass and requires a `relayUrl`. It
  does not fetch the note, and it does not verify its signature.
- Mentions are not parsed out of content. You supply `mentionedPubkeys`; a
  mismatch between the content and the tags is yours to fix.
- `NostrComment.tryParse` checks tag shape only. It does not verify the
  signature or check that the referenced root exists.

See [NIP coverage](../reference/nip-coverage.md) for the neighbouring kinds and
[Publishing events](../usage/relays-and-events/publishing-events.md) for receipt
handling.
