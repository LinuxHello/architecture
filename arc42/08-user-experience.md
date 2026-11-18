---
type: architecture
subject: "Arc42 section 8, user experience: what the user sees at every sign-in prompt, how methods are set up, and why Linux Hello needs its own channel for the prompt's state"
artifact: arc42-08-user-experience
status: active
owner: "@atterdag"
concepts: [user-experience, prompts, enrolment, pin, arc42]
tags: [architecture, arc42, ux]
sources: ["08-crosscutting-concepts.md", "12-glossary.md", "../adr/0003-destructive-reset.md", "../adr/0014-agent-bus.md", "../adr/0015-face-capture-and-enrolment.md", "../adr/0016-prompt-hosts.md", "../adr/0023-pam-module-and-login-failure.md", "../spikes/0007-pam-dbus-method-state.md", "../spikes/0008-howdy-interface.md", "../spikes/0009-plasma-prompt-component.md", "../spikes/0010-kcm-users-extension-point.md", "../spikes/0012-camera-rgb-ir-concurrent.md"]
date: 2026-11-17
---

# 8. Crosscutting concepts: user experience

Part of [section 8](08-crosscutting-concepts.md) of the [Arc42 architecture documentation](README.md).

This note answers the question: what does the user see when Linux Hello asks who they are, and how do they set it up? Windows Hello is used by ordinary people and by companies because it is clear: the user always sees which method is running, can switch to another, and sets up a face or a fingerprint in a guided window. That sets the bar for Linux Hello. The note lists the requirements, explains the design they force, and says what is built. Terms that may be new to you are in the [glossary](12-glossary.md).

## Requirements

The requirements are numbered UX1 to UX8 so that other notes can refer to them. "Where" names the screens the requirement applies to: the login screen (SDDM), the lock screen, and the Prompt UI, the window that asks the user to confirm a passkey during a session.

| Id | Requirement | Where |
| :-- | :-- | :-- |
| UX1 | The user always sees which method is active: the face (the camera is scanning), the fingerprint (touch the sensor) or the PIN (the field has focus). | Every prompt |
| UX2 | The user can switch to another method at any prompt ("Sign-in options"), and the PIN is always offered. | Every prompt |
| UX3 | Face and fingerprint run at the same time, and the first match wins. The user never waits for one method to time out before the next starts. | Every prompt |
| UX4 | Failures are explained ("Face not recognised: try again or use the PIN"), and so is a lockout ("PIN locked for 15 min"). | Every prompt |
| UX5 | The prompt looks and behaves the same on the login screen, the lock screen and in the Prompt UI. | SDDM, lock screen, Prompt UI |
| UX6 | Face setup is guided: a camera picture, guided capture, an immediate recognition test, and a way to record again or delete. | System Settings |
| UX7 | Fingerprint setup reuses KDE's own fingerprint window on its Users settings page, linked from Linux Hello's settings. | System Settings |
| UX8 | The first-run setup asks for the PIN first, because it is the root of trust, then offers face and fingerprint. | The setup wizard |

Two of these cannot be met everywhere in version 1.0. UX3 holds at the login screen, for `sudo` and on the console, where one PAM conversation runs every method, but not on the Plasma 6.8 lock screen, where KDE runs a separate service for each method ([ADR-0016](../adr/0016-prompt-hosts.md)). UX6 is without a live camera picture in 1.0, as explained below.

## The design these requirements force

PAM, the framework through which a login screen asks "is this the right person?", talks to the screen only in text: it can send a line to show and receive what the user types. A login screen therefore cannot tell from PAM which method is running, and cannot show a fingerprint symbol at the right moment (UX1). Stacking the existing fingerprint and face modules one after the other would also make the user wait for one to time out before the next starts, which breaks UX3.

So Linux Hello adds a second channel beside PAM. The PAM module only opens a *prompt*, the Agent's record of one sign-in attempt, and hands the conversation to the Agent ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)). The Agent runs fprintd and Howdy at the same time and reports the live state on D-Bus with signals:

- `MethodsAvailable`: which methods this prompt offers;
- `ActiveMethods`: which are running now;
- `State` and `Result`: progress and the outcome, with a reason such as "too dark" and, for a lockout, the seconds to wait;
- `Closed`: the prompt ended, so the screen can remove its indicator.

The login screen and the Prompt UI draw from that state through one shared QML component, the *Auth Prompt*, which is why they look alike (UX5). Every prompt has an identifier that the PAM module and the screen work out independently, because PAM's text channel cannot carry it. The Agent sends the state only to the user the prompt belongs to, by method reply or by a signal addressed to that user, never broadcast to everyone ([ADR-0014](../adr/0014-agent-bus.md)). The lock screen on Plasma 6.8 and later shows the text of KDE's own face and fingerprint services instead ([ADR-0016](../adr/0016-prompt-hosts.md)).

*State:* the Agent's calls for opening and following a prompt, and the signals `MethodsAvailable`, `ActiveMethod`, `State`, `Result` and `Closed`, are built and tested. The amendment of [ADR-0014](../adr/0014-agent-bus.md) of 2026-11-17 decided that `ActiveMethod` becomes the list `ActiveMethods` and that `Result` carries a reason and a waiting time; that change is not built yet. Running the methods, the PAM module and the Auth Prompt are not built.

## Setting up the methods

### The face: guided text, no live picture in 1.0

Howdy, the face-recognition program, gives no camera picture and no information about where it found a face ([spike 0008](../spikes/0008-howdy-interface.md)). In version 1.0 the face setup therefore shows guided text and the result of an immediate recognition test, not a live picture ([ADR-0015](../adr/0015-face-capture-and-enrolment.md)). While Howdy records, only Howdy holds the infrared camera.

A live picture is the target for a later version, as on Windows Hello. If it is built, these rules apply:

- The guidance ("face found", "too close", "turn slightly", "captured") comes from what the infrared sensor detects, never from the colour picture, so it reflects what is actually recorded. That needs detection results Howdy does not give; getting them means a change in Howdy or a component of Linux Hello's own, each a new ADR.
- The colour picture is only shown: never stored and never passed to Howdy.
- The camera has one owner at a time. The test camera, a Logitech BRIO, starts its colour and infrared streams together only in some orders ([spike 0012](../spikes/0012-camera-rgb-ir-concurrent.md)), so while Howdy records it alone holds the infrared stream.
- A computer without a colour camera shows the infrared picture in grey.
- If both streams cannot be held, the window falls back to no live picture or to the infrared picture. Only one camera model has been tested; a second is needed.

### One place for the sign-in methods

KDE's System Settings has a Users page, where fingerprint setup already lives. Ideally face and PIN would sit next to it, but that page offers no way for another program to add entries ([spike 0010](../spikes/0010-kcm-users-extension-point.md)). So Linux Hello has its own settings page, placed next to Users in System Settings, with face, PIN and a link to KDE's fingerprint setup, which stays unchanged on the Users page. Entries on the Users page itself would need a change in KDE that is not planned.

### Changing the PIN

The same settings page has a "Change PIN" entry:

- The user types the current PIN, then the new one twice. The TPM changes the root key's authorisation in place, so every passkey survives.
- The PIN rules, such as the minimum length or whether letters are allowed, are shown before the user types and checked while they type.
- "I forgot my PIN" leads to the reset, with a clear warning that the passkeys kept in the TPM will be deleted ([ADR-0003](../adr/0003-destructive-reset.md), [trust chain](08-trust-chain.md)).
- A lockout is shown ("PIN locked for 15 min"). It comes from the Agent's own count of wrong PINs per user, which stops a user before the TPM's shared counter is reached.

*State:* none of the settings pages, the setup wizard or the face setup is built.

## How the model changed

The requirements added several components to the C4 model: the Method Orchestrator and the Auth State Publisher in the Agent, the Agent Client in the PAM module, and the Auth Prompt, the Face Enrolment Module and the SDDM theme in the Plasma integration. [Section 5](05-building-block-view.md) describes each of them. Howdy's commands, the camera and KDE's fingerprint window became outside dependencies in [workspace.dsl](../workspace.dsl). The Method Orchestrator first sat in the PAM module and moved to the Agent with [ADR-0023](../adr/0023-pam-module-and-login-failure.md), so that the module loaded into the login screen stays small.
