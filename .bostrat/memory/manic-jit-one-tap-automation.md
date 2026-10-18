---
name: manic-jit-one-tap-automation
description: How far "open Manic and JIT is on" can be automated on the iPad - LocalDevVPN has a background Shortcuts action (Enable/Disable/Toggle), StikDebug's Enable JIT action always opens StikDebug, StikDebug waits 20 s for the VPN on a URL request; the StikDebug bounce cannot be removed without embedding a debugger
metadata:
  type: project
  modified: 2026-09-29T15:18:55-07:00
  scope: repo:manicemu
  provenance: source read of jkcoxson/LocalDevVPN (VPNShortcuts.swift, Constants.swift) and StikDebug/StikDebug HEAD (App/Intents.swift, Views/HomeView.swift, Views/SettingsView.swift) plus the App Intents metadata inside the Pi's StikDebug-3.1.13.ipa, Track 6d533315, 2026-09-29; nothing run on the iPad
  supersedes: none (relates to [[manic-jit-auto-enable-scoping]], [[wireless-signing-options-ipad]])
---

**Facts:**
- LocalDevVPN (App Store 1.3.0): App Intent `ControlLocalDevVPNIntent`, title "LocalDevVPN", operation Enable / Disable / Toggle, `openAppWhenRun = false` (runs in the background). Default tunnel addresses 10.7.1.1/32 (interface) and 10.7.0.1/32 (peer), so an app could detect the VPN by looking for that interface address.
- StikDebug 3.1.13: App Intents "Enable JIT" (parameter App, `openAppWhenRun = true`, launches/attaches by bundle id) and "Kill Process" (background). URL schemes `stikdebug` and `stikjit`; hosts `enable-jit`, `kill-process`, `launch-app`. With `pid` AND `bundle-id` it attaches to the running process and returns to that bundle id.
- A URL-triggered enable-jit restarts StikDebug's tunnel and waits up to 20 s for tunnel + developer disk image (`waitForJITPrerequisites`), so the VPN may come up at the same moment.
- StikDebug Settings → Behavior → "Confirm JIT Links" defaults ON in HEAD and puts a confirmation dialog in front of every URL request; "Always Run Scripts" sits beside it. Keep-alive = Silent Audio + Background Location toggles.
- The bounce through StikDebug cannot be removed while StikDebug is the debugger. Removing it means a debugger inside Manic (StikJIT helper extension) or outside the iPad (the Pi over the network); both are days of work and unproven.

**Why:** the operator's preferred state is "open Manic, next thing I see is the home page and JIT on" (2026-09-29).

**How to apply:** no-code route first - a Shortcuts personal automation "When Manic MP is opened → Enable LocalDevVPN" (Run Immediately), optionally a home-screen shortcut Enable LocalDevVPN → Wait → StikDebug Enable JIT for Manic MP. Runbook: "Manic MP opens with LocalDevVPN and JIT on by themselves". Never automate "when Manic is closed → disable VPN": the app also counts as closed during the StikDebug bounce, and the debugger must still be attached when a game prepares its JIT memory (see StikJIT facts below). LocalDevVPN on = Tailscale off on the iPad.

**StikJIT = StikDebug's engine as a framework (read 2026-09-29, StikDebug/StikJIT INTEGRATION.md, v1.9.0 of 2026-09-27, MPL-2.0, three releases in one week):**
- "Built-in StikJIT" needs a HELPER APP EXTENSION in the host app, because a process that attaches a debugger to itself deadlocks. The framework is linked into the helper only. "StikJIT does not provide or launch the helper extension. The app owns that integration." How to launch it is not described.
- Still needs LocalDevVPN (default endpoint `10.7.0.1:49152`), a pairing file inside the app (`Documents/StikJIT/pairingFile.plist`), `get-task-allow`, iOS 17.4+. It removes the StikDebug app and the app switch, nothing else.
- Universal protocol on TXM: attach, the app calls `JIT26PrepareRegion` (`brk #0xf00d`, x16=1) for each executable region, then `JIT26Detach` (x16=0). So the debugger is needed until the regions are prepared, NOT for the whole play session; a region added after detach needs a reconnect. Manic's own shim sends x16=2 (`BreakSendJITScript`) and already speaks universal.js, so the cores need no change. When Manic's cores detach is unverified (they are binaries here).
- Correction: earlier in Track 6d533315 the agent told the operator StikDebug "has to stay alive for the whole session"; that was an overstatement and was corrected in chat.
- Costs on this setup: a new Xcode target (pbxproj edit, Mac-only compile rounds), one more app id on the personal team, and the Pi signer has never signed an app with an extension (Manic has none today).

**Security of "Confirm JIT Links" (source read 2026-09-29, operator asked if turning it off leaves the iPad vulnerable):**
- The setting gates ONLY `enable-jit` links. `kill-process` and `launch-app` links always ask. The Shortcuts action "Enable JIT" never consults it.
- An `enable-jit` link may carry `script-data` (base64 JavaScript). Scripts get `send_command` (raw debug-server commands: read and write the target's memory and registers), `prepare_memory_region`, `take_screenshot`, `resume_app`, `get_pid`, `log`.
- So with the setting off, anything that can open the link (any installed app silently; a web page or message only after iOS's own "Open in StikDebug?" tap) can run a script inside a debuggable app. Debuggable = `get-task-allow`, i.e. dev-signed apps only (Manic MP here); never the system or App Store apps. It needs the VPN up and a valid pairing file.
- Runbook 94b0fbcb v2 keeps the setting ON and makes the Shortcuts icon the main way in; turning it off is an optional, explained step. Do not tell the operator to turn it off without that trade-off.
