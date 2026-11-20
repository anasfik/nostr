---
title: Media
sidebar_position: 5
description: imeta metadata, file metadata, picture-first posts, video and voice messages, with NIP-96 and Blossom clients.
---

# Media

Media support is split by job: NIP-92 describes attachments inside an event,
NIP-94 publishes metadata about a hosted file, NIP-68/71/A0 define the post
kinds, and NIP-96 plus Blossom move bytes to a server. The builders never touch
the network. Upload is a separate, opt-in HTTP call.

## What the layer provides

| Surface | Accessor | Kind | Role |
| --- | --- | --- | --- |
| NIP-92 `imeta` | `nostr.nips.nip92` | any | parse and match attachment metadata |
| NIP-94 file metadata | `nostr.nips.nip94` | 1063 | `createFileMetadata` |
| NIP-96 upload | `nostr.nips.nip96` | 24242 auth | `resolveApiUrl`, `upload` |
| Blossom | `nostr.nips.blossom` | 24242 auth | `headBlob`, `getBlob`, `uploadBlob`, `listBlobs` |
| NIP-68 picture-first | `nostr.nips.nip68` | 20 | `buildImage`, `generateTemplate`, `publish` |
| NIP-71 video | `nostr.nips.nip71` | 21, 22, 34235, 34236 | `generateTemplate`, `publish` |
| NIP-A0 voice | `nostr.nips.nipa0` | 1222, 1244 | `createVoiceMessage`, `createVoiceReply`, `publish` |

The NIP-92 helpers are static, so call `NostrNip92.parseAll` and
`NostrNip92.forProfileField` on the class; there is nothing to bind.

`NostrImeta` is the attachment model: `url`, `m`, `x`, `dim`, `alt`,
`blurhash`, `service`, repeatable `fallback` and `image` values, and `extras`
for every other key. `NostrNip92.parseAll(event)` returns the valid `imeta`
tags in order, and `NostrNip92.forProfileField(event, 'picture')` resolves the
tag that describes a kind-0 profile image.

## Example: picture-first post

NIP-68 accepts only `image/apng`, `image/avif`, `image/gif`, `image/jpeg`,
`image/png` and `image/webp`, and requires at least one `imeta` with a URL.

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

  final image = NostrNip68.buildImage(
    url: 'https://example.com/photo.jpg',
    mime: 'image/jpeg',
    alt: 'A bench under a tree',
    dim: '1600x1200',
    blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
  );

  final draft = NostrNip68.generateTemplate(
    title: 'Bench',
    images: [image],
    description: 'Morning light on the square.',
    hashtags: ['photography'],
  );

  final event = await nostr.nips.nip68.publish(draft);
  final result = await nostr.publish(event);
  result.fold(
    (receipt) => print('accepted: ${receipt.isEventAccepted}'),
    (failure) => print('failed: ${failure.message}'),
  );

  for (final imeta in NostrNip92.parseAll(event)) {
    print('${imeta.url} ${imeta.m} ${imeta.alt}');
  }

  nostr.nips.bindSigner(null);
  await nostr.disconnect();
}
```

## Example: attachment tags, video, voice and file metadata

```dart
import 'package:dart_nostr/dart_nostr.dart';

Future<void> main() async {
  final nostr = Nostr();
  final signer = NostrLocalKeySigner(nostr.keys.generateKeyPair());
  nostr.nips.bindSigner(signer);

  // NIP-92: build a tag by hand and read it back.
  final attachment = NostrImeta.parse([
    'imeta',
    'url https://example.com/clip.mp4',
    'm video/mp4',
    'dim 1080x1920',
    'alt A short clip',
  ]);
  print('${attachment.url} ${attachment.dim} ${attachment.isValid}');

  // NIP-71: kind 22 short video, media carried in imeta.
  final videoDraft = nostr.nips.nip71.generateTemplate(
    title: 'Documentation example clip',
    description: 'Ten seconds of nothing in particular.',
    kind: 22,
    url: 'https://example.com/clip.mp4',
    mime: 'video/mp4',
    dim: '1080x1920',
    duration: 10,
    hashtags: ['nostr'],
  );
  final video = await nostr.nips.nip71.publish(videoDraft);
  final parsedVideo = NostrVideoEvent.parse(video);
  print('${parsedVideo.kind} ${parsedVideo.duration}');

  // NIP-A0: the content is the absolute audio URL, imeta is optional.
  final voiceDraft = NostrNipA0.createVoiceMessage(
    audioUrl: 'https://example.com/voice.ogg',
    waveform: const [0, 4, 9, 12, 7, 3],
    duration: 6,
  );
  final voice = await nostr.nips.nipa0.publish(voiceDraft);
  final parsedVoice = NostrNipA0.tryParse(voice);
  print('${parsedVoice?.waveform.length} ${parsedVoice?.duration}');

  // NIP-94: metadata about a file somebody else hosts.
  final metadata = await nostr.nips.nip94.createFileMetadata(
    url: 'https://example.com/clip.mp4',
    mimeType: 'video/mp4',
    sizeBytes: 5242880,
    sha256Hex: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
    dimensions: const ['1080', '1920'],
    title: 'Documentation example clip',
  );
  print('${metadata.kind} ${metadata.tags?.first.join(' ')}');
}
```

A voice reply uses kind 1244 and the NIP-22 tag layout:
`NostrNipA0.createVoiceReply` requires `parentEventId`, `parentAuthorPubkey`
and `parentKind` as 64-character hex and an integer kind, and accepts
`rootEventId`, `rootAuthorPubkey` and `rootKind` when the thread root differs
from the parent.

## Uploading

Building a media event performs no upload: `generateTemplate`,
`createVoiceMessage` and `createFileMetadata` construct and validate tags only.
If you want the package to send the bytes, two clients exist:

```text
nostr.nips.nip96.resolveApiUrl(serverRootUrl) -> Future<String?>
nostr.nips.nip96.upload({apiUrl, bytes, fileName, contentType, validFor}) -> Future<String>
nostr.nips.blossom.uploadBlob({serverUrl, bytes, sha256Hex, contentType, validFor}) -> Future<Map<String, dynamic>>
```

Both sign a kind-24242 authorization event internally and send it in an
`authorization: Nostr <base64>` header. Neither computes the SHA-256 for you:
`uploadBlob` requires `sha256Hex`, and `upload` needs the bytes you already
have. Everything past the single request — retries, resumable uploads,
authorization renewal, mirroring to a second server, deletion — belongs to your
own HTTP client. NIP-96 is deprecated upstream in favour of Blossom but is
still deployed.

## Limits

- No upload happens while an event is built. The only network calls are the
  explicit `nip96` and `blossom` methods above, and each performs exactly one
  request.
- Nothing validates that the bytes match `x`, `size` or `m`. The library never
  sees the file unless you pass it to an upload client.
- There is no MIME sniffing, no image or video probing for `dim`, `duration`,
  `bitrate` or `waveform`. You supply them; a wrong value stays wrong.
- NIP-68 rejects any `imeta` whose `m` is not an accepted image type, and
  rejects an event without an image. Audio and video do not belong in kind 20.
- NIP-A0 requires `content` to be an absolute `http` or `https` URL. Builders
  throw `ArgumentError` for anything else, and reject a waveform of 100 or more
  samples or a non-positive `duration`.
- NIP-71 requires `d` for the addressable kinds (34235, 34236) and forbids it
  on the regular kinds (21, 22).
- `NostrImeta.isValid` only requires a non-empty `url` plus one other non-empty
  field. It does not check that `m` and `x` are well formed.
