---
name: wireless-signing-options-ipad
description: Cable-free re-sign/install routes for the Manic MP fork + StikDebug on the operator's iPad, scoped 2026-09-28 - Mac over Wi-Fi works with no new tools; SideStore (on-device) and a Pi signer (plumesign aarch64) both need the Apple ID in a third-party tool; iPad lockdownd is reachable from the Pi over the tailnet
metadata:
  type: project
  modified: 2026-09-29T15:20:00-07:00
  scope: operator
  provenance: Track signing-over-pi-30a38c9f on globo-pi, 2026-09-28 - measured probes (tailscale ping, TCP connect to 100.108.18.23:62078, GitHub release listings) + source read of claration/Impactor apps/plumesign
  supersedes: null
---

**Asked 2026-09-28:** sign + install Manic MP and StikDebug over Wi-Fi or on the iPad itself, no cable
(StikDebug was due for its 7-day re-sign). No route was chosen in that turn.

**Measured on the Pi (2026-09-28):**
- `ipad168` (100.108.18.23) answers `tailscale ping` via DERP(sfo), and TCP **62078 (lockdownd) is OPEN
  from the Pi over the tailnet**. Only the port was probed; no pairing record exists on the Pi, so an
  install over that path is unproven.
- No signing tooling is installed on the Pi (no usbmuxd, netmuxd, libimobiledevice, zsign, AltServer).
- `joeys-macbook-air` was offline on the tailnet (last seen 13 d) and has no ssh alias on the Pi.
- Impactor (claration/Impactor, ex PlumeImpactor) v2.6.5 ships `plumesign-linux-aarch64`. Its CLI has
  `account login -u/-p` (prompted 2FA, built-in anisette), `sign --apple-id --custom-identifier <id>
  --register-and-install --udid`, `device --install`. It talks to devices ONLY through the usbmuxd
  socket, so Wi-Fi on Linux needs netmuxd in front (mDNS discovery = same LAN, not the tailnet).
- StikDebug 3.1.13 (2026-09-28) is IPA/AltSource/source only, no longer on the App Store.

**Routes:**
1. Mac over Wi-Fi: the iPad is already Xcode-paired and shows as `localNetwork` when unplugged
   ([[ipad-check-via-gct-ipad]]); `xcodebuild -allowProvisioningUpdates` + `devicectl device install app`
   work over that link. App-sized payloads are fine; multi-GB pushes are what died on Wi-Fi.
2. SideStore + LocalDevVPN on the iPad: refreshes on-device, one computer session to set up.
3. Pi as signer: plumesign + netmuxd + pairing record + a weekly job.
4. Paid Apple Developer Program: 1-year profiles instead of 7 days.

**Why it matters:** routes 2 and 3 put the Apple ID into a third-party tool, which the standing rule in
[[manic-emu-fork-sideload-accepted]] forbids - the operator has to lift it explicitly. Third-party signers
also default to a team-suffixed bundle id, which installs Manic as a SECOND app with an empty library;
keep `com.globocodes.manicemu` (plumesign `--custom-identifier`) so it upgrades in place.

**Operator 2026-09-28 (same Track):** their worry about routes 2 and 3 is risk to the Apple account -
it is their MAIN one. So the main Apple ID stays in Xcode only; routes 2/3 are only on the table with a
separate burner Apple ID (SideStore documents this: wiki.sidestore.io/guides/burner-apple-id). A burner
is a different team, so it cannot upgrade the Xcode-signed Manic in place - one-time library move.
Known lock cause per SideStore/Sideloadly docs: old shared anisette servers; a lock clears with a
password reset.

**DECIDED 2026-09-28 (operator, decision recorded):** route 3, the Pi as signer, WITH THE MAIN Apple ID;
lock risk accepted ("account lock is fine if i can get back in with my password"). Burner creation had
failed (Apple refused their gmail/hotmail). Scope doc: better-games
`docs/wireless-signing-over-pi-scoping-2026-09-28.md` (private repo on purpose - ManicEMU fork is PUBLIC).

**Design facts from the source read (Impactor 6244bc3, idevice d32c818):**
- Split sign from install: `plumesign sign --apple-id --custom-identifier <id> -o out.ipa`, then
  `idevice-tools --host <ip> --pairing-file <f> ideviceinstaller upgrade out.ipa` (direct TCP, no
  netmuxd/mDNS, so it can run over the tailnet).
- idevice-tools Linux release is x86-64 ONLY; the Pi has no Rust toolchain - build in a rust container.
- plumesign stores email + adsid + xcode_gs_token (NOT the password), key at `keys/<team>/key.pem`,
  under `$XDG_CONFIG_HOME/PlumeImpactor`. Anisette = public `ani.sidestore.app` (v3), hard-coded: no
  flag or env var, self-hosting needs a source patch. Cert machine name `AltStore`; on Apple error 7460
  (too many certs) it REVOKES existing certs in list order, which can hit Xcode's.
- plumesign aarch64 v2.6.5 (sha256 7a1e8ac5...) runs on the Pi (`--help` in a no-network container).
- iPadOS runs one VPN at a time: LocalDevVPN on = Tailscale off, so the LAN address is the fallback.

**Operator answers 2026-09-28 (question card):** anisette = SELF-HOSTED on the Pi (so plumesign is built
from a pinned source commit with the URL patched, before the first login); devices = iPad ONLY (iPhone
Manic stays on the cabled Mac route).

**BUILT 2026-09-28 late (same Track, code in better-games `signer/`, uncommitted at the time):**
- State dir `~/.local/share/ios-signer` (0700, ext4): bin/ src/ state/ pairing/ inbox/ logs/ scripts/
  config.env. Operator-facing scripts are INSTALLED there (`signer/install.sh`) so runbook commands do not
  depend on a Track worktree path.
- `idevice-tools` aarch64 built from d32c8189 in `rust@sha256:a8a5f0a1...` (4.5 min). `plumesign` built
  from 6244bc3f + 3 patches (12 min cold). Anisette = `dadoum/anisette-v3-server` v2.2.2 pinned by digest,
  container `ios-signer-anisette`, published on 127.0.0.1:6969 only, restart unless-stopped.
- Gotchas hit: (1) omnisette only rewrites https->wss for the provisioning websocket, so an http:// base
  needs an http->ws rewrite too; (2) stock plumesign ECHOES the password at its prompt (read_line) -
  patched to dialoguer::Password; (3) `cargo build -p plume_core --example` needs `--features tweaks` or
  MachO fails to resolve; (4) tcpdump on `-i any` only showed DNS REPLIES, use -vv and parse `q: A? name`.
- Verified (`signer/verify-anisette.sh`, container with iptables allowlist): anisette probe got 10
  headers, looked up only gsa.apple.com, connected only to 17.32.194.x and the local server, 0 packets
  rejected; no public anisette host string in the binary. This covers the anisette step, NOT the login.
- R2 early evidence: idle iPad at 23:01 PDT was offline on the tailnet and :62078 gave no answer.
- Runbook c259b9c2 (open): step 1 pairing file via Taildrop to globo-pi (then `sudo tailscale file get`
  into pairing/ and rename to ipad.plist, chmod 600), step 2 Apple ID login GATED on my go-ahead after
  the link check passes. NO Apple ID entered, nothing signed, nothing installed as of this write.
- NEXT when the operator reports the pairing file sent: `signer/ipad.sh reach|info|apps` (read-only),
  over tailnet + LAN, awake / idle / LocalDevVPN on; write R1-R3, R8 into the scope doc.

**PHASE 0 PASSED 2026-09-29 00:37 PDT (PR #14 merged as f6cf32f; Pi main checkout
~/Documents/globo-pi/better-games updated):**
- The file StikDebug 3.x holds is a REMOTE-PAIRING file (keys alt_irk, identifier, private_key,
  public_key; iOS 17+), NOT a classic lockdown pairing record. idevice-tools `--host --pairing-file` only
  takes the classic kind, so it is NOT the install tool. Decision recorded: own small tool `rpcheck`
  (better-games signer/rpcheck, idevice git dep at d32c8189, needs feature `ring` when default-features
  are off). Flow: TCP <ip>:49152 -> RpPairingSocket -> attempt_pair_verify + validate_pairing (never
  `connect()`, which falls back to a fresh pair-setup and a Trust prompt) -> create_tcp_listener ->
  connect_tls_psk_tunnel_native -> tcp::adapter -> RsdHandshake -> <Service>::connect_rsd.
- Operator sent it by Taildrop; `sudo tailscale file get <dir>` then chown. Stored as
  `~/.local/share/ios-signer/pairing/ipad-rp.plist` (0600).
- Measured on tailnet 100.108.18.23 AND LAN 192.168.1.2 (LAN IP read from the tailnet peer's CurAddr):
  pairing accepted, tunnel up (61 services), ~0.3 s per check. Device reports iPadOS 26.5.2 (23F84),
  ProductType iPad16,8.
- CoreDevice appservice = ServiceNotFound through the tunnel (no developer disk image mounted); use
  installation_proxy shim (`get_apps(Some("User"))`) instead. Tunnel also offers afc, misagent,
  heartbeat, mobile_image_mounter shims - what an install needs.
- On the iPad: Manic EMU `com.globocodes.manicemu` 2.0.0, profile valid until 2026-10-01 08:37 UTC,
  get-task-allow true; StikDebug `com.globocodes.stikdebug` 3.1.10 with NO profile on the device
  (expired and removed). Both signed by dev certificate id 3Q4QQBA76L, team P6YSZ4N9VQ. The Pi login
  must be that same Apple ID or neither app upgrades in place. (The account email is deliberately not
  stored here; it shows in `ipad.sh apps`.)
- `reach-log.sh` started 00:39 PDT, 3-min interval, ~8 h, log at logs/reach.log: read it for R2 (idle
  iPad) and R3 (LocalDevVPN on). Runbook c259b9c2 v3: step 1 done, step 2 (login) OPEN, steps 3-4 are
  the measurement toggles and the DHCP reservation for 192.168.1.2.
- Gotcha 09-29 01:12: `plumesign account login` with NO options prints its help and exits (clap
  `arg_required_else_help` on LoginArgs), so the operator's first login attempt did nothing. login.sh
  now reads the email itself and passes `--username`; tested against a stub only, the real prompt
  sequence (hidden password, 2FA) is unverified until the operator logs in.
- NEXT = phase 1: add install to rpcheck (afc upload + installation proxy upgrade via connect_rsd),
  sign StikDebug with `--custom-identifier com.globocodes.stikdebug`, check get-task-allow, install.
  Needs the operator's login first, and their go-ahead to install.

**PHASE 1 DONE FOR STIKDEBUG 2026-09-29 01:24 PDT:**
- Operator logged in on the Pi (login.sh), approved losing the `iloader` cert, approved installing
  StikDebug only. Session: team P6YSZ4N9VQ, no password stored.
- Account had 2 certs (machine `iloader` from 09-15, and the MacBook Air's Xcode one). Apple issued a
  THIRD to the Pi and revoked NOTHING; the revoke path stays untested.
- StikDebug 3.1.13 (sha256 d730fdfd..., matches GitHub's digest; original bundle id com.stik.stikdebug,
  no nested bundles, no entitlements blob) signed as com.globocodes.stikdebug: team ok,
  get-task-allow true, profile names the iPad (UDID tail C3401C). Upgrade 3.1.10 -> 3.1.13 over the
  tailnet took 5 s for 14 MB. Signed until 2026-10-06 08:25 UTC. Launch/JIT NOT yet confirmed by the
  operator.
- `signer/resign.sh <ipa> <bundle id> [--dry-run]` = sign + checks + upgrade + read-back; installed at
  ~/.local/share/ios-signer/scripts/. rpcheck gained `upgrade` / `upgrade-dry` (refuses an app that is
  not already installed; uses idevice `upgrade_package_with_callback_rsd`).
- MY MISTAKE, do not repeat: testing the refusal with a made-up bundle id
  (`com.globocodes.notinstalled`) REGISTERED that id on the operator's Apple account, because signing
  (addAppId) happens before the installed-check. `--dry-run` signs too. Free accounts get 10 new app ids
  per 7 days; 2 used as of 09-29 (stikdebug + the junk one). Never sign with an id that is not real.
- UNEXPLAINED: `account app-ids` at 08:17 UTC listed 4 ids (manicemu + stikdebug created by Xcode, two
  SideStore ids); at 08:23, before the Pi added anything, Apple's list was EMPTY and stikdebug had to be
  re-added. No delete call exists in any log. Manic's id will be re-registered when it is re-signed.
- Each re-sign leaves the previous provisioning profile on the device (2 for stikdebug now); the daily
  job should remove superseded ones via misagent.
- plumesign stages under $TMPDIR and logs at DEBUG level including the account email: keep its logs in
  the 0700 logs dir and mask emails before quoting them.
- NEXT: operator confirms StikDebug launches (runbook c259b9c2 step 3) and exports the Manic IPA from
  the Mac to inbox/manic.ipa (step 4) before Manic's profile expires 2026-10-01 08:37 UTC; then
  `resign.sh inbox/manic.ipa com.globocodes.manicemu` with their go-ahead. Phase 3 = daily job.

**PHASE 3 BUILT 2026-09-29 01:35 PDT; MANIC BLOCKED:**
- Manic re-sign stopped at its first precondition: no `inbox/manic.ipa`, no fork releases or CI
  artifacts, Mac offline on the tailnet. Manic's profile still expires 2026-10-01 08:37 UTC. Upstream's
  published Manic is NOT a substitute (it would replace the fork).
- `signer/daily.sh` (installed in scripts/): reads `~/.local/share/ios-signer/apps.conf`
  ("<bundle id> <ipa>", currently StikDebug only, Manic line commented), re-signs what has <=
  RESIGN_BELOW_DAYS (3) left, prunes superseded profiles with `rpcheck prune <TEAM.bundle>`, writes
  status.json + logs/daily.log. Exit 0 ok / 3 iPad unreachable / 4 Apple session / 5 check or install
  failed / 6 config. Last line is the one-line result; it starts with URGENT when an app is < 48 h and
  not re-signed (works offline from status.json).
- Tested: skip, real re-sign of StikDebug (now signed until 2026-10-06 08:33 UTC, 1 profile left),
  unreachable + URGENT, missing config. NOT tested: lapsed session, failed install.
- Schedule NOT in place: `bostrat-loop propose` REFUSED from this multi-repo Track ("this Track isn't
  based on a repo"). Plan kept at better-games `signer/loop-plan.json` (`0 2,20 * * *` UTC = 13:00 +
  19:00 Pacific); propose it from a Track on better-games alone, or the operator adds it in the Loops
  tab. Never hand-write a cron/timer for it. Until then NOTHING re-signs on its own; StikDebug is due
  from 2026-10-03.
- R2/R3 still OPEN: only 19 readings in 54 min when written. reach-log.sh restarted 01:34 PDT at 5 min
  for 7 days (logs/reach.log) - read it before revising the schedule. It is a nohup process and dies
  on a reboot.
- Shell gotcha: `pkill -f "scripts/reach-log.sh"` killed the calling shell too (the pattern matches its
  own command line). Use `ps ... | grep "[r]each-log.sh"` and kill by pid.

**MANIC INSTALLED 2026-09-29 10:20 PDT - both apps now Pi-signed until 2026-10-06:**
- Operator ran `signer/mac-export-manic.sh` ON THE MAC over the home LAN (Tailscale off on the Mac):
  `ssh -o HostName=192.168.1.13 globo-pi cat .local/share/ios-signer/scripts/mac-export-manic.sh >
  /tmp/m.sh && SIGNER_PI_ADDR=192.168.1.13 bash /tmp/m.sh`. It zips the newest DerivedData
  `*-iphoneos/*.app` whose bundle id is com.globocodes.manicemu into Payload/ and scp's it to
  inbox/manic.ipa. No Archive/export needed. Worked first time. The Pi CANNOT reach the Mac (Remote
  Login off, no key); Mac LAN address 192.168.1.9, Pi 192.168.1.13.
- manic.ipa: 273 MB, app dir `ManicEmuSideload.app`, 2.0.0 build 20, 45 frameworks, NO appex. Sign 62 s,
  upgrade 47 s over a direct tailnet link. Entitlements kept: increased-memory-limit + get-task-allow.
  Signed until 2026-10-06 17:18 UTC. App id budget 3 of 10 this week.
- Re-copy is only needed for a NEW build of the fork; the Pi re-signs the same file weekly.
- `ipad.sh library <bundle id>` (rpcheck `library`, house_arrest vend_documents) = read-only file counts:
  Manic after install = Documents/Datas 18 files 16.64 GB, Documents 6 files 8.76 GB. No before-count
  was taken, so take one BEFORE any future Manic install.
- apps.conf now lists both apps; daily.sh skips both (7 days left). Operator has NOT yet confirmed
  launch / library / JIT (runbook c259b9c2 step 3).
- R2 MEASURED: iPad answered 00:39-01:34 (in use), NO ANSWER 01:39-09:57 on BOTH tailnet and LAN,
  answered again from 10:02. It drops within ~5 min of being put down. The daily run only works while
  the iPad is awake. Locked-on-charger and R3 (LocalDevVPN on) still unmeasured.

**CONFIRMED BY THE OPERATOR 2026-09-29:** after the wireless installs of both apps, asked to check
StikDebug, the Manic library and a JIT boot, they answered "Works like a charm". PR #16 merged
(ace970d); the Pi's main checkout and the installed scripts match it. Runbook c259b9c2 steps 1-4 done;
left: optional measurement toggles, the DHCP reservation for 192.168.1.2, and the SCHEDULE (due before
2026-10-03, propose signer/loop-plan.json from a better-games-only Track).

**R3 MEASURED + ADDRESS LOOKUP 2026-09-29 10:38 PDT:**
- With LocalDevVPN ON: tailnet path dead (peer goes offline within minutes), LAN path WORKS (pairing,
  tunnel, daily run). Away from home with LocalDevVPN on there is no path.
- The iPad's LAN address MOVES: 192.168.1.6 on 09-28, 192.168.1.2 on 09-29, same Wi-Fi hardware
  address 0e:c7:00:47:22:7e (a private address; stays put only while Private Wi-Fi Address = Fixed).
- DHCP server = the router at 192.168.1.1 (Pi-hole DHCP is off). Its admin page needs the operator's
  login; never attempt it. Reservation = operator step, runbook c259b9c2 step 6.
- `signer_find_ipad` (signer/env.sh) = configured IPAD_HOSTS in order, then lookup by IPAD_MAC in the
  neighbour table with one ping sweep of IPAD_LAN_PREFIX. Used by ipad.sh, resign.sh, daily.sh.
  reach-log.sh still logs the fixed addresses only.
- `bostrat-loop propose` needs a cwd inside a Track workspace AND a single-repo Track; from the main
  checkout it says "trackId required". Still no schedule as of 10:45.

**SCHEDULED 2026-09-29 10:53 PDT - the project is DONE:**
- Operator CHOSE (question card) a systemd user timer on the Pi over a Bostrat Loop, knowingly
  overriding the workspace rule against hand-written timers, for this one job. Do NOT also propose a
  Loop for it; `signer/loop-plan.json` was removed for that reason.
- Units `ios-signer-daily.timer` / `.service` in ~/.config/systemd/user (sources in better-games
  signer/systemd/, managed by `signer/install-timer.sh up|down|status`). Hourly 08:00-23:00
  America/Los_Angeles, jitter 2 min, `SuccessExitStatus=3` (sleeping iPad is not a failure), explicit
  PATH because user units start with a bare one. Linger=yes on globo.
- `scheduled.sh` = one daily.sh + alert rules: re-signed -> priority 2; URGENT (<48 h) -> priority 5,
  at most once per 6 h; Apple login / failed run / bad config -> priority 4, once per 20 h per cause;
  asleep or skipped -> silent. State in ~/.local/share/ios-signer/alert-state.
- Alerts = ntfy via `notify.sh`, topic read at send time from the file named by
  SIGNER_NTFY_TOPIC_FILE (config.env points at ~/Documents/globo-pi/cron/launch-notify/topic, the
  operator's existing private topic). Never print, copy or log the topic. `bostrat-notify` was NOT
  used: it needs a Track cwd, which a timer does not have.
- daily.sh now starts the anisette container if it is down before checking the Apple session.
- One real test alert was sent 10:53; whether the phone showed it is unconfirmed.
- Gaps: no alert if the Pi is off or the timer is removed; away from home with LocalDevVPN on there is
  no path to the iPad.

**CLOSED OUT 2026-09-29 11:40 PDT:** operator confirmed the test alert reached their phone and that
the iPad's Private Wi-Fi Address is set to Fixed (hardware address verified unchanged,
0e:c7:00:47:22:7e at 192.168.1.2; 192.168.1.6 now belongs to another device). Router reservation
SKIPPED by their choice (question card): the hardware-address lookup covers it. PR #17 merged
(5e5c4fd); Pi main checkout, installed scripts and units all match. Timer fired by itself at 11:01.
Runbook c259b9c2 marked done. Still unknown: Apple session lifetime (R5), behaviour of a locked iPad
on a charger, and a real alert from a real failure.

**GOTCHA noted 2026-09-29 (Track 6d533315):** the Pi re-signs from `inbox/manic.ipa`, so a newer build
installed straight from Xcode is REPLACED by the Pi's older copy at the next re-sign (<= 3 days left).
Every new fork build must be followed by `mac-export-manic.sh` on the Mac. The Pi cannot compile the
app (no Xcode / iOS SDK on Linux; fork has no `.github/workflows`), so compiling is the one step still
tied to the Mac; signing and installing are not.

**DECIDED 2026-09-29 (operator, Track 6d533315, decision recorded):** builds stay on the Mac by hand
("If its only when we have a new manic build, i am ok with maintaining the mac"). Do NOT propose a
cloud/CI build or a Pi-side compiler again unless they ask.

**How to apply:** build in the phase order of the scope doc (0 link proof with no Apple ID, 1 StikDebug,
2 Manic, 3 automation). Before that, do not install signing tools or enter an Apple ID anywhere until the operator picks a
route. Free-account ceilings apply to all of them: 3 sideloaded apps per device, 10 app ids per 7 days.
Related: [[free-apple-id-signing-gotchas]], [[operator-ipad-and-mac-hardware]].
