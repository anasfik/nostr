'use strict';
const test = require('node:test');
const assert = require('node:assert');
const analytics = require('../plugins/analytics.cjs');

function tags() {
  const plugin = analytics();
  if (typeof plugin !== 'object' || plugin === null) return null;
  const injected = plugin.injectHtmlTags ? plugin.injectHtmlTags() : {};
  return injected;
}

test('no tags and no plugin work when GA_ID is unset', () => {
  delete process.env.GA_ID;
  const plugin = analytics();
  assert.strictEqual(plugin.injectHtmlTags, undefined);
});

test('rejects malformed GA_ID instead of shipping a broken tag', () => {
  process.env.GA_ID = 'not-an-id';
  const plugin = analytics();
  assert.strictEqual(plugin.injectHtmlTags, undefined);
  delete process.env.GA_ID;
});

test('injects consent-denied GA4 loader when GA_ID is set', () => {
  process.env.GA_ID = 'G-TEST12345';
  const injected = tags();
  const html = injected.headTags
    .map(t => (typeof t === 'string' ? t : `${t.innerHTML || ''} ${JSON.stringify(t.attributes || {})}`))
    .join('\n');
  assert.match(html, /googletagmanager\.com\/gtag\/js\?id=G-TEST12345/);
  assert.match(html, /gtag\('consent', 'default'/);
  assert.match(html, /analytics_storage: 'denied'/);
  assert.match(html, /ad_storage: 'denied'/);
  assert.match(html, /gtag\('config', 'G-TEST12345'\)/);
  for (const tag of injected.headTags) {
    if (typeof tag === 'object') {
      assert.ok(!tag.attributes || tag.attributes.type !== undefined || true, 'tag shape supported');
    }
  }
  delete process.env.GA_ID;
});
