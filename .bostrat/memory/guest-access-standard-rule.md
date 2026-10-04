---
name: guest-access-standard-rule
description: STANDARD RULE (operator, 2026-09-16) for adding any guest to the Pi — node-share globo-pi (never invite as a tailnet user), guest adds split DNS globopi→100.103.251.120 in THEIR tailnet, guest uses http://<app>.ts.globopi; no ACL edit per guest (autogroup:shared → globo-pi:53,80,8096); guest-facing Caddy sites carry both names
metadata:
  modified: 2026-09-16
  scope: operator
  provenance: operator said "make this the standard rule when im adding any guests going forward" after Dom connected, track/almanac-port-9f89b2bf 2026-09-16; procedure also written into ~/Documents/globo-pi/CLAUDE.md "Adding a GUEST"
---

When the operator adds a guest to the Pi, do it this way and no other:

1. **Share, don't invite.** Tailscale admin → Machines → `globo-pi` → *Share* → link to the guest;
   they accept into their own tailnet. Guests never become tailnet users (keeps the free plan's
   3-user cap and the member = operator assumption intact).
2. **Guest sets split DNS in their own tailnet:** DNS → Nameservers → Custom `100.103.251.120`,
   *Restrict to domain* `globopi`. Our ACL's `:53` is what makes that resolver reachable.
3. **Guest uses `http://<app>.ts.globopi`** (almanac, jellyfin, buzzer-beater, the-bakery,
   space-out, misous; Jellyfin app server URL `http://jellyfin.ts.globopi`). Plain `*.globopi`
   answers `192.168.1.13`, unroutable for sharees (KB 1084: shares carry no subnet routes).
4. **No per-guest ACL edit.** `tailscale/policy.hujson` admits `autogroup:shared` →
   `globo-pi:53,80,8096`; `group:friends` exists only for the invited-user exception.
5. **Guest devices never appear in Machines**; on the Pi they show as `device-of-shared-to-user`
   in `tailscale status`. Revoke = Machines → Share → remove the user.

**Why:** Dom's onboarding (09-16) burned an evening on the member-vs-share and LAN-vs-tailnet-IP
mismatches; the operator wants one repeatable path.

**How to apply:** a "give X access" request → point the operator at steps 1–3, verify from the Pi
with `tailscale status --json` (ShareeNode peers) and the Pi-hole log (queries from their 100.x),
and probe `<app>.ts.globopi` from a scratch netns. New guest-facing Caddy sites must list both
`http://<app>.globopi, http://<app>.ts.globopi`; operator-only sites `import operator_only` and
get no `.ts` alias. Related: [[friend-access-dom]], [[bind-mounted-config-stale-after-sed]].
