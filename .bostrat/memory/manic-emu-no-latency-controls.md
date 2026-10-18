---
name: manic-emu-no-latency-controls
description: Manic EMU's GameCube emulation is the libretro Dolphin core and the app exposes no latency-related option (no dual-core, immediate XFB, vsync or audio-buffer setting; only cpu_core, clock rate, vi_skip, OSD, logging, cheats, Wii options); GAFE01.ini ships Action Replay codes only; the only place for an emulator-side lag fix is the operator's Manic MP fork (globocodes/ManicEMU); Animal Crossing itself reads the pad within one refresh
metadata:
  type: project
  modified: 2026-09-24T02:40:00-07:00
  scope: operator
  provenance: read from Manic-EMU/ManicEMU on GitHub (System.core/Libretro/info/dolphin_libretro.info, Sys/GameSettings/GAFE01.ini, Sources/Business/GameInfo/Models/SpecialCoreOption.swift) and ac-decomp src/padmgr.c in Track 3da2b075, 2026-09-24, while scoping the Animal Crossing Plus blueprint (BP-AC-R9/D9)
  supersedes: none (relates to [[manic-emu-fork-sideload-accepted]], [[operator-ipad-and-mac-hardware]])
---

**Facts:** Manic EMU runs GameCube through `dolphin_libretro` (savestates "basic", core options v1.0) behind the app's own libretro frontend, not a RetroArch build. `SpecialCoreOption.swift` lists every Dolphin option the app sets or shows: `dolphin_cpu_core`, `dolphin_cpu_clock_rate`, `dolphin_vi_skip`, `dolphin_osd_enabled`, `dolphin_fast_disc_speed`, `dolphin_gpu_texture_decoding`, `dolphin_shader_compilation_mode`, logging, cheats, `dolphin_skip_gc_bios`, and the Wii/IR/rumble set; with JIT it forces clock 1.00 and vi_skip off. Nothing touches dual core, XFB presentation, vsync or the audio buffer. `Sys/GameSettings/GAFE01.ini` is cheats only (AR codes, a 16:9 Gecko); `GAF.ini` sets `SafeTextureCacheColorSamples = 512`. In the game, `padmgr` reads the pad on the retrace thread and `game_get_controller` copies it at the start of every frame, so the game contributes at most one refresh of lag.

**Why:** the operator sees roughly half a second of lag on the iPad with a Bluetooth controller and loses fish to it; the blueprint requires measuring before any game-side change (BP-AC-R9, D9).

**How to apply:** look for lag fixes in the fork's frontend (audio-driven pacing, display link, Game Mode engagement via the app category) or on the controller/system side, never in a Dolphin INI the app does not read; a game recipe (`fish_patience`, BP-AC-D10) is the fallback only.
