---
name: no-claude-artifacts-unless-asked
description: NEVER publish/store a Claude Artifact (claude.ai artifact page) unless the operator explicitly asks for one — deliverables live in the repo (docs/, bostrat-mock, bostrat-runbook, bostrat-blueprint)
metadata:
  modified: 2026-08-21T00:00:00Z
  scope: operator
  provenance:
    node: fly
    trust: operator-feedback
  supersedes:
---

**Feedback (operator, 2026-08-21):** never store/publish Claude Artifacts (the `Artifact` tool / claude.ai artifact pages) unless explicitly asked to.

**Why:** the research doc on rework attribution was auto-published as an artifact; the operator does not want deliverables parked on claude.ai. The Bostrat surfaces (repo `docs/`, `bostrat-mock`, `bostrat-runbook`, `bostrat-blueprint`, chat) are the durable, reviewable homes.

**How to apply:** write deliverables into the repo and/or the bostrat-* publishers; summarize in chat. Only call the Artifact tool when the operator says "artifact" / "publish to claude.ai".
