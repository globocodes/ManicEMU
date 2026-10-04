---
name: emli-interview-2026-10-01
description: Operator has a 1h sit-down 2026-10-01 with the two Emli founders (get-emli.com, AI marketing, a16z speedrun) about joining; verified product facts + the pitch angle used for prep
metadata:
  type: project
  modified: 2026-10-01T09:30:00Z
  scope: operator
  provenance: Track "Emli lockdown" 9f75a067, web research 2026-09-30 (get-emli.com + solution pages, search snippets of older site copy, Vercel headers); founders NOT findable publicly
  supersedes: null
---

**Emli, Inc.** (Delaware c/o 251 Little Falls Dr; hello@get-emli.com; get-emli.com, Next.js/Turbopack on Vercel sfo1, own email+password auth at /app/signin). Tagline "Simulate every customer. Optimize every offer." Builds an "AI model/persona of every customer" from transaction history, estimates each one's response to candidate offers (incl. inaction), outputs a customer-level plan with reasons + constraints; today exports CSV into the brand's existing tools, older copy promised a "Campaign Studio" sending through Braze/Iterable/Salesforce and an "Emli AI Agent" that re-scores past campaigns against the optimal design. Verticals: retail/e-com, subscriptions, travel/hospitality, F&B. Early access, services-assisted onboarding ("our team helps you get started with your data"). Backed by Vento (Exor's Italian-founder fund) → at least one founder likely Italian. Operator says recently accepted to a16z speedrun (cohort not confirmed; SR007 runs Jul 27–Oct 11 2026, SR008 would be next). Thesis page is password-gated but the operator has read it: framing = "from segmentation to atomization", and it explicitly proposes a hybrid of uplift modeling + simulation (so the hybrid pitch is agreement, not correction); no founder names, pricing, customers or metrics anywhere public.

**Update 2026-10-01:** operator reports Emli is bringing on a Fortune 500 customer, named by the operator 10-01 as P&G (not public). Prep retargeted to "young company landing an enterprise account": what to make durable (data handling, plan correctness, audit/replay, holdout integrity) vs cheap (everything else), simulation cost at millions of customers, and the operator as the engineer who kept enterprise accounts at Pave.

**Founders (operator-supplied 2026-10-01):** Alberto Minghetti (LinkedIn /in/minghetti CONFIRMED by operator 10-01: "Stealth Startup", Oxford, ex-Coinbase per snippet, London/US, engages with BMLL market-data content — quant/finance read, low confidence) and Mark Robinson (name provisional per operator, no public footprint). Emli absent from speedrun.a16z.com/companies through SR007 → likely SR008. Prep repo: github.com/globocodes/emli-prep (private; docs 01–06: research, founders, thesis vs counterargument, measurement/holdout primer, audit trail from Bostrat event log, pitch plan, 08 enterprise retention/SLA/on-call with [fill] slots, 09 AI safety from the Agent action audit circuit 384e35ce + BP-NG circuit, 10 hour-long conversation script (seven timeboxed blocks, the doc to carry in), day-of runbook = Bostrat runbook 57be5b33 on Track 9f75a067).

**Why:** operator asked 2026-09-30 for a discussion plan + pitch for coming on board; outcome lands in a later Track.
**How to apply:** pitch = Daisy (campaign reporting, Mailchimp/Mandrill, HubSpot ETL) + Pave (Workday writeback, no-PII ingestion, 40–200GB customer datasets) + Postyx Plan/Execute-with-review (= Campaign Studio pattern) + Bostrat/Misous per-task LLM cost attribution and eval harnesses. Offer a paid trial build instead of a traditional interview. Update with the founders' names and outcome. Related: [[kiloforge-jo-interview-2026-09-24]], [[onsite-build-interview-framework]], [[gve-ghost-valley-enterprises]].
