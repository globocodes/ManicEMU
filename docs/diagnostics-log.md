# Diagnostics Log (Manic MP)

A per-game option for GameCube and Wii titles. While it is on, every launch
of the game writes one RetroArch log to `Documents/Netplay Logs/retroarch__<date>.log`
(visible in the Files app under Manic MP) with the tagged lines below besides
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
is the wait for the Vulkan swapchain, i.e. vsync) and "presenting on" the
screen that wait belongs to ("device", or "AirPlay 1920x1080 @ 60 Hz" while
the game view sits on the AirPlay window; the app names it through
`-[LibretroCore setDiagnosticsScreen:]` each time it moves the view); the longest gap in which
the main thread was busy elsewhere; the iteration time net of the audio wait;
the number of stalls; the window's audio underruns and the silence they
produced; the lowest audio buffer fill seen. Then "Pacing:" (fork
1b469784, for a hitch too short to be a stall): a histogram of the window's
iteration times (under 17 ms, 17-20, 20-25, 25-33, over 33); "no new frame",
the iterations in which the core presented no new picture (`frame()` calls
net of duped frames), each of which repeats the last frame on screen;
"held 2+ slots", the iterations longer than 1.5 display slots at the
current refresh rate, with the mean spacing between consecutive ones, so a
hitch every half second reads as a spacing of about 500 ms; and the audio
buffer fill at the start of the over-20 ms iterations, averaged: a full
buffer (90-100%) at every long iteration means the core was waiting for
audio room, i.e. audio pacing rather than vsync was holding it, while a
half-full buffer means the time went into the core or the present. Then
"Screen:" (fork d077cc34), the only fields that see past the present call:
the swapchain size in pixels; the frames the screen reported showing (each
drawable of the game's Metal layer reports its presented time) with the
average and longest interval between them; "shown for 2+ refreshes", the
frames that stayed up for two or more refreshes of that screen because the
next one arrived 1.5 refreshes or more later, with the mean spacing between
consecutive ones; "replaced within half a refresh", frames the next one
overtook; and "never shown", drawables that came back without a presented
time. "0 frames shown" in a window that ran means the screen reports no
presented times at all, not that nothing was shown. An AirPlay screen is
that case: every drawable comes back with a presented time of 0, so on
AirPlay the section reads "0 frames shown ... never shown 601" and only the
swapchain size is evidence (walk test 2026-11-05). The section measures the
device screen, and should measure a wired display.

`[Frame] Swapchain at +T s:` the Vulkan swapchain was recreated at another
size on the device screen (a rotation, a layout change). Every session has
one a few seconds in: the swapchain starts at the full screen ("Using
resolution 2360x1640") and is recreated at the game view's own size once
the skin has laid it out, 2185x1640 for a 4:3 core on this iPad.

`[Frame] Stall at +T s:` the moment an iteration or main-thread gap reaches
30 ms, two or more missed 60 Hz slots, or 20 ms (one missed slot) while the
game view presents on an external screen (at most 12 lines per 10 s window,
the rest counted in Stats; the "Stalls >= N ms" field names the threshold
in effect). Splits the iteration into core, display and the wait
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

`[AirPlay]`: the external screen connecting and disconnecting
(`ExternalSceneDelegate`), with its size in points and pixels, scale and
maximum refresh rate, the modes it offers ("2 modes: 1920x1080 (current,
preferred, pixel aspect 1); 1280x720 (pixel aspect 1)") and whether the game
window on it is shown (it is hidden unless the member's AirPlay setting is on
and a game is running); then what the app setting "AirPlay 720p Stream" did
at that connect: "720p stream setting on: asked the screen for 1280x720 (was
1920x1080); the screen now reports ..." when a smaller mode at or above
1280x720 exists, "the screen offers only 1920x1080, nothing to change" when
the screen lists a single mode (the setting then does nothing, and this line
is the proof), or "720p stream setting off: screen mode left at ...". The
setting is read when the screen connects, so a change takes effect at the
next AirPlay connection. "external screen mode changed: ..." follows whenever
the screen's mode actually changes. Then each
move of the game Metal view onto that window or back to the device
(`PlayViewController.updateAirPlay`), with the scaling option in effect and
the view's size before the window scale; and, from the fork, "swapchain
recreated for <screen>: WxH -> WxH px" when the swapchain follows the view
(on the clock of the `[Frame] Stall` lines, which starts a second or two
after the app's). The swapchain is sized to the pixels the view covers on
the screen it is on: 1440x1080 for a 640x480 pt core view scaled to the
height of a 1920x1080 @1x AirPlay window (960x720 when that window is in a
1280x720 mode), and the game view's own pixels on the device, 2185x1640 for
a 4:3 core on this iPad, not the full 2360x1640 screen. The moves therefore
log "2185x1640 -> 1440x1080" and back. Before fork d077cc34 it was view size
x the iPad's scale on every screen, 1280x960 on that AirPlay window,
stretched by 1.125 to fit, and the change was not logged. A new size has to
hold for two checks and 50 ms before the swapchain follows it, and on an
external screen a size larger than the screen is dropped outright: the
2026-11-08 session logged "2185x1640 -> 3278x2460 -> 1920x1080" within
22 ms at a connect (the view measured under the AirPlay container's
transform before its layout), which the two-check rule alone let through. The `[Device]`
start line repeats the external screen's facts, its modes and the 720p
setting's outcome, or says "no AirPlay screen". Each connect or disconnect of
AirPlay also stalls the game for three to six seconds while the audio route
changes (iterations of 0.6-1.8 s "waiting for audio room", 150-300
underruns): that is the transition, not a fault in play. AirPlay itself
(capture, H.264 encode, the network and the receiver's decode) runs outside
the app and is not measurable from here: these lines only tell an AirPlay
window of `[Frame] Stats` from an on-device one, so the two can be compared
on the core, display and audio figures.

`[Audio]` (the app, `PlayDiagnosticsLogger`): where the sound goes and how
late the system says it comes out. "route Speaker 'iPad Speakers': output
latency 8.3 ms, IO buffer 23.2 ms, 48000 Hz" at start, at every
`AVAudioSession` route change (with its reason: "new device available",
"old device unavailable", "category change", ...), at each `[AirPlay]`
connect and disconnect (the route usually follows the screen a moment later,
so the change line is the one that shows the AirPlay route), and once every
10 s. The port type is AVAudioSession's (`Speaker`, `AirPlay`,
`BluetoothA2DP`, `HDMI`, `Headphones`) with the device's name. The output
latency is the route's own figure, the time between the audio unit handing
a buffer to the system and the sound leaving the output as the system
estimates it; the RetroArch buffer (`audio_latency`, 200 ms by default,
"buffer never below N%" in the `[Frame] Stats` line) sits in front of it.
The `[Device]` start line also says which RetroArch audio buffer this
launch got and why ("RetroArch audio buffer 96 ms (AirPlay Audio Buffer
setting 96 ms, applied: external screen connected at launch)"); see step 9.

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
   `ShaderCompilationMode` to 2 (asynchronous ubershaders) for JIT runs and
   3 (asynchronous, skip drawing) for interpreter runs. JIT runs used 0
   (synchronous) until 2026-11-01, when a Diagnostics Log showed a 234 ms
   core stall on entering an unvisited acre with the vertex-shader cache
   growing at the next poll. The per-game core options (the game's info
   screen, "core configs") can override it: 0 = synchronous (a new shader
   stalls the frame it is first drawn in), 2 = asynchronous ubershaders (the
   object is drawn with a generic shader while its own compiles; more GPU
   work, longer first boot while the ubershaders compile), 3 = asynchronous
   skip drawing (the object is skipped for a few frames instead). Stored
   per-game values win over the launch defaults, so a game whose core
   configs were edited by hand keeps its stored mode.
4. An `[App] auto save state requested` line within a second of it: the
   serialize. Turn off Auto Save State to confirm.
5. A `[Device] thermal state now serious` line before a run of windows with
   many iterations over 20 ms: the device is throttling.
6. `[Input]` lines with long gaps while deflected but no stall: the
   controller, not the emulator.
7. A walk-stop hitch (smooth play broken by a brief hold every half second
   or so, no audible gap): first pick the windows in which the player was
   actually walking, by the `[Input] pad` lines (10-45 callbacks a second
   with a deflected stick). In the 2026-11-04 walk test those windows were
   clean on the device and on AirPlay alike: 60.0 iterations/s, 0-1
   iterations over 20 ms, no "no new frame", no audio wait. So the hitch is
   not in the frame loop. On the device screen, and on a wired display, the
   place to read it is the "Screen:" section: "shown for 2+ refreshes" at a
   steady mean spacing (about 500 ms for a hitch every half second) while
   the Pacing fields stay clean means the frames left on time and the screen
   held some, which is the swapchain on that screen or the screen's own
   clock. On AirPlay the section is blind (no presented times), so the
   verdict there rests on the Pacing fields plus what the player sees. The
   2026-11-05 walk test settled this case: with the swapchain at 1:1
   (1440x1080) the AirPlay walking windows were as clean as the device's,
   the device screen showed 601 frames per window at an even 16.665 ms with
   none held, and the player still saw the hitch on AirPlay only. The hitch
   is in the AirPlay path to the TV (capture and encode, Wi-Fi, the
   receiver), not in the app. What the app can still vary is how much there
   is to send: the "AirPlay 720p Stream" setting, when the screen offers
   such a mode. A window at 60/s with "held 2+ slots" at a steady spacing
   and a half-full buffer is a periodic cost inside the core or the present.
   Not the hitch: a window at 61 iterations/s with 30-90 iterations in the
   20-25 ms bucket, about as many "no new frame", a present wait under
   10 ms and the audio buffer at 90-100% at the start of those iterations.
   That is a screen on which the core dupes frames (title, loading, just
   after a resume; no stick input in the `[Input]` lines): a duped frame
   skips the present, so the audio buffer paces that iteration instead of
   vsync. It appears on the device as much as on AirPlay and no frontend
   setting changes it.
8. An AirPlay session: split the `[Frame] Stats` windows by their "presenting
   on" value. If the AirPlay windows show the same core time, display wait,
   iteration rate and underruns as the device windows, the emulator is not the
   source of the lag and what remains is the AirPlay path (typically 100-200 ms,
   out of the app's hands; a lower-latency receiver or wired HDMI is the fix).
   A display wait that grows on AirPlay (for example to a 30 Hz cadence) means
   the external screen's refresh rate or the swapchain on it is pacing the
   core: check the `[AirPlay]` line's "up to N Hz".
9. An audio/video offset (the sound ahead of or behind the picture). The log
   sees the audio half only. Inside the app the sound runs behind the core by
   the RetroArch buffer's fill: rate control holds the buffer about half
   full, so with the default `audio_latency` of 200 ms that is about 100 ms
   (47% = 94 ms in every playing window of the 2026-11-08 session), and the
   `[Audio]` line's output latency comes on top of it. The picture's own
   latency - the swapchain present, then on AirPlay the capture, encode,
   network and the TV's decode - is not measurable here, so the offset the
   player sees cannot be computed from the log; it can be measured by
   filming the TV with a phone at 60 fps on a sound-tied event (a menu
   click, a tree hit) and counting frames between the picture and the sound.
   What the log does tell: (a) whether the offset is constant - a steady
   buffer fill and a steady output latency mean the audio side is constant
   and the offset is the AirPlay path; (b) a varying offset - in windows
   where the core dupes frames (title, loading, dialogs: "no new frame"
   30-90, 60.4-61.1 iterations/s, "waited" 0.5-1.9 s, buffer 93-95% at the
   over-20 ms iterations) audio pacing holds the buffer at ~190 ms instead of
   ~94 ms, so the sound runs about 100 ms later than in play until rate
   control (2% per second of audio) pulls the buffer back over about 5 s;
   (c) a route change mid-session ("route changed (new device available):
   route AirPlay ...") marks where the output latency jumped. The lever is
   the "AirPlay Audio Buffer" setting (Settings, next to "AirPlay 720p
   Stream"): 96, 200 or 320 ms of RetroArch buffer for a game launched while
   an external screen is connected (200 everywhere else). The sound runs
   about half the chosen value behind the core, so 96 ms takes about 50 ms
   off the audio lag when the sound comes after the picture, and 320 ms adds
   about 60 ms when it comes first. 96 ms leaves headroom above the 34 ms
   worst in-play iteration of the 2026-11-08 session but not above a menu
   pause or a synchronous shader compile, which underrun at any size. The
   value is read once at launch (RetroArch applies `audio_latency` only when
   its audio driver is created), so the A/B is: connect AirPlay, then start
   the game, and read the `[Device]` start line for the value in effect.

## Where the code is

- RetroArch fork (`Dependencies/Libretro`, globocodes/RetroArch): the frame
  logger and `manic_frame_stats_reset` in `ui/drivers/ui_cocoatouch.m`; the
  underrun, silence and blocked-time counters in
  `audio/drivers/coreaudio.c` (the iOS driver) and `coreaudio3.m` (macOS), shared through `audio/drivers/coreaudio_diag.h`;
  the core and present time totals in `manic_frame_timing.c/.h`, fed from
  `core_run` (`runloop.c`) and `video_driver_frame` (`gfx/video_driver.c`);
  `-[LibretroCore logDiagnosticsEvent:line:]` for the app's tagged lines and
  `-[LibretroCore setDiagnosticsScreen:]` for the Stats line's "presenting on"
  (`manic_frame_set_present_screen`, `manic_frame_timing.h`); the swapchain
  sizing per screen in `gfx/drivers_context/cocoa_vk_ctx.m`
  (`cocoa_vk_view_scale`); the presented-time counters in
  `manic_frame_timing.c/.h`, fed by `ManicMetalLayer` (`ui_cocoatouch.m`).
- DeltaCore fork (`Dependencies/DeltaCore`): `InputDiagnostics`.
- App: `PlayDiagnosticsLogger` (its `screenFacts` / `screenModes` /
  `presentScreenName` helpers feed the `[AirPlay]` lines in
  `PlayViewController.updateAirPlay` and `ExternalSceneDelegate`); the
  "AirPlay 720p Stream" setting (`ExtraKey.airPlayLowRes`,
  `SettingItem.ItemType.airPlayLowRes`, applied in
  `ExternalSceneDelegate.applyStreamMode`, with
  `AirPlayViewController.viewDidLayoutSubviews` rescaling the game view when
  the window changes size); the `[Audio]` lines (`audioRouteFacts`,
  `routeChangeReason`, the route-change observer in `start(game:)`, the
  10 s line from the shader poll, and the connect/disconnect lines in
  `ExternalSceneDelegate`); the "AirPlay Audio Buffer" setting (`enum
  AirPlayAudioBuffer` in `ExternalSceneDelegate.swift`, `ExtraKey.airPlayAudioBuffer`,
  `SettingItem.ItemType.airPlayAudioBuffer`, applied as `audio_latency` in
  `PlayViewController.updateLibretroConfigs` and noted on the `[Device]`
  start line through `PlayDiagnosticsLogger.audioLatencyNote`); and the option plumbing
  (`ExtraKey.inputDiagnostics`, `GameOption.inputDiagnostics`,
  `PlayViewController.updateInputDiagnosticsConfigs`).
