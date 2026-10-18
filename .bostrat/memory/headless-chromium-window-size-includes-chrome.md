---
name: headless-chromium-window-size-includes-chrome
description: On the Pi, `chromium --headless=new --window-size=W,H --screenshot` yields a viewport ~87px shorter than H; bottom-anchored (fixed/absolute bottom) elements fall off-screen and look "missing"
metadata:
  type: reference
  modified: 2026-10-12T20:40:00Z
  scope: operator
  provenance: observed 2026-10-12 while checking a 1300×820 mock comp; fixed/absolute bottom:24px elements rendered at y≈709 and the stage's bottom 87px were blank; --window-size=1300,907 gave the true 820px viewport
  supersedes: null
---

Headless chromium on the Pi (`/usr/bin/chromium --headless=new --no-sandbox --disable-gpu --hide-scrollbars --window-size=W,H --screenshot=…`) counts ~87px of window chrome inside `--window-size`, so the layout viewport is H−87. Anything pinned to the viewport bottom (`position:fixed; bottom:24px`, or an absolute child of a full-height stage) is painted ~87px higher than expected or clipped entirely — it is NOT missing from the page.

**Why:** a 1300×820 comp checked this way showed its chat composer, toast and FAB gone; three layout "fixes" were wasted before noticing the send button sat at y≈709 = (820−87)−24. The published `bostrat-mock` render uses a proper viewport and was never wrong.

**How to apply:** to verify a comp of height H locally, pass `--window-size=W,(H+87)` and ignore the blank strip at the bottom of the PNG, or trust the `bostrat-mock` render. Don't re-layout the page when only the local screenshot looks cut off. See [[mock-renderer-needs-chromium]].
