# Website

This website is built using [Docusaurus 2](https://docusaurus.io/), a modern static website generator.

### Installation

```
$ yarn
```

### Local Development

```
$ yarn start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

### Build

```
$ yarn build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

### Deployment

The site is live at <https://anasfik.github.io/nostr/>.

Two modes exist, and only one is active at a time in Settings → Pages:

- **Deploy from a branch** (current): Pages serves the `gh-pages` branch. After changing docs, run `npm ci && npm run build` here, copy `build/` into a checkout of `gh-pages`, and push. `.nojekyll` in `static/` ships into `build/`, so nothing is processed by Jekyll.
- **GitHub Actions**: switch Pages to "GitHub Actions" and `.github/workflows/docs-pages.yml` builds and deploys on every push to `main` that touches `docs/`. `deploy.ps1` and the old `gh-pages` deploy script are obsolete.
