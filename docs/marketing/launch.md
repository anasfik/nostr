# dart_nostr site launch kit

Status: drafts, not published. Owner: maintainer. Updated: 2026-11-14.
Read `.agents/product-marketing.md` before changing claims.

## Positioning and audience

An MIT-licensed Nostr SDK for Dart and Flutter developers building clients,
services, or protocol experiments. Lead with runnable workflows, readable API
examples and source access. The new site introduces the package; documentation
explains it; the Flutter playground lets visitors inspect the core workflow.
No user counts, comparative performance, audits, or adoption claims are available.

## Search evidence and page ownership

Exa's 2026-11-11 query for Dart/Flutter Nostr SDK documentation returned
[pub.dev](https://pub.dev/packages/dart_nostr),
[the API reference](https://pub.dev/documentation/dart_nostr/latest/), and
[relay API documentation](https://pub.dev/documentation/dart_nostr/latest/nostr_instance_relays_relays/NostrRelays-class.html).
The [pub.dev API](https://pub.dev/api/packages/dart_nostr) reports latest 10.0.1;
repository version 11.0.0 is a source preview (rechecked 2026-11-14). Search excerpts can be stale: use
the package API for release truth. These are observed results, not search-volume
or rank measurements. GSC query/click/impression data is MISSING (auth failed).

| Intent hypothesis | Owning page | Reader's next action |
|---|---|---|
| Dart Nostr SDK / Flutter Nostr package | `/` | Try the playground or open quick start |
| Install dart_nostr / source preview | `/docs/installation/` | Resolve the matching dependency |
| Connect and publish with Dart Nostr | `/docs/quick-start/` | Run a local example |
| Nostr relay subscription Dart | `/docs/usage/relays-and-events/subscribing-to-events/` | Manage a subscription lifecycle |
| Nostr typed error handling | `/docs/usage/advanced/error-handling/` | Handle a failure explicitly |
| Nostr key management in Dart | `/docs/usage/keys-management/` | Choose a safe key workflow |
| npub vs nsec vs nprofile vs nevent | `/docs/usage/identity/nip19/` | Choose what to share |
| Encode and decode Nostr bech32 in Dart | `/docs/usage/keys-management/bech32-encoding/` | Use the SDK encoding methods |

See `seo-audit.md` for current technical evidence and `distribution.md` for
channel-specific drafts. These intent labels are hypotheses, not measured demand.

## Launch gate

- Host-specific nginx and origin TLS are live; do not claim that every local fix is deployed.
- Atomically deploy the corrected Flutter bundle and current SEO build after administrator access is available.
- Verify root, all docs, Flutter app, metadata, discovery files and genuine 404 on that release.
- Keep preview version clear. The separately requested package publication attempt stopped at Google OAuth; 11.0.0 is not published.
- Reauthenticate GSC/GA through their secure auth flows before activating measurement; never paste tokens.
- Obtain approval before submitting sitemap/indexing or posting announcements.
- Capture browser screenshots and disclose unsupported playground features.

## Announcement draft

Do not post until the corrected playground is live. Recheck the registry version
immediately before posting and update the version sentence if publication succeeds.

dart_nostr has a new home: https://nostr.gwhyyy.com/

Explore the Dart and Flutter SDK, follow the guides at `/docs/`, or open the
Flutter Web playground to inspect relay connections, keys, and signed events.
Publishing is an explicit action because Nostr events can be public and permanent.

These guides preview the 11.0.0 source tree. The published package is 10.0.1;
installation instructions explain how to use the matching source preview.

Source and issues: https://github.com/anasfik/nostr

## Listing copy draft

**Name:** dart_nostr
**Tagline:** A Nostr SDK for Dart and Flutter.
**Description:** Connect to Nostr relays, create and sign events, and manage
subscriptions from Dart and Flutter. MIT-licensed source, practical guides, and a
browser-based Flutter playground for exploring the core workflow.
**Website:** https://nostr.gwhyyy.com/
**Repository:** https://github.com/anasfik/nostr
**Package:** https://pub.dev/packages/dart_nostr

## Focused growth plan

1. **Executive priorities:** correct deployment, working first example, measured
   discovery. The website/docs/playground are the reusable owned assets.
2. **Strategic frame:** developer tooling, free open-source distribution. Frequent
   integration friction is a hypothesis, not customer-interview evidence.
3. **Current state:** existing pub.dev, GitHub and awesome-nostr library listing;
   the domain serves the SDK site. Corrected playground and SEO changes await an
   atomic deployment. Budget, team capacity, traffic and adoption baseline MISSING.
4. **Acquisition:** improve owned docs first. Prepare a GitHub release/site update
   and one Flutter/Nostr community post; publish only after approval. Skip ads.
5. **Activation:** visitor → playground or quick start → local integration.
   Measure guide entry and package/source exits, not invented successful installs.
6. **Retention:** maintain compatibility notes and examples with SDK changes.
   Prioritize recurring GitHub issues over a new mailing system.
7. **Referral:** make source and issue links useful; invite reproducible examples.
   No fabricated customer quotes or unsolicited bulk outreach.
8. **Revenue:** package remains MIT/free; no monetization or paid plan assumed.
9. **90 days:** weeks 1–2 ship/verify and unlock Google access; weeks 3–4 use real
   GSC queries to improve titles/answers; weeks 5–8 address first-use issues;
   weeks 9–12 revisit the most-used guides. Maintainer owns each stage.
10. **12 months:** quarterly compatibility refreshes; add content only where actual
    issues/search demand justify it. No forecast without traffic/capacity data.
11. **Operations:** repo holds copy/checks; GSC for search, GA4 for consented site
    behavior once configured. No account connection is currently verified.
12. **Tactics:** now = documentation, useful demo, package/source consistency;
    later = tutorial from observed questions; skip paid acquisition, directories
    unrelated to developer tooling, scaled SEO pages and email automation.
13. **Measurement and decisions:** see `tracking.md`. Review weekly after access
    works. Kill a content experiment if it addresses no real query or issue;
    use matching closed time windows before comparing rates. Budget and hiring
     decisions stay with the maintainer; no funding assumptions.

## Weekly operating loop

Maintainer: check broken links and version claims each week. After Google access
works, export the last complete 28 days of query/page data and compare with the
preceding 28 days. Improve one page with relevant impressions and a weak snippet
or missing answer, then annotate its deployment date. Judge changes only after a
comparable observation window; low samples remain inconclusive. Use reported
integration issues to pick the next example. Do not generate pages without a
distinct reader task or send promotional messages automatically.
