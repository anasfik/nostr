const assert = require('node:assert/strict');
const {test} = require('node:test');
const {searchDocs, normalizeQuery} = require('../src/search.cjs');

const items = [
  {title: 'Dart NIP-19 identifiers', description: 'Choose npub and nsec formats.', permalink: '/nostr/docs/identity/'},
  {title: 'Relay connections', description: 'Connect and disconnect Dart clients.', permalink: '/nostr/docs/relays/'},
  {title: '<script>alert(1)</script>', description: 'Example text, never markup.', permalink: '/nostr/docs/example/'},
];

test('empty search shows no results; the page provides starting points', () => {
  assert.deepEqual(searchDocs(items, '  '), []);
});
test('matches every token without case or identifier punctuation sensitivity', () => {
  assert.deepEqual(searchDocs(items, 'DART nip19').map(item => item.permalink), ['/nostr/docs/identity/']);
  assert.equal(searchDocs(items, 'connect dart')[0].title, 'Relay connections');
});
test('misses and punctuation are literal, never a regular expression', () => {
  assert.deepEqual(searchDocs(items, 'wallet'), []);
  assert.deepEqual(searchDocs(items, '[.*'), []);
});
test('caps user input and results while preserving plain untrusted text', () => {
  assert.equal(normalizeQuery('x'.repeat(200)).length, 120);
  assert.equal(searchDocs(Array(25).fill(items[0]), 'Dart').length, 20);
  assert.equal(searchDocs(items, 'script')[0].title, '<script>alert(1)</script>');
});
test('controlled route topics make keys and nip19 discoverable without stemming', () => {
  const guides = [
    {title: 'Nostr key management', description: 'Generate and manage an identity.', permalink: '/docs/usage/keys-management/'},
    {title: 'Choose an identifier', description: 'Public profiles and event references.', permalink: '/docs/usage/identity/nip19/'},
  ];
  assert.equal(searchDocs(guides, 'keys')[0]?.permalink, guides[0].permalink);
  assert.equal(searchDocs(guides, 'nip19')[0]?.permalink, guides[1].permalink);
});
test('plugin emits base-prefixed routes and canonical trailing-slash result links', async () => {
  const plugin = require('../plugins/docs-search.cjs')({baseUrl: '/nostr/', siteConfig: {trailingSlash: true}});
  let items, route;
  await plugin.contentLoaded({
    allContent: {'docusaurus-plugin-content-docs': {default: {loadedVersions: [{docs: [
      {title: 'Keys', description: 'Manage keys.', permalink: '/nostr/docs/usage/keys-management'},
    ]}]}}},
    actions: {createData: async (_, data) => {items = JSON.parse(data); return '/generated/guides.json';}, addRoute: value => {route = value;}},
  });
  assert.equal(items[0].permalink, '/nostr/docs/usage/keys-management/');
  assert.equal(route.path, '/nostr/search/');
});
