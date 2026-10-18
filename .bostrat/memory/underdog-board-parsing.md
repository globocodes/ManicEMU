---
name: underdog-board-parsing
description: "How to pull and de-vig the full Underdog Fantasy prop board; why the flat pick'em line is always ~50/50; the join check skips per line and fails only at a 10% mismatch rate (feed-side mojibake titles 09-14)"
metadata:
  node_type: memory
  type: reference
  modified: 2026-09-15T20:05:00Z
  scope: operator
  provenance:
    node: pi
    trust: operator-dogfood
  supersedes:
---

Underdog Fantasy's full prop board is fetchable as one public JSON document (the v5 board
endpoint under `api.underdogfantasy.com`) — ~16 MB, all sports at once. On 2026-08-14 it
carried 7,215 `over_under_lines` across 83 `games` + 158 `solo_games`.

**Join path** (four collections, joined by id):
`over_under_lines[].over_under.appearance_stat.appearance_id` → `appearances[].id`, then
`appearances[].player_id` → `players[].id` (carries `sport_id`, name, team) and
`appearances[].match_id` → `games[].id` **or** `solo_games[].id` (tennis uses `solo_games`,
with `abbreviated_title` like `"Baez vs Dimitrov"`). Validate the join by asserting
`over_under.title` starts with the joined player's name — it caught 0/376 mismatches on a
good join. **But a nonzero count is NOT proof the join is wrong** (three false-mismatch
incidents so far): Underdog strips accents from titles and prefixes soccer titles with a
space (09-11, 79 lines — fixed by comparing `normName`), and on 2026-09-14 20:00 PT the feed
itself carried mojibake titles (`"Mario Soriano Carren?o Goals O/U"` for player `Soriano
Carreño`, 6 soccer lines) that no normaliser can repair. Each time the check threw the WHOLE
board away and the nightly built 0 slips, because Sleeper is never a fallback by design
(`slips-pool-starvation-09-05`). Since 09-15 (PR #44, DEPLOYED 09-15 ~19:50Z; the 12:54 PT regenerate built runs 205/206 with 7 lines skipped) `parseBoard` skips a mismatched line by itself
(run note `skipped {"join-mismatch":N}`) and `fetchBoard` throws only when mismatches reach
`JOIN_MISMATCH_FAIL_FRACTION` (10%) of checked lines — a genuinely wrong join mismatches
essentially every line, so the threshold separates the two. When a run note says
`underdog: FAILED — … join check failed: N/M`, read N/M: a small N is a feed glitch, a
near-total one is the join.

**Finding the real pick'em line.** Each player+stat is a *ladder* of rungs. The standard
flat-payout line is the one where **both options have `payout_multiplier == "1.0"`**; every
other rung is an alternate paying more or less than 1×. Do not guess the standard rung from
prices. `has_alternates` is `false` on every record and is useless.

**Key structural fact:** de-vigging the two-sided American prices on the flat rungs shows the
standard board is engineered flat — across 90 props on a WNBA + tennis slate, every single
favoured side landed in a **50.0%–52.4%** band (median hold 5.18%). Underdog sets the line at
its projection's median, so ranking the flat board by probability ranks rounding error, not
edge. Real probability spreads (70–85%) exist only on alternates, which pay proportionally
less. Any analysis that claims a big edge on a flat rung is almost certainly using a stale
baseline.

**The classic trap:** comparing lines to *season* averages screams "mispriced" whenever a
player's role just changed. On 2026-08-14 Alanna Smith's lines implied ~2× her season line;
she had just moved into the starting lineup for an injured Jessica Shepard and gone 13/11.
Always reconcile a large model-vs-market gap against injury/role news before believing it.
