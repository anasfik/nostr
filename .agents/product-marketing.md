# Product marketing context

**Document version:** v1
**Last updated:** 2026-11-11

## Product overview
dart_nostr is an MIT-licensed Dart and Flutter SDK for Nostr applications. It provides relay connections, signed events, typed results, subscription streams and identity utilities. Source: README, pubspec.yaml and the public client facade. Package version in this checkout: 11.0.0; Dart SDK >=3.0.0 <4.0.0.

## Audience and jobs
Dart and Flutter developers building social clients, relay-backed tools and Nostr integrations. Primary job: connect to relays and publish or subscribe from an existing Dart application. Secondary job: manage keys and NIP-05/NIP-19 identities. These are repository-derived hypotheses, not customer interview findings.

## Positioning and evidence
- Category: open-source Nostr SDK for Dart and Flutter.
- Concrete capabilities: `NostrClient.connect`, `publish`, `subscribe`; `NostrResult<T>` success/failure contract; key tooling and identity guides.
- Differentiation claims require comparison research. Do not claim fastest, safest, most popular or complete protocol coverage.
- Adoption counts, conversion baseline, customer quotes and paid marketing budget: MISSING.
- No customer or security certification claims are approved.

## Voice
Technical, direct and helpful. Show real API names and failure handling. Avoid hype, fabricated urgency and guarantees that network operations succeed. Explain that relays can reject events and public publishing is irreversible.

## Objections and boundaries
Review examples and API reference before adopting. Custom signing integrations use the public signer interface; do not imply bundled browser/mobile signers. This is an SDK, not a hosted relay or a turnkey Nostr app. Maintain private keys securely; never send them to analytics.

## Primary action
Read the quick start, install from pub.dev, then inspect source on GitHub. The website must introduce the package at `/` and keep documentation at `/docs/`.

## Measurement
Search Console access, GA4 stream and consent requirements must be verified before activation. An outbound package click is intent, not a verified installation. Never send keys, event content, npubs, relay URLs, arbitrary query strings or other identifiers as custom analytics parameters.

## Learnings
No measured marketing experiments yet.

## Changelog
- v1 (2026-11-11) — Initial repository-derived context for the domain landing page; unknown audience and measurement assumptions explicitly marked.
