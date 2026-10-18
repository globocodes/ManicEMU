---
name: mock-renderer-needs-chromium
description: bostrat-mock renders on the node via /usr/bin/chromium (fallback `firefox`); the bostrat-node:1.7.6 container ships neither — apt-get install chromium fixes "firefox exited non-zero"
metadata:
  modified: 2026-08-18T18:25:00Z
  scope: operator
  provenance: observed on joeyafern-node while publishing the schedule-review mock (Track schedule-view-update)
  supersedes: null
---

`bostrat-mock add/update` fails with `render failed: firefox exited non-zero` (even for a trivial HTML probe) when the node has no browser: the agent tries `BOSTRAT_CHROMIUM_BIN` (default `/usr/bin/chromium`), and on "failed to launch" falls back to `BOSTRAT_FIREFOX_BIN` (default `firefox`). The `bostrat-node:1.7.6` Fly container (Debian 12) has neither.

**Fix (done 2026-08-18 on joeyafern-node):** `apt-get install -y --no-install-recommends chromium fonts-dejavu-core fonts-liberation` — renders worked immediately after, no agent restart needed. Root FS is ephemeral-looking (30 MB used), so a container rebuild may need it again; the durable fix is baking chromium into the node image.

Each failed `add` still creates an `error` mock record — `bostrat-mock rm` the extras before retrying with `update`.
