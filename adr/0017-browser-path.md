---
type: adr
subject: Browsers reach Linux Hello as a USB security key in 1.0; the own extension is deferred
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [webauthn, browser, virtual-ctap, extension]
tags: [adr, browser]
sources: ["0005-provider-path.md", "0013-browser-fallback.md", "../spikes/0094-virtual-ctap-end-to-end.md", "../spikes/0006-browser-webauthn-portal.md", "../spikes/0033-own-extension-origin-and-confined-native-messaging.md"]
date: 2026-11-08
---

# ADR-0017: Browser path for 1.0, after ADR-0005 option B

## Status

Accepted, 2026-11-08, on the maintainer's decision the same day (proposed 2026-11-08). Supersedes [ADR-0013](0013-browser-fallback.md), which is still proposed.

## Context

[ADR-0013](0013-browser-fallback.md) chose an own web extension and native-messaging host in front of the broker, because no stock browser calls the credentials portal ([spike 0006](../spikes/0006-browser-webauthn-portal.md)) and ADR-0005 then gave Linux Hello its own broker (option D). [ADR-0005](0005-provider-path.md) was revised to option B, a virtual CTAP authenticator, so the broker is a USB security key as far as a browser can tell.

[Spike 0094](../spikes/0094-virtual-ctap-end-to-end.md) tried that on a software TPM with Chromium 156 and Firefox 157 (Playwright builds): both created and used a TPM-backed credential on a local page, in about a second, without any extension. Both report `authenticatorAttachment` = `cross-platform`. Discoverable credentials, user verification and presence prompts are not built; Firefox refused a resident-key request and Chromium waited. Distribution packages (Snap, Flatpak), Chrome stable and a real relying party were not tried.

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. The virtual CTAP authenticator alone** for 1.0 | Works with stock browsers, no extension, no store listings, no origin logic of ours (the browser checks the origin) | Roaming-key presentation; needs resident keys, user verification and presence prompts built; confined browsers need hidraw access, untested |
| B. A: and the own extension and native-messaging host of ADR-0013 | Closer to a platform authenticator; origin chain under our control | Two containers, two store listings, the browser-side WebAuthn checks reimplemented; needed only if A fails real sites |
| C. KeePassXC-Browser only | Released; any site | No TPM custody and no routing policy, and it bypasses the unlock gate |

## Decision

**Option A for 1.0.** Linux Hello does not ship a browser extension or native-messaging host in 1.0. The Virtual CTAP Authenticator ([workspace.dsl](../workspace.dsl)) is the browser path, and design rule 4 in [section 4](../arc42/04-solution-strategy.md#design-rules) already says so.

1. **Build before release** (each needs a security property and a test named after it): resident keys through the Credential Index, `getInfo` options for user verification, a presence and verification prompt for every request through the Prompt UI (nothing signs without one), one signature per request even when a browser asks twice.
2. **Verify before release:** Chrome stable and the distribution Firefox, including Snap and Flatpak access to `hidraw`; a real relying party; a hardware TPM.
3. **Revisit option B** only if (2) shows real sites that need a platform authenticator or fail on a roaming key. It then returns as a new ADR with the origin chain of ADR-0013.
4. **KeePassXC-Browser:** both it and Linux Hello can answer a WebAuthn request. The install documentation must say which to use for which keys; the interaction was not tested.

## Consequences

**Easier:** no extension to build, sign or list; the browser keeps doing the origin and secure-context checks; the same path serves native apps that use CTAP over HID.

**Harder:**

- Sites that require a platform authenticator, or treat a USB key differently, are out of reach until option B or a platform-authenticator path exists.
- The presence and verification prompt is now security-critical: without it, any local process that can open the HID device obtains signatures ([spike 0094](../spikes/0094-virtual-ctap-end-to-end.md)).
- Confined browsers (Snap, Flatpak) may block `hidraw`; [spike 0033](../spikes/0033-own-extension-origin-and-confined-native-messaging.md) concerned native messaging and does not answer this.
- ADR-0013's follow-ups (extension and host containers in the model) are dropped; [section 5](../arc42/05-building-block-view.md) already says the extension is not modelled.
