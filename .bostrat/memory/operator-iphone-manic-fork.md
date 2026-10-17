---
name: operator-iphone-manic-fork
description: Operator's iPhone "GloboPhone" = iPhone 16 Pro (iPhone17,1) on iOS 26.6.1 (23G83), devicectl id 76B9A398-ADCD-5EBA-98B0-443592FFDA14, listed BEFORE the iPad; the dev-signed Manic EMU fork (com.globocodes.manicemu 2.0.0, builtByDeveloper) IS installed and `device info apps` DOES list apps on the phone (unlike the iPad); its Manic library on 2026-09-24 = Mario Kart Double Dash + Melee Rev 2 (NKit); `Animal Crossing (USA) [gct plus].iso` staged in Documents/ 2026-09-24 10:16 PDT (crc32 933e159e, 76 s wired); JIT on iOS 26.6.1 unproven
metadata:
  type: user
  modified: 2026-09-24T10:20:00-07:00
  scope: operator
  provenance: measured 2026-09-24 in Track 3da2b075 (better-games) on Joeys-MacBook-Air with Xcode devicectl (`list devices`, `device info apps --include-all-apps`, `gct ipad list --device-id …`), then `gct ship --device-only --device-id … --target-name "Documents/…"`
  supersedes: none (relates to [[operator-ipad-and-mac-hardware]], [[ipad-check-via-gct-ipad]], [[manic-emu-fork-sideload-accepted]], [[ac-plus-seven-recipe-disc]])
---

**Facts (2026-09-24):** `xcrun devicectl list devices` shows GloboPhone (iPhone 16 Pro, iOS 26.6.1 build 23G83, id `76B9A398-ADCD-5EBA-98B0-443592FFDA14`) first and JoelPad second. Plugged in it reads `wired / connected / paired`. `device info apps --include-all-apps` returns 307 apps on the phone, including **Manic EMU `com.globocodes.manicemu` 2.0.0 with builtByDeveloper=true** (the operator's dev-signed fork; the iPad returns zero apps from the same call, so on the phone this is a valid "fork installed" check). Its container holds `Documents/Datas/Mario Kart - Double Dash!! (USA).nkit.iso` and `Documents/Datas/Super Smash Bros. Melee (USA) (En,Ja) (Rev 2).nkit.iso` (both 2019 NKit imports), plus dolphin-emu/EKA2L1/3DS config and netplay logs from 2026-09-17/18. No Animal Crossing entry existed before this Track.

**Staged 2026-09-24 10:16 PDT (Track 3da2b075 after it moved Pi -> Mac):** `Documents/Animal Crossing (USA) [gct plus].iso` = the SEVEN-recipe GAFE01 build (disc sha1 7e8bb3abf7e646bbccdfb3bc66cfe15e80fd403e, crc32 933e159e, 1,459,978,240 bytes; rsynced from `globo-pi:incoming/gct-work/GAFE01/build/GAFE01-museum_grey_donated+…+toolchain.iso` in 38 s, sha1 checked against the build JSON before the push) pushed with `gct ship --device-only --device-id 76B9A398-… --target-name "Documents/…"` and read back OK in 76 s wired. Next: operator imports it in Manic MP on the phone (Files -> On My iPhone -> Manic EMU), then `gct ipad check "Animal Crossing (USA) [gct plus].iso" --device-id 76B9A398-ADCD-5EBA-98B0-443592FFDA14 --expect-crc 933e159e --expect-size 1459978240` on the Datas copy.

**Why:** the operator asked (2026-09-24) for the new disc on the iPhone "instead for now" and chose the wired Mac route; the iPad still holds the three-recipe `[gct plus]` (crc32 f1f6e7ac).

**How to apply:** `gct ipad …` / `gct ship --device*` default to the iPad, so every phone call needs `--device-id 76B9A398-ADCD-5EBA-98B0-443592FFDA14`. GameCube speed under JIT on iOS 26.6.1 (a newer build than the iPad's 26.5.2, see [[operator-ipad-and-mac-hardware]]) is unproven until the operator plays. Same staging rule as the iPad: new titles go in `Documents/`, never straight into `Datas`.
