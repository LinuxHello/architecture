---
type: spike
subject: Howdy interface for live preview, enrolment and test
artifact: spike
status: open
owner: "@atterdag"
concepts: [howdy, face, ir-camera, pam, enrolment]
tags: [spike, m0, upstream]
sources: []
date: 2026-11-06
issue: https://github.com/LinuxHello/linux-hello/issues/8
---

# Spike: Howdy interface for live preview, enrolment and test

## Question

Does Howdy expose a library, D-Bus or CLI interface that supports live preview, enrolment and a test match without going through PAM?

## Time box

Proposed: 2 working days. Stop at the time box and record what is known.

## Method

Read Howdy's source at the current release; list entry points; check its licence (MIT expected, unverified; see [spike 0013](0013-upstream-licences.md)); test each entry point with an IR camera.

Nothing has been run for this note yet. Mark each command and script tested or untested, with versions and hardware class, when the spike is run.

## Blocks

The face enrolment wizard needs the IR detection results and a preview. The PAM module needs a match call it can run in parallel with fprintd. Blocks the face enrolment wizard and the parallel face method in `pam-linuxhello`.

## Evidence

None yet. The spike is open.

## Answer

Open. Fill in Yes / No / Partly here, and link the ADR or issue the answer changes.
