---
name: end-of-turn-summary-required
description: Every turn's LAST message must carry a standalone recap of what happened; a ship/offer card line alone is not a closing message
metadata:
  type: feedback
  modified: 2026-09-14T10:30:00Z
  scope: operator
  provenance: operator correction in Track 5bd24936 (magic-mirror), 2026-09-14
  supersedes: null
---

The operator reads only the final message of a turn. Ending a turn with just the ship-offer sentence
("Want me to commit and push this, or open a PR?") after a recap that was written *before* the
`bostrat-ship offer` / `bostrat-followup offer` call leaves them with no context.

**Why:** the operator said: "you aren't giving me any context at the end of turns … I need summaries to know what has happened." Text emitted before a tool call is not what they see last.

**How to apply:** run the offer/followup CLI first, then write ONE final message that (1) recaps what was found, done, and verified, (2) says what is pending and whose move it is, and (3) ends with the explicit ship-offer sentence as its own last line. Never end a turn with the offer sentence alone. Same for runbook/blueprint/followup cards: name them in the recap. See [[no-claude-artifacts-unless-asked]] for the other delivery rule.
