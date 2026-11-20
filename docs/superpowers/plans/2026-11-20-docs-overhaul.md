# Documentation overhaul implementation plan

**Goal:** Rebuild the public documentation for dart_nostr 11.2.0, refresh its UI, verify examples, and push source plus the generated GitHub Pages site.

**Architecture:** Retain Docusaurus, upgrade its dependencies, and preserve existing guide URLs. Use native documentation navigation, an explicit protocol reference, and runnable Dart example checks. Library behavior and the package version stay unchanged.

**Tech stack:** Docusaurus 3, React 19, MDX 3, CSS variables, Dart analysis, Node's built-in test runner.

**Spec:** User request: “work on docs/ too … rebuild add edit remove, ui rework, upgrade, improve and push new docs/”.

## Constraints

- Preserve the existing installation pin update to 11.2.0.
- Limit changes to docs and its documentation deployment workflow.
- Derive API examples from source and tests; report partial support and security boundaries explicitly.
- Preserve published paths or provide redirects.
- Keep GitHub Pages serving gh-pages; no account configuration changes.
- No package release or edits to library code.

## Review focus

- Examples must compile against this checkout, including signer binding and subscription cleanup.
- Broken internal links fail the build.
- The base path /nostr/ must work after publishing, including nested routes.
- Navigation and reference controls must work with keyboard, light/dark themes, and narrow viewports.
- Unknown/missing protocol support must not be presented as fully implemented.

## Tasks and status

- [x] Ground: inspect existing site, release APIs, deployment configuration, and upstream upgrade requirements.
- [ ] ACTIVE — Upgrade Docusaurus and establish token-based theme, navigation, metadata, and regression checks.
- [ ] Rewrite existing guides and add protocol coverage, accessor reference, feature guides, migration and troubleshooting.
- [ ] Validate all executable Dart examples; build and crawl generated HTML; test desktop/mobile, theme, keyboard and accessibility.
- [ ] Independent code/content/UI review; fix blockers and rerun affected checks.
- [ ] Commit and push docs source, deploy generated gh-pages, and verify live routes and metadata.

## Proof commands

- `npm test` in docs: content/version/route regression checks.
- `npm run check:examples` in docs: extract complete Dart examples and analyze them against this package.
- `npm run build` in docs: production SSR and strict link checks.
- Browser screenshots at 1440 and 390 CSS pixels; console, overflow, keyboard and theme checks.
- Git status/diff scope inspection before commit; live HTTP and page content checks after deployment.

## Rollback

The source rollback point is f72dd74. Generated deployment changes are isolated to gh-pages and retain its git history.
