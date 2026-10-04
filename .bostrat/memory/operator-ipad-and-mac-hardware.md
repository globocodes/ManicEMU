---
name: operator-ipad-and-mac-hardware
description: Operator's iPad is an iPad Air 11-inch (M4) on iPadOS 26.5.2 (TXM JIT class, keep off 26.6/27 until JIT proven); an Apple Silicon Mac is available for Xcode
metadata:
  type: user
  modified: 2026-09-14T09:30:00Z
  scope: operator
  provenance: operator answer on a Phase 0 chat card + Settings screenshot, Track 5bd24936 (magic-mirror), 2026-09-14
  supersedes: null
---

The operator's iPad (tailnet name `ipad168`) is an **iPad Air 11-inch (M4)** on **iPadOS 26.5.2**
(Settings screenshot, 2026-09-14). M4 = TXM class: iOS 26 JIT needs StikDebug ≥ 2.3 plus a per-app
page-marking handshake; iOS 27 JIT on M-series was unverified as of DolphiniOS 5.0.0b6 (2026-06).
An Apple Silicon Mac (tailnet `joeys-macbook-air`) is available for Xcode 16+ builds.

**Why:** every iOS emulator/JIT question for this operator turns on the chip class and exact iOS build.
**How to apply:** treat the iPad as TXM; advise staying on 26.5.2 until JIT is confirmed working. See [[gve-ghost-valley-enterprises]] for the operator's studio context.
