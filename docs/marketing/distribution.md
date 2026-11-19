# Distribution queue

Updated 2026-11-18. **Prepared, not sent.** Every external post, submission and
indexing request needs explicit approval. The refined build is live
(`/var/www/nostr/current` → `releases/20261118-180832`) with the corrected console,
so the "old playground" warning no longer applies — recheck the live page once more
before using any draft, and keep the 11.0.0-preview vs 10.0.1-published distinction.
No marketing account or API credential is currently connected (see the access
requests in `tracking.md`); nothing here can be posted from this session without one.

No merge or push is part of this queue. The pre-existing Pages workflow can run
on docs changes pushed to `main`; review that legacy publication path before any
future integration (see `seo-audit.md`, “Legacy Pages publication gate”).

## Channel decisions

| Channel | Evidence / fit | Next action | Gate |
|---|---|---|---|
| GitHub | Existing package repository and issue audience | Use the site-update draft below in an existing appropriate discussion or release note | Corrected site live; maintainer approval; do not create a release for unpublished 11.0.0 |
| Maintainer's Nostr account | Developers can try a Nostr SDK in their browser | Publish one useful note, respond to actual integration questions | Corrected playground live; explicit public-event approval and secure signer access |
| Show HN | A working tool is tryable without registration | Use the demo-led draft only after the corrected demo is live | Review current rules, maintainer present to answer, posting approval |
| awesome-nostr | dart_nostr is already in Libraries | Keep the existing listing; no duplicate PR or backlink submission | Only propose an update if its description is inaccurate |
| pub.dev | Existing package listing; latest 10.0.1 | Complete the separately requested 11.0.0 release through secure OAuth, then update version claims | Release checks and owner authentication; never bypass validation |
| Broad directories / paid ads / cold outreach | Audience fit, budget and conversion data MISSING | Skip | Revisit only with evidence |

## GitHub site update draft

**Title:** A new home for the dart_nostr guides and Flutter playground

The Dart and Flutter Nostr SDK now has a dedicated site:
https://nostr.gwhyyy.com/

The guides cover relay connections, signing events, subscriptions and typed
failures. The Flutter Web playground lets you generate an ephemeral identity,
inspect signed event JSON and read relay events. It connects only when you ask.
Publishing requires a separate public-event confirmation.

The guides target the 11.0.0 source preview. pub.dev currently lists 10.0.1;
the installation guide explains how to use the matching source snapshot.

Start with https://nostr.gwhyyy.com/docs/quick-start/ or try
https://nostr.gwhyyy.com/playground/. If an example fails, report the SDK version,
platform and a minimal reproduction without private keys or sensitive event data.

## Nostr note draft

I'm working on dart_nostr, an MIT-licensed Nostr SDK for Dart and Flutter.
The new site has practical guides and a Flutter Web playground for inspecting
relay connections and signed events: https://nostr.gwhyyy.com/

The playground starts offline. Generate an ephemeral key, sign locally, then
connect to read events. Public publishing is a separate confirmed action.
It covers the core workflow, not every NIP or wallet integration.

The docs preview 11.0.0; pub.dev currently lists 10.0.1. The install guide explains
the source-preview setup. I'd like feedback on unclear examples or integration
failures. Please keep private keys and sensitive event data out of reports.

## Show HN draft

**Title:** Show HN: A Flutter Web playground for a Dart Nostr SDK

**URL:** https://nostr.gwhyyy.com/playground/

**First comment:** I maintain dart_nostr and built this console to make its core
workflow inspectable. It uses the actual Dart SDK in a Flutter Web app: generate
an ephemeral identity, sign an event locally, connect to a relay and read a
subscription. Nothing connects on page load. Publishing requires confirmation
because relays can retain public events.

This is a focused SDK demo, not a complete Nostr client. Direct messages, wallet
flows and external signer integrations are outside the playground's scope.
The guides target the 11.0.0 source preview; the registry still lists 10.0.1.
Source: https://github.com/anasfik/nostr

## Before and after any approved post

1. Verify the corrected live demo hash, mobile layout, local signing and read-only
   subscription. Cancel the publish dialog during QA; do not post a test event.
2. Check https://pub.dev/api/packages/dart_nostr and update every version sentence.
3. Review the destination's current rules. One relevant post; no duplicate
   submissions, bought links, vote requests or unsolicited direct messages.
4. Record the approved channel, post URL and date. Optional campaign URLs use
   only fixed labels, such as `?utm_source=nostr&utm_medium=social&utm_campaign=docs-launch`;
   never include a user identifier or key. Tracking is currently disabled.
5. Reply with technical help. Record recurring questions as candidate guide fixes,
   not testimonials or validated conversion claims.

Sources checked 2026-11-14:
- https://news.ycombinator.com/showhn.html
- https://github.com/aljazceru/awesome-nostr#libraries (existing dart_nostr entry)
- https://pub.dev/api/packages/dart_nostr
