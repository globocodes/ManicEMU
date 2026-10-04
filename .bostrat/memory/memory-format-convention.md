---
name: memory-format-convention
description: "Fact-file frontmatter convention (fleet-memory M0.5, 2026-07-31): every fact carries modified/scope/provenance/supersedes in metadata"
metadata: 
  node_type: memory
  type: reference
  modified: 2026-08-01T01:03:58.029Z
  scope: operator
  provenance: 
    node: pi
    trust: operator-dogfood
  originSessionId: e09cc838-ef9a-45a0-9db2-4adae879751b
---

Per the fleet-memory epic M0.5 (`docs/fleet-memory-epic.md` §4, backfilled 2026-07-31), every memory fact file carries four fields inside `metadata:` in addition to the existing `type`/`originSessionId`:

- **`modified`** — ISO-8601 timestamp of the last content change. Matches Claude Code's native stamping (v2.1.214+). Used for per-fact last-write-wins conflict resolution and staleness signalling. Update it whenever you edit a fact.
- **`scope`** — `operator` (personal/feedback facts, follows the person) or `repo:<slug>` (project facts, follows the repo — e.g. `repo:bostrat`, `repo:globo-pi`, `repo:misous`). Mechanical mapping from `type`: `user`/`feedback` → `operator`; `project`/`reference` → `repo:<slug>`.
- **`provenance`** — where the fact came from: `node` (machine), `trackId`/`originKey` (for facts migrated from orphaned managed-clone memory keys at M0), `trust` class (`operator-dogfood` for everything authored in operator sessions; facts derived from untrusted web/PR content must carry a lower trust class and are not promoted to `operator` scope without review). `metadata.originSessionId`, where present, is the sessionId component.
- **`supersedes`** — slug of a fact this one replaces (expire-don't-delete; keeps correction history). Empty for most facts.

**How to apply:** stamp all four on every NEW fact; bump `modified` on every edit; when correcting a wrong fact, prefer writing the corrected fact with `supersedes: <old-slug>` (or append a dated correction to the same file for minor updates). The 11 facts recovered from orphaned workspace memory keys on 2026-07-31 carry their source key in `provenance.originKey`.
