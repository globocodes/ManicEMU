---
name: claude-code-headless-gating
description: Verified 2026-10-10 from code.claude.com docs — how to fence a headless `claude -p` run (deny-rule syntax and limits, hook + sandbox for real boundaries) and that claude-code-action v1 accepts a Max-plan `claude_code_oauth_token`
metadata:
  type: reference
  modified: 2026-10-10T00:00:00-07:00
  scope: operator
  provenance: code.claude.com/docs/en/permissions and /docs/en/github-actions fetched 2026-10-10 while scoping the ClosingBell build agent (BP-CB-D17, D18); Claude Code CLI 2.1.296 on the Pi
  supersedes: null
---

- Rules evaluate deny → ask → allow; an allow can never carve an exception out of a deny.
- File rules are checked only as `Read(path)` and `Edit(path)`; `Write(...)`, `MultiEdit(...)`,
  `Glob(...)` path rules are accepted but never consulted. A `Read` deny also blocks Edit and Write
  on that path (CLI ≥ 2.1.228). Patterns are gitignore-style; as deny rules `secrets/**` matches at
  any depth, `/src/**` only at the anchor; with `--settings <file>` the anchor is that file's dir.
- A `Bash(curl *)` deny matches the text Claude types, not `/usr/bin/curl` or `sh -c 'curl …'`:
  the docs say it is not a security boundary. Real boundaries = a PreToolUse hook reading the full
  command text + the sandbox (`sandbox.enabled`, network allowlist) + no credentials in the env.
- `--settings`, `--allowedTools`, `--disallowedTools`, `--max-turns`, `--append-system-prompt-file`,
  `--output-format json --json-schema` all work with `-p`; `--bare` skips hooks and never reads OAuth.
- claude-code-action v1 inputs: `claude_code_oauth_token` (Max/Pro, from `claude setup-token`),
  `prompt`, `claude_args`, `settings`; it authenticates as the Claude GitHub App (Contents write) —
  too much reach for a fenced agent, use the raw CLI in a plain workflow step instead.

**How to apply:** for any "agent that may only touch X" design, pair deny rules with a hook and the
sandbox and keep secrets out of the step's env; see [[claude-subscription-for-personal-tools]] for
the token policy and the ClosingBell blueprint D17/D18 for a worked layout.
