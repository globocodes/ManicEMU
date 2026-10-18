---
name: ipad-crash-and-session-logs-via-pi
description: The Pi pulls iPad crash reports (.ips) and Manic's Documents files over the signer's remote-pairing tunnel: ~/.local/share/ios-signer/scripts/manic-logs.sh <out dir> (one command), or bin/rpcheck arms crashlogs / crashpull / docs-ls / docs-pull via scripts/ipad.sh; source is better-games signer/ (PR #34, 10-18)
metadata:
  type: reference
  modified: 2026-10-18T16:30:00-07:00
  scope: operator
  provenance: Track 2a2d9596 2026-10-17; idevice crate CrashReportCopyMobileClient + HouseArrestClient over RSD (connect_rsd), same tunnel as rpcheck; built with the signer's docker rust image in ~44 s
  supersedes: none (relates to [[wireless-signing-options-ipad]], [[manic-controller-input-path]])
---

**Facts:** `~/.local/share/ios-signer/bin/rpcheck-logs <host> ~/.local/share/ios-signer/pairing/ipad-rp.plist crashlogs [filter]` lists the device's crash reports (name, kind, size); `crashpull <name> <local path>` copies one; `docs-ls com.globocodes.manicemu "/Documents/Netplay Logs"` and `docs-pull <bundle> <path> <local>` read an app's Documents (house arrest). It is the signer's `rpcheck` (read-only remote-pairing checks) plus four arms; `bin/rpcheck` itself is untouched. Source: `~/.local/share/ios-signer/src/rpcheck-logs/` (Cargo.toml, src/main.rs, `pull-manic-logs.sh` = wait-for-iPad-then-pull script); rebuild with the docker command from better-games `signer/build-rpcheck.sh` pointing `-v .../src/rpcheck-logs:/src`, target dir `build/rpcheck` is shared and fine. `idevice-tools` in bin cannot do this (needs a classic lockdown pairing). Crash reports are named `ManicEmuSideload-YYYY-MM-DD-HHMMSS.ips` (JSON: first line meta, second body; `exception`, `faultingThread`, `threads[].frames`, `vmRegionInfo`, `codeSigningFlags`). Manic writes one RetroArch log per Dolphin launch to `Documents/Netplay Logs/retroarch__<date>.log` and one line per session to `Manic MP sessions.log`. The host changes (192.168.1.9 on 10-17; `signer_find_ipad` in scripts/env.sh finds it); the iPad answers only while awake.

**How to apply:** for any "the app crashed" report, pull the .ips first instead of guessing from code; run the pull script in the background and let it wait for the iPad. Fold the four arms into better-games `signer/rpcheck/src/main.rs` when next touching that repo.

**Update 2026-10-18:** the four arms were folded into the signer's real `rpcheck` (better-games PR #34, branch `track/rpcheck-logs-2a2d9596`: `signer/rpcheck/src/main.rs`, `signer/ipad.sh` arms, new `signer/manic-logs.sh`, installed by `install.sh`). The Pi's `bin/rpcheck` is that build (old one kept as `bin/rpcheck.prev`; `bin/rpcheck-logs` is now a symlink to it) and `scripts/ipad.sh` + `scripts/manic-logs.sh` are installed. `~/.local/share/ios-signer/src/rpcheck-logs` was removed. Easiest pull: `~/.local/share/ios-signer/scripts/manic-logs.sh <out dir> [--wait <min>] [--reports n] [--logs n]`. A second pre-fix report (Kirby Air Ride, 2026-10-18 06:13Z, same KERN_CODESIGN_ERROR at 0x308000000, 96 s after launch) confirmed the diagnosis.
