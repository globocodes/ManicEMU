# Google Drive save sync for Manic MP — scoping (2026-09-28)

Blueprint: "Multiplayer GameCube on the iPad" (magic-mirror
`docs/blueprint-gamecube-on-the-ipad.md`), items BP-D17 (design) and BP-I32
(implementation). This note turns those two lines into a buildable scope. It
amends BP-D17 through BP-D21–BP-D24 and splits BP-I32 into BP-I44–BP-I49.

**Goal.** Play Animal Crossing (GameCube, `GAFE01`) on the iPad, close it, open
Manic MP on the iPhone and be in the same town at the same moment, and back.
The operator's Google Drive is the only store. Nothing runs on the Pi.

**Devices.** iPad Air 11-inch (M4), iPhone 16 Pro, both with the fork
installed (bundle id `com.globocodes.manicemu`, display name "Manic MP",
`ManicEmuSideload` target, personal team). The Mac is a possible third device
later and changes nothing below.

## 1. What the fork has today (verified against upstream `1647190`, this branch)

Upstream Manic EMU already syncs, behind a membership-gated iCloud switch. The
sync has two halves, both in `ManicEmu/Sources/Tools/Others/SyncManager.swift`:

| Half | Mechanism | What it carries | Fate in the fork |
|---|---|---|---|
| Records | IceCream `SyncEngine` over CloudKit | Realm objects: `Game`, `GameSaveState`, `GameCheat`, `Skin`, `ImportService`, `Settings`, `ControllerMapping`, `Theme`, `Trigger`, `Prefference` | Gone. CloudKit needs the iCloud entitlement, which the sideload entitlements already drop (BP-I20). |
| Files | SwiftCloudDrive mirror of `Documents/` into the iCloud container | Everything under Documents except `/Datas/` (games), `/wpkdata` and `/SYSTEM/CACHE/` | Kept in shape, re-pointed at Google Drive. |

Facts that shape the design:

- **Where the memory card lives.** The Dolphin core's user directory is
  `Documents/Dolphin/` (`R.Path.Dolphin`, `Constants.swift`). GameCube saves use
  the core's GCI-folder mode: one `.gci` per game in
  `Documents/Dolphin/User/GC/<USA|EUR|JAP>/Card A/` (seen on the iPad in the
  Sonic investigation, magic-mirror
  `docs/sonic-adventure-dx-investigation-2026-09-19.md` §3). Animal Crossing
  is one `GAFE01` `.gci` in `USA/Card A/`. The card is not tied to a `Game`
  record: Dolphin finds the `.gci` by game id on boot. **Syncing that folder
  restores every GameCube save on the other device with no library mapping at
  all.** This is what makes Phase 1 small.
- **No save states for GameCube.** Manic treats Dolphin as "basic-only"
  (`Game.swift`, `supportRewind`): no save states, no rewind. The memory card is
  the only state Animal Crossing has.
- **Triggers exist.** `startSync()` runs at launch from
  `ApplicationSceneDelegate` when the switch is on, and `syncDocument()` runs on
  the `StopPlayGame` notification, which `PlayViewController` posts when a game
  closes. A pre-play download hook exists too: `PlayViewController` already
  downloads a ROM from the cloud before boot when it is missing locally.
- **Conflict handling is thinner than it looks.** `syncDocument()` compares
  local vs cloud modification time and the newer side wins silently. The
  "conflict prompt" appears only when the local timestamp cannot be read.
  After a download the local file gets a fresh mtime, so the next pass would
  re-upload it unless the remote time is stamped back onto it.
- **Games are uploaded too.** The bulk walk skips `/Datas/`, but
  `FilesImporter` explicitly calls `SyncManager.upload` on each imported
  ROM (`romUrl`) and `GamesSelectionView` on save files. For a 1.4 GB `.iso`
  that is a cost and a bug; the fork must suppress it for Dolphin titles.
- **Google Drive is already wired for import.** `CloudDriveConnetor.swift`
  builds a `GoogleDriveConnector` (OAuth via ASWebAuthenticationSession) and
  `ImportService.cloudDriveProvider` a `GoogleDriveServiceProvider`, both from
  the `Daiuno/CloudServiceKit` SPM package. Tokens live in the Realm
  `ImportService` row (`token`, `refreshToken`); `renewToken` refreshes them.
  The provider has everything the sync needs: `contentsOfDirectory` (returns
  `modifiedTime` and `md5Checksum`), `createFolder`, `uploadFile` (resumable,
  6 MB chunks), `uploadData` (multipart), `downloadableRequest`, `removeItem`,
  `moveItem`, `copyItem`, `searchFiles`.
- **But the connector asks for read-only.** `GoogleDriveConnector.scope`
  defaults to `drive.readonly` + `userinfo.profile`. Every upload returns 403
  until the fork sets `scope` to `drive.file` before connecting.
- **No client id in the tree.** `Cipher.swift` ships every app id empty, and
  `Info.plist` carries upstream's Google URL scheme
  (`com.googleusercontent.apps.177622908853-…`). The fork needs its own client
  id and a matching scheme, on the sideload target only.
- **Game identity.** `Game.id` is a hash of the imported file
  (`FilesImporter.swift:581`). The same disc file imported on both devices
  gets the same id, which is what a later manifest can key on. Manic also
  stores the Dolphin game id (`gameIDForDolphin`, e.g. `GAFE01`).

## 2. Decisions

These are the calls this note makes. Each becomes a blueprint design item.

### D21 — What syncs, and where it lives on Drive

Drive folder `Manic MP/` at the root of the operator's Drive, created by the
app on first sign-in (with `drive.file` the app only ever sees what it
created, which is exactly this folder). Layout:

```
Manic MP/
  gc/
    USA/Card A/GAFE01.gci        ← mirrors Documents/Dolphin/User/GC/USA/Card A/
    EUR/Card A/…                    (only regions that exist locally)
    JAP/Card A/…
  history/
    gc/USA/Card A/GAFE01.gci.2026-09-28T19-04-11Z.ipad    ← last 10 per file
  devices/
    <device-id>.json             ← per-device lease + last-sync record
  manifest.json                  ← Phase 2 (library, cheats, mappings, skins)
```

Phase 1 syncs the memory-card folders only. Phase 2 adds the manifest and the
rest of BP-D17's list. Never synced: `Datas/` (games stay on the Pi share),
`Dolphin/User/Cache`, `Dolphin/User/ShaderCache`, `Dolphin/User/Logs`,
`Netplay Logs/`, `SYSTEM/CACHE`, `wpkdata`. Save states stay local: Dolphin
has none, and the other cores are out of scope for this fork.

Rejected: mirroring all of `Documents/` as upstream does (shader caches and
logs are large and device-specific), and Memory Card B (unused; the visit flow
of BP-D13 will mount a Slot B snapshot from a different source when it comes).

### D22 — The sync protocol: pull before boot, push on close, lease for conflicts

The problem with "sync at launch and on close" is a stale card: launch on the
iPhone while the iPad's upload has not finished, or with no network, and the
iPhone plays yesterday's town and later overwrites today's. The protocol:

1. **Pull, blocking, before Dolphin boots** a GameCube title. Spinner over the
   play view, "Syncing town from Drive…". Compare Drive `md5Checksum` against
   the local file's md5; download only when they differ. Timeout 20 s.
2. **Offline or timed out:** boot anyway only after an explicit tap on
   "Play with the local copy" and mark the device's lease as *dirty-offline*.
   Default button is "Cancel".
3. **Lease.** Before boot, write `devices/<device-id>.json` with
   `{ playing: true, since, deviceName }`. Another device pulling while a lease
   is live sees "Animal Crossing is open on GloboPad since 19:04" and can
   cancel or take over (taking over is the operator's choice; it never blocks
   hard, because a crashed device would otherwise lock the town forever).
4. **Push on `StopPlayGame`** and on `sceneDidEnterBackground` while a Dolphin
   title is running (the OS may kill the app; the card has already been
   flushed by Dolphin on each in-game save). Upload is md5-gated too: no
   change, no upload. Clear the lease after a successful push.
5. **History before overwrite.** Every upload that replaces a file first copies
   the Drive version into `history/` with a timestamp and device suffix
   (`copyItem`, server side, no download). Keep the last 10 per file. Every
   download that replaces a local file first copies the local file into
   `Documents/Dolphin/User/GC/.history/` (same retention). Nothing is ever
   destroyed by the sync; a wrong resolution is one file copy to undo.
6. **Real conflict** = the local file differs from what this device last
   pulled *and* Drive differs from that too (both sides wrote since the common
   ancestor; `devices/<id>.json` stores the md5 of the last pulled version).
   Then, and only then, a prompt: "This iPhone and GloboPad both saved
   Animal Crossing since they last synced. Keep this device's town (19:04) or
   GloboPad's (18:52)?" Both versions are in `history/` either way.
7. **Timestamps.** After a download, set the local file's modification date
   to the Drive `modifiedTime`, so mtime stays meaningful for the operator
   and upstream's walker never sees a phantom change.
8. **Never inside a session.** The pre-play pull runs before hosting a
   BP-D19 streaming session; the push runs when the session ends. Viewers
   run no emulator and never sync.

Rejected: mtime last-writer-wins (upstream's rule; silent loss on the second
device), a hard lock (a dead device locks the town), and background upload via
`BGTaskScheduler` (unreliable on a sideloaded 7-day build; the
foreground push on close plus the background-entry push is enough).

### D23 — OAuth and the Google side

- The fork's own **Google Cloud project** on the operator's Google account,
  free tier; Google Drive API enabled; OAuth client of type **iOS** with the
  sideload bundle id `com.globocodes.manicemu`. No client secret exists for
  iOS clients, matching CloudServiceKit's `appSecret: ""`.
- **Scope `drive.file`** only, set on `GoogleDriveConnector.scope` before
  `connect`. It is a non-sensitive scope: no Google verification review, and
  the app sees only the folder it created. `userinfo.profile` stays so the
  Settings row can show the account.
- **Consent screen published**, not left in Testing. In Testing mode Google
  expires refresh tokens after 7 days, which would mean signing in again on
  both devices every week. With only non-sensitive scopes, publishing needs
  no review; the "unverified app" interstitial appears once per device and
  is fine for an audience of one.
- **Client id placement.** `R.Cipher.GoogleDriveAppId` stays empty in the
  tracked tree. The sideload build reads the id from an untracked
  `Config-Local.xcconfig` key (`MANIC_GOOGLE_CLIENT_ID`) that lands in the
  target's `Info.plist` both as the URL scheme
  (`com.googleusercontent.apps.<id>`) and as a key the code reads. This is
  the same mechanism BP-D15 already uses for the team id, so a rebase stays
  clean and the id is never committed (it is not secret, but it is
  operator-specific).
- **Token storage** reuses the `ImportService` row of type `.googledrive`
  (Realm), so an operator who has already connected Google Drive as an import
  source needs no second sign-in, and `renewToken` keeps working unchanged.

Rejected: the full `drive` scope (restricted, needs verification), a service
account (no per-user Drive without Workspace), and committing the client id.

### D24 — Library manifest is Phase 2, and the Delta-era items retire

Because Dolphin finds saves by game id in a shared card folder, Phase 1 needs
no manifest at all. Phase 2 adds `manifest.json` keyed by `Game.id` (file
hash) with the Dolphin game id, display name, region, per-game core options
(`SpecialCoreOption` values), cheats, controller mapping and skin choice, so a
fresh install can offer "import these from the share" and restore the rest
once the file arrives. Games themselves never travel through Drive.

Blueprint reconciliation:

- **BP-D6 / BP-I13** (GCI copied into Delta's per-game save file, Delta
  Sync) belong to the dropped Phase 3 and are superseded by BP-D17 + D21.
- **BP-I26** (Pi save hub, backup at session end) conflicts with BP-D17's
  "Pi-as-backend out of scope". Drive is the store; the Pi's job shrinks to a
  nightly `rclone` mirror of the `Manic MP/` folder (BP-I49), which satisfies
  BP-R16's "backed up to the Pi" without any device talking to the Pi.
- **BP-R4** (saves survive relaunch, update, re-sign) is met today by the
  fixed bundle id; Drive adds "survive a reinstall on a new device".

## 3. Implementation plan

Estimates are for a Mac Track doing the Swift work; the Pi Track cannot build
iOS. Everything is in `globocodes/ManicEMU` on the live fork branch
(`phase-b-netplay` today, see BP-I41), gated by `SIDE_LOAD` so upstream's
iCloud path is untouched for a rebase.

### Phase 1 — Animal Crossing across two devices (BP-I44–BP-I47)

**BP-I44 · Sign-in (½ day + operator runbook).**
Runbook "Google Drive sync signed in on both devices" covers the Google Cloud
console steps (project, Drive API, OAuth client, consent screen publish) and
the `Config-Local.xcconfig` line. Code: `GoogleDriveConnector.scope =
"…/drive.file …/userinfo.profile"` in `CloudDriveConnetor.genConnector`; read
the client id from `Info.plist` when `R.Cipher.GoogleDriveAppId` is empty;
`Info.plist` URL scheme for the sideload target from the xcconfig; a
"Google Drive sync" row in Settings for `SIDE_LOAD` builds in place of the
iCloud row (`iCloudSettingView` reskinned: account, last sync, switch), with
`Settings.iCloudSyncEnable` reused as the master switch so every existing
guard keeps working. Done when: sign-in completes on the iPad and iPhone,
`Manic MP/` appears in Drive, and a token refresh succeeds after the 1-hour
access token expiry (log line).

**BP-I45 · Drive-backed store (1 day).**
A `DriveSyncStore` (actor) wrapping `GoogleDriveServiceProvider`: `list(path)`
→ `[name, md5, modifiedTime, id]`, `upload(localURL, path)` (resumable; ensure
parent folders, cache folder ids), `download(path, to:)`, `copyToHistory(path,
suffix)`, `writeJSON` / `readJSON` for `devices/` and `manifest.json`.
`SyncManager`'s static `upload/download/delete/isFileExist` gain a
`SIDE_LOAD` branch that routes to the store; the iCloud `CloudDrive` and
`NSMetadataQuery` code compiles out under `SIDE_LOAD`. Unit tests against a
fake provider (list, md5 gating, history retention, folder creation).

**BP-I46 · Memory-card sync path (1½ days).**
`GameCubeSaveSync` implementing D22: `pullBeforeBoot(game)` called from
`PlayViewController` before `showPlayView()` for `isDolphinCore` titles;
`pushAfterClose()` from the `StopPlayGame` observer and from
`sceneDidEnterBackground` while `PlayViewController.isGaming`; lease file;
conflict detection from the last-pulled md5; local `.history/`; mtime
stamping; one line per pull/push/conflict in `Netplay Logs/Manic MP
sessions.log` (BP-I40's log) with byte counts and durations. Suppress
`SyncManager.upload(romUrl)` for Dolphin titles in `FilesImporter`.

**BP-I47 · Operator test (½ day, operator).**
Steps in the runbook: (1) iPad: play Animal Crossing, save, quit → "Synced
town to Drive" toast; (2) iPhone: open the same title → spinner → same town,
same day; play, save, quit; (3) iPad again → the iPhone's changes are there;
(4) conflict: both devices in Airplane Mode, play and save on both, reconnect,
open on either → prompt; choose; verify both towns are in `history/`. Record
timings in §7 of this note.

### Phase 2 — breadth (BP-I48) and backup (BP-I49)

**BP-I48 · Manifest, cheats, mappings, skins (2 days).** Per D24. Export
`GameCheat`, `ControllerMapping` and the per-game options to JSON in
`manifest.json` on push; on pull, apply to matching `Game.id` records and
list the missing games with a "these need importing from the share" screen.
Skins: upload `.deltaskin`/`.manicskin` files under `skins/`; the Realm row
is rebuilt from the file on the other device.

**BP-I49 · Pi backup (½ day, Pi Track).** `rclone` remote for the same Google
account (its own OAuth, on the Pi, read-only scope) mirroring `Manic MP/` to
`library/saves/manic-mp/` nightly with 30 days of versions; a line in the
magic-mirror README. Satisfies BP-R16's backup half.

## 4. Open questions for the operator

1. Google account for the Drive folder: BP-D17 recorded `globoaims@gmail.com`
   on 2026-09-16. Confirm before the Cloud project is created there.
2. Lease behaviour when the other device shows as playing: default to
   "cancel" (this note) or "take over"?
3. Phase 2 timing: after Phase 1 is played, or never (memory cards may be all
   that matters)?

## 5. Risks and gotchas

- **Read-only scope.** The one that will bite first: uploads 403 until the
  connector's scope is changed (§1). Test the very first upload by hand.
- **`drive.file` and a second client id.** Files are visible only to the
  client id that created them. If the client id ever changes (new Cloud
  project), the old folder becomes invisible to the app; `history/` on the
  old folder is still reachable through the Drive web UI. Keep the project.
- **Testing-mode expiry.** Unpublished consent screen = weekly re-login on
  both devices. Publish it (D23).
- **Crash mid-play.** No push happens; the lease stays. The next launch on the
  same device pushes (local differs from last pulled) and clears the lease.
  On the other device the lease prompt shows the stale "playing since".
- **Time skew.** No decision depends on device clocks; md5 and the recorded
  last-pulled md5 decide. Timestamps are display only.
- **7-day re-sign.** A reinstall over the same bundle id keeps Documents, so
  the card and the token survive (BP-R15). A *fresh* install pulls the card on
  the first Dolphin boot and needs one sign-in.
- **CloudServiceKit download API.** `downloadableRequest` returns a URL
  request; the download itself is a `URLSession` task the fork owns. Progress
  UI is ours.
- **Large cards.** A `.gci` is at most 16 Mbit (2 MB); Animal Crossing's is
  well under 1 MB. Multipart `uploadData` would do, but `uploadFile`
  (resumable) is used throughout for one code path.

## 6. Out of scope

Dropbox, OneDrive, WebDAV and the Pi as sync backend (BP-D17); save states
for non-Dolphin cores; syncing game files; multi-user sharing of one Drive
folder (the visit flow, BP-D13, is a different mechanism); the App Store
build (`isMember`-gated iCloud stays as upstream ships it).

## 7. Test log

*(empty until BP-I47 runs)*
