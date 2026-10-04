---
name: underdog-correlated-stacks
description: "Tennis single-match stacks on Underdog: fit hold rates to the ladder, then near-nested legs give a 5-10x joint-probability lift the goblin pricing doesn't charge for"
metadata:
  node_type: memory
  type: reference
  modified: 2026-08-16T16:40:00.000Z
  scope: operator
  provenance:
    node: pi
    trust: operator-dogfood
  supersedes:
---

Follow-on to [[underdog-board-parsing]]. The flat board is engineered to ~50–52% and the
alternates are priced so each leg is roughly EV-neutral against a flat leg (multiplier x
probability ≈ 0.48 on every rung measured 2026-08-16). So no single leg carries edge. **The
only structural edge on a tennis board is correlation inside one match.**

**Recovering the match distribution exactly.** Fit two hold rates (server wins a game w.p. h,
i.i.d.) to the posted ladder and enumerate the full set/match distribution by DP — ~2,900
terminal states, no simulation needed. Serve order must carry across sets (a set with an odd
game count flips who serves first; a 7-6 set is 13 games). Fits land at 2–5pp RMS across
7–11 rungs on a Cincinnati slate; the tight ones (Sabalenka 2.2pp, Kostyuk 1.8pp, Medvedev
1.8pp) are trustworthy, 6pp+ ones are not. Code: `exact.py` / `fit2.py` pattern — grid search
h_fav ∈ [.56,.97], h_dog ∈ [.42,.95], minimise SSE vs de-vigged market probabilities.

**Only trust the model for the correlation, never the marginals.** The fitted model will
disagree with flat rungs by 2–8pp; that is fit error, not edge. Compute
`joint_adj = prod(market p) x [joint_model / prod(model p)]`, capped at the smallest market
leg. Using raw model marginals invents edge that isn't there.

**The result.** Legs like *Sets Played Lower 2.5*, *Dog Sets Won Lower 0.5*, *Tiebreakers
Lower 0.5*, *Fav Games Won Lower 12.5* and *Fav Games Played Lower X* are all restatements of
one scoreline — "favourite wins 2-0, short, no tiebreak". Some are logically nested (Dog Sets
Won = 0 implies Sets Played = 2). Joint probability lands 5–10x above the independent product,
while the base multiplier rises 3x -> 6x -> 10x -> 20x and each extra leg costs only ~0.65–0.85x.
So **a 5-pick inside one match strictly dominates a pair** — pairs on this board price out
below 1.0 EV, 5-picks at 2–4x. On 2026-08-16, five-leg single-match stacks hit 40–52% at
5–9x (breakeven 12–20%).

**⚠️ THE ACTUAL SLIP RULES, operator-confirmed 2026-08-16.** Tennis: **one stat per PLAYER,
but the opponent in the same match may be added on a DIFFERENT stat** — so exactly two legs
per tennis match are buildable, never more. WNBA: mixing is loose (multiple players and
multiple stats from one game are fine). The board JSON gives no warning of any of this
(`rfq_combinable` is true on everything; restrictions are enforced server-side at entry
build), so a big same-match EV is a red flag that the slip won't build unless it fits these
shapes. Five-leg single-match stacks are dead; the two-leg tennis version is not.

**The free leg.** Under those rules the best tennis pair is
`FAV Sets Played LOWER 2.5` + `DOG Sets Won LOWER 0.5` — different players, different stats,
legal. `DOG wins 0 sets` **strictly implies** `sets played = 2`, so the pair's joint
probability equals the dog leg alone: the Sets Played leg adds **zero risk** while moving the
slip one rung up the base ladder (3→6→10→20x). Two such pairs plus one independent leg is a
5-man carrying only **three** real risk units. On 2026-08-16 that built 5-mans at 19–30% for
3.2–6.6x, EV 0.96–1.22 — the only structures on the board that reach EV ≥ 1. Sanity check any
candidate pair by confirming the joint equals the smaller marginal exactly; if it doesn't, the
legs aren't nested and you're paying for a second risk unit.

**What's actually true once legs must be independent.** Measured across 205 alternates ≥55%
on the 2026-08-16 card, `p × payout_multiplier` sits in **[0.476, 0.489], mean 0.481** — and
exactly **0.500** on all 202 flat rungs. So a high-probability leg is not a bargain and not a
trap; it is hit-rate purchasable at a **fixed ~3.8% EV toll** versus a flat leg. Consequences,
all monotone: a 5-pick of 5 goblins hits ~29% and pays ~1.7x (EV 0.50); 5 flats hit ~4% and
pay 20x (EV 0.77); each goblin swapped in moves you along that line. Underdog's base ladder
(3/6/10/20x vs a fair 4/8/16/32x) means **fewer legs always = less hold** — a 2-pick is the
least-bad structure, a 6-pick the worst. Nothing on an independent-leg tennis board is +EV;
pick the size for the hit rate you want and pay the known toll.
