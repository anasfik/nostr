# Nostr debug playground

A real Flutter Web console for `dart_nostr` (`path: ../`). It connects to
public relays on demand, subscribes to reads, generates ephemeral keys, signs
and verifies events locally, and publishes only after an explicit confirmation.

## Run

```bash
export PATH=/path/to/flutter/bin:$PATH
cd playground
flutter pub get
flutter run -d chrome
```

No relay is contacted until you press **Connect**.

## Build for `/playground/`

```bash
docs/scripts/build-playground.sh
```

The release bundle lands in `playground/build/web`. Serve it under
`/playground/` because the build uses `--base-href /playground/`:

```bash
mkdir -p /tmp/playground-site
ln -sfn "$PWD/playground/build/web" /tmp/playground-site/playground
(cd /tmp/playground-site && python3 -m http.server 8099)
# open http://127.0.0.1:8099/playground/
```

Parent assembly owns copying this into the Docusaurus build. The script does
not touch `docs/` output.

## Tests

```bash
flutter analyze
flutter test
```

Tests cover WSS-only relay validation, key generation, signing, ID and
signature verification, tampered events, bounded logs, filter validation,
publish confirmation gating, error states and responsive layout. SDK lifecycle
tests use a local WebSocket server; no test publishes to a public relay.

## Security and data handling

- Keys are generated with `NostrKeyPairs.generate()` and live in memory only.
  They are dropped on reload and when an established relay session is
  disconnected; cancelling a pending connection keeps them. Disconnecting an
  established session also clears the locally signed event. Keys are never
  written to storage.
- Private keys are never displayed, logged or sent anywhere. Signed events
  contain only public fields, the event ID and the signature.
- Relay content is untrusted and rendered as plain text, never HTML. Oversized
  events are dropped before retention.
- Logs contain operation metadata and event IDs, not key material.
- Publishing uses kind/content/tags chosen by you and requires a live
  connection, the confirmation dialog and `confirmed: true` in the controller.
  The SDK surfaces the first relay response; other relay outcomes may differ.

## Limits

Core workflow only: connect, read, sign, verify, publish. No wallet or zaps,
DMs/NIP-17, NIP-42 AUTH, key import, persistence, NIP-05 or media uploads.
WSS only, max 3 relays, max 100 feed events, 200 log lines, 5000 compose
characters, 20 compose tags and a 100-event read limit. Relay events are capped
at 256 KiB, 65,536 content characters, 100 tags and 32 KiB of tag text before
retention. Connection and publishing timeouts are bounded. Remaining SDK
registry limits are count-based, so a count cap alone does not bound payload
bytes. The browser build has no service worker and no analytics.
