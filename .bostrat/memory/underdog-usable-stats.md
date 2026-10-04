---
name: underdog-usable-stats
description: "Operator-locked whitelist of Underdog stat categories that are actually selectable for tennis and WNBA slips"
metadata:
  node_type: memory
  type: feedback
  modified: 2026-09-12T01:00:00.000Z
  scope: operator
  provenance:
    node: pi
    trust: operator-stated
  supersedes:
---

Locked by the operator 2026-08-16 ("lock that in for now and the future") after three rounds of
me proposing picks that could not be placed. **Only these stat categories may appear in a
proposed slip** — treat anything else as unbuildable no matter how good the number looks:

| Sport | Stat | Sides allowed |
|---|---|---|
| Tennis | **Games Played** | over + under |
| Tennis | **Break Points** | **over only** |
| Tennis | **Aces** (full match only — **1st Set Aces removed 2026-08-17**) | over + under |
| Tennis | **Double Faults** | over + under |
| WNBA | **3-Pointers Made** | over + under |
| WNBA | **Rebounds** | over + under |
| NFL (locked 2026-08-21, E15) | **Receptions** | over + under |
| NFL | **Receiving Yards** | over + under |
| NFL | **Rushing Yards** | over + under |
| NFL | **Passing Yards** | over + under |
| NFL | **Completions** | over + under |
| CFB (locked 2026-08-29, E24) | **Pass Yards, Receiving Yards, Rush Yards, Rush + Rec Yards, Receptions, Pass TDs, Receiving TDs, Rush TDs, Rush + Rec TDs ("player touchdowns"), Pass Attempts, Completions, FG Made, XP Made, Kicking Points, Longest Completion, Longest Rush, Longest Reception** (Underdog keys in `STAT_WHITELIST.cfb`) | over + under |
| CFB | **INTs Thrown** (`passing_ints`) | **over only** (operator 2026-09-01) |
| MLB (locked 2026-09-11, E26) | **Hits, Total Bases, Runs, RBIs, Hits + Runs + RBIs, Singles, Doubles, Batter Walks, Batter Strikeouts** | over + under |
| MLB | **Home Runs, Stolen Bases** | **over only** (a 0.5 under is the "stays quiet" shape; the backtest says they land 88.3% / 93.6%) |
| MLB | **Strikeouts, Pitching Outs, Hits Allowed, Earned Runs Allowed (`runs_allowed`), Walks Allowed** — starting pitchers | over + under |
| MLB | **1st Inn. Strikeouts / Runs Allowed / Hits Allowed / Batters Faced / Pitch Count** (`period_1_*`) | over + under — but the model is **muted** on them, see [[mlb-stats-db]] |
| Soccer (locked 2026-09-11, E27) | **Goalkeeper Saves, Fouls Committed (`period_1_2_fouls_against`), Fouls Drawn (`period_1_2_fouls_for`)** | over + under |
| Soccer | **Goals, Assists, Goals + Assists, Cards** | **over only** (every line is 0.5) |

**MLB not locked:** Fantasy Points. **Soccer NOT locked — offered and declined 2026-09-11:**
**Shots on Target** (374 lines) and **Shots Attempted** (251), the two biggest markets on the
soccer board; also every `period_1_*` (1H) key. Do not propose them.

**CFB not locked:** Total TDs (`total_tds`, counts passing TDs), First TD Scorer, every `period_*` / `season_*` / `game_high_*` line, Fantasy Points, Rush Attempts.

**NFL not locked (v0 out):** TDs, Longest reception/rush, Fantasy Points, Rush+Rec combos,
Tackles+Assists, Sacks, Kicking. NFL legs are singles only until the QB×receiver pair model
(T15.9) is backtested.

**Explicitly dead** (each rejected by the operator in turn): tennis **Sets Played** (either
side), **1st Set Games Won**, **Sets Won**, **Tiebreakers Played** lower, **Games Won**,
**1st Set Games Played**; WNBA **Assists**, **Points**, and every combo stat
(Pts+Rebs+Asts, Rebounds+Assists, Fantasy Points).

Still apply the `option_priority` check from [[underdog-correlated-stacks]] *on top of* this
list — it is per-line, and it is why WNBA 3-pointers **under** is offered on only ~32 of 93
rungs even though the category is legal. Whitelist first, then priority, then price.

**What this does to slip construction.** The old high-probability legs are all gone: the
ceiling drops from ~80% (1st Set Games Won) to roughly **68%** (Games Played over). Nothing on
a legal board reaches 70%. The one correlated pair shape that survives is **Games Played over
(player A) + Aces / Break Points / Double Faults over (player B)** — different players,
different stats, all four driven by the same latent "long match" factor, so they lift together.
Model it by making the rate stat Poisson with a per-game rate calibrated to its own market
median, then conditioning on total games from the fitted match distribution; do **not** treat
them as independent, and do not assume the old nested-pair lift (that needed Sets Played).
