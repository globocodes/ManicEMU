---
name: kiloforge-jo-interview-2026-09-24
description: Operator is interviewing (Sept 2026) with Nate Tucker, founder/CEO of Kiloforge — Codename Jo (codenamejo.com) is a Kiloforge product; key facts + the Postyx/Bostrat overlap used for prep
metadata:
  modified: 2026-09-30T22:30:00Z
  scope: operator
  provenance: operator report in Track chat 2026-09-24 + web research (codenamejo.com schema.org publisher=Kiloforge, HN job post 47981348, kiloforge.com/careers, talks.natetucker.com); Jo-vs-Superhuman deep comparison 2026-09-24 → postyx/docs/25
  supersedes: null
---

**Codename Jo is a Kiloforge product** (schema.org `publisher` on codenamejo.com = Kiloforge). Nate Tucker = Kiloforge founder/CEO (SF; Harvard CS; ex Goldman/Jane Street, Vicarious, Google, Meta, Microsoft; CTO Nebula Genomics; founded StartPlaying — YC + a16z, profitable; left 2025). Kiloforge: "company factory" — agents ideate/validate/build/distribute software; vision 10,000 micro-apps × $1M ARR; founded 2026; $5.5M from a16z, Uncork, Rahul Vohra, YC partners. Values: Proactivity + Good Judgment. Founding-engineer JD: ship one niche app/week, extract patterns into the pipeline; $180–225K + 1–1.5%; TS/React/Node/Python/SwiftUI; onsite SF 5 days. Process: 15-min founder call → 1h in person → half/full-day onsite.

**Jo:** iOS hands-free voice assistant ("Talk to your tools"), private beta. gpt-realtime-2.1-mini over WebRTC, ephemeral-token broker, remote MCP servers declared in session config, single-tap activation, barge-in, read-back confirmation on exact values/destructive writes (incl. Mercury payments). Blog = 5 posts all dated 2026-07-30 (likely agent-authored). **Sept-8 legal docs narrow it to "a voice assistant for email"** (mailbox tokens, Gemini for attachments, liability for "mail sent, archived, or filed on a misheard instruction"); free invite-only beta; wake word + Android/CarPlay not shipped.

**Jo vs Superhuman (postyx/docs/25, 2026-09-24):** Superhuman has NO hands-free command surface (Write with Voice = AI drafting input, Apr 2026) but announced "full voice mode … completely hands-free" on 2026-09-01; Go 1.0 + iOS app shipped 2026-08-12, 150+ connectors, no voice. Squeeze: ChatGPT Voice + connected apps (Gmail/Calendar/Slack) shipped 2026-09-23 to free tiers; iOS 27 Siri AI (Gemini) beta late 2026 + CarPlay voice-app entitlement. Jo's defensible remainder = write-safety grammar (tiered read-back, spoken yes on Mercury payments), command-tuned turn detection, ops-tool depth. Vohra invests in Kiloforge → frame Jo as Superhuman-adjacent bet, never "Superhuman has no voice".

**Why:** the operator asked for interview prep on 2026-09-24; outcome arrives later in another Track.
**How to apply:** the overlap pitch = Postyx voice-mode doc 20 (same Realtime architecture, measured /plan 18.5s median, gate failed → pivot to STT+TTS) + read-back-fidelity/"recite don't paraphrase" + doc 22 MCP-commoditization thesis + Bostrat Realtime concierge (PR #343) + Bostrat "agents run ops" receipts. Never claim Superhuman can't write Outlook (Vohra is a Kiloforge investor). Update this file when the outcome lands. Related: [[accelerator-applications-status]], [[voice-chat-realtime-built]].

**Onsite challenge (2026-09-30):** rebuild a simplified StartPlaying.games in 1 hour on onsite-kit (Express + Vite/React, Neon); scored on prioritization + velocity; ten unordered features (listing, categorization, auth, FAQ, SEO/GEO, privacy/ToS, quiz, events, payments, deployment). Plan lives in circuit **Codename Jo Build** (blueprint ids `BP-JO-R*`/`BP-JO-I*`, 10 decisions on the ledger). Golden path = browse → filter → detail → quiz → book; payments/SSR/scraping are WON'T. Gotcha: `~/.onsite.env` has no `ANTHROPIC_API_KEY`, so the quiz demos on the replay cache until the key is set (M3).
