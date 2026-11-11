# Search and analytics readiness

Updated 2026-11-11. **Not activated.** No tracking scripts or placeholder IDs ship.

## Actual access checks

- GSC `list_properties`: authentication failed; no property list obtained.
- Google Analytics `get_account_summaries`: invalid_grant, token expired/revoked.
- A configured MCP server or a credential filename is not evidence of access.
- Search performance, property ownership, GA property and measurement ID: MISSING.

## Google Search Console

Use the secure authentication flow. Confirm whether an existing `sc-domain:gwhyyy.com`
property covers the subdomain; do not create duplicates by assumption. If no usable
property exists, request approval to create a URL-prefix or domain property and
complete the verification Google provides. DNS/account writes remain approval-gated.
After live verification, ask once before submitting
`https://nostr.gwhyyy.com/sitemap.xml`. Inspect root and quick-start URL index status.
Collect query/page clicks, impressions, CTR and position over matching closed
windows; do not promise indexing or infer rankings from Lighthouse.

## GA4 activation contract

Obtain the real property/data stream and its `G-…` ID via authenticated tools or
the secure admin UI. Confirm retention, privacy notice and consent requirements
before enabling it. A future implementation must default analytics/ad storage to
denied, load tracking only after consent, offer withdrawal, honor refusal, and
avoid duplicate SPA pageviews. Test accept, reject, revoke and route navigation
in the browser and verify receipt in GA DebugView before claiming activation.

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
