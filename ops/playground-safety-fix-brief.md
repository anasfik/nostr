# Playground safety fix wave

Read the controller, UI, tools, tests and SDK relay callers before editing.
No commits, pushes, privileged actions, live publishing or child agents.
Do not run Flutter builds while RAM is tight; inspect resources first and stop
heavy work if less than 2 GiB is available. Use /tmp/opencode/nostr-build.lock.

## Blocking findings to reproduce and fix

1. SDK relay disconnect currently clears relaysList only after socket closes;
   onDone calls _reconnectToRelay, which delays then reconnects without checking
   cancellation. Scheduled retries and in-flight connections must not register a
   socket after disconnect/free. Preserve existing public APIs and legitimate
   reconnect behavior. Test using a local WebSocket server, no external relay.
   A guard only before the delay is insufficient: disconnect may occur during it.
   Inspect every caller, init, registration and cleanup path; prove explicit
   disconnect and delayed/in-flight reconnect cancellation leave no live socket.
2. Controller connect awaits _closeSession before marking itself connecting;
   two calls or a disconnect during that await can orphan or revive a session.
   Use an operation/session generation or equivalent minimal cancellation guard,
   mark busy before first await, and dispose abandoned instances. Test concurrent
   connect, disconnect during connect, timeout and dispose with controlled local
   transport/session dependencies. Avoid a large fake API abstraction.
3. Count limits do not bound relay-controlled event content/tags. Bound accepted
   event bytes/fields and the SDK wire/registry path before expensive parsing or
   retention where feasible. Keep compose limits separate. Test oversized content
   and tags, count overflow and bounded warnings. Document residual wire limits
   honestly; no claim that a count cap bounds payload bytes.
4. README and UI claim keys clear on disconnect but controller retains them.
   Clear keys and locally signed event on explicit disconnect (safer default),
   align tests and copy. Private keys never appear in signed events; only public
   fields and signatures may leave the tab. Remove the false exception sentence.

## Address related verified review findings in the same path

- Disable publish unless connected with a signed event; confirmation lists live
  destinations, not configured-but-disconnected ones.
- The filter-validation test returns early while disconnected. Extract/reuse pure
  filter validation and test limits 0/101, no kinds/authors, malformed authors.
- Replace the hardcoded locally-verified indicator with actual authenticity.
  Remove unused JSON verification helpers/state if not exposed by the UI, rather
  than adding another feature. Inspect actual references first.
- SDK publish returns the first relay response, not all destinations. UI must say
  exactly that and must not imply rejection means no relay accepted. Do not add a
  receipt aggregation subsystem. Make partial/unknown outcome explicit.
- Avoid repeated BIP-340 verification on each build; bounded authenticity cache
  with correct invalidation, no trusting the same id with changed content.
- Remove misleading 'verified publishing' manifest copy. Make connect cancellable
  if the existing disconnect action can safely cancel the operation.

## Verification and report

Use real local WebSocket/lifecycle checks for SDK logic and widget/unit checks for
the UI. Observe regression failure first. Then run covering tests, analyze, and
the full offline package/playground suites when resources permit. No external
network publishing. Report exact commands/output, changed files, API contracts,
timeout/partial failure behavior, and any blocked checks to
/tmp/opencode/nostr-playground-fix-report.md. Do not claim release readiness from
source inspection. Leave build artifacts for parent assembly and deployment.
