---
type: adr
subject: Face enrolment and matching call Howdy as it is; a live preview is not part of 1.0
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [howdy, face, enrolment, preview, camera]
tags: [adr, face]
sources: ["../spikes/0008-howdy-interface.md", "../spikes/0012-camera-rgb-ir-concurrent.md", "../arc42/08-crosscutting-concepts.md", "../arc42/02-constraints.md"]
date: 2026-11-08
---

# ADR-0015: Face capture, enrolment and preview

## Status

Accepted, 2026-11-08, on the maintainer's decision the same day (proposed 2026-11-08).

## Context

The enrolment wizard (UX6, UX6a in [section 8](../arc42/08-crosscutting-concepts.md#user-experience)) shows a live camera preview with a guidance overlay driven by IR face detection, then captures and tests. [Spike 0008](../spikes/0008-howdy-interface.md) read Howdy v2.6.1 (MIT) and its unreleased 3.0 beta and found:

- **Match** works without PAM as a subprocess: `compare.py <user>` returns only an exit status.
- **Enrolment** works as a root-only CLI (`howdy add`) with text output, one encoding per model and no progress.
- **No preview and no detection results** are exposed to another process, in either version.

[Spike 0012](../spikes/0012-camera-rgb-ir-concurrent.md) found that RGB and IR streams start together unreliably on the Logitech BRIO (one camera tested).

Constraint C1 ([section 2](../arc42/02-constraints.md)) says reuse upstream and do not reimplement.

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. Call Howdy as it is** (`compare.py` and `howdy add` as subprocesses); the wizard shows status text, not a live preview | Reuses Howdy; smallest change; keeps C1 and C4; nothing to maintain beyond the subprocess contract | No preview or overlay (UX6a not met); text output must be parsed; the contract can change in Howdy 3.0 |
| B. A Linux Hello capture-and-detect component, writing Howdy's model format so `compare.py` keeps working | Full UX6a; our own progress and error reporting | Reimplements enrolment with dlib and OpenCV; depends on Howdy's model format, which only the code defines; needs a second owner of the camera; breaks C1 |
| C. Contribute a library or machine-readable interface to Howdy | Reuse with a preview; helps others | Depends on upstream review and a release; Howdy 3.0 is a beta with no date |
| D. Replace Howdy with our own face recognition | Full control | The largest scope; face recognition quality and liveness are then ours |

## Decision

**Option A for 1.0.** The Face Client calls `compare.py` as a subprocess and trusts only its exit status. The Face Enrolment Module calls `howdy add` and `howdy` management commands through a privileged helper owned by the Agent, because they need root. The wizard shows guided text and the result of an immediate recognition test, not a live preview.

- **Camera.** While Howdy captures, only Howdy holds the IR stream; the module does not open the camera. This avoids the RGB and IR start-order failure of spike 0012. An RGB-only preview without an overlay would add little and is not built.
- **Contract.** The subprocess contract (exit codes, the CLI arguments, the model directory) is written down in a test that runs against the pinned Howdy version, so a change shows up in CI and not in the field.
- **Later.** Option C is the route to a preview: open a Howdy issue or pull request for detection results once the first release has shown whether the missing preview matters. Option B is not planned. Either needs a new ADR that supersedes this one.

## Consequences

**Easier:** no face-recognition code of ours; Howdy updates come through the distribution; the camera has one owner at a time.

**Harder:**

- UX6a (RGB preview with IR-driven guidance) is not met in 1.0; [section 8](../arc42/08-crosscutting-concepts.md#user-experience) and the `Face Enrolment Module` and `Camera Stream Owner` components in [workspace.dsl](../workspace.dsl) must follow once accepted. The `Camera Stream Owner` stays only if a preview is built later.
- Howdy's model files, root-only CLI and absence of liveness checks are its properties, not ours; the security view of the face method rests on them.
- Not verified: running `compare.py` as a non-root user, the model file permissions, and the Howdy polkit policies (spike 0008).
