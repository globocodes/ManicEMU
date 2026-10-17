---
name: cursor-eye-piclaude-retired-pi-term
description: CursorEye + PiClaude decommissioned 2026-09-02, bakery launcher removed (kill-only); successor pi-term LIVE at https://pi-term.tail9f27a0.ts.net — Tailscale sidecar node + passkey (one, synced via 1Password), never *.globopi
metadata:
  modified: 2026-09-03
  scope: operator
  provenance: track/cursor-eye-upgrade-eb861a6a (Claude) — teardown executed on the Pi, pi-term SCOPE.md written
  supersedes:
---

On 2026-09-02 the `cursor-eye` (:3360) and `pi-claude` (:3361) containers were stopped and removed, their Caddy routes and Pi-hole records deleted (tombstones in `docker-compose.yml` / `caddy/Caddyfile`), and the-bakery's "Launch agent in tmux" button + `runAgentTmuxLaunch` were deleted — bostrat launches agent sessions now. The bakery keeps **Kill tmux sessions**, deploy-pi and reboot (all still use the host tmux socket + `globo-tmux.service` / `_keepalive`). Source trees `cursor-eye/` and `pi-claude/` stay on disk as reference (pi-claude was never committed; its GitHub repo is empty). cursor-eye's previously uncommitted mobile keybar/drawer work is preserved on its final commit for porting.

Successor **pi-term** (`~/Documents/globo-pi/pi-term`, GitHub `globocodes/pi-term`, scoped in `SCOPE.md`, BUILT 2026-09-02 and smoke-tested from the arm64 image against the host socket; compose services `pi-term-ts` + `pi-term`, `.env` keys `PI_TERM_*`, ACL draft in `tailscale/policy.hujson`; LIVE 2026-09-03: sidecar node `pi-term` = 100.108.12.119, cert issued, one passkey enrolled labelled `ipad` and synced through 1Password to iPhone/Mac, so revocation is all-or-nothing and every login audits as `ipad`; runbook closed): one xterm.js shell for phone/tablet/desktop, `tmux new-session -A` on the host socket. Security design (approved by the operator's "begin the build" 2026-09-02): its OWN tailnet node via a `tailscale/tailscale` sidecar (`tag:pi-term`, ts.net cert, identity headers) + per-device WebAuthn passkeys enrolled with a one-time code minted from an existing Pi shell, 12h/30m-idle sessions, Origin-checked WS, audit log. Deliberately NOT on `*.globopi`/Caddy: passkeys need HTTPS, and the Pi node's `tailscale serve :443` already fronts magic-mirror/RomM on 127.0.0.1:8090 — cookies are host-scoped, so sharing that hostname would leak the shell cookie to RomM. Note `sudo` is NOPASSWD for globo, so the shell is root-equivalent.

Gotcha seen live: applying `tag:pi-term` to the `globo-pi` machine itself (done by mistake in the console) drops it out of autogroup:member and it can't reach anything until re-authed as the user with `sudo tailscale up --force-reauth --hostname=globo-pi --advertise-exit-node --advertise-routes=192.168.1.13/32 --accept-dns=false --stateful-filtering=false` (IP kept). The Pi host has accept-dns=false, so ts.net names don't resolve there — test with curl --resolve. Auth key lives in `secrets/tailscale/PI_TERM_TS_AUTHKEY`. Gotchas: `pi-term/data` and `pi-term/ts-state` must exist owned by globo before first `up` (docker would create them root-owned); the dev bypass `PI_TERM_DEV_NO_AUTH=1` only works with `NODE_ENV=development`; enroll/list/revoke via `docker compose exec pi-term node src/enroll.js`.

**How to apply:** don't re-add cursor-eye/pi-claude routes; treat any new Pi terminal surface as pi-term work; keep pi-term off port 443 of the `globo-pi` node.
