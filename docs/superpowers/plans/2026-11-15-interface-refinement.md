# Interface refinement implementation plan

**Goal:** Make the landing page, every documentation route, and the Flutter console feel like one clear, accessible developer workbench.
**Authority:** User requested a production-quality UI/UX/DX/accessibility refinement and delegated design judgment. Existing Docusaurus 2.4.1 and Flutter stay. Deployment is a separate approval gate.

## Design and constraints

- Keep cool paper/deep ink/cobalt, light and dark modes, sharp 4px controls, restrained motion, and existing URLs/metadata.
- Self-host IBM Plex Sans (OFL): one Latin WOFF2 for web, original variable TTF for Flutter. Use installed fontTools for conversion; no runtime font service or new dependency.
- Typography: 16px base, 1.6 body line height, major-third heading scale, 400/500/600 weights; code uses existing monospace fonts. Tokens precede component changes.
- Shared palette: light background #f6f8fc, surface #ffffff, ink #17263e, muted #4a5b73, border #cbd5e2, accent #245ac4; dark background #111b2b, surface #18263b, ink #ecf1fa, muted #b6c4da, border #43536c, accent #95bbff. Success #1b7f3b light / #6fcf97 dark; verify contrast against actual surfaces.
- Space scale: 4/8/12/16/24/32/48/72px; radius 4px; focus 3px; interactive targets >=44px (Flutter >=48px); no decorative animation.
- Preserve the 19 pre-existing dirty paths and original main checkout. No commits, pushes, package publication, Google setup, public Nostr posting, or external announcements in this wave.
- Preserve ephemeral-key handling, cancellation generations, payload/feed bounds, explicit public-publish confirmation, and honest 10.0.1 published / 11.0.0 source-preview copy. No invented claims.

## Task 1 — Flutter workbench (complete)

Files: playground/lib/main.dart, lib/src/{playground_page,playground_controller,playground_theme}.dart, tests, pubspec.yaml, web/{index.html,manifest.json}, README.md, font assets.

Write failing widget/controller tests first. Add relay presets that only fill the input (Primal, Snort, nostr.wine), explain no auto-connect and relay availability, useful disconnected/empty guidance, and publish prerequisite text. Require a nonempty live-relay set in both UI eligibility and publish method before transport work. Keep confirmation rechecked after awaiting.

Introduce theme tokens with exact brand light/dark contrast. Add restrained live announcements for session/error/publish outcomes (never every incoming event). Label/select event rows with stable keys and authenticity state. Mobile/tablet uses list then explicit inspection/back rather than two cramped panes; desktop panes start at 1180px. Dialog initially focuses Cancel, Esc cancels, and focus returns to the trigger. Keep existing controller tests and add 390/1024/1280px, text scaling, live semantics, zero-live-relay, and mobile inspector regressions.

Verify: serial capped Flutter analyze + full Flutter tests. No production build until parent integration/resource check.

Observed: 75 Flutter tests pass; analyze has no issues. Scoped review accepted explicit button/tab focus rings, stable event-row state keys, 16px body typography, and the bundled OFL license. Focus may safely leave an event after a feed prepend; it must never activate a different event. Persistent native Home/Documentation links live outside the removable loading card, and Flutter is embedded in a bounded flex host. Release build succeeded under a 1024 MiB cap with swap allowed (`/tmp/opencode/nostr-refinement-console-build2.log`), and the real-browser proof passes sign/validate/read/cancel-publish/mobile-inspection/keyboard (`/tmp/opencode/nostr-refined-console-proof.log`, `after/console/browser.json`). Live pages confirmed the loader ignores `hostElement` and appended `<flutter-view>` to `<body>`, covering the nav; `flutter-view` is now pinned to `top: 48px` and the boot test asserts it.

## Task 2 — Landing and documentation (complete)

Files: docs/src/css/custom.css, src/pages/index.{jsx,module.css}, docusaurus.config.js; small search plugin, search helper/tests, search route, docs/scripts/check-site.mjs; docs/README.md and font assets.

Apply shared font/tokens to all docs, navigation, TOC, footer, code, tables, admonitions, pagination, and focus states. Keep native Docusaurus navigation rather than custom menus. Consolidate concise preview messaging without hiding the version distinction. Landing makes published install vs source-preview examples explicit, improves hierarchy and section rhythm, and gives clear paths to docs and console.

Add an accessible dedicated /search/ page using a small local index of Docusaurus doc title/description/permalink metadata (no network search API, analytics, modal or new dependency). Query lives in URL, result count announced politely, empty/no-match states have recovery, rendering uses text not HTML. Index only documentation; trim/cap query and result count. Preserve root and /nostr/ build prefixes; exclude utility search from sitemap and set noindex. Unit checks cover empty/case-insensitive multi-token/miss/long input/untrusted text. Build assertions cover the real route and metadata.

Verify: search unit tests RED then GREEN; capped domain and Pages builds + route assertions. No existing route removal.

Observed: six search unit tests pass. Domain-root and GitHub Pages builds pass the 21 canonical-route checks plus utility search assertions. All 22 web routes pass settled light/dark automated accessibility scans at desktop/mobile widths. Direct search/reload/back/no-match recovery and trusted keyboard checks pass. Dark root selector specificity now overrides Infima without altering light mode; independent review accepted the fix.

## Task 3 — Proof and review (complete)

One independent review per implementation wave. Capture actual desktop/mobile light/dark screenshots for landing, long docs, tables, search, console empty/filled/error/inspection. Keyboard: trusted Tab/Shift+Tab, Enter/Space, Esc, skip link, mobile drawer, search form, event selection and publish Cancel/focus return. Check 320/390/1024/1440 widths, console text scaling, overflow and console errors. Run automated accessibility checks and local Lighthouse; label human screen-reader/field metrics NOT RUN when unavailable. Read from public relays only; never confirm a public event as a test.

Resource guard: shared flock /tmp/opencode/nostr-build.lock; one heavy command at a time; MemoryMax=768M, MemorySwapMax=0. Flutter release may use 1024M only with sufficient available RAM (>=1.8GiB). Do not stop user services.

## Task 4 — Delivery (deployed 2026-11-18, approved by user)

Assembled the verified Flutter build after the Docusaurus build, generated the artifact, and — with the user's explicit "deploy yes" — switched production atomically to `/var/www/nostr/releases/20261118-180832`. Live verification found and fixed two real defects (webpack cache baking the Pages base path into the font URL; the loader ignoring `hostElement` so the canvas covered the nav), then the release was rebuilt, re-checked and re-verified 18/18. Rollback releases retained: 20261118-180057, 20261114-084001, 20261111-155830. Remaining out-of-scope gaps: screen-reader speech, Lighthouse rerun, pub.dev OAuth, GSC/GA auth, certificate renewal proof and admin cleanup.
