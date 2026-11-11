# Website and documentation

Existing Docusaurus 2 site: package landing at `/`, guides at `/docs/`, and a
separately built Flutter Web console at `/playground/`. Target domain:
<https://nostr.gwhyyy.com/>. This file does not assert that deployment is live.

### Installation

Use Node 22 or later.

```
$ npm ci
```

### Local Development

```
$ npm start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

### Build

```
$ npm run build
$ node scripts/check-site.mjs --site-only
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

After assembling the Flutter build, run `node scripts/check-site.mjs` without
`--site-only`; this release gate also requires the playground entry point and JS.

### Deployment

Follow [`../ops/DEPLOY.md`](../ops/DEPLOY.md) for assembly, nginx, TLS, approval
gates, live checks and rollback. Static files need no Node production process.

The earlier GitHub Pages deployment remains separate at
<https://anasfik.github.io/nostr/>. Two Pages modes exist:

- **Deploy from a branch** (current): existing `gh-pages` content stays unchanged.
  Never copy a domain-root build into that branch. A Pages build requires
  `SITE_URL=https://anasfik.github.io BASE_URL=/nostr/ npm run build` and separate
  validation of all base-prefixed links before publishing.
- **GitHub Actions**: switch Pages to "GitHub Actions" and `.github/workflows/docs-pages.yml` builds and deploys on every push to `main` that touches `docs/`. `deploy.ps1` and the old `gh-pages` deploy script are obsolete.
