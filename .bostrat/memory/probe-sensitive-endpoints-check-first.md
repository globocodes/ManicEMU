---
name: probe-sensitive-endpoints-check-first
description: "Before writing to a security-monitored endpoint to test a hypothesis, confirm the task still needs it and use a read-only path first — a refused /v1/ingest event PAGES the operator on ONE event"
metadata:
  node_type: memory
  type: feedback
  modified: 2026-09-16T03:37:00Z
  scope: operator
  provenance:
    node: pi (lesson from Track a953b3ac, laptop epoch on joeyafer-laptop, 2026-09-15)
    trust: operator-dogfood
  supersedes:
---

**Principle.** Before probing or writing to any security-sensitive or tenancy-monitored
endpoint, (1) confirm the action is actually still needed — the task may already be complete —
and (2) exhaust READ-ONLY alternatives that answer the same question. A write-probe to settle a
read-only hypothesis is never the first move.

**Concrete bostrat gotcha.** Any event the plane REFUSES on `/v1/ingest` (or on the WS
`events/append` door) — `forgedUserId`, `foreignTrack`, `squattedTrack`, `transferredAway` —
fires the tenancy alarm (`plane/src/tenancy-alarm.js` `refuse()`), and the F-19 bridge turns
that into a durable `audit_events` row + an ntfy PAGE to the operator on a single event.
Never re-POST an already-acked event to `/v1/ingest` "to see if it persists".

Read-only paths that answer persistence/ownership questions without paging anyone:
- `GET https://plane.bostrat.ai/v1/spine/<trackId>?limit=5000` with the node token
  (403 = not this token's owner, 404 = unknown, 200 = the plane's copy) — see
  [[investigate-remote-node-via-spine]]
- `GET /metrics` with the node token (ingest accepted/rejected/deferred counters)
- the node's own `GET /api/health` `plane` block (per-Track acked cursor)
- the plane DB itself, read-only, via [[plane-db-readonly-query-recipe]]
  (`audit_events where evt like 'tenancy.%'` shows every refusal with node/track/type)

**Why:** in Track a953b3ac (2026-09-15, laptop epoch) the lead re-POSTed one acked event to
`/v1/ingest` after the cleanup task was already done, purely to test whether the laptop's
events were reaching the plane; the plane answered `discarded` and the session was flagged.
(Root cause of the non-persistence turned out to be [[laptop-node-stale-bostrat-owner-2026-09-15]]
— the page was firing on every laptop event already; the probe added one more and was
unnecessary either way.)

**How to apply:** read first, write never for diagnosis; if a write is genuinely required,
say so and get the go-ahead before touching a monitored door. Related:
[[plane-tenancy-audit-2026-07-29]], [[tenancy-hardening-epic-t1-built]].
