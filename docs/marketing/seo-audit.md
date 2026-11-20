# SEO and launch audit — 2026-11-14

## Summary

The live domain serves the SDK site, not the tattoo application. All 21 live
sitemap URLs returned HTTP 200 with a self-canonical, description and one H1 in
this audit. That proves the crawlable foundation, not indexing or rankings.

This wave improves search titles, separates overlapping identity guides, removes
unsupported overview guarantees, identifies the package in structured data and
sets a deliberate indexing policy for the Flutter console. These changes are
local until the new artifact is atomically deployed. Production parent-directory
access is still unavailable; the older live playground is not the corrected build.

## Evidence and limits

| Signal | Scope / source | Observed result |
|---|---|---|
| Live crawl | 21 URLs from the live XML sitemap; identifying verification user-agent | 21 HTTP 200; exact self-canonicals, descriptions and one H1 |
| Local metadata check | `cd docs && node scripts/check-site.mjs` | PASS: domain-root assembled release; 21 routes, short sidebar labels, unique titles/descriptions, five intent titles, schema, compact logo, discovery files and Flutter indexing policy. GitHub Pages environment build/check also passed (site only). |
| First mobile Lighthouse run | Lighthouse 13.6.0; local static build on this constrained VM | SEO 100, accessibility 100, best practices 100, performance 84; LCP 1.3s, CLS 0, TBT 640ms |
| Final mobile Lighthouse run | Same local setup after logo and review fixes | SEO 100, accessibility 100, best practices 100, performance 84; LCP 1.2s, CLS 0, TBT 630ms; image sizing/delivery audits pass |
| Measurement caveat | Lighthouse emitted a slow-CPU warning | Local lab data, not CrUX, production network performance or INP; TBT is not INP |
| Rendered guide check | Overview, keys and identifiers; 1440/390px, light/dark | Twelve states checked for overflow, headings, canonical and page errors |
| Google Search Console | `list_properties`, 2026-11-14 | Authentication/configuration failure; ownership, queries, clicks, impressions and index coverage MISSING |
| Google Analytics | No GA tools exposed on 2026-11-14; previous 2026-11-11 call returned invalid_grant | Measurement ID and usable account access MISSING; tracking remains off |
| Registry | `https://pub.dev/api/packages/dart_nostr`, 2026-11-14 | Latest 10.0.1; repository 11.0.0 remains a source preview |
| Existing discovery | awesome-nostr Libraries section | dart_nostr already listed; no duplicate submission needed |

Machine-readable evidence lives under `/tmp/opencode/nostr-seo-proof/` in this
session: `live-baseline.json`, `live-robots.txt`, `browser.json`, screenshots and Lighthouse JSON.
The build logs are `/tmp/opencode/nostr-seo-build.log` and
`/tmp/opencode/nostr-seo-final-build.log`; final reviewed rebuild logs are
`/tmp/opencode/nostr-seo-review-build.log` (Pages build) and
`/tmp/opencode/nostr-seo-domain-review.log` (domain build).
Reports must accompany the deploy artifact;
temporary paths are not permanent hosting or external proof links.

The assembled release is `/tmp/opencode/nostr-site-seo-20261114.tar.gz`, SHA-256
`36c903bf348057f2efad278f67524a5808670f469d8e9e6529394573824ccdf2`.
It includes the previously verified corrected Flutter program with this wave's
HTML indexing metadata. No Dart application logic changed or was rebuilt in this
wave. Nothing in this artifact has been deployed by this audit.

## Findings and smallest fixes

| Priority | Finding / evidence | Action |
|---|---|---|
| High | Generic search titles such as `dart_nostr`, `Keys` and `Quick Start` omit the developer task | Set descriptive frontmatter titles while preserving a single visible H1; regression-check five priority titles |
| High | Overview promised production readiness and exception-free operations without proof | Describe high-level result handling accurately; acknowledge local parsing/crypto errors |
| Medium | NIP-19 and bech32 pages repeated encoding intent | Make NIP-19 a sharing/format decision guide and bech32 the Dart API guide; add reciprocal links and key-workflow entry points |
| Medium | The Flutter route has a canvas app rather than a full server-rendered guide | Add `noindex, follow` and a self-canonical to its HTML; keep it out of the sitemap and link it for human use |
| Medium | SoftwareSourceCode schema lacked homepage and package identity | Add environment-aware `url` and the actual pub.dev listing as `sameAs`; parse and assert the built JSON-LD |
| Medium | Lighthouse found a 46,422-byte 512px logo rendered at 40px without HTML dimensions | Retain the original; use an 80px 4,281-byte navbar derivative with width/height 40. This removes 42,141 image bytes without changing its displayed size |
| High delivery gate | Corrected local app and SEO pages differ from the deployed release | Deploy a versioned complete artifact and switch the current symlink atomically; never overwrite the live release piecemeal |
| Measurement gate | GSC and GA are unavailable | Restore secure access before making demand, indexation or conversion claims; follow `tracking.md` |

No blanket framework upgrade, speculative new landing pages, paid links or
package-platform overrides were added. Lighthouse's main-thread/unused-code
opportunities remain framework-level follow-up, not evidence of a new regression.
Real-user CWV and a human screen-reader review remain unverified.

## Public surface inventory

Routes come from the sitemap, not marketing copy. Existing paths stay stable.

| Route | Purpose | Primary next action |
|---|---|---|
| `/` | Dart/Flutter Nostr SDK introduction | Try the playground or quick start |
| `/docs/` | SDK/API conventions | Install or start the example |
| `/docs/category/usage/` | Usage navigation hub | Choose a workflow |
| `/docs/contributing/` | Contribution and safe issue reporting | Run tests or report a minimal reproduction |
| `/docs/installation/` | Published versus preview setup | Select the matching dependency |
| `/docs/must-know/` | Lifecycle and key-safety prerequisites | Read quick start |
| `/docs/quick-start/` | First connect/publish/subscribe workflow | Run the example locally |
| `/docs/usage/advanced/client-options/` | Configure client behavior | Choose timeouts/retry settings |
| `/docs/usage/advanced/error-handling/` | Results and failures | Handle failures and relay rejection |
| `/docs/usage/advanced/low-level-api/` | Low-level integration | Inspect transport and callback contracts |
| `/docs/usage/identity/nip05/` | NIP-05 identity | Use identity lookup helpers |
| `/docs/usage/identity/nip19/` | Choose a human-readable Nostr identifier | Share the right public format |
| `/docs/usage/keys-management/` | Key workflow navigation | Generate, sign or encode safely |
| `/docs/usage/keys-management/bech32-encoding/` | Dart bech32 methods | Encode/decode a value |
| `/docs/usage/keys-management/generate-key-pair/` | Key creation | Generate an identity safely |
| `/docs/usage/keys-management/sign-verify/` | Signing and verification | Verify a signature |
| `/docs/usage/relays-and-events/connecting-to-relays/` | Relay connections | Connect and clean up |
| `/docs/usage/relays-and-events/count-events/` | Count queries | Issue a count request |
| `/docs/usage/relays-and-events/creating-events/` | Event construction | Create a signed event |
| `/docs/usage/relays-and-events/publishing-events/` | Relay publication | Explicitly publish and inspect acceptance |
| `/docs/usage/relays-and-events/subscribing-to-events/` | Filtered streams | Start and close a subscription |
| `/playground/` (outside sitemap) | Interactive Flutter debug console | Sign locally, then explicitly connect/read |

## Crawler and AI-search policy

The live robots response includes a Cloudflare-managed policy with
`Content-Signal: search=yes, ai-train=no` and named blocks including GPTBot,
ClaudeBot and Google-Extended. The origin's wildcard allow and sitemap remain.
Do not remove training/privacy choices to chase a score. The sampled response
does not name-block OAI-SearchBot, Claude-SearchBot or PerplexityBot; that is not a
guarantee that every CDN/WAF path permits them. Google-Extended is not Google Search.

The sampled response is saved as `live-robots.txt` in the evidence directory above.

## Review follow-up

- Search titles retain six short `sidebar_label` values; the generated-page check
  verifies both without relying on collapsed sidebar children being server-rendered.
- The compact logo has an alpha channel with a transparent edge pixel, not a
  black background. The check also reads the PNG header and requires 80×80 pixels;
  a valid 512×512 PNG under 10KB was rejected before the original asset was restored.
- The existing `playground/web/flutter_bootstrap.js` already removes the loading
  card after `runApp`. A browser assertion confirmed `#boot` was absent with the
  Flutter controls visible; no duplicate cleanup handler was added.
- The installation check date is 2026-11-14, and the quick start correctly names
  the `NostrFailureCode` enum. No SDK behavior changed in this SEO wave.
- Independent scoped re-review found no remaining actionable blocker; runtime
  checks and live-vs-local delivery status remain the parent's verified evidence.

## Legacy Pages publication gate

The existing `.github/workflows/docs-pages.yml` still has a docs-touching push to
`main` trigger and an explicit manual trigger. This wave does not push, merge or
run it. The Pages API on 2026-11-14 reported `build_type: legacy`, source
`gh-pages:/`, status `built`; workflow source is not proof of environment approval
rules. Before future integration,
review the Pages source/environment settings and explicitly decide whether to
retire the legacy origin or redirect/canonicalize it to the custom domain.
Do not merge and assume the legacy publication path is approval-gated. Changing
the established release workflow is a separate integration decision, not an SEO
content edit.

The existing `llms.txt` and `llms-full.txt` are optional discovery aids. They do not
prove AI ingestion, citations, Google indexing or ranking. Primary guide content
and JSON-LD exist in static HTML. SoftwareSourceCode is semantic markup, not a
promise of a Google rich result. No ratings, fake reviews or unsupported offers
were added.

## Next actions, in order

1. Atomically deploy the corrected assembled site; verify changed titles,
   canonical, schema, compact image, Flutter head and real 404 from the live URL.
2. Restore GSC/GA through secure authentication. Confirm existing ownership and
   stream before creating accounts or adding scripts. Ask before sitemap submission.
3. Promote one useful, working demo using the drafts in `distribution.md` only
   after channel approval. Recheck the registry version immediately before posting.
4. Use matching completed 28-day GSC windows to pick the next guide improvement.
   Without query or support evidence, do not manufacture a keyword cluster.

References checked 2026-11-14:
- https://nostr.gwhyyy.com/sitemap.xml
- https://nostr.gwhyyy.com/robots.txt
- https://pub.dev/api/packages/dart_nostr
- https://github.com/aljazceru/awesome-nostr#libraries
- https://github.com/nostr-protocol/nips/blob/master/19.md
- https://dart.dev/tools/pub/pubspec

## Changed-file record

Paths below are relative to the repository; `:1` identifies each complete change
in the final diff rather than claiming the edit starts on line one.

| File | Why |
|---|---|
| `.agents/product-marketing.md:1` | Versioned registry/listing facts and promotion boundaries |
| `docs/docs/contributing.md:1` | Search title and safe, actionable contribution workflow |
| `docs/docs/installation.md:1` | Installation-intent title and version-aware description |
| `docs/docs/intro.md:1` | SDK documentation title and evidence-backed API claims |
| `docs/docs/quick-start.md:1` | Dart quick-start search intent |
| `docs/docs/usage/identity/nip19.md:1` | Identifier-choice guide instead of duplicate encoding content |
| `docs/docs/usage/keys-management/bech32-encoding.md:1` | Link to the format decision guide |
| `docs/docs/usage/keys-management/index.md:1` | Key-workflow navigation and secret-handling context |
| `docs/docusaurus.config.js:1` | Compact navbar image and reserved dimensions |
| `docs/static/img/logo-nav.png:1` | 80px optimized derivative; original retained |
| `docs/src/pages/index.jsx:1` | Homepage and package identity in source-code schema |
| `playground/web/index.html:1` | Deliberate canvas-app indexing policy and canonical |
| `docs/scripts/check-site.mjs:1` | Runnable built-output regressions for metadata, schema, image and indexing policy |
| `docs/marketing/launch.md:1` | Accurate launch gates, intent map and weekly workflow |
| `docs/marketing/tracking.md:1` | Dated access evidence and inactive privacy-safe measurement plan |
| `docs/marketing/distribution.md:1` | Ready channel drafts, existing listing status and posting gates |
| `docs/marketing/seo-audit.md:1` | Audit, route inventory, measurements, limitations and delivery record |
