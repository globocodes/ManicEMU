---
name: stuut-hm-screen-2026-10-08
description: Operator is interviewing with Stuut (stuut.ai, AI agents for accounts receivable, NYC + SF eng, Series B 10-07) — HM screen 10-08, FDE call with head of FDE 10-13; verified company/role facts, prep doc location, portfolio-overlap pitch
metadata:
  type: project
  modified: 2026-10-15T23:30:00Z
  scope: operator
  provenance: Track "Stuut walkthrough" 659e116d; Ashby public posting API 2026-10-08, stuut.ai dev-blog + About, Fortune/TFN funding coverage
  supersedes: null
---

**Stuut** (stuut.ai, NYC HQ, SF engineering office, ~20–31 people, onsite): "AI coworker for order-to-cash" —
agents run collections (email/SMS/voice), cash application, payments, disputes/deductions, order management,
credit coming. Founders Tarek Alaruri (CEO, ex-Fairmarkit), Ben Winter (COO), Miraj Mohsin (design); eng
leadership Mek Stittri (CTO, ex-GitLab VP), Jason Jho (Head of Eng, NYC), John Kang (Head of AI), Adam
Chaarawi (cofounder, "Agentic OS"). Seed $5.9M → Series A $29.5M a16z-led (announced 2025-11-20) → Series B
$52.5M Insight-led with a16z + M12 (reported 2026-10-07, single source). Stack: Python/SQLAlchemy, Postgres,
Vue 3 + TS, Snowflake + CDC + semantic views, AWS, DBOS (credit team), AI code reviewer in CI. Values:
"Stand in front of the truck for customers / Face the bear / Think independently / Hard work creates room."
Open SF eng roles 10-08: MTS Applied AI Fullstack ($185–250K), MTS UI/UX (Vue), MTS AI/ML ($220–350K),
Data Engineer; NYC: MTS Full Stack Credit, FDE. Prep assumed the Applied AI Fullstack role.

**Update 2026-10-13:** role is now confirmed as **Forward Deployed Engineer** (NYC posting). 10-13 call = head of the FDE team, part conversation + part technical exercise (JS). Portfolio-overlap pitch used: Pave Workday bi-directional writeback for 20–30 enterprise customers = FDE work without the title; Retool onboarding platform (~80 users, ~5,000 customers) = scaling deployments; 40–200GB datasets + 91% load-time cut = enterprise ledger scale; no-PII client-side redaction = finance compliance; AI support agent (-28% investigations) + Postyx Plan/Execute + Bostrat approval cards/event log/cost attribution = safe, auditable, metered agents; Daisy checksum-based ETL = idempotent sync/CDC. Honest gaps: no NetSuite/SAP (Workday is the same class), no AR domain, Vue not React. The 10-08 prep doc path was NOT found on disk 10-13 (not under ~/.bostrat/repos or ~/Documents); the prep lived in Track 659e116d's workspace.

**Update 2026-10-13 (later):** operator PASSED the FDE call and advanced to the FINAL round. Recruiter call same day to get the final's format; FINAL FORMAT (recruiter notes 10-13): (1) 60 min technical implementation / integration-building case study from a real Stuut customer — whiteboard discovery, NOT coding: break down the problem, identify data + systems, scope and clarify up front, lock input/output first, game out edge cases, collaborate with the interviewer like a teammate, incorporate feedback immediately, explain choices and offer alternatives. (2) 30 min founding-team culture/values/behavioral — co-worker collaboration, autonomy + ownership, know the company north stars beyond website text. (3) 30 min customer-facing behavior — responsiveness, unruly customer, pushback/objection handling, expectation setting, unexpected problems, internal escalation (who, when, who is in the meeting, context). Prep plan delivered in chat 10-13. **Prep repo created 10-15: github.com/globocodes/stuut-prep (private), local checkout ~/.bostrat/repos/globocodes/stuut-prep** — docs 01 company research, 02 JS refresher, 03 portfolio overlap, 04 final round plan, 05 round-1 discovery + edge cases (carry into the room), 06 story bank with [fill] slots. Revise these docs, never a near-duplicate. **10-15 (later): doc 07 competitor deep dive added** (five tiers; HighRadius is the real fight and answered with $0-implementation gain-share pricing 2026-02-27; ZoomInfo = only public head-to-head and it is coexistence; Stuut soft spots = SOC 2 "in progress", DSO quoted 37/47/~50%, 4 G2 reviews, 404 pricing page; every match-rate/DSO figure in the field is vendor-reported; SuiteWorld 2026-10-25..28 may stale the NetSuite section).

**Why:** operator asked 2026-10-08 for hiring-manager-screen prep; the interviewer and exact posting were not stated.
**How to apply:** prep doc = `business/stuut-hiring-manager-screen-prep-2026-10-08.md` (walkthrough = Bostrat
event log/attribution/approval cards, backup = Pave Workday; bridges to their four dev-blog posts). Update with
the interviewer's name, the actual role, and the outcome. Never deliver prep as an Artifact ([[no-artifacts-ever]]).
Related: [[emli-interview-2026-10-01]], [[kiloforge-jo-interview-2026-09-24]], [[onsite-build-interview-framework]].
