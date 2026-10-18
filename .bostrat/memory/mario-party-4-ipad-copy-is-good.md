---
name: mario-party-4-ipad-copy-is-good
description: iPad Manic Datas/Mario Party 4 (USA).rvz is byte-identical to ~/Documents/mp-4.rvz on the Mac and verifies clean (GMPE01, crc32 150a4c40) - a "corrupt MP4" symptom is not the disc file
metadata:
  type: project
  modified: 2026-10-02T00:00:00-07:00
  scope: operator
  provenance: measured 2026-10-02 in Track 29bdedc9 (devicectl pull-back from JoelPad + cmp; dolphin-tool verify on globo-pi)
  supersedes: none (relates to [[ipad-check-via-gct-ipad]], [[ipad-video-files-via-manic-container]])
---

Operator asked to replace the "corrupt" Mario Party 4 on the iPad with ~/Documents/mp-4.rvz. The iPad's Datas copy (470,366,000 bytes) is byte-identical to that file, and `dolphin-tool verify` on the Pi reports no problems (RVZ zstd-19, GMPE01 rev 0, disc crc32 150a4c40, sha1 a13a7c6b...). Nothing was pushed.
**How to apply:** for an MP4 problem in Manic, look at the save/memory card, Manic's library record, or core settings, not the image file. "The pi" in iPad file requests means the iPad.
