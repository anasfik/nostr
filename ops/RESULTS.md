# Nostr delivery results — 2026-11-11

## Outcome and remaining gates

- **Live routing is fixed:** https://nostr.gwhyyy.com/ serves the Nostr landing, `/docs/` serves its guides, and `/playground/` serves the initial Flutter demo. The tattoo app was not changed.
- **Corrected replacement is verified locally, not deployed:** production remains `/var/www/nostr/releases/20261111-155830`. Its Flutter JS hash differs from the corrected bundle. Do not call the older live playground release-ready. The user chose to leave it accessible while fixes proceed.
- **Package upload attempted, not published:** clean-tree validation passes. Upload reached Google publisher authorization and timed out waiting for the owner. Subsequent pub.dev API check shows latest `10.0.1` and no `11.0.0`.
- **Source preserved:** feature commits `f450695` and `77063e5`; no push, merge or tag move. Original main checkout remains untouched.
- Google Search Console authentication fails; Analytics authorization is expired/revoked. No tracking script, indexing submission or marketing post was published.

## Checks and observed evidence

| Check | Result | Evidence |
|---|---|---|
| `dart test --concurrency=1 --reporter=expanded`, public-network and archive opt-ins disabled | PASS: 423 | `/tmp/opencode/nostr-offline-tests.log` |
| Original-SDK disconnect/backoff regression | Expected FAIL, proving regression sensitivity | `/tmp/opencode/nostr-regression-red.log` |
| `dart analyze lib test example` | PASS: no errors/warnings; 1,136 existing style infos | `/tmp/opencode/nostr-sdk-analyze.log` |
| `bash docs/scripts/build-playground.sh` with the recorded Flutter executable | PASS: 9 lifecycle tests, clean Flutter analysis, 45 Flutter tests, release build | `/tmp/opencode/nostr-playground-verified-build.log` |
| First-click system-light theme regression before fix | Expected FAIL; both system modes pass after fix | `/tmp/opencode/nostr-theme-red.log` and final Flutter suite |
| `npm run build` from docs | PASS | `/tmp/opencode/nostr-docs-final-build.log` |
| `node scripts/check-site.mjs` from docs | PASS: 21 routes, metadata, discovery and assembled Flutter assets | Final assembled `docs/build/` |
| `RUN_PACKAGE_ARCHIVE_CHECK=1 dart test test/package_archive_test.dart --concurrency=1 --reporter=expanded` | PASS: 2, including actual clean-tree pub dry-run; archive 147 KB | `/tmp/opencode/nostr-archive-clean.log` |
| Real Chromium landing: 1440/390, light/dark, keyboard focus, docs deep link | PASS; no page errors or horizontal page overflow | `/tmp/opencode/nostr-browser-proof/browser-check.json` and screenshots |
| Real Flutter browser: ephemeral key, signing, storage, read-only REQ/CLOSE, cancel publishing, disconnect | PASS; no EVENT sent | `/tmp/opencode/nostr-browser-proof/playground-browser.json` |
| Final Flutter offline browser, including actual dark appearance | PASS; no connections or page errors | `/tmp/opencode/nostr-playground-offline-browser.log` and final mobile screenshots |
| Public HTTPS sitemap routes and unknown URL | PASS: 21 routes, exact canonical links, one H1; unknown route 404 | `/tmp/opencode/nostr-browser-proof/final-live-check.json` |
| `dart pub publish --force` | BLOCKED: publisher OAuth required, no release confirmed | CLI authorization prompt; subsequent public API check |
| Final code reviews | PASS for scoped source changes; README correction applied | DS 4.1 lifecycle/controller and final build/theme reviews |

The successful public-relay read was followed by a connection timeout on a later
run. Relay availability is external; no public event was posted. Full hostile-relay
load testing, a fresh Lighthouse audit, a real screen reader, minimum Dart 3.0
compatibility and certificate renewal/reload-hook verification were not performed.
The playground bounds retained feed/log data; the underlying SDK wire parser is
not a byte-bounded hostile-input sandbox.

## Ready-to-install artifact

- `/tmp/opencode/nostr-site-f450695.tar.gz`
- SHA-256: `99dfb89da2d2dee98995aa3b9efc2c1ef986ceb64a2045c3295ff054cdd95dde`
- Verified local Flutter JS: `e852aaaabd92fd58cd96c143d0212de9aa66f4959ed408b58909e19cb9678d27`
- Observed live Flutter JS: `4cc952bd36f038743b3d7c9d04fb2524975ccfda043dc7fefdd5886a7b10c654`

## Human-only actions

1. Grant narrowly scoped release-directory access through a secure administrator
   terminal, or have the administrator perform the atomic release switch in
   `ops/DEPLOY.md`. The previously reported grant was not present when checked:
   both production parent directories remain non-writable to `gw`.
2. Complete pub.dev publisher Google authorization in the owner's secure terminal
   before resuming the validated upload. Do not paste credentials or authorization
   codes into chat. The earlier OAuth link is no longer a usable running session.
3. Reconnect GSC/GA through their proper authorization UI before account changes,
   sitemap submission or tracking activation.
4. Rotate any credential exposed earlier. Administrator cleanup and scoped
   certificate-renewal verification are recorded in `ops/DEPLOY.md`.

## Changed-file manifest

Each entry names the file and the reason; generated build trees and credentials
are not committed.

- `.agents/product-marketing.md:1` — evidence-based package positioning and limits.
- `.github/workflows/docs-pages.yml:1` — preserve Pages base path and run site checks.
- `.gitignore:9` — retain the Flutter application lockfile without a pub warning.
- `.pubignore:1` — exclude local sites, operations and generated artifacts from pub.
- `CHANGELOG.md:1` — record relay teardown and package-archive fixes.
- `README.md:1` — current domain, 11.0.0 installation guidance and accurate result handling.
- `docs/README.md:1` — document local build, assembly and deployment boundaries.
- `docs/docs/installation.md:1` — distinguish published package from source preview.
- `docs/docs/must-know.md:1` — replace obsolete initialization advice with current lifecycle guidance.
- `docs/docs/quick-start.md:1` — resolve source-relative guide links correctly.
- `docs/docs/usage/advanced/client-options.md:1` — correct retry defaults.
- `docs/docs/usage/advanced/error-handling.md:1` — document actual result, failure and retry types.
- `docs/docs/usage/advanced/low-level-api.md:1` — correct transport setup and EOSE callback.
- `docs/docs/usage/identity/nip19.md:1` — use actual Bech32 method names and arguments.
- `docs/docs/usage/keys-management/bech32-encoding.md:1` — correct APIs and stop logging private keys.
- `docs/docs/usage/relays-and-events/subscribing-to-events.md:1` — correct filters and subscription lifetime example.
- `docs/docusaurus.config.js:1` — production origin, `/docs/`, metadata and discovery output.
- `docs/marketing/launch.md:1` — prepare announcement, listing copy and measured launch plan.
- `docs/marketing/tracking.md:1` — record auth blockers and privacy-safe tracking requirements.
- `docs/package-lock.json:1` — align the Node engine declaration.
- `docs/package.json:1` — require Node 22 for supported build APIs.
- `docs/scripts/build-playground.sh:1` — reproducible tested Flutter build and safety gates.
- `docs/scripts/check-site.mjs:1` — executable route, metadata, discovery and assembly assertions.
- `docs/src/css/custom.css:1` — coherent light/dark tokens, focus and contrast corrections.
- `docs/src/pages/index.jsx:1` — package landing, guide links and real-time demo entry.
- `docs/src/pages/index.module.css:1` — responsive landing layout and interaction styles.
- `docs/static/img/social-card.png:1` — branded social preview using the existing logo.
- `docs/superpowers/plans/2026-11-11-domain-site.md:1` — execution and verification record.
- `lib/nostr/instance/relays/relays.dart:1` — invalidate stale handshakes/reconnects during teardown.
- `ops/DEPLOY.md:1` — atomic deployment, rollback, renewal and access runbook.
- `ops/RESULTS.md:1` — final evidence, artifact hashes and remaining gates.
- `ops/nginx/nostr-http.conf:1` — host-specific ACME bootstrap configuration.
- `ops/nginx/nostr.conf:1` — host-specific TLS and static route configuration.
- `ops/playground-safety-fix-brief.md:1` — explicit safety contracts and regression scope.
- `playground/.gitignore:1` — exclude generated Flutter state.
- `playground/.metadata:1` — record the Flutter project's tool metadata.
- `playground/README.md:1` — setup, operation, safety boundaries and feature inventory.
- `playground/analysis_options.yaml:1` — Flutter static-analysis configuration.
- `playground/lib/main.dart:1` — application theme and correct system-mode toggle.
- `playground/lib/src/nostr_tools.dart:1` — validated filters, local crypto and bounded event helpers.
- `playground/lib/src/playground_controller.dart:1` — session lifecycle, bounded feed/logs and explicit publication state.
- `playground/lib/src/playground_page.dart:1` — responsive relay/key/event/debug interface and publish confirmation.
- `playground/pubspec.lock:1` — lock application dependency versions.
- `playground/pubspec.yaml:1` — use Flutter and the repository's Dart SDK directly.
- `playground/test/main_test.dart:1` — first-click theme regressions in both system modes.
- `playground/test/nostr_tools_test.dart:1` — crypto, filter and payload-bound checks.
- `playground/test/playground_controller_test.dart:1` — races, teardown, bounds and publication-state checks.
- `playground/test/playground_page_test.dart:1` — real widget interactions and responsive states.
- `playground/web/favicon.png:1` — web application favicon.
- `playground/web/flutter_bootstrap.js:1` — Flutter loading/failure bootstrap.
- `playground/web/icons/Icon-192.png:1` — web application icon.
- `playground/web/icons/Icon-512.png:1` — high-resolution web application icon.
- `playground/web/icons/Icon-maskable-192.png:1` — maskable application icon.
- `playground/web/icons/Icon-maskable-512.png:1` — high-resolution maskable icon.
- `playground/web/index.html:1` — loading, failure and no-JavaScript recovery links.
- `playground/web/manifest.json:1` — accurate playground app metadata.
- `pubspec.yaml:1` — canonical homepage and documentation URLs.
- `test/fake_relay_server.dart:1` — observable server-side WebSocket closure for real lifecycle tests.
- `test/nostr/instance/relays/relay_lifecycle_test.dart:1` — teardown, cancellation, backoff and reconnect regressions.
- `test/package_archive_test.dart:1` — actual pub dry-run archive exclusion checks.
