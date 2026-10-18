---
name: cloudflare-token-on-pi
description: Cloudflare API token lives at Documents/globo-pi/secrets/cloudflare/CLOUDFLARE_API_TOKEN on the Pi; zone-scoped, now sees six zones incl. closingbell.us (added 2026-10-09), DNS read+edit, expires 2027-06-01
metadata:
  type: reference
  modified: 2026-10-09T00:20:00-07:00
  scope: operator
  provenance: verified 2026-10-08 on the ClosingBell planning Track; re-verified 2026-10-09 on Track BP-CB-D7 after the operator widened the scope
  supersedes: null
---

The operator's Cloudflare API token on the Pi is the file
`~/Documents/globo-pi/secrets/cloudflare/CLOUDFLARE_API_TOKEN` (root-owned, world-readable,
53 chars, trailing newline — `tr -d '\n'` before use). Verified 2026-10-08: status active,
expires 2027-06-01, DNS records readable. It is ZONE-SCOPED: on 2026-10-08 `/zones` listed only bostrat.ai
and ghostvalley.enterprises (both on konnor/rosalie.ns.cloudflare.com, account
"Globocodes@gmail.com's Account", account id 969fd4af…). No account-level read.

The same account hosts the Cloudflare Pages project `ghost-valley-web` (wrangler logs in
`~/.config/.wrangler/logs`, no stored wrangler login). postyx-web deploys to Pages from
GitHub Actions with repo secrets CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID — a separate copy.

2026-10-09: the operator widened the token. `/zones` now lists bostrat.ai, bostrat-views.app,
closingbell.us, ghostvalley.enterprises, localcircuit.app and postyx.ai. closingbell.us zone id
c6853bb9215b7fb6434c1769a574a526, status active, konnor/rosalie nameservers, ZERO DNS records
as of that check (nothing points anywhere yet). Edit scope is not provable read-only; BP-CB-I7's
first `--dry-run` then real upsert is the proof. Plan: [[closing-bell]] blueprint BP-CB-D10 / BP-CB-I7.

**How to apply:** read the token from the file, never print or commit it; probe read-only
(`/user/tokens/verify`, `/zones?name=`) before any write; if a zone is missing from `/zones`,
it is the token scope, not the account.
