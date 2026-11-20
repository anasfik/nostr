---
title: Cashu wallets
sidebar_position: 2
description: NIP-60 wallet state and NIP-61 nutzaps through nostr.nips.nip60 and nostr.nips.nip61.
---

# Cashu wallets

Two accessors cover ecash: `nostr.nips.nip60` for wallet state and
`nostr.nips.nip61` for mint recommendations and nutzaps. Both are
signer-bound, because NIP-60 payloads are NIP-44 encrypted to your own public
key and NIP-61 events are signed by you.

## What the layer provides

NIP-60 (`NostrNip60`):

| Kind | Purpose | Methods |
| --- | --- | --- |
| 17375 | wallet state, replaceable | `createWalletEvent`, `parseWalletEvent`, `tryParseWalletEvent` |
| 7375 | unspent token proofs | `createTokenEvent`, `parseTokenEvent`, `tryParseTokenEvent` |
| 7376 | spending history | `createHistoryEvent`, `parseHistoryEvent`, `tryParseHistoryEvent` |
| 7374 | in-flight mint quote | `createQuoteEvent`, `parseQuoteEvent`, `tryParseQuoteEvent` |

NIP-61 (`NostrNip61`):

| Kind | Purpose | Methods |
| --- | --- | --- |
| 10019 | accepted relays and mints, plus the P2PK key | `createMintRecommendation`, `parseMintRecommendation`, `tryParseMintRecommendation` |
| 9321 | nutzap carrying P2PK-locked proofs | `createNutzap`, `parseNutzap`, `tryParseNutzap`, `verifyNutzapStructure` |

Supporting types: `NostrCashuWallet({privateKey, mints})`,
`NostrCashuTokenEvent({mint, proofs, unit, del})`,
`NostrCashuProof({id, amount, secret, C, unblindedSignature, dleq})`,
`NostrCashuHistoryEntry`, `NostrCashuSpendPlan`, `NostrMintRef`.

NIP-60 keeps wallet state and history encrypted, so the bound signer must be
able to NIP-44 encrypt and decrypt to its own public key. A local key signer
does. A remote signer must expose self-addressed `nip44_encrypt` and
`nip44_decrypt`; otherwise the calls throw `StateError`.

## Example: wallet, token, spend plan

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

  const mintUrl = 'https://mint.example.com';

  final wallet = NostrCashuWallet(
    privateKey: nostr.keys.generateKeyPair().private,
    mints: const [mintUrl],
  );
  final walletEvent = await nostr.nips.nip60.createWalletEvent(wallet: wallet);

  // Placeholder proofs: a real wallet fills these from its mint.
  final token = NostrCashuTokenEvent(
    mint: mintUrl,
    proofs: const [
      NostrCashuProof(
        id: '009a1f3f0f0c9f0e',
        amount: 64,
        secret: 'cashu-secret-one',
        C: '02placeholder',
      ),
      NostrCashuProof(
        id: '009a1f3f0f0c9f0e',
        amount: 32,
        secret: 'cashu-secret-two',
        C: '03placeholder',
      ),
    ],
  );
  final tokenEvent = await nostr.nips.nip60.createTokenEvent(token: token);

  for (final event in [walletEvent, tokenEvent]) {
    final result = await nostr.publish(event);
    result.fold(
      (receipt) => print('${event.kind} accepted: ${receipt.isEventAccepted}'),
      (failure) => print('${event.kind} failed: ${failure.message}'),
    );
  }

  final restored = await nostr.nips.nip60.parseWalletEvent(walletEvent);
  print('mints: ${restored.mints}');

  final plan = NostrNip60.planSpend(proofs: token.proofs, amount: 64);
  print('sufficient: ${plan.sufficient}, spent: ${plan.spent.length}');

  if (plan.sufficient) {
    final change = await nostr.nips.nip60.rolloverTokenEvent(
      previousEventId: tokenEvent.id!,
      token: token,
      spentProofs: plan.spent,
    );

    final history = await nostr.nips.nip60.createHistoryEvent(
      entries: [
        NostrCashuHistoryEntry(
          direction: NostrCashuHistoryEntry.outgoing,
          amount: 64,
          eventId: tokenEvent.id!,
          kind: NostrCashuHistoryEntry.destroyed,
        ),
      ],
    );

    print([change.kind, history.kind]);
  }

  nostr.nips.bindSigner(null);
  await nostr.disconnect();
}
```

## Example: mint recommendation and nutzap

The P2PK key for a NIP-61 nutzap is a compressed `02`-prefixed key. When you
omit `p2pkPubkey`, `createMintRecommendation` derives it as
`02` + your x-only public key, which is the same form nutzaps expect.

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

  final p2pkKey = '02${signer.publicKey}';

  final recommendationEvent =
      await nostr.nips.nip61.createMintRecommendation(
    relayUrl: 'wss://relay.damus.io',
    mints: const [NostrMintRef(url: 'https://mint.example.com')],
  );

  // NUT-11 P2PK secrets are a JSON string array. Real proofs come from a mint.
  final lockedProof = NostrCashuProof(
    id: '009a1f3f0f0c9f0e',
    amount: 21,
    secret: '["P2PK",{"data":"$p2pkKey","nonce":"docs-example"}]',
    C: p2pkKey,
  );

  print(NostrNip61.p2pkLockForProof(lockedProof));

  final nutzap = await nostr.nips.nip61.createNutzap(
    recipient: signer.publicKey,
    mintUrl: 'https://mint.example.com',
    proofs: [lockedProof],
    p2pkKey: p2pkKey,
    comment: 'Thanks for the note.',
  );

  for (final event in [recommendationEvent, nutzap]) {
    final result = await nostr.publish(event);
    result.fold(
      (receipt) => print('${event.kind} accepted: ${receipt.isEventAccepted}'),
      (failure) => print('${event.kind} failed: ${failure.message}'),
    );
  }

  final recommendation = NostrNip61.parseMintRecommendation(recommendationEvent);
  final parsed = NostrNip61.parseNutzap(nutzap);
  final verification = NostrNip61.verifyNutzapStructure(
    nutzap: parsed,
    recommendation: recommendation,
  );
  print(verification.problems);

  nostr.nips.bindSigner(null);
  await nostr.disconnect();
}
```

`createNutzap` rejects a `p2pkKey` that is not 66 characters with an `02`
prefix, and rejects any proof whose secret is not P2PK-locked to that same key.
`verifyNutzapStructure` re-checks the recipient against the recommendation
author, the mint and unit against the recommendation, the key prefix and the
proof locks, and returns every problem it finds in `problems`.

## Limits

- A local key or a signer with self `nip44_encrypt`/`nip44_decrypt` is required
  for NIP-60. Remote signers commonly do not implement self-addressed NIP-44,
  and then every wallet call throws `StateError`.
- There is no DLEQ proof verification. `NostrCashuProof.dleq` is preserved as
  received, never checked.
- There is no mint HTTP client. Nothing contacts a mint, redeems proofs,
  requests quotes, or checks proof states.
- There is no spend or burn execution. `planSpend` only selects proofs and
  returns them as a `NostrCashuSpendPlan`; the caller publishes the token,
  history and NIP-09 deletion. `rolloverTokenEvent` builds the replacement
  token and records `del`, but the old token event stays on relays until you
  publish its deletion with `NostrNip60.createDeleteTemplate`.
- `planSpend` is mint- and unit-agnostic and greedy. Group proofs per mint and
  unit first, and treat the plan as a selection, not a balance.
- Malformed ciphertext is a content problem, not a configuration one:
  `parseWalletEvent` and the other `parse*` methods throw `FormatException`,
  while the `tryParse*` variants return `null`.
- `verifyNutzapStructure` is structural. It does not verify event signatures
  and does not prove the proofs are unspent.
