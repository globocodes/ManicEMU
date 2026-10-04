---
name: talkeetna-availability-watcher
description: Watcher script polls Talkeetna Alaskan Lodge's Inntopia API for Feb 23 - Mar 1 2027 availability and pings ntfy on change
metadata:
  modified: 2026-08-16
  scope: operator
  provenance: built in Track session 2026-08-13 at operator request; landed on main 2026-08-16
---

`talkeetna-watch/check.py` on `main` of github.com/globocodes/talkeetna-watch
(its own repo; PR #1 merged 2026-08-16) watches Talkeetna Alaskan
Lodge (Pursuit/Alaska Collection) for the operator's Feb 23 – Mar 1 2027 stay
becoming bookable. It queries the lodge's own Inntopia booking API
(`bookings.alaskacollection.com`) — NOT Google Hotels, which has no public API
and lags the hotel's own engine. Anonymous storefront login comes from the
public `/content/configs/anonymoususers.json` (geography `TAC`); the signal is
per-night `inventory` from `/api/product/hotelcheckincalendar` (product code
`TAL-TAL`, rate `BAR`). As of 2026-08-13 the whole window shows inventory 0 and
the product's earliest bookable date is 2027-02-26 (winter 2026 season was
Feb 27 – Mar 23, so the operator's Feb 23 check-in may never fully open — the
watcher distinguishes full vs partial window). Change-only notifications go to
ntfy topic named in the script/README; state in
`~/.local/state/talkeetna-watch/state.json`. Meant to be driven by a daily
operator-created Loop ("Talkeetna availability watch").

The proposed loop's plan is checked in at `talkeetna-watch/loop-plan.json`.

**Why:** avoids re-deriving the reverse-engineered API flow if the loop breaks.
**How to apply:** if the check starts failing, re-verify the endpoints against
the app bundle at `bookings.alaskacollection.com/bundles/app` before rewriting.
A loop's run Track is created from the repo's DEFAULT branch — code a loop
invokes must be merged to `main`, not left on a PR branch, or run 1 fails.
