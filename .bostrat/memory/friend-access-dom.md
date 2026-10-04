---
name: friend-access-dom
description: Dom (she/her) is the first friend on the tailnet — invited as a MEMBER so *.globopi resolves; ACL fences friends to the Pi :53/:80/:8096, Caddy 403s *.bostrat.globopi + bostrat-design.globopi for non-operator sources (allowlist of operator device IPs in the operator_only snippet)
metadata:
  modified: 2026-09-16
  scope: operator
  provenance: track/almanac-port-9f89b2bf 2026-09-16 — edits to ~/Documents/globo-pi/tailscale/policy.hujson + caddy/Caddyfile, fence verified from a scratch netns; runbook:6de24d67 holds the console steps
  supersedes: tailscale-migration-scoped (friends-as-node-share part only)
---

Dom (she/her) needs almanac, Jellyfin "and the likes" (2026-09-16). Design: she is
**invited as a tailnet member** (free plan 3 users), not node-shared, because shared-in
users never get our split DNS and `almanac.globopi` would not resolve for them.

**ACL** (`policy.hujson`, paste in the admin console): `group:operator` = globocodes@gmail.com
→ `*:*`; `group:friends` → `globo-pi:53,80,8096` only (no exit node, SSH, raw app ports,
pi-term). `autogroup:member` is no longer "operator" — never reintroduce it as such.

**Caddy fence** (`caddy/Caddyfile` snippet `operator_only`, imported by `*.bostrat.globopi`
and `bostrat-design.globopi`): fail-closed `not remote_ip` allowlist = loopback, 192.168.1.0/24,
172.16.0.0/12, and the operator's device IPs (iPad 100.108.18.23, iPhone 100.79.127.78,
MacBook 100.123.250.48). **A new operator device must be added there** or it gets 403 on
those two hosts only. Docker DNAT preserves the peer's 100.x source, so the fence works for
real tailnet peers; probes from the Pi itself or from containers arrive as loopback/bridge
addresses and always pass — test from a scratch netns (`ip netns` + veth, source 10.99.0.2).

**How to apply:** a friend who "can't reach X" → check ACL group membership first, then that
X is behind Caddy :80 (not a raw port). Anything operator-only that gets a Caddy route later
must `import operator_only`. Related: [[tailscale-migration-scoped]], [[almanac-slips-epic]].
