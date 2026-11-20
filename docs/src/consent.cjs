'use strict';

// Pure consent helpers: no DOM/window access here so node:test can cover them.
// The React banner passes localStorage in; gtag is only touched by the component.
const KEY = 'nostr_consent';

function readConsent(storage) {
  try {
    const v = String(storage.getItem(KEY) || '').trim();
    return v === 'granted' || v === 'rejected' ? v : null;
  } catch {
    return null;
  }
}

function writeConsent(storage, value) {
  const v = String(value || '').trim();
  if (v !== 'granted' && v !== 'rejected') {
    throw new Error('consent must be granted or rejected');
  }
  storage.setItem(KEY, v);
}

function updateArgs(value) {
  const state = value === 'granted' ? 'granted' : 'denied';
  return ['consent', 'update', {
    ad_storage: state,
    ad_user_data: state,
    ad_personalization: state,
    analytics_storage: state,
  }];
}

module.exports = {CONSENT_KEY: KEY, readConsent, writeConsent, updateArgs};
