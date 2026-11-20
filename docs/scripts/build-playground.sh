#!/usr/bin/env bash
# Build the Flutter Web Nostr playground for /playground/.
# Leaves the release bundle in playground/build/web; Docusaurus assembly is
# owned by the parent workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK_DIR=/tmp/opencode
LOCK_FILE="$LOCK_DIR/nostr-build.lock"

if [[ "${NOSTR_PLAYGROUND_LOCKED:-0}" != "1" ]]; then
  mkdir -p "$LOCK_DIR"
  exec env NOSTR_PLAYGROUND_LOCKED=1 flock "$LOCK_FILE" "$0" "$@"
fi

FLUTTER_BIN="${FLUTTER_BIN:-}"
if [[ -z "$FLUTTER_BIN" ]]; then
  FLUTTER_BIN="$(command -v flutter || true)"
fi
if [[ -z "$FLUTTER_BIN" ]]; then
  for candidate in \
    "$HOME/flutter/bin/flutter" \
    "$HOME/development/flutter/bin/flutter" \
    /opt/flutter/bin/flutter \
    /usr/local/flutter/bin/flutter \
    /tmp/opencode/flutter-sdk/flutter/bin/flutter; do
    if [[ -x "$candidate" ]]; then
      FLUTTER_BIN="$candidate"
      break
    fi
  done
fi
if [[ -z "$FLUTTER_BIN" || ! -x "$FLUTTER_BIN" ]]; then
  echo "error: Flutter SDK not found. Set FLUTTER_BIN=/path/to/flutter." >&2
  exit 1
fi

export PUB_CACHE="${PUB_CACHE:-/tmp/opencode/pub-cache}"
cd "$ROOT"

DART_BIN="$(dirname "$FLUTTER_BIN")/dart"
if [[ ! -x "$DART_BIN" ]]; then
  DART_BIN="$(command -v dart || true)"
fi
if [[ -z "$DART_BIN" || ! -x "$DART_BIN" ]]; then
  echo "error: Dart executable not found next to Flutter or on PATH." >&2
  exit 1
fi

echo "==> SDK relay lifecycle regression"
"$DART_BIN" pub get
"$DART_BIN" test test/nostr/instance/relays/relay_lifecycle_test.dart

cd "$ROOT/playground"

echo "==> Flutter: $FLUTTER_BIN"
"$FLUTTER_BIN" --version
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test
"$FLUTTER_BIN" build web --release --base-href /playground/ \
  --no-wasm-dry-run --no-web-resources-cdn --optimization-level=2

OUT="$ROOT/playground/build/web"

# Flutter still emits a legacy service worker file; this app never registers it.
rm -f "$OUT/flutter_service_worker.js"

for required in index.html main.dart.js flutter_bootstrap.js flutter.js; do
  if [[ ! -f "$OUT/$required" ]]; then
    echo "error: missing $OUT/$required" >&2
    exit 1
  fi
done

grep -q '<base href="/playground/">' "$OUT/index.html" || {
  echo "error: base href is not /playground/" >&2
  exit 1
}

if grep -q 'flutter_service_worker' "$OUT/index.html"; then
  echo "error: a service worker is registered; expected none" >&2
  exit 1
fi

echo "Built: $OUT"
echo "Serve it under /playground/ (for example with python3 -m http.server)."
