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
assert.ok(home.includes(`href="${root}"`), 'Root canonical must match deployment');
assert.match(home, /application\/ld\+json/);
assert.ok(home.includes(`href="${baseUrl}docs/quick-start/"`), 'Quick-start link must include baseUrl');
assert.ok(home.replace(/<[^>]*>/g, '').includes('flutter pub add dart_nostr'), 'Install command must be visible');
const playgroundUrl = baseUrl === '/' ? '/playground/' : 'https://nostr.gwhyyy.com/playground/';
assert.ok(home.includes(`href="${playgroundUrl}"`), 'Demo link must reach its hosting domain');
assert.ok(home.includes(`href="${baseUrl}docs/installation/"`), 'Announcement link must include baseUrl');
assert.match(home, /10\.0\.1/);
assert.equal((home.match(/<h1[ >]/g) || []).length, 1);
assert.ok(existsSync(resolve(build, 'docs/index.html')), 'Docs intro must live under /docs');
assert.ok(existsSync(resolve(build, '404.html')));
assert.match(readFileSync(resolve(build, 'docs/installation/index.html'), 'utf8'), /d61258e/);
for (const name of ['robots.txt', 'llms.txt', 'llms-full.txt', 'img/social-card.png']) {
  assert.ok(existsSync(resolve(build, name)), `Missing ${name}`);
}
const sitemap = readFileSync(resolve(build, 'sitemap.xml'), 'utf8');
const urls = [...sitemap.matchAll(/<loc>(.*?)<\/loc>/g)].map(match => new URL(match[1]));
assert.ok(urls.length >= 21, 'Landing plus at least twenty documentation routes');
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
}
assert.doesNotMatch(home, /googletagmanager|google-analytics\.com|G-[A-Z0-9]{6,}/, 'No unconfigured tracking');
if (!siteOnly) {
  for (const name of ['index.html', 'main.dart.js', 'flutter_bootstrap.js']) {
    assert.ok(existsSync(resolve(build, 'playground', name)), `Assembled release is missing playground/${name}`);
  }
  assert.match(readFileSync(resolve(build, 'playground/index.html'), 'utf8'), /<base href="\/playground\/">/);
}
console.log(`PASS: ${urls.length} routes, metadata, discovery files, no unconfigured tracking${siteOnly ? ' (site only; demo NOT checked)' : ', and Flutter artifact'}`);
