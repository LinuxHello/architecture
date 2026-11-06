---
type: index
subject: Index of Milestone 0 spikes
artifact: spike-index
status: active
owner: "@atterdag"
concepts: [spikes]
tags: [spike, m0, index]
sources: []
date: 2026-11-01
---

# Spikes

| Spike | Answer | Issue |
| :-- | :-- | :-- |
| [0005: credentialsd provider API and portal on KDE Plasma](0005-credentialsd-provider-api.md) | No, not at v0.3.1; see [ADR-0005](../adr/0005-provider-path.md) | [#5](https://github.com/LinuxHello/linux-hello/issues/5) |
| [0006: Browser WebAuthn through the portal (Firefox, Chromium)](0006-browser-webauthn-portal.md) | Partly: no stock browser calls the portal; only add-ons and an experimental Firefox build | [#6](https://github.com/LinuxHello/linux-hello/issues/6) |
| [0007: PAM module publishes method state over the Agent's D-Bus API](0007-pam-dbus-method-state.md) | Partly: only the system bus is reachable in every PAM context; the Agent must serve the PAM module there (needs an ADR) | [#7](https://github.com/LinuxHello/linux-hello/issues/7) |
| [0013: Licences of libwebauthn, KeePassXC, fprintd and Howdy](0013-upstream-licences.md) | Yes: all fit C2 and C3 | [#13](https://github.com/LinuxHello/linux-hello/issues/13) |

New spikes start from [the template](../templates/spike.md). See [index](../README.md).
