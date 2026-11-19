import assert from 'node:assert/strict';
import {readFileSync, existsSync} from 'node:fs';
import {resolve} from 'node:path';

const build = resolve('build');
const origin = process.env.SITE_URL || 'https://nostr.gwhyyy.com';
const baseUrl = process.env.BASE_URL || '/';
const root = new URL(baseUrl, origin).href;
const siteOnly = process.argv.includes('--site-only');
const home = readFileSync(resolve(build, 'index.html'), 'utf8');
assert.match(home, /Build Nostr apps/);
const logoImages = [...home.matchAll(/<img\b[^>]*>/g)].map(match => match[0]).filter(image => image.includes('alt="Dart Nostr logo"'));
assert.ok(logoImages.length > 0 && logoImages.every(image =>
  image.includes(`src="${baseUrl}img/logo-nav.png"`) && /\bwidth="40"/.test(image) && /\bheight="40"/.test(image)),
'Navbar images must use the compact logo with reserved dimensions');
const logo = readFileSync(resolve(build, 'img/logo-nav.png'));
assert.ok(logo.length < 10_000, 'Navbar logo must stay below 10KB');
assert.equal(logo.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
assert.deepEqual([logo.readUInt32BE(16), logo.readUInt32BE(20)], [80, 80], 'Navbar logo must be 80×80 pixels');
assert.ok(home.includes(`href="${root}"`), 'Root canonical must match deployment');
assert.match(home, /application\/ld\+json/);
const sourceSchema = [...home.matchAll(/<script[^>]*type="application\/ld\+json"[^>]*>(.*?)<\/script>/gs)]
  .map(match => JSON.parse(match[1])).find(schema => schema['@type'] === 'SoftwareSourceCode');
assert.equal(sourceSchema?.url, root, 'Source schema must identify the deployed homepage');
assert.ok(sourceSchema.sameAs?.includes('https://pub.dev/packages/dart_nostr'), 'Source schema must identify the package listing');
assert.ok(home.includes(`href="${baseUrl}docs/quick-start/"`), 'Quick-start link must include baseUrl');
assert.ok(home.replace(/<[^>]*>/g, '').includes('flutter pub add dart_nostr'), 'Install command must be visible');
const playgroundUrl = baseUrl === '/' ? '/playground/' : 'https://nostr.gwhyyy.com/playground/';
assert.ok(home.includes(`href="${playgroundUrl}"`), 'Demo link must reach its hosting domain');
assert.ok(home.includes(`href="${baseUrl}docs/installation/"`), 'Announcement link must include baseUrl');
assert.match(home, /10\.0\.1/);
assert.equal((home.match(/<h1[ >]/g) || []).length, 1);
assert.match(home, /aria-label="Analytics consent"/, 'Consent bar must render on the landing page');
assert.match(home, />Accept<\/button>/, 'Consent bar must offer Accept');
assert.match(home, />Reject<\/button>/, 'Consent bar must offer Reject');
const gtagRefs = (home.match(/googletagmanager\.com/g) || []).length;
if (process.env.GA_ID) {
  assert.ok(gtagRefs > 0, 'GA build must load the tag manager');
  assert.match(home, /analytics_storage:\s*['"]denied['"]/, 'Consent defaults must deny storage before any grant');
} else {
  assert.equal(gtagRefs, 0, 'No tracking may ship without GA_ID');
}
assert.ok(existsSync(resolve(build, 'docs/index.html')), 'Docs intro must live under /docs');
assert.ok(existsSync(resolve(build, '404.html')));
assert.match(readFileSync(resolve(build, 'docs/installation/index.html'), 'utf8'), /d61258e/);
for (const name of ['robots.txt', 'llms.txt', 'llms-full.txt', 'img/social-card.png']) {
  assert.ok(existsSync(resolve(build, name)), `Missing ${name}`);
}
const sitemap = readFileSync(resolve(build, 'sitemap.xml'), 'utf8');
const urls = [...sitemap.matchAll(/<loc>(.*?)<\/loc>/g)].map(match => new URL(match[1]));
assert.ok(urls.length >= 21, 'Landing plus at least twenty documentation routes');
const expectedTitles = {
  'docs/': 'Dart and Flutter Nostr SDK documentation',
  'docs/installation/': 'Install dart_nostr for Dart and Flutter',
  'docs/quick-start/': 'Dart Nostr quick start',
  'docs/usage/keys-management/': 'Nostr key management in Dart',
  'docs/usage/identity/nip19/': 'Nostr identifiers: npub, nsec and relay hints',
};
const titles = new Set();
const descriptions = new Set();
for (const url of urls) {
  assert.equal(url.origin, new URL(origin).origin);
  assert.ok(url.pathname.startsWith(baseUrl));
  const path = decodeURIComponent(url.pathname.slice(baseUrl.length)).replace(/\/$/, '');
  const file = resolve(build, path, 'index.html');
  assert.ok(existsSync(file), `Missing generated route ${url.pathname}`);
  const html = readFileSync(file, 'utf8');
  assert.ok(html.includes(`href="${url.href}"`), `Canonical mismatch ${url.pathname}`);
  assert.match(html, /name="description"/);
  assert.equal((html.match(/<h1[ >]/g) || []).length, 1, url.pathname);
  const title = html.match(/<title[^>]*>(.*?)<\/title>/)?.[1];
  const description = html.match(/<meta[^>]*name="description"[^>]*content="([^"]+)"/)?.[1];
  assert.ok(title?.trim() && !titles.has(title), `Missing or duplicate title ${url.pathname}`);
  assert.ok(description?.trim() && !descriptions.has(description), `Missing or duplicate description ${url.pathname}`);
  titles.add(title);
  descriptions.add(description);
  const expectedTitle = expectedTitles[url.pathname.slice(baseUrl.length)];
  if (expectedTitle) {
    assert.equal(title, `${expectedTitle} | Dart Nostr`, `Search intent title ${url.pathname}`);
  }
}
const intro = readFileSync(resolve(build, 'docs/index.html'), 'utf8');
const search = readFileSync(resolve(build, 'search/index.html'), 'utf8');
assert.ok(home.includes(`href="${baseUrl}search/"`), 'Search must be reachable from navigation');
assert.match(search, /<label[^>]*for="docs-query"/);
assert.ok(search.includes(`action="${baseUrl}search/"`), 'Native search submission must preserve baseUrl');
assert.match(search, /Never enter private keys or secrets/);
assert.match(search, /name="robots" content="noindex, follow"/);
assert.ok(!urls.some(url => url.pathname === `${baseUrl}search/`), 'Utility search must stay outside the sitemap');
assert.ok(existsSync(resolve(build, 'fonts/ibm-plex-sans-latin.woff2')), 'Typography must be self-hosted');
for (const [route, label] of Object.entries({
  '': 'Overview',
  'installation/': 'Installation',
  'quick-start/': 'Quick start',
  'usage/keys-management/': 'Keys',
  'usage/identity/nip19/': 'Identifiers',
  'contributing/': 'Contributing',
})) {
  const page = readFileSync(resolve(build, 'docs', route, 'index.html'), 'utf8');
  const sidebarLinks = [...page.matchAll(/<a\b[^>]*class="[^"]*menu__link[^"]*"[^>]*>.*?<\/a>/g)].map(match => match[0]);
  assert.ok(sidebarLinks.some(link => link.includes(`href="${baseUrl}docs/${route}"`) && link.endsWith(`>${label}</a>`)), `Short sidebar label: ${label}`);
}
assert.doesNotMatch(intro, /production-ready|No unchecked exceptions|Typed results everywhere/, 'Overview must not promise unverified production or exception guarantees');
if (!process.env.GA_ID) {
  assert.doesNotMatch(home, /googletagmanager|google-analytics\.com|G-[A-Z0-9]{6,}/, 'No unconfigured tracking');
}
if (!siteOnly) {
  for (const name of ['index.html', 'main.dart.js', 'flutter_bootstrap.js']) {
    assert.ok(existsSync(resolve(build, 'playground', name)), `Assembled release is missing playground/${name}`);
  }
  const playground = readFileSync(resolve(build, 'playground/index.html'), 'utf8');
  assert.match(playground, /<base href="\/playground\/">/);
  assert.match(playground, /<nav[^>]*aria-label="Project"/);
  assert.match(playground, /id="flutter-host"/);
  assert.match(playground, /<meta name="robots" content="noindex, follow">/, 'Canvas app must not compete with the readable SDK landing page');
  assert.match(playground, /<link rel="canonical" href="https:\/\/nostr\.gwhyyy\.com\/playground\/">/);
}
console.log(`PASS: ${urls.length} routes, metadata, discovery files, no unconfigured tracking${siteOnly ? ' (site only; demo NOT checked)' : ', and Flutter artifact'}`);
