'use strict';

// Analytics is opt-in: nothing is injected unless GA_ID is set at build time.
// Consent defaults are denied, so no cookies are stored until a visitor grants
// consent through a future banner. See docs/marketing/tracking.md.
module.exports = function analytics() {
  const id = (process.env.GA_ID || '').trim();
  if (!/^G-[A-Z0-9]{6,}$/.test(id)) {
    return {name: 'analytics'};
  }
  return {
    name: 'analytics',
    injectHtmlTags() {
      return {
        headTags: [
          {
            tagName: 'script',
            attributes: {async: true, src: `https://www.googletagmanager.com/gtag/js?id=${id}`},
          },
          {
            tagName: 'script',
            innerHTML: [
              'window.dataLayer = window.dataLayer || [];',
              'function gtag(){dataLayer.push(arguments);}',
              "gtag('consent', 'default', {ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'denied'});",
              `gtag('js', new Date());`,
              `gtag('config', '${id}');`,
            ].join('\n'),
          },
        ],
      };
    },
  };
};
