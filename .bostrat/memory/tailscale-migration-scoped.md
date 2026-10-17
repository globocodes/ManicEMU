---
name: tailscale-migration-scoped
description: WireGuard→Tailscale migration in progress; doc + ACL draft live in globo-pi tree (removed from bostrat repo); P0 host install done, node awaiting auth
metadata:
  modified: 2026-09-16
  scope: operator
  provenance: track/tailscale-upgrade-4c990934 scoping session; P0 executed + doc relocated in track ba2c56fa
---

WireGuard→Tailscale migration IN PROGRESS as of 2026-08-02 — scope doc at `~/Documents/globo-pi/docs/tailscale-migration-scope-2026-08-02.md` (moved out of the bostrat repo, where it was committed in error on `track/tailscale-upgrade-4c990934` and removed in `bab59db`; globo-pi is not a git repo). P0 done on the Pi host: tailscaled 1.98.10 via apt (Debian trixie), IP forwarding in `/etc/sysctl.d/99-tailscale.conf`, eth0 UDP-GRO tuning persisted via `tailscale-gro-tuning.service`, brought up with `--accept-dns=false --advertise-exit-node`; awaiting operator auth. ACL draft: `~/Documents/globo-pi/tailscale/policy.hujson`.

Load-bearing design: tailnet **split DNS `globopi` → Pi-hole** preserves every `*.globopi` URL and the Views wildcard, so the bostrat app needs **zero code change** (only the optional ts.net-TLS Phase 5 would touch `extractViewSlug()` 2-label assumption, cert filename literals, vite allowedHosts). Sharpest motivation: WG has no ACLs — any friend peer can hit the unauthenticated `:3362` API incl. `GET /api/github/token`; Tailscale ACLs fence friends to Jellyfin day one. Friends migrate via free node-sharing (they lose `jellyfin.globopi`, use the ts.net name). One real gotcha: off-home devices stop egressing from the home IP unless using the Pi exit node — the IP-locked `*.v.bostrat.ai` views host depends on that ([[plane-ip-allowlist]], [[plane-perimeter-flip-us-only]]). Remaining phases: P1 operator devices, P2 ACL paste, P3 friend shares, P4 decommission WG container + DuckDNS + 51820 port-forward after ~1 wk clean parallel run.

**2026-09-16:** migration finished 08-18 (WG decommissioned). The P3 "friends via node share" design is superseded for the first friend by [[friend-access-dom]] — invited member + ACL groups + Caddy source-IP fence.
