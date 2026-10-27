# Diagnostics Log (Manic MP)

A per-game option for GameCube and Wii titles. While it is on, every launch
of the game writes one RetroArch log to `Documents/Netplay Logs/retroarch__<date>.log`
(visible in the Files app under Manic MP) with four kinds of lines besides
RetroArch's own. It exists to tell a slow emulator from a slow device, a slow
game build or a slow controller without guessing. Leave it off otherwise: the
log costs a line per second and a few `stat()` calls every two seconds.

Turn it on from the game's options sheet ("Diagnostics Log"); it takes effect
at the next launch. Pull the logs to the Pi with
`~/.local/share/ios-signer/scripts/manic-logs.sh <out dir>` (better-games
`signer/manic-logs.sh`), which also copies `Manic MP sessions.log` and any
crash reports.

## The lines

`[Frame] Stats:` every 10 s (RetroArch fork, `ui/drivers/ui_cocoatouch.m`):
iterations and rate; iteration time avg/max and the count over 20 ms (gross:
core, display and the wait for room in the audio buffer); "Core alone"
avg/max (the core's `retro_run` net of the present and the audio wait);
"Display" avg/max (the time inside the video driver's present, which on iOS
is the wait for the Vulkan swapchain, i.e. vsync); the longest gap in which
the main thread was busy elsewhere; the iteration time net of the audio wait;
the number of stalls; the window's audio underruns and the silence they
produced; the lowest audio buffer fill seen.

`[Frame] Stall at +T s:` the moment an iteration or main-thread gap reaches
30 ms, two or more missed 60 Hz slots (at most 12 lines per 10 s window, the
rest counted in Stats). Splits the iteration into core, display and the wait
for audio room, then gives the audio buffer fill before and after and the
running underrun count. The display is paced by vsync, so a slow core frame
quantizes to whole 60 Hz slots: a 35 ms iteration is two slots and a 52 ms
one is three, and only the core figure says whether the core overran by 17
or by 35 ms. The two 2026-10 Animal Crossing sessions showed 3-6 such
iterations per 10 s with the display absorbing the rest. RetroArch's rate control
keeps the output buffer about half full - roughly 100 ms of the 200 ms the app
asks for - so a stall longer than that is an audible gap, and the underrun
counter confirms it.

`[Input] pad ...` once a second per controller and `[Input] coalescer`
(DeltaCore): HID callbacks, GameController delivery latency, the longest
silence while a stick is deflected, how long samples waited for the main
thread.

`[Device]` (the app, `PlayDiagnosticsLogger` in `PlayViewController.swift`):
model, OS, display refresh rate, thermal state, Low Power Mode at start; every
thermal or power-state change afterwards. A `serious` or `critical` thermal
state explains a run of slow frames that no code change will fix.

`[App]`: the app resigning active, backgrounding, foregrounding, memory
warnings, "emulation paused" / "emulation resumed" (the in-game menu and
anything else that pauses the core: while paused the audio output starves, so
a pause reads as a long main-thread gap with hundreds of underruns - the
2026-10-27 session had two, 7.4 s and 9.1 s, that looked like freezes until
the controller re-assignment across them gave it away), and each auto save state ("requested" then "written after N ms,
M MB"). Auto Save State serializes the whole core on the emulator thread every
120 s while the setting is on.

`[Shaders]`: at start, Dolphin's shader compilation mode and CPU core in effect
and the sizes of this game's shader caches under `dolphin-emu/User/Cache`
(`<GameID>.uidcache`, `Shaders/Vulkan-specialized-ps-<GameID>-*.cache`,
`-vs-`, and the shared `Vulkan-Pipeline-*.cache`); then a line every time one
of them grows while playing. Dolphin appends the pixel shader cache the moment
a new shader is compiled, so a growth in the same second as a `[Frame] Stall`
names that stall's cause.

## Reading a stall

1. Find the `[Frame] Stall` lines. If "waiting for audio room" accounts for
   most of the iteration, the frame was not slow - the main thread was blocked
   on audio pacing because something else (a long previous frame) had let the
   buffer fill. Look at the stall before it. If "display" accounts for most of
   it, the core finished a little late and the present waited for the next
   vsync slot: the core figure is the real overrun. A stall whose "idle
   before it" is seconds long with an `[App] emulation paused` line before
   it is a pause, not a stall.
2. If the audio buffer went from ~50% to under ~10% or the underrun count
   rose, the stall was audible.
   A steady trickle of underruns with NO stall is the other audible pattern:
   Stats windows that read "buffer never below 5-11% full" with 1-4 underruns
   of 21 ms each (one CoreAudio callback) and "waited 0 ms" mean the core
   produced audio slightly slower than real time, the buffer drained, and
   rate control ran out of range. The 2026-10-26 Animal Crossing session
   showed exactly this at 59.5 frames/s (4-6 frames of 35-53 ms per 10 s,
   so about 0.7% slow) with RetroArch's default `audio_rate_control_delta`
   0.005, which can stretch the audio by at most 0.5%. The app now sets 0.02
   for Dolphin games (`PlayViewController`), enough for a 1-2% deficit;
   windows that still show underruns at a buffer under 10% mean the deficit
   is larger than that, and the slow frames themselves are the thing to fix.
3. A `[Shaders] cache grew` line within a second of it: a shader compiled
   synchronously. Manic's launch defaults set Dolphin's
   `ShaderCompilationMode` to 0 (synchronous) for JIT runs and 3
   (asynchronous, skip drawing) for interpreter runs. The per-game core
   options (the game's info screen, "core configs") can override it: 2 =
   asynchronous ubershaders (the object is drawn with a generic shader while
   its own compiles; more GPU work, longer first boot while the ubershaders
   compile), 3 = asynchronous skip drawing (the object is skipped for a few
   frames instead). Stored per-game values win over the launch defaults.
4. An `[App] auto save state requested` line within a second of it: the
   serialize. Turn off Auto Save State to confirm.
5. A `[Device] thermal state now serious` line before a run of windows with
   many iterations over 20 ms: the device is throttling.
6. `[Input]` lines with long gaps while deflected but no stall: the
   controller, not the emulator.

## Where the code is

- RetroArch fork (`Dependencies/Libretro`, globocodes/RetroArch): the frame
  logger and `manic_frame_stats_reset` in `ui/drivers/ui_cocoatouch.m`; the
  underrun, silence and blocked-time counters in
  `audio/drivers/coreaudio.c` (the iOS driver) and `coreaudio3.m` (macOS), shared through `audio/drivers/coreaudio_diag.h`;
  the core and present time totals in `manic_frame_timing.c/.h`, fed from
  `core_run` (`runloop.c`) and `video_driver_frame` (`gfx/video_driver.c`);
  `-[LibretroCore logDiagnosticsEvent:line:]` for the app's tagged lines.
- DeltaCore fork (`Dependencies/DeltaCore`): `InputDiagnostics`.
- App: `PlayDiagnosticsLogger` and the option plumbing
  (`ExtraKey.inputDiagnostics`, `GameOption.inputDiagnostics`,
  `PlayViewController.updateInputDiagnosticsConfigs`).
