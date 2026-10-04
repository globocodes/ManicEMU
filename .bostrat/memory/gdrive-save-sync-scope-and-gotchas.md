---
name: gdrive-save-sync-scope-and-gotchas
description: Google Drive save sync for Manic MP scoped 2026-09-28 (fork docs + blueprint v21 Phase K); where the Multiplayer GameCube blueprint source lives; CloudServiceKit's Drive connector defaults to drive.readonly
metadata:
  type: project
  modified: 2026-09-28T00:00:00Z
  scope: repo:ManicEMU
  provenance: Track google-drive-integration-b5fb35ff, code read of upstream 1647190 + Daiuno/CloudServiceKit clone
  supersedes: null
---

Google Drive save sync (BP-D17/BP-I32) was scoped 2026-09-28 in the fork at `ManicEMU/docs/google-drive-save-sync-scoping-2026-09-28.md`; blueprint "Multiplayer GameCube on the iPad" v21 carries it as Phase K (BP-D21–D24, BP-I44–I49). Runbook e60a1c7d has the Google Cloud console steps. Nothing built yet; Swift work needs a Mac Track.

Gotchas not visible from the ManicEMU tree: the `Daiuno/CloudServiceKit` `GoogleDriveConnector.scope` defaults to `drive.readonly`, so uploads 403 until the fork sets `drive.file`; a Google consent screen left in Testing expires refresh tokens after 7 days. Dolphin's GCI folder (`Documents/Dolphin/User/GC/<region>/Card A/*.gci`) is shared across games and found by game id, so syncing it needs no library manifest. Upstream `FilesImporter` uploads every imported ROM to the cloud mirror (must be suppressed for Dolphin titles).

The blueprint's markdown source is magic-mirror `docs/blueprint-gamecube-on-the-ipad.md` (Pi checkout `~/Documents/globo-pi/magic-mirror`, main); the Bostrat show API returns items only, not markdown. The v21 text is saved at `~/incoming/bo-work/blueprint-gamecube-on-the-ipad-v21-2026-09-28.md` and still needs committing to magic-mirror from a magic-mirror Track.

**Why:** the next Track that picks up BP-I44+ should start from the scope, not re-derive it.
**How to apply:** read the scoping doc first; verify the read-only-scope fix landed before testing any upload. Related: [[manic-emu-fork-sideload-accepted]], [[operator-iphone-manic-fork]].
