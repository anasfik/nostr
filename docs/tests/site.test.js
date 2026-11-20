'use strict';

const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');

const root = path.resolve(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

/** Load docusaurus.config.js without resolving the ESM prism package. */
function loadConfig() {
  const filename = path.join(root, 'docusaurus.config.js');
  const localRequire = createRequire(filename);
  const configRequire = (id) => {
    if (id === 'prism-react-renderer') {
      return {
        themes: {
          github: {plain: {color: '#000', backgroundColor: '#fff'}, styles: []},
          dracula: {plain: {color: '#fff', backgroundColor: '#000'}, styles: []},
        },
      };
    }
    return localRequire(id);
  };
  configRequire.resolve = localRequire.resolve;
  const mod = {exports: {}};
  const evaluate = new Function(
    'require',
    'module',
    'exports',
    '__dirname',
    '__filename',
    read('docusaurus.config.js'),
  );
  evaluate(configRequire, mod, mod.exports, root, filename);
  return mod.exports;
}

const pkg = JSON.parse(read('package.json'));
const config = loadConfig();
const classicOptions = config.presets.find(([name]) => name === 'classic')[1];
const docsOptions = classicOptions.docs;

function docSlugs(dir = path.join(root, 'docs'), found = []) {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      docSlugs(full, found);
    } else if (entry.name.endsWith('.md') || entry.name.endsWith('.mdx')) {
      const frontmatter = /^---\r?\n([\s\S]*?)\r?\n---/.exec(
        fs.readFileSync(full, 'utf8'),
      );
      if (frontmatter) {
        const slug = /^slug:\s*(.+)$/m.exec(frontmatter[1]);
        if (slug) found.push({file: path.relative(root, full), slug: slug[1].trim()});
      }
    }
  }
  return found;
}

const exists = (p) => fs.existsSync(path.join(root, p));

test('docusaurus packages are pinned to the supported 3.10.2 line', () => {
  for (const name of [
    '@docusaurus/core',
    '@docusaurus/preset-classic',
  ]) {
    assert.equal(pkg.dependencies[name], '3.10.2', `${name} must be exactly 3.10.2`);
  }
  assert.equal(
    pkg.devDependencies['@docusaurus/module-type-aliases'],
    '3.10.2',
    'module type aliases must match core',
  );
  assert.match(pkg.dependencies.react, /^\^19\./);
  assert.match(pkg.dependencies['react-dom'], /^\^19\./);
  assert.match(pkg.dependencies['@mdx-js/react'], /^\^3\./);
  assert.match(pkg.dependencies['prism-react-renderer'], /^\^2\./);
});

test('node engine and test command support the built-in runner', () => {
  assert.match(pkg.engines.node, /^>=20/);
  assert.equal(pkg.scripts.test, 'node --test tests/*.test.js');
});

test('site is served from the /nostr/ base path', () => {
  assert.equal(config.url, 'https://anasfik.github.io');
  assert.equal(config.baseUrl, '/nostr/');
});

test('link and anchor failures are strict', () => {
  assert.equal(config.onBrokenLinks, 'throw');
  assert.equal(config.onBrokenAnchors, 'throw');
  assert.equal(config.markdown.hooks.onBrokenMarkdownLinks, 'throw');
  assert.equal(config.markdown.hooks.onBrokenMarkdownImages, 'throw');
});

test('docs keep the root route without a competing pages route', () => {
  assert.equal(docsOptions.routeBasePath, '/');
  const roots = docSlugs().filter((doc) => doc.slug === '/');
  assert.equal(roots.length, 1, `expected exactly one slug /, got ${roots.map((r) => r.file)}`);
  assert.equal(roots[0].file, path.join('docs', 'intro.md'));
  for (const ext of ['js', 'jsx', 'ts', 'tsx', 'md', 'mdx']) {
    assert.equal(
      exists(path.join('src', 'pages', `index.${ext}`)),
      false,
      `src/pages/index.${ext} would compete with the docs root route`,
    );
  }
  assert.equal(exists(path.join('docs', 'index.md')), false);
});

test('navbar exposes the handbook entry points', () => {
  const items = config.themeConfig.navbar.items;
  const byLabel = new Map(items.map((item) => [item.label, item]));
  assert.equal(byLabel.get('Getting started').to, '/');
  assert.equal(byLabel.get('Protocols').to, '/reference/nip-coverage');
  assert.equal(byLabel.get('API').to, '/reference/accessors');
  assert.equal(byLabel.get('GitHub').href, 'https://github.com/anasfik/nostr');
  assert.equal(byLabel.get('Pub').href, 'https://pub.dev/packages/dart_nostr');
});

test('classic preset keeps sitemap generation enabled', () => {
  assert.ok(classicOptions.sitemap, 'classic preset sitemap config must be explicit');
  assert.equal(classicOptions.sitemap.filename, 'sitemap.xml');
});

test('theme tokens define paper, ink, accent and one 4px radius', () => {
  const css = read('src/css/custom.css');
  const token = (name) => new RegExp(`--dh-${name}\\s*:`);
  for (const name of [
    'paper',
    'surface',
    'ink',
    'ink-muted',
    'rule',
    'accent',
    'accent-ink',
    'code-bg',
    'font-sans',
    'font-mono',
    'text-sm',
    'text-base',
    'text-lg',
    'space-1',
    'space-2',
    'space-3',
    'space-4',
    'space-6',
  ]) {
    assert.match(css, token(name), `missing --dh-${name}`);
  }
  assert.match(css, /--dh-radius:\s*4px/);
  assert.match(css, /\[data-theme=['"]dark['"]\]/);
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /:focus-visible/);
  assert.match(css, /@media\s*\(max-width:\s*996px\)/);
  assert.doesNotMatch(css, /(linear|radial)-gradient\(/);
  const shadows = [...css.matchAll(/box-shadow:\s*([^;]+)/g)].map((m) =>
    m[1].trim(),
  );
  assert.deepEqual(
    shadows.filter((value) => value !== 'none'),
    [],
    'theme must not add shadows',
  );
});

test('Infima is driven by the custom tokens', () => {
  const css = read('src/css/custom.css');
  assert.match(css, /--ifm-background-color:\s*var\(--dh-paper\)/);
  assert.match(css, /--ifm-font-color-base:\s*var\(--dh-ink\)/);
  assert.match(css, /--ifm-color-primary:\s*var\(--dh-accent\)/);
  assert.match(css, /--ifm-global-radius:\s*var\(--dh-radius\)/);
});

test('template scaffolding is removed', () => {
  for (const p of [
    'src/components/HomepageFeatures',
    'src/pages',
    'static/img/undraw_docusaurus_mountain.svg',
    'static/img/undraw_docusaurus_tree.svg',
    'static/img/undraw_docusaurus_react.svg',
  ]) {
    assert.equal(exists(p), false, `${p} is unused template scaffolding`);
  }
});

test('llms text files describe the known routes', () => {
  for (const file of ['static/llms.txt', 'static/llms-full.txt']) {
    assert.ok(exists(file), `${file} missing`);
    const text = read(file);
    assert.match(text, /\/nostr\//, `${file} must use the published base path`);
    assert.match(text, /installation|quick-start|usage/i, `${file} must list known guides`);
  }
});
