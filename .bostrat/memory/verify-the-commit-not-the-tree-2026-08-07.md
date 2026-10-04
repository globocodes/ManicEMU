---
name: verify-the-commit-not-the-tree-2026-08-07
description: "The red-signal convention (reintroduce the defect, confirm the test goes red) rewrites source files in place — and a cp-restore dance can leave a correct working tree but stage the pre-change original. Verify `git show HEAD:<file>`, not the tree, before pushing."
metadata:
  node_type: memory
  type: feedback
  modified: 2026-08-07T00:00:00.000Z
  scope: operator
  provenance:
    node: pi
    trust: operator-dogfood
  supersedes:
---

**After an experiment that rewrites source files in place, verify the COMMIT, not the working tree.**
`git status` showing a file as modified is not confirmation that the modification you want is the one
staged.

**How it bit (PR #482, 2026-08-07).** The repo's own convention is that a regression test which has
never failed proves nothing ([[event-ts-is-epoch-ms-2026-08-06]]), so the peer-message test was
validated by reintroducing the defect: `cp src/turn-ingest.js /tmp/ti.bak` → `perl -0pi` the defect in
→ run (13 assertions red, correct) → `cp /tmp/ti.bak src/turn-ingest.js`. Run twice, restored both
times, and the test passed green after each restore.

The commit then staged the **pre-change original** of that one file — no import, no `stateFor` reseed
branch, no ingest branch — while the other eight files landed intact. So CI ran the new
`peer.message` event type against ingestion that never emitted it: peer bubbles fell through to
`turn.user` exactly as before, and CI reproduced *precisely* the 13-assertion signature the
deliberate defect had produced locally.

**Why every local check missed it.** Standalone run, full suite, Node 22 *and* Node 24, and a
post-merge run against `origin/main` — all green, because every one of them reads the **working tree**,
which was correct the whole time. The bug existed only in the index. Re-running tests harder was
never going to find it, and about twenty minutes went into chasing environment differences (node
version, clean HOME, aarch64 vs x86, a stale branch, a merge interaction) before checking the one
thing that actually differed: what got committed.

**The check that finds it, in one line:**

```sh
git diff HEAD --stat          # empty = tree and commit agree
git show HEAD:path/to/file | grep -c <the-symbol-you-added>
```

**Diagnosis notes worth keeping.** A failure signature *identical* to a deliberate
defect-reintroduction is strong evidence the change isn't running at all — read it as "my code is
absent," not "my code is wrong," and check delivery before logic. And when a captured CI log is
truncated (the log handed over covered only the alphabetical tail, and the failing file runs early),
`gh run view <id> --log-failed` gets the real thing rather than guessing from a fragment.

Related: [[cross-session-messaging-2026-08-07]] is the change this happened to.
