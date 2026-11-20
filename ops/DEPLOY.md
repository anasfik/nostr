# nostr.gwhyyy.com deployment

## Observed state, 2026-11-20 (current)

Release `/var/www/nostr/releases/20261120-205215` is selected by
`/var/www/nostr/current`, shipping `dart_nostr 11.2.0` (published
2026-11-20). It merges upstream `385674e` (87/100 NIP coverage, per-NIP
accessors) while keeping this site's shell on Docusaurus 2.4.1.

What changed: 29 documentation routes from upstream (new `features/` and
`reference/` sections, API-accurate guides), 65 documentation links rewritten
to relative `.md` targets so they resolve under `/docs/` instead of upstream's
root `routeBasePath` (build fails on `onBrokenLinks: 'throw'` otherwise),
version copy and checker expectations re-derived for 11.2.0, and the Flutter
console rebuilt against the new SDK.

Evidence:
- docs build `nostr-112-docs-build2` exit 0, client 9.76 s / server 14.11 s,
  `PASS: 30 routes, metadata, discovery files, no unconfigured tracking (site
  only; demo NOT checked)` (`/tmp/opencode/nostr-112-docs-build2.log`).
- Flutter `nostr-112-flutter` exit 0: analyze clean, `75/75` tests, release
  build (`--no-wasm-dry-run --no-web-resources-cdn`, service worker removed),
  `FLUTTER_BUILD_OK` (`/tmp/opencode/nostr-112-flutter.log`).
- Assembled checker `PASS: 30 routes, …, and Flutter artifact`.
- Live metadata sweep `/tmp/opencode/nostr-live-sweep-112.py`:
  `PASS: 30 live routes, canonical, one h1, unique titles and descriptions`.
- Live browser check `nostr-112-live-proof` `18/18 checks passed` (theme,
  search `?q=keys`, mobile docs, playground boot, Project nav, `flutter-view`
  below the 48 px header, no page errors), console proof
  `PASS: refines real Flutter UI signs, validates, reads controlled protocol
  event, cancels publishing, mobile inspector/back, keyboard walk`.
- curl: `/`, `/docs/`, `/docs/installation/`, `/docs/features/signers/`,
  `/docs/reference/nip-coverage/`, `/search/?q=nip-19`, `/playground/`,
  `/sitemap.xml` (30 locs), `/robots.txt`, `/llms.txt`, `/img/social-card.png`
  all 200; `/nope` 404.

Rollback releases retained: `20261118-193000`, `20261118-180832`,
`20261118-180057`, `20261114-084001`, `20261111-155830`.

Deliberately not done: the upstream Docusaurus 3.10.2 + React 19 migration
(this shell's plugins, CSS tokens and browser proofs target 2.4.1); GitHub
Pages stays disabled so `anasfik.github.io/nostr` cannot serve a stale copy;
`gh-pages` branch left untouched.

## Observed state, 2026-11-18 (evening)

Release `/var/www/nostr/releases/20261118-193000` is selected by
`/var/www/nostr/current`. It adds GA4 (`G-2GYP7GFL4D`, property `565042173`)
with denied-by-default consent plus an Accept/Reject banner mounted on every
route, on top of the refined UI. Live verification: 18/18 checks pass
(`nostr-live-refined-check4.log`, headless shell 1234), home/docs/search/
playground/sitemap 200, banner markup and tag loader present in served HTML,
`/nope` 404. Local consent proof 10/10 (`nostr-consent-proof.log`): banner
visible on landing and docs, Accept/Reject persist the choice, tag fires,
no page errors.

Rollback releases retained: `20261118-180832`, `20261118-180057`,
`20261114-084001`, `20261111-155830`.
`/var/www/nostr/current`. It carries the interface refinement: IBM Plex Sans
self-hosted for the site and the Flutter console, one 16 px/1.6 type scale,
68ch prose measure, local `/search/` (noindex, URL-addressable, no service or
dependency), truthful version copy, and a console with real relay presets,
publish blocked without a live relay, 3 px focus rings, stable event-row keys,
mobile list→inspector with Back, and persistent Home/Documentation links.

Live verification (`/tmp/opencode/nostr-live-refined-check.log`, 18/18): IBM
Plex face loads and resolves; one `<h1>`; no overflow at 1440; the theme toggle
sets `data-theme=dark` with html background `rgb(17, 27, 43)`; `/search/?q=keys`
returns key management, stays `noindex, follow` and keeps `q` in the URL; mobile
390 docs do not overflow and code blocks scroll internally; the playground boot
card is removed, `nav[aria-label="Project"]` is present and a hit test at the
canvas top edge returns the nav, not the app (the `flutter-view` rect starts at
y=48); zero page errors.

Rollback releases retained: `20261118-180057` (font/nav defects, live briefly),
`20261114-084001`, `20261111-155830`.

### Resolved defect: webpack font cache baked in the Pages base path

The first 2026-11-18 release served the font from
`/nostr/assets/fonts/…woff2` (404, `document.fonts` status `error`) because
`docs/node_modules/.cache/webpack` still held the asset URL emitted by the
GitHub-Pages-mode build (`BASE_URL=/nostr/`). Clear that cache
(`rm -rf docs/node_modules/.cache/webpack`) after any build that changes
`BASE_URL`, then rebuild. The domain build now emits a root-absolute
`/assets/fonts/…woff2`.

### Resolved defect: the Flutter loader ignored `hostElement`

`flutter_bootstrap.js` passes `config.hostElement`, but Flutter 3.47's loader
does not support it (`grep hostElement` finds nothing in the SDK `flutter.js`),
so it appended `<flutter-view>` to `<body>` and the canvas covered the persistent
Project nav. `playground/web/index.html` now pins `#flutter-host` with
`position:absolute; inset:48px 0 0 0` and forces `flutter-view` to
`position: fixed` starting at `top: 48px`. `docs/scripts/playground-boot.test.cjs`
asserts the rule, so a loader change that drops it fails the test rather than
shipping a covered nav.

### Cosmetic: `.woff2` static duplicate has no MIME mapping

`/fonts/ibm-plex-sans-latin.woff2` is served as `application/octet-stream`
because Ubuntu nginx 1.18 maps only `application/font-woff woff;`. The page does
not request it (CSS loads the hashed `/assets/…` file), so there is no
user-facing effect; fixing it needs an admin edit to `/etc/nginx/mime.types`.

## Previous state, 2026-11-14

Release `/var/www/nostr/releases/20261114-084001` was selected by
`/var/www/nostr/current`, replaced atomically by renaming a fresh symlink over the
old one. It was unpacked from `/tmp/opencode/nostr-site-seo-20261114.tar.gz`,
SHA256 `36c903bf348057f2efad278f67524a5808670f469d8e9e6529394573824ccdf2`.

This release contains the corrected Flutter playground (guarded relay teardown,
bounded untrusted feed, real cleanup on disconnect, working theme toggle) and the
SEO wave (intent-specific guide titles, unique descriptions, short sidebar labels,
80×80 logo derivative with intrinsic dimensions, schema `url`/`sameAs`, indexed
Flutter bootstrap with `noindex, follow`). The `onEose` guide correction is
included.

Verified over public HTTPS with user agent `nostr-release-verification/1.0`:
21 sitemap routes return 200 with unique titles, unique descriptions, exact
self-canonical URLs and one `<h1>`; home serves the landing page, not the tattoo
app; `SoftwareSourceCode` JSON parses with `url` and `sameAs`; playground
`main.dart.js` matches the locally verified build and the page carries
`noindex, follow` plus a self-canonical; discovery files and images return 200;
unknown paths return 404. A live Chromium pass checks the playground boot card is
removed and the theme toggle changes and restores the rendered theme.
Logs: `/tmp/opencode/nostr-live-verify.log`, proofs in
`/tmp/opencode/nostr-seo-proof/`.

### Resolved defect: `.wasm` MIME type blocked the Flutter playground

Ubuntu nginx 1.18 does not map `.wasm` in `/etc/nginx/mime.types`, so
`/playground/canvaskit/*.wasm` and `skwasm*.wasm` are served as
`application/octet-stream`. Chromium then refuses to instantiate them
(`Failed to execute 'compile' on 'WebAssembly': Incorrect response MIME type`)
and the app stays on its loading card. This affects the previous release too;
only the HTML shell was verified live before, while local browser proof ran on
Python's static server, which sends `application/wasm`.

Fix requires one administrator write to nginx configuration, then reload:

```bash
sudo sed -i '0,/^}$/s|^}$|    application/wasm                wasm;\n}|' /etc/nginx/mime.types
sudo nginx -t && sudo systemctl reload nginx
```

Verify with
`curl -sI https://nostr.gwhyyy.com/playground/canvaskit/canvaskit.wasm | grep -i content-type`
which must return `application/wasm`, then reload the playground and confirm the
boot card disappears.

Applied 2026-11-14 and verified: both `canvaskit/canvaskit.wasm` and
`canvaskit/chromium/canvaskit.wasm` return `application/wasm` through Cloudflare
and directly at the origin. The live playground now boots (`#boot` removed),
renders its three panes, and the theme toggle switches to dark and back
(`/tmp/opencode/nostr-live-verify.log`). Any future server that gains this host
needs the same `mime.types` entry before the demo will start.

Access was granted with `setfacl -m u:gw:rwx` on `/var/www/nostr` and
`/var/www/nostr/releases` only. nginx reload is not required for a symlink swap;
none was performed. TLS and the remaining administrator cleanup items are below.

### Relay check note

`wss://relay.damus.io` and `wss://nos.lol` accepted the demo's connection but
returned no events from this host, and `wss://nos.lol` did not complete its
handshake. Direct probes from the same browser reached `wss://relay.primal.net`
(29 events), `wss://relay.snort.social` (17) and `wss://nostr.wine` (3), so this
is a relay/geography issue rather than a client defect. Against
`wss://relay.primal.net` the live demo delivered events normally: the counter
climbed 21 to 79 in ten seconds, the list rendered kind 1 notes with valid
signatures and the JSON inspector showed the raw event
(`/tmp/opencode/nostr-read-live.log`, screenshot
`/tmp/opencode/nostr-browse/read-primal.png`). When a visitor reports an empty
feed, check the relay before the app.

## Prior state, 2026-11-11

The Cloudflare-proxied domain now serves the Nostr site through a dedicated nginx
vhost. The unrelated tattoo app and its existing vhost were left intact.
Current release: `/var/www/nostr/releases/20261111-155830`, selected by
`/var/www/nostr/current`. Origin TLS and public HTTPS were verified; the new
Let's Encrypt certificate expires on 2027-02-09.

All 21 sitemap routes, metadata, discovery files and Flutter entry assets were
verified over public HTTPS. Unknown paths return 404 and HTTP redirects to HTTPS.
Interactive live Flutter verification and the renewal dry-run/reload hook remain
pending. Subsequent source review found playground disconnect/reconnect and
concurrent-session safety defects. The user chose to leave the existing demo
accessible. Corrected source now passes 423 offline SDK tests, 45 Flutter tests,
analysis and a rebuilt release. A real browser verified local signing, read-only
relay interaction, cancelled publishing and disconnect cleanup. The verified
replacement was assembled in `docs/build/` and later deployed as the 2026-11-14
release above; this section records the state before that switch.
Do not treat the 2026-11-11 playground as release-ready. Close any demo tabs
opened against it; it is no longer served.
That earlier release lacked the `onEose` guide correction; the 2026-11-14 release
includes it. One default Python sitemap request received
403; subsequent identified requests and curl returned 200. A later robots.txt
sample returned 200 for verification, Googlebot, OAI-SearchBot and Python user
agents. This is sampled HTTP access, not proof of search indexing or universal
bot access.

The production parent directories were root-owned. Write access is now granted to
`gw` on `/var/www/nostr` and `/var/www/nostr/releases` only, so the next release
can repeat the atomic directory-plus-symlink switch. Writable files inside a
release are still not a reason to update it piecemeal.

Administrator follow-up: remove the two temporary probe files
`/var/www/certbot/probe` and `/var/www/certbot/.well-known/acme-challenge/probe`.
The temporary broad sudo grant was revoked; `/etc/sudoers.d/ship-nostr` is now an
empty root-owned file and can be removed by an administrator. Privileged access
again requires secure administrator authorization. Rotate any credential exposed
in chat or command history; do not reuse it here.

This is a static site. A Node/Flutter development-server reverse proxy would add
an unnecessary process and expose a development server. Nginx serves one assembled
release: Docusaurus at `/`, documentation at `/docs/`, Flutter Web at `/playground/`.

## Build locally

From `docs/`, use Node 22+ and run `npm ci`, `npm run build`, then `node scripts/check-site.mjs --site-only`.
Build the playground using `bash docs/scripts/build-playground.sh` from the repo
root (see `playground/README.md` for Flutter requirements). Assemble its generated
files into `docs/build/playground/` **after** building Docusaurus. Run
`node scripts/check-site.mjs` from `docs/` to check the assembled artifact. Do not deploy a
landing with a missing playground. Preview the assembled directory with
`npm run serve -- --host 127.0.0.1 --port 8899` from `docs/`.

## Approval-gated administrator steps

These are a runbook, not an automatically executed script. Obtain approval before
each production phase. Never put a sudo password in a command, file, or chat.

1. Record the existing enabled nginx sites and previous `current` symlink target.
   Create `/var/www/nostr/releases/` and `/var/www/certbot/` with appropriate
   ownership. Copy the assembled, verified build into a **new** release directory.
   Nginx's `www-data` user needs directory traversal and file read permissions.
   Never serve a directory being rebuilt.
2. Install `ops/nginx/nostr-http.conf` as
   `/etc/nginx/sites-available/nostr.gwhyyy.com` and enable a same-named symlink.
   Run `sudo nginx -t` before `sudo systemctl reload nginx` (separate commands).
   Verify a temporary ACME challenge file is retrievable through the public
   domain, then remove only that test file. Bootstrap deliberately returns 503
   outside the challenge path until TLS is ready.
3. Request the certificate only after HTTP routing is verified:

   ```sh
   sudo /home/gw/.local/bin/certbot certonly --webroot -w /var/www/certbot -d nostr.gwhyyy.com
   ```

   Use the secure interactive prompt for account/email/terms if required. Do not
   borrow an unrelated certificate or disable TLS checks. If Cloudflare blocks
   the challenge, inspect the domain-specific rule before proposing changes.
4. Atomically point `/var/www/nostr/current` to the completed release. Replace the
   host's bootstrap config with `ops/nginx/nostr.conf`. Check the referenced
   certificate/options paths exist, run `sudo nginx -t`, then separately reload.
5. Verify origin TLS with SNI and public Cloudflare HTTPS. Confirm this site's
   title, not merely HTTP 200. Check `/`, `/docs/`, a deep guide, `/playground/`,
   Flutter JS/WASM assets, `/robots.txt`, `/sitemap.xml`, `/llms.txt`, social card,
   and an unknown URL returning **404**, plus HTTP → HTTPS. Inspect both browser
   consoles and the actual relay read workflow. Do not publish a public event
   without explicit approval.
6. Certbot timer is present, but renewal for this new certificate must be
   verified with a scoped `certbot renew --cert-name nostr.gwhyyy.com --dry-run`.
   Arrange an nginx reload deploy hook after renewal; test it with administrator
   approval. Do not claim renewal works merely because the timer exists.

## Rollback

Keep the previous release and vhost backup. Restore the previous `current` target
atomically; test nginx before reloading if configuration changed. For a failed
first deployment, disable only the new nostr vhost and restore its prior absence.
Do not delete certificates, other sites, release history, or the old Pages branch.

## GitHub Pages

Existing `gh-pages` deployment remains untouched. The Actions build explicitly sets
`SITE_URL=https://anasfik.github.io` and `BASE_URL=/nostr/`; it is not the production
domain release pipeline. Actions billing was previously locked. Domain-root links
and the Flutter `/playground/` build target are for the custom domain; do not deploy
this assembled domain build onto a repository-path Pages site. A future Pages
migration needs redirect mapping for old deep links, not a blind artifact copy.
