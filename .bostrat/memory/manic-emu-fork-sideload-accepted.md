---
name: manic-emu-fork-sideload-accepted
description: Since 2026-09-16 the operator accepts a dev-signed (free Apple ID, 7-day re-sign) fork of Manic EMU for multi-device play and will pay for the Apple Developer Program later; this relaxes the earlier "nothing sideloaded" rule for the fork only
metadata:
  type: feedback
  modified: 2026-09-22T20:20:00-07:00
  scope: operator
  provenance: operator chat message in Track 5bd24936 (magic-mirror), 2026-09-16 ("Thats fine. i can always pay after. Lets do a custom manic emu fork")
  supersedes: null
---

The operator wants a **custom fork of Manic EMU** (`globocodes/ManicEMU`, from upstream's latest
tag) as the multi-device multiplayer client, dev-signed from the Apple Silicon Mac with a **free
Apple ID** (7-day re-sign, reinstall over USB). They said they can pay for the Apple Developer
Program later. Stock App Store Manic EMU stays the single-player path.

**Why:** the 2026-09-16 requirement is two devices (four later) in one GameCube session; stock
Manic EMU has netplay for fifteen libretro cores but not Dolphin, so only a fork can add it.

**How to apply:** the earlier "no sideloading, no Apple ID in any third-party tool" rule
([[operator-ipad-and-mac-hardware]]) still holds for third-party signing services (SideStore,
AltStore); Xcode with the operator's own Apple ID is fine. Scoping and phases live in the repo:
`docs/multiplayer-emulator-scoping-2026-09-16.md` and blueprint items BP-R9+, BP-D11+, BP-I19+.


**Update 2026-09-22 (operator, Track c7580437):** as a reference, The Sims Bustin' Out (G4ME69) on the iPad ran ONLY in the Manic MP fork with JIT; stock Manic / the interpreter path is not a valid baseline. Any rebuilt-disc check on the iPad (gct ship --device, BP-GT-R4/I4/I6/I10) must use that build.
