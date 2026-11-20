---
title: Live activities
sidebar_position: 3
description: NIP-53 streams, chat, rooms, meetings and presence through nostr.nips.nip53.
---

# Live activities

`nostr.nips.nip53` builds and signs NIP-53 events. The generators return
unsigned `NostrEvent` templates; `publish` signs with the bound signer, and
sending the signed event is a separate `nostr.publish` call.

## What the layer provides

| Kind | Purpose | Generator |
| --- | --- | --- |
| 30311 | live activity (addressable) | `generateLiveEvent` |
| 1311 | live chat message | `generateChatMessage` |
| 30312 | room / space (addressable) | `generateRoom` |
| 30313 | meeting inside a room (addressable) | `generateMeeting` |
| 10312 | room presence (replaceable) | `generatePresence` |

Typed parsers mirror the kinds: `parseLiveEvent`, `parseChatMessage`,
`parseRoom`, `parseMeeting`, `parsePresence`, plus `tryParse*` variants that
return `null` instead of throwing `ArgumentError`. The classes are also usable
directly as `NostrLiveEvent.parse(event)` and so on.

Tags follow NIP-53: `d`, `title`, `summary`, `image`, `t`, `streaming`,
`recording`, `starts`, `ends`, `status`, `current_participants`,
`total_participants`, `p` participants, `relays` and `pinned`. Participants use
`["p", pubkey, relay, role, proof]` and `NostrLiveParticipant` pads the
intermediate slots so `role` and `proof` stay positional.

## Example: publish a stream and a chat message

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

  final starts = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final activityDraft = nostr.nips.nip53.generateLiveEvent(
    dTag: 'docs-example-stream',
    title: 'Documentation example stream',
    summary: 'A stream built by the docs example.',
    hashtags: ['nostr'],
    streamingUrl: 'https://example.com/live.m3u8',
    starts: starts,
    status: 'live',
    currentParticipants: 1,
    participants: [
      NostrLiveParticipant(
        pubkey: signer.publicKey,
        relay: 'wss://relay.damus.io',
        role: NostrLiveParticipant.hostRole,
      ),
    ],
    relays: ['wss://relay.damus.io'],
  );

  final activity = await nostr.nips.nip53.publish(activityDraft);
  final activityAddress = NostrLiveEvent.parse(activity).address!;

  final chatDraft = nostr.nips.nip53.generateChatMessage(
    activityAddress: activityAddress,
    activityRelay: 'wss://relay.damus.io',
    content: 'Hello from the documentation example.',
  );
  final message = await nostr.nips.nip53.publish(chatDraft);

  for (final event in [activity, message]) {
    final result = await nostr.publish(event);
    result.fold(
      (receipt) => print('${event.kind} accepted: ${receipt.isEventAccepted}'),
      (failure) => print('${event.kind} failed: ${failure.message}'),
    );
  }

  final parsed = NostrLiveChatMessage.tryParse(message);
  print(parsed?.activityAddress);

  nostr.nips.bindSigner(null);
  await nostr.disconnect();
}
```

## Example: rooms and status parsing

A room requires a `room` name, a `status` of `open`, `private` or `closed`, a
`service` URL and at least one provider with the `Host` role. Omitting the name
is a hard error since 11.2.0.

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final signer = NostrLocalKeySigner(nostr.keys.generateKeyPair());
  nostr.nips.bindSigner(signer);

  final roomDraft = nostr.nips.nip53.generateRoom(
    dTag: 'docs-example-room',
    roomName: 'Documentation room',
    status: 'open',
    serviceUrl: 'https://example.com/room',
    participants: [
      NostrLiveParticipant(
        pubkey: signer.publicKey,
        role: NostrLiveParticipant.hostRole,
      ),
    ],
  );
  final room = NostrLiveRoom.parse(roomDraft);
  print('${room.roomName} ${room.status} ${room.hasHost}');

  final legacy = NostrEvent(
    id: null,
    kind: NostrLiveKind.liveEvent,
    content: '',
    sig: null,
    pubkey: signer.publicKey,
    createdAt: DateTime.now(),
    tags: [
      ['d', 'legacy-status'],
      ['status', 'on-hold'],
    ],
  );
  final parsed = NostrLiveEvent.tryParse(legacy);
  print('${parsed?.status} ${parsed?.rawStatus}');
}
```

`generateLiveEvent` accepts only `planned`, `live` or `ended` and throws
`ArgumentError` for anything else. The parser is more tolerant: an unknown
`status` value parses to `status == null`, with the original text kept in
`rawStatus`, so a client can show the value it does not understand.

## Limits

- Generators return unsigned events. `nostr.nips.nip53.publish` only signs;
  call `nostr.publish` yourself, and expect relay rejections.
- `parse*` validates tags, not signatures. Call `isVerified()` on the event if
  authenticity matters.
- Participant proofs are optional and only checked when you call
  `verifyParticipantProof` or `verifyProof(coordinate: ...)`. The library does
  not require them, and relays are free to ignore the field.
- A chat message needs a kind-30311 `a` tag that resolves to a valid address.
  Messages for kinds other than a live activity are rejected.
- `pinned` values are copied as given; no message is fetched or validated.
- The library does not talk to a streaming or media server. `streaming`,
  `recording`, `service` and `endpoint` are strings you supply.
- `generateRoom` also requires a `Host` participant; a room without one fails
  validation even if the tags are otherwise correct.
