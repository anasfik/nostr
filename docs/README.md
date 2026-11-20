# Documentation website

This directory contains the [Docusaurus 3](https://docusaurus.io/) site for
`dart_nostr`. The source guides live in `docs/docs/`; the site is published at
<https://anasfik.github.io/nostr/> under the `/nostr/` base path.

## Requirements

- Node.js 20 or newer (CI uses Node 22).
- npm (the lockfile is `package-lock.json`).

## Commands

Run from this `docs/` directory:

```bash
npm ci          # reproducible install from the lockfile
npm start       # local dev server with hot reload
npm test        # node:test regression checks for config, routes, and theme
npm run build   # production build into build/; strict links and anchors
npm run serve   # preview the production build locally
```

`npm test` asserts the Docusaurus version line, the `/nostr/` base path,
strict broken-link and anchor settings, the single root docs route, navbar
entry points, sitemap configuration, and the theme tokens.

## Route model

The classic preset serves docs from the site root (`routeBasePath: '/'`) and
`docs/intro.md` owns the `/` route with `slug: /`. Do not add
`src/pages/index.js`; it would conflict with that route. Existing guide URLs
must stay stable.

`/reference/nip-coverage` and `/reference/accessors` are advertised in the
navbar and footer ahead of the reference content. If those documents are
missing, `npm run build` fails on the strict broken-link check for those two
routes; that failure is expected and is separate from upgrade or theme
regressions.

## Deployment

The site is live at <https://anasfik.github.io/nostr/>. Two modes exist, and
only one is active at a time in Settings → Pages:

- **Deploy from a branch** (current): Pages serves the `gh-pages` branch.
  After changing docs, run `npm ci && npm run build` here, copy `build/` into a
  checkout of `gh-pages`, and push. `static/.nojekyll` ships into `build/`, so
  Jekyll does not process the output.
- **GitHub Actions**: switch Pages to "GitHub Actions" and
  `.github/workflows/docs-pages.yml` builds and deploys on every push to `main`
  that touches `docs/`. `deploy.ps1` and the old `gh-pages` deploy script are
  obsolete.

## Theme

`src/css/custom.css` is the only global stylesheet. It defines the design
tokens (`--dh-*`): warm paper, charcoal ink, one blue accent, a 1.25 type
scale, a 4px spacing grid, and one 4px radius. Infima variables are mapped onto
those tokens. The site uses native system font stacks, so no font requests are
made at runtime. The dark theme mirrors the same token names.
