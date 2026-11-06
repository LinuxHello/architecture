---
type: spike
subject: Camera streams RGB and IR at the same time
artifact: spike
status: open
owner: "@atterdag"
concepts: [camera, v4l2, ir-camera, face, enrolment]
tags: [spike, m0]
sources: []
date: 2026-11-06
issue: https://github.com/LinuxHello/linux-hello/issues/12
---

# Spike: Camera streams RGB and IR at the same time

## Question

Can a typical Windows Hello-class IR camera stream its RGB and IR sensors at the same time on Linux?

## Time box

Proposed: 2 working days. Stop at the time box and record what is known.

## Method

Enumerate V4L2 devices and formats on at least two IR camera models; try concurrent capture; record kernel and driver versions.

Nothing has been run for this note yet. Mark each command and script tested or untested, with versions and hardware class, when the spike is run.

## Blocks

The face enrolment wizard shows the RGB feed while Howdy captures IR. Blocks the face enrolment wizard design.

## Evidence

None yet. The spike is open.

## Answer

Open. Fill in Yes / No / Partly here, and link the ADR or issue the answer changes.
