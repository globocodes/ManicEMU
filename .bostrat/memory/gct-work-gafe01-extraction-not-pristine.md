---
name: gct-work-gafe01-extraction-not-pristine
description: On globo-pi, ~/incoming/gct-work/GAFE01/root/files already carries the move_homes edit (forest_1st.arc and forest_2nd.arc rewritten 2026-10-01 10:21), so better-games tests/test_move_homes.py::test_apply_edits_the_real_archives_once fails under GCT_WORK=~/incoming/gct-work (apply is a no-op, the "archives change" assert is False); 69 pass, 3 skip otherwise
metadata:
  type: project
  modified: 2026-10-03T22:40:00-07:00
  scope: operator
  provenance: Track 84fa4dbd, 2026-10-03, after fast-forwarding ~/Documents/globo-pi/better-games to 4fa7267 (PR #20, signer/ only): ran `GCT_WORK=~/incoming/gct-work .venv/bin/python -m pytest -q` = 1 failed, 69 passed, 3 skipped; applied the recipe to copies of both archives and compared bytes
  supersedes: none (relates to [[pi-scratchpad-tmpfs-wiped-mid-track]])
---

**Fact:** the GAFE01 extraction used as GCT_WORK on the Pi is a modded tree, not a pristine disc extraction. `gct_recipe_move_homes.apply` on copies of `forest_1st.arc` / `forest_2nd.arc` from it changes neither file ("Move homes" is already in forest_1st.arc). The test asserts both archives differ from the extraction after apply, so it fails there. The pull that surfaced it touched only `signer/`.

**Why:** a red test on the Pi checkout reads like a regression from whatever was just pulled; it is the work tree's state.

**How to apply:** treat that one failure as environmental until the extraction is refreshed (`gct extract` into a clean GCT_WORK, or point GCT_WORK at a pristine tree). Do not re-extract over ~/incoming/gct-work without asking: another Track's in-place edits live there.
