---
name: bind-mounted-config-stale-after-sed
description: On the Pi, caddy/Caddyfile and pihole/etc-dnsmasq.d are bind-mounted files/dirs — `sed -i` (or any rename-over-write) gives the host a NEW inode while the container keeps reading the OLD one, so `caddy reload`/`pihole reloaddns` silently apply stale config; after such an edit `docker restart <svc>`, and verify with `docker exec <svc> grep` before trusting any test
metadata:
  modified: 2026-09-16
  scope: operator
  provenance: track/almanac-port-9f89b2bf 2026-09-16 — Caddy kept serving a config without the ts.globopi aliases and with a removed allowlist IP until `docker restart caddy`; `docker exec caddy grep -c ts.globopi /etc/caddy/Caddyfile` was 0 while the host file had 8
---

`~/Documents/globo-pi/caddy/Caddyfile` is mounted into the caddy container as a single-file bind
mount (`./caddy/Caddyfile:/etc/caddy/Caddyfile:ro`). A file bind mount pins the inode. `sed -i`
writes a temp file and renames it over the original → new inode on the host, old inode (old
content) still mounted in the container. `docker exec caddy caddy reload` then re-reads the OLD
file and reports success, so tests against the "new" config test the old one.

**Why:** cost 20 min of confused fence tests on 2026-09-16 (a removed allowlist IP kept passing;
new site aliases returned Caddy's empty 200).

**How to apply:** after editing a bind-mounted config on the Pi, `docker restart <service>` (or
`docker compose up -d <service>`), then `docker exec <service> grep -c <new token> <path>` before
running any verification. In-place appends (`>>`) and Python `open(p,'w')` keep the inode and are
safe with a plain reload; `sed -i`, editors that write-then-rename, and `mv` are not. Directory
bind mounts (`pihole/etc-dnsmasq.d`) are immune to the inode swap but Pi-hole v6 still needs a
container restart to load new dnsmasq conf files (`pihole reloaddns` did not). Related:
[[friend-access-dom]].
