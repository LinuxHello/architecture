---
type: spike
subject: Third-party prompt in the Plasma login manager and kscreenlocker
artifact: spike
status: open
owner: "@atterdag"
concepts: [plasma, sddm, kscreenlocker, qml, ux]
tags: [spike, m0, upstream]
sources: []
date: 2026-11-06
issue: https://github.com/LinuxHello/linux-hello/issues/9
---

# Spike: Third-party prompt in the Plasma login manager and kscreenlocker

## Question

How do the Plasma login manager and kscreenlocker accept a third-party prompt component, and can one component look identical in both and in-session?

## Time box

Proposed: 2 working days. Stop at the time box and record what is known.

## Method

Read the greeter and kscreenlocker QML and plugin loading at the current Plasma release; build a minimal component that subscribes to the Agent's method-state signals. Builds on [spike 0007](0007-pam-dbus-method-state.md), which settled which bus each context can reach.

Nothing has been run for this note yet. Mark each command and script tested or untested, with versions and hardware class, when the spike is run.

## Blocks

The login manager, lock screen and in-session prompts must look identical and show the active method. Blocks the Plasma prompt component and UX2.

## Evidence

None yet. The spike is open.

## Answer

Open. Fill in Yes / No / Partly here, and link the ADR or issue the answer changes.
