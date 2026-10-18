---
name: bostrat-video-mocks-served-from-s3
description: Video mocks in the Bostrat chat are NOT served by the plane itself — /plane/content/mocks/<id>/blob?kind=mp4 answers 302 to a 1-hour presigned URL on bostrat-plane-backups.s3.us-east-2.amazonaws.com, while image mocks and posters come back inline (200) from plane.bostrat.ai; a network that filters *.amazonaws.com (corporate VPN / secure web gateway) shows the poster but never plays the video
metadata:
  modified: 2026-10-15T17:40:00Z
  scope: operator
  provenance: observed in Track chat-feature-rework subtask b4e78c06 (closing-bell) while diagnosing "can't view the video mock over VPN" for mock 072793bf; verified with curl against plane.bostrat.ai /v1/content using the node token and against the presigned S3 URL from the Pi
  supersedes: null
---

How the Bostrat chat loads a mock, as of plane bundle `index-BHf2Lo70.js` (2026-10-15):

- The node pushes every mock version to the plane as content blobs (`/v1/content/mocks/<id>/blob?v=N&kind=png|mp4|webm|html`); the outbox in `~/.bostrat/content-outbox.json` is empty when delivery is done.
- The browser uses `/plane/content/mocks/<id>/blob?kind=<png|mp4>&v=N` (same origin, Clerk session cookie). `kind=png` is returned inline with a 200. `kind=mp4` is answered with **302 → `https://bostrat-plane-backups.s3.us-east-2.amazonaws.com/content-blobs/<user>/mocks/<id>/vN.mp4?X-Amz-…`** (SigV4 presigned, `X-Amz-Expires=3600`). S3 honours Range (206, `Accept-Ranges: bytes`), which iOS Safari requires.
- The chat bubble shows only the poster `<img>` plus a ▶; the `<video src controls playsInline preload=metadata>` lives in the lightbox, with an "Open ↗" link to the same URL. Tapping Open ↗ is the one-tap diagnostic: it lands on the amazonaws.com URL and shows whatever the network does to it (block page / timeout = the VPN or filter is the cause).
- From the Pi (home egress, Pi-hole DNS) the whole chain works, so a Tailscale exit node through globo-pi is a working path; Pi-hole has no amazonaws block. A video that fails only "over VPN" while posters load is the S3 hop being filtered, not the file (072793bf is H.264 High yuv420p faststart, 2.3 MB).
- If a video must reach a filtered network, the source file is on the node at `~/.bostrat/workspaces/<track>/.bostrat/mocks/<id>.vN.mp4` (see [[ipad-video-files-via-manic-container]] for a sideload path).
