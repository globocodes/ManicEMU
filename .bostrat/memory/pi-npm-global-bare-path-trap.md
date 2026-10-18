---
name: pi-npm-global-bare-path-trap
description: On globo-pi, shells under systemd --user units (globo-tmux.service → the Bakery "Deploy to Pi" button; systemd-run → bostrat-node self-update) have the BARE manager PATH; nvm's npm then runs on system node v20 and EACCESes on /usr/lib/node_modules — put <nvm prefix>/bin first on PATH before any `npm i -g bostrat-node`
metadata:
  modified: 2026-08-18T20:20:00Z
  scope: operator
  provenance: observed on globo-pi 2026-08-18 (self-update 1.7.6→1.7.8 "npm install failed"; Bakery bostrat deploy no-op'd on the stale v1.7.7 script) — Track bakery-deploy-921befcb
  supersedes: null
---

The user service manager on globo-pi exports `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin` (`systemctl --user show-environment`). Anything spawned from it inherits that: `globo-tmux.service` (the tmux server the Bakery API drives via `/tmp/tmux-1000/default` — a Docker'd client can't add PATH), and `systemd-run --user` transient units (bostrat-node's self-update one-shot).

Calling nvm's npm by absolute path does NOT escape it: the shim is `#!/usr/bin/env node`, so it resolves `/usr/bin/node` (v20.19.2), and npm derives its global prefix from *that* node → `EACCES: mkdir /usr/lib/node_modules`. Journal of the transient unit has the real error (`journalctl --user -u bostrat-self-update-<ver>`); the status.json only says "npm install failed".

**Fix:** `export PATH="$PREFIX/bin:$PATH"` (PREFIX = the nvm prefix owning `bostrat-node.service`'s WorkingDirectory, e.g. `~/.nvm/versions/node/v24.18.0`) and pass `--prefix "$PREFIX"`. Landed in the-bakery `scripts/deploy-pi-prod.sh` (also runs `origin/main:scripts/deploy-pi.sh` from a temp copy — the npm-package Pi never moves its checkout, so the checkout's copy is frozen at the last pinned release) and in bostrat `agent/src/self-update.js` + `scripts/deploy-pi.sh` (patch pending PR).

**Also:** don't trust a tmux `new-session` test from an interactive shell — the client's PATH leaks into the new session; probe with `env -i … tmux new-session` to see what the Bakery really gets.
