---
name: onsite-build-interview-framework
description: Build-in-an-hour interview retro 2026-09-30 — layer-shaped Tracks + a 30-min lead phase + no integrator left the quiz unmerged and the DB unseeded; next time feature-shaped Tracks, thin lead (≤10 min), one integrator, kit pre-bakes auth/seed/SEO
metadata:
  type: feedback
  modified: 2026-10-01T03:05:00Z
  scope: operator
  provenance: Track "Onsite retro" fb3bf691, git timeline + blueprint v7 freeze notes; full write-up in onsite-kit docs/onsites/2026-09-30-codename-jo/retro-onsite-2026-09-30.md
  supersedes: null
---

The 2026-09-30 Codename Jo onsite (StartPlaying in 60 min, scored on prioritization + velocity) froze at
3 clean / 2 half / 1 defended decline / 4 missing of ten features. Causes: the lead Track took ~30 of 60
minutes (M1 target was 10) because it also built in-memory handlers and an asserted fixture generator;
Tracks were split by layer (data/backend/smarts/screens) so the quiz needed three PRs to show anything
and PR #5 never merged; a research Track ("future proofing") ran inside the hour; nobody owned
merge + seed + smoke, so the View pointed at an empty Neon DB; auth stayed the invisible kit cookie.

**Why:** the operator read the exercise as form when it was delivery — the judge scores only what is
clickable on the link at minute 60 plus the defended MUST/SHOULD/WON'T order.
**How to apply:** 0–5 blueprint with reasons; 5–15 thin lead (migration + contract + seed-in-dev + View);
15–45 one Track per FEATURE (end to end, PR, kill time 40); 45–55 integrate + seed + phone smoke;
55–60 narrate from the blueprint. Give every feature a visible surface (Sign-in page, /sitemap.xml).
Before the next one, bake auth UI, seed-on-dev, SEO routes, by-date list and legal/FAQ templates into
onsite-kit and rehearse once on a different domain. Related: [[kiloforge-jo-interview-2026-09-24]],
[[onsite-view-demo-db-and-gating]].
