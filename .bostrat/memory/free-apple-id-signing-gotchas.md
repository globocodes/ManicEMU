---
name: free-apple-id-signing-gotchas
description: What a free Apple ID (Personal Team) refuses when dev-signing an iOS app from Xcode, and how to read the real team id
metadata:
  modified: 2026-09-16T22:30:00Z
  scope: operator
  provenance: magic-mirror Track phase-a-3d360944, first Mac build of the globocodes/ManicEMU fork (fork commits f9096b7, 6a6d8fa)
  supersedes: none
---

Personal Teams are refused more than iCloud/push/App Groups: Xcode also rejects
**Extended Virtual Addressing** and **In-App Purchase**. In-App Purchase is not an
entitlement: Xcode infers it from an explicit `StoreKit.framework` entry in the
target's Link Binary phase, so remove that entry (Swift auto-links StoreKit).
Increased Memory Limit is accepted. Embedded framework targets that hard-code
another team must skip signing (`CODE_SIGNING_ALLOWED = NO`; CodeSignOnCopy
re-signs them).

The team id is the `OU=` of the "Apple Development" certificate, or `teamID` in
`defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`. It is NOT the
parenthetical after the name on the identity line, and grepping a pbxproj diff
returns the removed upstream id first.

**How to apply:** when preparing any fork for free-Apple-ID sideloading, strip
these up front and give the operator the `defaults read` command for the team id.
Related: [[manic-emu-fork-sideload-accepted]], [[operator-ipad-and-mac-hardware]].
