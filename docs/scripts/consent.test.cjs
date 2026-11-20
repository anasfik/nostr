const test = require('node:test');
const assert = require('node:assert');

// RED: helper does not exist yet.
const consent = require('../src/consent.cjs');

function mem(initial) {
  let store = {...(initial || {})};
  return {
    getItem: (k) => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    _dump: () => store,
  };
}

test('no stored choice returns null', () => {
  assert.strictEqual(consent.readConsent(mem()), null);
});

test('round-trips granted and rejected', () => {
  const s = mem();
  consent.writeConsent(s, 'granted');
  assert.strictEqual(consent.readConsent(s), 'granted');
  consent.writeConsent(s, 'rejected');
  assert.strictEqual(consent.readConsent(s), 'rejected');
});

test('rejects garbage and trims', () => {
  const s = mem({nostr_consent: '  yes  '});
  assert.strictEqual(consent.readConsent(s), null);
  consent.writeConsent(s, 'granted   ');
  assert.strictEqual(consent.readConsent(s), 'granted');
});

test('update args grant storage on accept, deny on reject', () => {
  assert.deepStrictEqual(consent.updateArgs('granted'), ['consent', 'update', {
    ad_storage: 'granted', ad_user_data: 'granted',
    ad_personalization: 'granted', analytics_storage: 'granted',
  }]);
  assert.deepStrictEqual(consent.updateArgs('rejected'), ['consent', 'update', {
    ad_storage: 'denied', ad_user_data: 'denied',
    ad_personalization: 'denied', analytics_storage: 'denied',
  }]);
});
