---
name: headless-chromium-wedges-track-shell
description: On the Pi node, a foreground headless chromium run (dump-dom / screenshot) blocks the Track's Bash tool for minutes and every later foreground command times out; run it in the background writing to files, and never `pkill -f chromium` from inside that background command (it matches and kills itself)
metadata:
  modified: 2026-10-12T21:20:00Z
  scope: operator
  provenance: observed in Track granular-portfolio-stage-graph (closing-bell) while smoke-testing web/app.js with /usr/bin/chromium --headless=new
  supersedes: null
---

Headless chromium works on the Pi node (`/usr/bin/chromium --headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage --allow-file-access-from-files --virtual-time-budget=3000 --timeout=60000 --dump-dom file://…` or `--screenshot=…`), but a run takes a minute or two and a FOREGROUND call wedges the Claude Bash tool: the call itself and every later foreground command (`echo`, `cat`) time out until the browser exits.

**How to apply:** launch chromium with `run_in_background: true`, redirect stdout/stderr to files in the scratchpad (`> dom.html 2> dom.err < /dev/null`) and read them with the Read tool when the task notification lands. Do not add `pkill -f chromium` to that background command: the pattern matches the command's own shell line and kills the whole job before chromium starts. A self-contained harness page (real `web/index.html` with `/static/` rewritten to `file://`, `window.fetch` stubbed per route, `setInterval` captured so the 5-minute refresh can be fired by hand, checks appended into a `<pre id="results">`) plus `--dump-dom` is enough to assert DOM state; the same harness with `--screenshot` gives the picture. Related: [[mock-renderer-needs-chromium]].
