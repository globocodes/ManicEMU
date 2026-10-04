---
name: claude-subscription-for-personal-tools
description: DEPLOYED 08-28 (PR #26; token minted from chat via tmux-driven `claude setup-token`) — operator call: Claude calls inside the operator's own personal-use tools (almanac screenshot parser) run on their Claude Max subscription via headless `claude -p` with a `claude setup-token` credential (CLAUDE_CODE_OAUTH_TOKEN), not a metered API key; API key stays wired as fallback. Never route other users through it.
metadata:
  type: feedback
  modified: 2026-08-28T10:30:00Z
  scope: operator
  provenance: operator message "its fine because this is a product linked to personal use" after the policy read-out from code.claude.com/docs/en/legal-and-compliance (fetched 2026-08-28); PR follow-up to #24 on track/mismatch-adjustments-b0835b20
  supersedes: null
---

The Pi is logged in to Claude Code on a Max plan; the almanac container carries a
1-year `setup-token` credential in `~/Documents/globo-pi/.env` (mode 600) since
2026-08-28 — minted from chat by driving `claude setup-token` in tmux (paste the
OAuth code with `send-keys`, then a second `Enter` to submit). The operator decided their
own single-user tools may spend plan quota instead of API dollars.

**Why:** the product is personal-use — one operator, their own plan. Anthropic's
docs steer *product* code to API keys and forbid routing *other users'* requests
through plan credentials or collecting Claude.ai credentials; a one-operator
tool is the "ordinary individual use" case. They reserve enforcement, so the
API-key path is kept as a one-line `.env` fallback.

**How to apply:** when a feature in the operator's own repos needs a Claude
call, prefer spawning `claude -p … --output-format json --json-schema …` with
`CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token` (the pattern in
`lib/slips/entries/parse.ts`; the musl build installs on alpine images).
Gotchas pinned there: the CLI's schema validator rejects a `$schema` key; close
stdin or it idles 3 s; `--bare` never reads OAuth credentials. If the tool ever
gets a second user, switch to an API key — do not extend the subscription to
them. See [[prizepicks-entries-cross-book]].
