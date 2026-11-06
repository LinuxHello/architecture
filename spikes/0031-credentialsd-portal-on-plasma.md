---
type: spike
subject: credentialsd with the patched portal and its GTK backend on Plasma
artifact: spike
status: open
owner: "@atterdag"
concepts: [credentialsd, xdg-desktop-portal, plasma, webauthn]
tags: [spike, m0, upstream]
sources: []
date: 2026-11-06
issue: https://github.com/LinuxHello/linux-hello/issues/31
---

# Spike: credentialsd with the patched portal and its GTK backend on Plasma

## Question

Does credentialsd v0.3.1, built with the patched xdg-desktop-portal (`credentials-portal` branch), serve a WebAuthn create/get from a test client on KDE Plasma, using the GTK `credentialsd-ui` backend?

## Time box

Proposed: 2 working days.

## Method

Build credentialsd and the patched portal in a disposable environment (container or VM, not the host session); register the portal; drive one create and one get with `demo_client`; record what the GTK UI does under Plasma. Follows up [spike 0005](0005-credentialsd-provider-api.md), which answered from source only.

Nothing has been run for this note yet. Mark each command and script tested or untested, with versions and hardware class, when the spike is run.

## Blocks

Decides whether the portal path works on Plasma at all before a KDE backend is designed. Blocks the KDE portal backend design and end-to-end tests for any provider.

## Evidence

None yet. The spike is open.

## Answer

Open. Fill in Yes / No / Partly here, and link the ADR or issue the answer changes.
