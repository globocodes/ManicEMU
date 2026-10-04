---
name: no-remote-docs-except-github
description: Never publish docs/reports to remote services (e.g. Claude artifacts) — markdown files in the repo only; GitHub is the sole acceptable remote
metadata: 
  node_type: memory
  type: feedback
  originSessionId: da4d2371-e671-4438-9f09-6cca935bad14
  modified: 2026-07-03T06:26:27.233Z
  scope: operator
  provenance:
    node: pi
    originKey: -home-globo--bostrat-workspaces-7a4129bb
    trackId: 7a4129bb
    trust: operator-dogfood
  supersedes:
---

Do not publish documentation, reports, or one-pagers to any remote service by default. The only acceptable remote surface for docs is GitHub (via the repo itself). Stated 2026-07-02 after I published an eng one-pager as a Claude artifact and the user asked for it as a markdown file in the repo instead.

**Why:** globo keeps project docs versioned alongside code (see `bostrat/docs/` convention of dated kebab-case markdown files) and doesn't want content scattered on or cached by external hosts.

**How to apply:** When asked to "document" something, write a markdown file in the relevant repo (match the existing docs convention, e.g. `docs/<topic>-YYYY-MM-DD.md`). Don't use the Artifact tool for documentation unless explicitly requested. Related: [[bostrat-pr-merge-ui-research]]
