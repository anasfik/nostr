# Nostr domain site implementation plan

**Goal:** Package landing at `https://nostr.gwhyyy.com/`, reference guides at `/docs/`, with verifiable local artifacts and a safe hosting handoff.
**Architecture:** Keep Docusaurus 2 and its statically rendered React pages. Nginx serves generated files directly; no Node production process is needed.
**Tech stack:** Existing React, Docusaurus, Infima, Node built-in assertions.
**Spec:** User request in this session; user delegated design decisions.

## Constraints and design
- No new runtime dependency, invented usage metrics, tracking IDs, or unsupported package claims.
- Preserve all twenty documentation routes under `/docs/`; unknown URLs must return 404.
- Keep GitHub Pages build compatibility through explicit URL/base-path build variables. Do not publish to Pages during this task.
- Never commit, push, change nginx, request certificates, or submit indexing without approval.
- Tokens: cool paper/ink/cobalt, native sans body, Trebuchet display, monospace code; 1.25 type ratio, 4px spacing unit, 4px radius, no shadows.
- Flow: landing → installation or quick start → guide; package and repository links are secondary destinations. Static content works before JavaScript. No data collection without configured, approved analytics and privacy decisions.
- Failure: broken build stops delivery; unknown route gets useful 404; unavailable Google access is reported, not bypassed.

## Tasks
1. [complete] Build assertion-based routing/SEO regression check; observed failure against old build. Homepage, coherent theme, /docs routing, metadata and discovery files built. Production build and 21-route assertions pass.
2. [complete] Product context, launch copy, search/analytics instructions and hosting runbook prepared. Corrected Flutter Web playground built and assembled; Flutter analysis and 45 tests pass. No claim to cover every NIP.
3. [complete] Final scoped review and clean-tree release archive check pass. SDK offline suite passes 423 tests; real Flutter browser workflow passes without public publishing. Verified commits are f450695 and 77063e5, kept on the isolated feature branch without a push.
4. [complete] Approved domain-specific nginx/certificate setup is live. Release `20261114-084001` was unpacked beside the old one and selected by an atomically renamed symlink; all 21 public routes, entry assets, schema, discovery files and unknown-route 404 verified over HTTPS, and a live Chromium pass proves the Flutter playground boots and its theme toggles. Renewal dry-run/reload hook and administrator cleanup remain open operational items. Google account/auth and external submissions stay explicit gates.
5. [blocked: authentication] Clean-tree pub dry-run and archive assertions pass. The approved 11.0.0 publication attempt reached Google publisher authorization and timed out waiting for the owner. No publisher credentials were read or supplied. Public API verification still shows 10.0.1, with no 11.0.0 release. Resume through the publisher's secure interactive login, not credentials in chat.

## Proof and rollback
Run `npm run build` and `node scripts/check-site.mjs` from docs. Crawl sitemap and local HTML/assets with Node assertions. Browser screenshots recorded outside tracked source.
Rollback: main checkout remains untouched at d61258e; all work is isolated on feat/nostr-domain-site. Production release uses a versioned directory and atomic current symlink; retain previous target.

## Review focus
Deep-link refresh, mobile overflow, missing assets, incorrect production canonical, analytics before consent. Test generated files, not mocked components.

## Observed blockers
- Live domain routing and TLS are fixed. Privileged access is no longer available; certificate renewal verification and cleanup need an administrator.
- GSC authentication failed; GA account summaries returned invalid_grant (expired/revoked token). No account data or tracking ID available.
- pub.dev API latest is 10.0.1; repo is 11.0.0. Keep preview labels until an actual verified publication. User has since requested a package release attempt.
- Browser initially crashed under memory pressure. Verification now runs serially in memory-capped cgroups; preserve this boundary and keep unrelated services running.
- Safety review found disconnect/reconnect and concurrent-session defects in the deployed playground. User explicitly chose to leave it accessible while fixes proceed. Source fixes now exist, but the deployed bundle is unchanged; publication and redeployment require runtime regression/build checks first.

## Verification ledger
- 2026-11-11: `npm run build` and `node scripts/check-site.mjs` pass (21 routes). Existing main remains untouched.
- Browser: 1440px/390px landing has no horizontal overflow. Axe light and settled dark landing scans report zero violations. Skip link receives visible 3px focus. Screenshots in temporary browser artifacts.
- Fixed scoped CSS selector leaking `display:block` into Prism spans. Code tokens now remain inline. Adjusted light/dark Prism palettes after measured contrast failures.
- Quick-start dark scan found unmarked inline links; underline fix applied and rebuilt in both deployment modes. Browser recheck paused after a browser crash under memory pressure.
- Domain setup subsequently completed after approval: dedicated nginx vhost, versioned release and Let's Encrypt certificate. Temporary broad sudo grant was then revoked; secure administrator access is required for further privileged work.
- Independent scoped review accepted landing/build fixes; found one remaining low-level guide callback arity error. Changed onEose to (relay, eose), matching the SDK. Version banner intentionally remains visible while preview/published versions differ.
- Public verification passed for 21 routes, exact canonicals, descriptions, headings, JSON-LD, home assets, discovery files, Flutter entry assets and unknown-route 404. The onEose source correction still needs a rebuilt deployment.
- SDK/playground safety fixes and package exclusions were implemented by DS 4.1. Only Dart parsing/formatting ran; regression tests, analysis, archive dry-run and rebuilt bundle remain NOT RUN due to ~1.3 GiB available RAM. Independent scoped re-review is in progress. Resume commands: `/tmp/opencode/nostr-playground-fix-report.md`.
- User requested a pub.dev 11.0.0 publication attempt. No upload attempted: old `.pubignore` would have included playground build output; exclusions are fixed in source but exact archive remains unverified. Existing local v11.0.0 tag is stale and untouched; no git commit/push authorized.
- Round-two independent source review accepted all seven scoped fixes: actual pub tree parser, ignore protections, single NOTICE reconnect, pending-connect key preservation, dropped-event notification batching, teardown error propagation and strengthened lifecycle/build gates. No runtime pass is claimed.
- Final resource boundary: about 1.3 GiB RAM available with over 3 GiB swap used. OpenClaw gateway uses about 1.6 GiB; user declined temporarily stopping it. Heavy verification remains paused. Do not deploy the stale bundle as proof of fixes or attempt pub publication until the recorded checks run safely.
- User requested optimized continuation. Replaced the blanket 2 GiB gate for narrow checks with a verified cgroup boundary: `MemoryMax=768M`, `MemorySwapMax=0`, one process tree under the shared flock, bounded runtime. Preflight observed `memory.max=805306368` and `memory.swap.max=0`. A test exceeding the cap may fail locally without consuming host swap. Unbounded builds remain blocked; do not stop unrelated workloads. First lifecycle regression is running with this boundary; result pending.
- First capped lifecycle run completed without an OOM: 7 passed, 2 server-side close-observation timeouts. DS 4.1 is investigating the test observation contract; no timeout increase is authorized as a substitute for proof.
- Real opt-in archive dry-run completed under the cap, exit 65: listing excludes local site/playground/build paths, but release gate failed on a new unnecessary non-null assertion and dirty tracked release files. Warning fix assigned to lifecycle implementer. No force, validation bypass, commit or upload performed.
- Capped runtime verification completed: lifecycle 9/9 passes; full offline SDK suite 423 passes with archive opt-in skipped; Flutter analysis has no issues and all 43 tests pass. Public-network tests remain disabled. The isolated original-SDK baseline fails the same disconnect-during-backoff regression with an unexpectedly live relay, proving the new check detects the defect.
- Final Docusaurus build passed under 768 MiB. Its 21-route metadata/discovery check passes. A separately capped real Chromium run verified 1440/390 light/dark landing layouts, visible keyboard skip focus, docs deep-link loading and zero page errors. Proof: `/tmp/opencode/nostr-browser-proof/`.
- User approved committing verified work on the isolated feature branch, without pushing or moving existing tags. No commit yet; final review and release checks are in progress.
- Corrected Flutter bundle build hit the 768 MiB cgroup limit (contained OOM). With 1.8 GiB host RAM available, one changed retry uses a 1 GiB cap, disables the duplicate WASM dry run, self-hosts web resources and uses JS optimization level 2. Result pending; do not deploy an old bundle as the safety fix.
- The changed Flutter build retry passed in 53 seconds. Its self-hosted output is assembled with the final Docusaurus build, and the complete artifact check passes. This supersedes earlier source-only/build-pending ledger entries; production still uses the older artifact.
- Real Chromium verification of the corrected Flutter bundle passed: no automatic connection, generate ephemeral identity, local signing with a valid signature, no browser storage, connect to relay.damus.io, cancel public-publish confirmation without sending EVENT, send a read REQ, stop, disconnect and clear identity. No page errors. Desktop/mobile screenshots are in `/tmp/opencode/nostr-browser-proof/`.
- Production root and releases parent remain root-owned. Existing release contents are writable, but an atomic new-release symlink switch needs a narrowly scoped administrator action. Do not replace the live directory piecemeal or reuse exposed credentials.
- Administrator granted a path-scoped ACL (`user:gw:rwx` on `/var/www/nostr` and `/var/www/nostr/releases`); no general sudo. Artifact `36c903bf…` unpacked to `releases/20261114-084001` and selected with `mv -T` over a fresh symlink. Public verification: 21 sitemap URLs with unique titles/descriptions, exact canonicals, one H1; home is the landing page; JSON-LD parses; playground `noindex, follow` with self-canonical; assets and discovery files 200; unknown 404; HTTP 301 to HTTPS. `ar.tattoo` still 200.
- First live browser run exposed a real production defect: nginx served `.wasm` as `application/octet-stream`, so Chromium refused to compile CanvasKit and the playground never booted — also true of the previous release, whose HTML shell alone had been checked. Administrator added the `application/wasm wasm;` mime mapping. Both CanvasKit wasm paths now return `application/wasm` through Cloudflare and at the origin; a live Chromium pass shows the boot card removed, three panes rendered, no page errors, and the theme toggling dark and back (`/tmp/opencode/nostr-live-verify.log`).
- Final browser pass exposed a first-click theme bug in system-light mode. A new widget regression failed before the fix. After deriving the effective system brightness, the reproducible build script passes 9 lifecycle tests, clean Flutter analysis, all 45 Flutter tests and a release build under a 1 GiB cap. The assembled artifact check passes. Offline real Chromium confirms local signing, empty browser storage, no connection on load and visibly correct light/dark mobile rendering with zero page errors.
- A repeat public-relay browser run timed out on connection availability. The earlier successful read/cancel/disconnect proof remains valid; relay uptime is external and not guaranteed. No public event was sent.
- Final independent source review accepted the build, theme, tests and release copy. Corrected its remaining README result/failure-property sentence against the actual SDK types.
- Clean committed archive check passes both tests, including a real `dart pub publish --dry-run`. The archive is 147 KB and excludes the documentation site, playground, operations files and generated output. A warning about the Flutter lockfile was fixed with an explicit `.gitignore` exception, not bypassed.
- `dart pub publish --force` was used only to skip confirmation after successful validation, not to skip validation or warnings. It stopped at the Google authorization prompt; the timed-out process is gone. No 11.0.0 exists on pub.dev after the attempt.
- Fresh public verification again passes all 21 routes and unknown-route 404. Live Flutter JS SHA-256 differs from the verified local bundle, confirming the corrected artifact remains undeployed. Production parent-directory access is still absent. Final proof and remaining steps: `ops/RESULTS.md`.
