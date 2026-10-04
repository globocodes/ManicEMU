---
name: pi-scratchpad-tmpfs-wiped-mid-track
description: On the Pi the Claude scratchpad lives on /tmp (8 GB tmpfs) and was wiped mid-Track on 2026-09-22 (extracted 1.3 GB disc, venv, dtk binaries all gone between turns); keep multi-GB or multi-turn teardown work under ~/incoming/<work>/ on the SSD, scratchpad only for throwaway files
metadata:
  type: feedback
  modified: 2026-09-22T17:46:00-07:00
  scope: operator
  provenance: observed 2026-09-22 in Track 20eda7bd - /tmp usage dropped from 1.9 GB to 8.6 MB between two turns; ~/incoming survived. CORRECTED 2026-09-22 by Track 422607e2 (journal): the drop was the operator's `sudo reboot` at 17:24:08 PDT emptying the tmpfs, not a mid-Track wipe
  supersedes: none
---

The session scratchpad `/tmp/claude-1000/.../scratchpad` is on tmpfs (8 GB) and does not survive across an interrupted turn on the Pi: everything extracted or downloaded there in the Sims Bustin' Out teardown vanished while the ISO under `~/incoming` and the RVZ in the library stayed.

**Why:** re-extracting a 1.3 GB disc and re-fetching tools costs minutes each time and silently invalidates paths cited in earlier findings.

**How to apply:** for teardown/decomp work use `~/incoming/bo-work/` (disc/, bin/, venv/, dolphin-user/) or the future framework repo's gitignored work dir; only truly disposable files go in the scratchpad. Related: [[sims-bustin-out-gc-teardown-facts]].

**Correction (2026-09-22, pi-crash-investigation Track):** the "wipe between two turns" was the Pi reboot at 17:24 PDT (`sudo reboot`, journal boot -1 → 0); nothing deletes the scratchpad mid-Track. The advice stands for a stronger reason: /tmp is RAM, and the 1.9 GB extracted there was charged to that box's 4 GB cgroup and shrank the machine's usable memory — see [[pi-tmpfs-shmem-oom-2026-09-22]].
