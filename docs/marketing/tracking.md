# Search and analytics readiness

Updated 2026-11-18. **Tracking is off in production.** No measurement ID, no loaded
script, no cookie. Analytics wiring is implemented but inert: `docs/plugins/analytics.cjs`
injects GA4 only when `GA_ID` is set to a valid `G-…` value at build time. A
2026-11-18 build without it produced `gtag count: 0` and passed the site checker
(`/tmp/opencode/nostr-analytics-build.log`).

## Actual access checks

- GSC: **AUTHENTICATED 2026-11-18** via the `mcp-gsc` loopback consent flow; token at
  `~/.config/mcp-gsc/token.json`. `list_properties` returns five `siteOwner` Domain
  properties; `sc-domain:gwhyyy.com` already covers the subdomain, so no new property
  and no DNS TXT verification were needed.
- GSC sitemap: `https://nostr.gwhyyy.com/sitemap.xml` submitted 2026-11-18 18:59 and
  processed the same day — status Valid, **21 indexed URLs**, 0 errors, 0 warnings.
  The older `https://gwhyyy.com/sitemap.xml` remains Valid with 20.
- GSC performance for the whole domain (28 days, 2026-10-21 → 2026-11-18): 3 clicks,
  123 impressions, CTR 2.44%, average position 6.4. That is dominated by the separate
  `openai_dart` project. The only Nostr-relevant query so far is `nostr flutter`
  (5 impressions, position 8.6, 0 clicks); `get_search_by_page_query` for
  `https://nostr.gwhyyy.com/` reports no data in 28 days.
- GSC index status, minutes after submission: `/` "URL is unknown to Google",
  `/docs/` unknown, `/docs/quick-start/` "Discovered - currently not indexed";
  `robots_txt_state` UNSPECIFIED and no Google canonical yet on any of them, which is
  normal before the first crawl. There is no public API to request indexing of
  ordinary pages; the sitemap, internal links and time are the available levers.
- GA `get_account_summaries` (2026-11-18): `503 … invalid_grant: Bad Request` — the
  refresh token is revoked or expired. A fresh loopback consent is listening on
  `127.0.0.1:8766` (`/tmp/opencode/ga_auth.py`, unit `ga-auth`); the token will land at
  `~/.config/gcloud/analytics_user.json` and the MCP env must then point at it.
- Cloudflare: the token at `~/.config/cloudflare/mcp_token` works for zone DNS reads
  (`gwhyyy.com` = `a2c724b37de8a94783dd1bdecbad8864`, 31 records). Zone Analytics
  returns error `1016` (permission missing); the remote MCP path returns `401`. Add
  Zone → Analytics → Read to that token to read traffic.
- A configured MCP server or credential filename is not evidence of access.
- GA property and measurement ID: MISSING (see GA4 section). Cloudflare analytics
  data: MISSING (token lacks the permission).

## Google Search Console

Authenticated and submitted; nothing further is user-blocked. The remaining work is
measurement over matching closed windows: query/page clicks, impressions, CTR and
position. Do not promise indexing or infer rankings from Lighthouse. Indexing follows
the submitted sitemap plus internal links; re-inspect after the first crawl rather
than resubmitting.

If a future property is genuinely needed, verification options in order of least
access: (1) domain property via a DNS TXT record in Cloudflare, (2) URL-prefix
property verified by an HTML file served from `docs/static/` once Google gives the
token, (3) a service account with read access to GSC.

## GA4 activation contract

Property `nostr.gwhyyy.com` (`properties/565042173`) with web data stream
`nostr.gwhyyy.com web` (`G-2GYP7GFL4D`, `https://nostr.gwhyyy.com`) was created
2026-11-18 under `anas fikhi` (`accounts/79832735`) via the Admin API using a
separate `analytics.edit` consent (`~/.config/gcloud/analytics_edit.json`);
the MCP's everyday credential remains the `analytics.readonly` consent. The
other 8 properties on the account belong to other products — verified via
data-stream inventory — and none was reused. Live release `20261118-193000`
builds with `GA_ID=G-2GYP7GFL4D`: the tag fires (browser proof requested
`googletagmanager.com`, `nostr-consent-proof.log` 10/10), consent defaults stay
denied until the visitor decides, and the banner from `docs/src/theme/Root.js`
offers Accept/Reject with the choice in `localStorage` (`consent.test.cjs`
4 pass, `check-site.mjs` asserts denied-by-default and no-tag-without-ID).
SPA navigations send no extra pageviews (no manual pageview code). Privacy note
lives in the banner's "What changes if I accept" disclosure; never collected:
keys, events, relay URLs, form input.

Still required before enabling: a consent banner (accept/reject/withdraw), a privacy
notice covering GA4, retention confirmation, duplicate-SPA-pageview suppression, and a
DebugView receipt test. Until then, do not set `GA_ID` in a production build.

| Proposed event | Trigger | Allowed enum properties | Decision |
|---|---|---|---|
| `page_view` | Consented navigation | Sanitized origin + pathname only | Which guides get used? |
| `cta_click` | Real link activation | `source`: hero/nav/footer; `destination`: playground/quick_start/package/source | Where does intent go? |
| `install_copy` | Successful clipboard write | `source`: landing/installation | Is installation sought? |

These are proposed events, not implemented collection. Package exits are not
successful installations. Do not capture playground actions until a separate
privacy review approves their exact schema. Never collect private keys, public
keys/npubs, event content/JSON, relay URLs, arbitrary query strings, form values,
raw referrers or user identifiers. Disable automatic outbound/search/form events
that could bypass these restrictions. Sanitize `page_location` and referrers,
including on `/playground/`, rather than relying on custom-parameter filters.

## Initial reporting

Weekly: count consented site visits, guide entries and package/source exits;
record sample sizes and consent coverage. Keep Google search impressions/clicks
separate from GA visits. Traffic from assistants is a lower bound, not full AI
attribution. Neither llms.txt nor schema proves inclusion or citations.
