---
name: blueprint-sibling-tick-copy-source
description: When bostrat-blueprint update is refused because a sibling ticked an item on the plane before its PR merged, the verbatim line is on the sibling's remote track branch or in its worktree under ~/.bostrat/workspaces/<id>/docs/BLUEPRINT.md
metadata:
  type: feedback
  modified: 2026-10-09T06:40:00Z
  scope: operator
  provenance: BP-CB-D8 Track, 2026-10-09, three refusals in a row (D10 on main, D11 and I6 only on the plane)
  supersedes: null
---

During a fan-out, `bostrat-blueprint update` is refused with "would un-tick" or "N items differ" whenever a sibling Track published its tick ahead of its merge. `origin/main` then does NOT carry the line; `bostrat-blueprint show` prints item text without the status note; the show JSON API has no markdown either.

**Why:** the plane's version advances on every sibling publish, so a doc built on the merged main is stale within minutes during a fan-out.

**How to apply:** `git fetch origin` and read the sibling's branch (`git show origin/track/bp-cb-<item>-<id>:docs/BLUEPRINT.md | grep '^- \[x\] \[BP-..-X\]'`); if not pushed yet, grep the sibling's local worktree `~/.bostrat/workspaces/*/docs/BLUEPRINT.md`. Replace only that line, then `bostrat-blueprint update --base <v> docs/BLUEPRINT.md` with the version the refusal names. To merge main with uncommitted work, park it in a WIP commit, merge, then `git reset --soft origin/main` so the ship card still makes the real commit.
