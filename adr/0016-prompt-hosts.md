---
type: adr
subject: One shared prompt module; the lock screen uses the stock Face and Fingerprint services, SDDM gets an own theme
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [plasma, sddm, kscreenlocker, qml, prompt]
tags: [adr, plasma, ux]
sources: ["../spikes/0009-plasma-prompt-component.md", "../spikes/0007-pam-dbus-method-state.md", "0014-agent-bus.md", "../arc42/08-crosscutting-concepts.md"]
date: 2026-11-08
---

# ADR-0016: Where the authentication prompt is shown

## Status

Proposed, 2026-11-08.

## Context

UX1 to UX5 want the login manager, the lock screen and in-session prompts to look the same and to show the active method. [Spike 0009](../spikes/0009-plasma-prompt-component.md), read at Plasma 6.8.2 and SDDM `develop`, found that neither login manager nor lock screen has a slot for a third-party prompt:

- **SDDM** loads a whole theme directory and has no theme inheritance; a theme can import any QML module on the greeter's path.
- **The Plasma Login Manager** (new in 6.8, a fork of SDDM) compiles its greeter QML in and has no theme hook.
- **The lock screen** in 6.8.2 is `lockscreen/LockScreen.qml` in the shell package named by `ShellPackage`, which also selects plasmashell's shell. From 6.8 it lists Password, Smartcard, Fingerprint, Face and Universal 2 Factor as PAM services `kde`, `kde-smartcard`, `kde-fingerprint`, `kde-face`, `kde-u2f` and shows their PAM info and error text. Plasma 6.6.x, which Ubuntu 26.04 ships, has only `kde`, `kde-fingerprint` and `kde-smartcard`.
- **One QML module** in the system QML directory can be imported by all hosts, as `org.kde.breeze.components` already is. The page around it differs per host.
- A prompt can only see method state over the **system bus** ([ADR-0014](0014-agent-bus.md)).

| Option for the lock screen | Pros | Cons |
| :-- | :-- | :-- |
| **A. Stock services**: configure the `kde-face` and `kde-fingerprint` services (Plasma 6.8 and later) and show their PAM text | No QML of ours, no fork; works with what KDE ships | Text only, no live camera state; one method per service, not the parallel face, fingerprint and PIN of UX3; not on 6.6 |
| B. Fork of `org.kde.plasma.desktop` limited to `lockscreen/` | Our component on the lock screen | Replaces what plasmashell loads when the same key is used; tracks Plasma releases |
| C. Propose a method-state slot in `LockScreenUi.qml` upstream | The clean end state | Needs KDE's agreement and a release; nothing to ship until then |

| Option for the login manager | Pros | Cons |
| :-- | :-- | :-- |
| **D. Own SDDM theme package** (a Breeze fork) importing the shared module | Works today in SDDM | We own a theme and follow Breeze |
| E. An upstream patch to SDDM or the Plasma Login Manager | No fork | The Plasma Login Manager has no theme hook, so only this works there; needs upstream |

## Decision

1. **One shared QML module**, `Auth Prompt QML Component`, installed in the system QML directory with its URI under the ADR-0012 prefix. Every host imports it; it reads state from the Agent on the system bus ([ADR-0014](0014-agent-bus.md)).
2. **Lock screen: option A on Plasma 6.8 and later**, with C proposed upstream once the first release shows what is missing. On Plasma 6.6.x the lock screen runs the face, fingerprint and PIN methods inside the `kde` service through `pam_linuxhello`, text only. Option B is not adopted.
3. **SDDM: option D.** The Plasma Login Manager is supported only after an upstream change (option E) and is not part of 1.0.
4. **In-session Prompt UI:** the shared module in a Linux Hello window outside the calling app.

The parallel-methods rule of UX3 therefore holds at SDDM, `sudo` and the console, where one PAM conversation runs all methods, and not on the 6.8 lock screen, where KDE already runs separate PAM services. [Spike 0007](../spikes/0007-pam-dbus-method-state.md) noted the clash; this ADR resolves it in favour of KDE's services at the lock screen.

## Consequences

**Easier:** no shell-package fork; a small shared component; the lock screen follows KDE's own method list.

**Harder:**

- UX2 and UX4 text at the lock screen is whatever the PAM services print; there is no live camera state there.
- Face on the lock screen needs Plasma 6.8; on 6.6.x it is text inside the password service.
- We own an SDDM theme and follow Breeze changes.
- Not verified (spike 0009): whether the `sddm` greeter has a session bus, how the Plasma Login Manager sets up its bus and PAM, and addressed signal delivery to one peer.
- [Section 5](../arc42/05-building-block-view.md) and [workspace.dsl](../workspace.dsl) name `SDDM Theme` and `Lock Screen Shell Package`; once this is accepted the second becomes "stock services, no package" and the component is removed.
