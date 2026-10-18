---
name: repo-naming-convention
description: All new repos are named in lowercase kebab-case (closing-bell, not ClosingBell)
metadata:
  type: feedback
  modified: 2026-10-08T23:20:00Z
  scope: operator
  provenance: operator instruction in Track ca55e2b9 (ClosingBell), 2026-10-08
  supersedes: null
---

New repositories are named in lowercase kebab-case: `closing-bell`, never `ClosingBell` or `closingbell`. The product name inside the repo (README title, app name, circuit name) can keep its own casing; only the repo slug follows this rule.

**Why:** the operator renamed the first ClosingBell repo from `ClosingBell` to `closing-bell` on 2026-10-08 and asked that this be the convention for every repo going forward.

**How to apply:** when running `gh repo create` or proposing a repo name, use lowercase words joined by hyphens. If a Fly app or package needs the same name, derive it from the kebab slug (Fly app names allow hyphens). See [[closingbell-project]].
