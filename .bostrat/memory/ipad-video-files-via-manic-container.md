---
name: ipad-video-files-via-manic-container
description: Non-game files (e.g. .mkv video) go to the operator's iPad the same wired way as discs - `xcrun devicectl device copy to` into Manic EMU's Documents/ (Files -> On My iPad -> Manic EMU); no VLC/Infuse/nPlayer container exists on the iPad to target instead; 2 GB ~55 s wired push, ~50 s pull-back; hawkeye-1-3/1-4.mkv delivered + crc-verified 2026-09-24, hawkeye-1-5.mkv 2026-09-25
metadata:
  type: project
  modified: 2026-09-25T21:30:00-07:00
  scope: operator
  provenance: measured 2026-09-24 in Track a3da7266 (better-games) on Joeys-MacBook-Air, Xcode devicectl against JoelPad (AA4586F5-…, iPadOS 26.5.2, wired)
  supersedes: none (relates to [[ipad-check-via-gct-ipad]], [[operator-ipad-and-mac-hardware]])
---

**Route:** for an arbitrary file the operator wants "in my iPad Files", use the disc route by hand -
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device copy to --device AA4586F5-0ED8-509C-8819-7D205F7D078F --timeout 1800 --domain-type appDataContainer --domain-identifier com.globocodes.manicemu --source <file> --destination "Documents/<name>"`.
It lands in Files -> On My iPad -> Manic EMU beside the staged `[gct …]` ISOs. `gct ship` is not the tool here (it wants a disc image).

**Probed 2026-09-24 (read-only `device info files`):** org.videolan.vlc-ios, com.firecore.infuse, com.newin.nplayer(.plus) all ABSENT on the iPad - Manic EMU is the only known file-sharing container, so there is no player folder to push video into directly.

**Delivered 2026-09-24 ~21:00 PDT:** `Documents/hawkeye-1-3.mkv` (2,076,408,349 bytes, crc32 6b2fd002) and `Documents/hawkeye-1-4.mkv` (1,811,274,618 bytes, crc32 978fbc39) from `~/Documents` on the Mac; pushes 58 s / 52 s wired (~36 MB/s, faster than the ISO pushes), pull-back 51 s / 45 s, crc32 + size matched the originals.

**Delivered 2026-09-25 ~21:30 PDT:** `Documents/hawkeye-1-5.mkv` (2,010,378,017 bytes, crc32 830780b2), push 53 s wired, pull-back size + crc32 matched. The operator called the iPad "the pi" in that request - "the pi via the wired connection" means this iPad route, not the Raspberry Pi.

**Why:** the operator asked for the files "similar to what we do moving the files over wired connection to the iPad".
**How to apply:** verify with a pull-back + crc32 as for discs; check `list devices` shows `wired` first (Wi-Fi drops big pushes, see [[ipad-check-via-gct-ipad]]). devicectl cannot delete - the operator removes the files in Files when done.
