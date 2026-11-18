---
type: architecture
subject: "Arc42 section 1: introduction and goals of Linux Hello"
artifact: arc42-01-introduction-and-goals
status: draft
owner: "@atterdag"
concepts: [credential-broker, passkeys, arc42]
tags: [architecture, arc42]
sources: ["README.md", "12-glossary.md", "../adr/0004-agent-roles.md", "../adr/0005-provider-path.md", "../adr/0020-presence-and-verification.md", "../adr/0023-pam-module-and-login-failure.md", "https://github.com/LinuxHello/linux-hello/blob/main/README.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/security/threat-model.md", "https://docs.arc42.org/section-1/"]
date: 2026-11-17
---

# 1. Introduction and goals

Part of the [Arc42 architecture documentation](README.md).

This section is the place to start. It says what Linux Hello is, which problem it solves, how far it has come, what matters most in its design, and who has a stake in it. The later sections assume you have read it. Terms that may be new to you are explained in the [glossary](12-glossary.md).

## 1.1 Linux Hello in five minutes

### The problem

Websites are moving from passwords to **passkeys**. A [passkey](12-glossary.md#passkey) is a key pair made for one website: the website keeps the public key, and the private key stays with the user and signs a challenge each time the user signs in. A passkey cannot be phished, and a leak of the website's database reveals no secret. To use one, the user proves to their own computer that they are there and that it is them, usually with a fingerprint, the face or a short PIN.

Something on the computer has to keep those private keys and ask for that proof. That something is called an [authenticator](12-glossary.md#authenticator). On Windows it is **Windows Hello**, which does three things:

1. It keeps keys in the [TPM](12-glossary.md#tpm-tpm-20), a chip in the computer that never lets a key be copied out.
2. It checks the user with the face, a fingerprint or a PIN, and that check only unlocks the use of the keys; it never hands them out.
3. It offers one system-wide service that every browser and app calls when a website wants a passkey.

Linux has the first two pieces, but not the third:

- **Keys in a chip:** most Linux machines have a TPM 2.0, and Linux can use it through the `tpm2-tss` libraries. Many systems already use it to unlock an encrypted disk.
- **Checking the user:** [fprintd](12-glossary.md#fprintd) reads fingerprint sensors and [Howdy](12-glossary.md#howdy) recognises faces with an infrared camera. Both work today for logging in to Linux, through [PAM](12-glossary.md#pam).
- **A service every app can call:** there is **none**. Each browser has its own passkey code and mostly talks only to a separate USB [security key](12-glossary.md#security-key). [KeePassXC](12-glossary.md#keepassxc), a password manager, can store passkeys, but it serves them only through its browser extension, so desktop apps cannot use them, and its keys are protected by a master password rather than by a chip.

The result is that a Linux user who wants passkeys either buys a USB security key or keeps passkeys in a password manager that only the browser can reach. Neither gives the "look at the camera and you are in" experience that Windows and macOS users have.

### What Linux Hello adds

Linux Hello is the missing third piece for the Linux desktop, starting with KDE Plasma. It is one service for the whole session, not a browser add-on:

- **One check, everywhere.** The same fingerprint, face or PIN signs the user in to the computer, unlocks the screen, confirms `sudo`, and confirms a passkey on a website or in an app.
- **The PIN is the root.** The PIN unlocks the user's keys in the TPM. Fingerprint and face are a quicker way to do the same, never a replacement for the PIN. The account password can only reset the PIN, and that reset deletes the keys ([trust chain](12-glossary.md#trust-chain)).
- **The owner chooses where keys live.** For each website, a policy decides whether its passkey is kept in the TPM, where it can never leave the machine ([device-bound](12-glossary.md#device-bound-key)), or in KeePassXC, where it can be synced to other machines ([portable](12-glossary.md#portable-key)). Banks and work accounts can be held to the TPM; an administrator can set the rules for everyone.
- **One look at every prompt.** The login screen, the lock screen and the passkey prompt show the same thing: which method is running, and how to switch to another.

### How it works, in one paragraph

Every browser already knows how to talk to a USB security key. Linux Hello therefore pretends to be one: it creates a security key in software, through the Linux [uhid](12-glossary.md#uhid) interface, and browsers and apps use it without any change ([ADR-0005](../adr/0005-provider-path.md)). Behind that virtual key, a central service, the [Agent](12-glossary.md#agent), decides whether a request is allowed, asks the user for a fingerprint, the face or the PIN, and has the key signed in the TPM or in KeePassXC. The browser shows Linux Hello as "a security key" and not as "this device", which is the price of needing no browser change. [Section 4](04-solution-strategy.md) explains this choice and the alternatives.

### What works today

Linux Hello is **pre-alpha: it does not sign anyone in yet.** Using the [status words](12-glossary.md#status-words) of these notes:

| State | What |
| :-- | :-- |
| Built and tested | The Agent as a system service, with its interface on the [D-Bus](12-glossary.md#d-bus) system bus, its bus policy, its [systemd](12-glossary.md#systemd-systemd-service) unit and its [AppArmor](12-glossary.md#apparmor) profile, checked under an enforcing profile on Ubuntu 24.04 and 26.04 ([section 7](07-deployment-view.md)). The routing policy engine. Each user's policy layer, kept by the Agent ([ADR-0018](../adr/0018-user-policy-layer.md)). |
| Proven in an experiment, not built | The virtual security key: it created and used TPM-backed passkeys with Chromium and Firefox in a test machine, in an experiment the project calls a [spike](12-glossary.md#spike) ([spike 0094](../spikes/0094-virtual-ctap-end-to-end.md)). |
| Decided, not built | The TPM provider, the KeePassXC provider, the PAM module, the prompt, the Plasma settings page and the login-screen theme. The [ADRs](12-glossary.md#adr) (architecture decision records) listed in [section 9](09-architecture-decisions.md) record how each is to work. |
| Open | The questions listed in [section 11](11-risks-and-technical-debt.md), such as how a fingerprint match is tied to the TPM. |

The code is in the [linux-hello repository](https://github.com/LinuxHello/linux-hello); its README keeps the same list up to date.

## 1.2 Requirements overview

These are the main things Linux Hello must do. The detailed requirements are in the sections named after each.

1. **Sign in to websites with passkeys.** Any browser or app that supports a USB security key can create and use passkeys through Linux Hello, confirmed with the fingerprint, the face or the PIN. A website is told the user was verified only if they were checked for this request or at most 60 seconds before it ([user verification](12-glossary.md#user-verification-uv), [ADR-0020](../adr/0020-presence-and-verification.md)).
2. **Never sign without the user.** Every signature needs a gesture that another program of the same user cannot fake, such as a fingerprint touch or the PIN ([presence gesture](12-glossary.md#presence-gesture)).
3. **Sign in to the computer.** The same methods work at the login screen, the lock screen and for `sudo`. If Linux Hello fails, the account password still works ([fall-through](12-glossary.md#fall-through), [ADR-0023](../adr/0023-pam-module-and-login-failure.md)).
4. **Keys stay where the policy puts them.** Private keys are created and used inside the TPM or KeePassXC, and never handed to any program ([section 4, design rules](04-solution-strategy.md#43-design-rules)).
5. **Rules an administrator can set.** PIN length, which methods each situation allows, and which websites must keep their keys in the TPM are set in [policy](12-glossary.md#policy-routing-policy) files, modelled on the settings of Windows Hello for Business, the version of Windows Hello for company-managed computers ([section 8, Policy](08-crosscutting-concepts.md#policy)).
6. **Always show what is happening.** At every prompt the user sees which method is active, can switch to another, and has the PIN on offer. These are the requirements UX1 to UX8 in [section 8, User experience](08-crosscutting-concepts.md#user-experience).
7. **Fewer logins for desktop apps.** Desktop and [Electron apps](12-glossary.md#electron-app) that sign in through a browser should need at most one touch when their login expires. On the machine where this was first seen (Claude Desktop, with [KWallet](12-glossary.md#kwallet), KDE's password store, open), the cause was the service's own token lifetime of under 24 hours, which no store on the computer can extend. The aim is therefore to renew the token without the user, not to keep it longer ([section 4, token reissue](04-solution-strategy.md#44-signing-in-again-without-the-user)).

## 1.3 Quality goals

When two goals conflict, the higher one wins. The order follows from two things: Linux Hello must be "fast and robust enough that people keep it switched on", and it must keep the rules that no change may break, the [invariants](12-glossary.md#invariant) in linux-hello's [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants).

| Rank | Goal | What it means | How it is checked |
| :-- | :-- | :-- | :-- |
| 1 | Security | The PIN is the root of trust. Nothing quietly weakens how the user is checked. A program running as the same user cannot fake the user's presence ([ADR-0020](../adr/0020-presence-and-verification.md)). | Each [security property](12-glossary.md#property-security-property) has a test named after it ([docs/security/](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md)). |
| 2 | Availability at login | A failure of Linux Hello never locks the user out of their own computer: the account password still works ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)). | Three failure scenarios in [section 10.2](10-quality-requirements.md#102-quality-scenarios): the Agent does not answer, a sensor program is missing, and Linux Hello is unavailable altogether (A1 to A3). |
| 3 | Speed | Signing in is quick enough that nobody turns it off: for example, at most one second from a fingerprint touch to the unlocked desktop. | Five time budgets in [section 10.2](10-quality-requirements.md#102-quality-scenarios), from a call to the Agent to a passkey signature (L1 to L5). They are targets; most are not measured yet. |
| 4 | Usability | The user always sees which method is running and what to do next. | The requirements UX1 to UX8 in [section 8](08-crosscutting-concepts.md#user-experience). |

Security comes before availability, yet the account password still works when Linux Hello fails. The two fit because the password only logs the user in: it never unlocks the keys in the TPM, so a login by password leaves every passkey locked.

## 1.4 Stakeholders

The people and groups below have a stake in the architecture. The first two are the people in the [C4 model](12-glossary.md#c4-model), the diagrams of the architecture ([workspace.dsl](../workspace.dsl)); the roles of the project come from [ADR-0004](../adr/0004-agent-roles.md). The expectations are taken from the decisions and notes linked in each row. Nobody outside the project has yet been asked to confirm them.

| Who | Expectations of the architecture | Where it is answered |
| :-- | :-- | :-- |
| **Desktop user**, who signs in to the computer, websites and apps, and enrols a fingerprint, the face and a PIN | Signing in is quick and the same everywhere; it is always clear which method is running; a forgotten PIN or a broken Linux Hello never locks them out of the computer; a forgotten PIN warns before passkeys are deleted | Sections [8, User experience](08-crosscutting-concepts.md#user-experience) and [10](10-quality-requirements.md); [ADR-0003](../adr/0003-destructive-reset.md), [ADR-0023](../adr/0023-pam-module-and-login-failure.md) |
| **Administrator**, who installs Linux Hello, sets the policy for the machine and authorises a reset | Rules are set in plain files and cannot be loosened by users; a broken file makes the system stricter, not looser; Linux Hello is confined and watched like any other security service | Sections [7](07-deployment-view.md) and [8, Policy](08-crosscutting-concepts.md#policy); [ADR-0018](../adr/0018-user-policy-layer.md) |
| **Maintainer** (@atterdag), who decides and merges, and owns the architecture, the threat model and the security properties | Assurance comes from properties in plain language and the tests that check them, not from reading Rust code; every decision is recorded where it can be found again | Section [8, Security hardening](08-crosscutting-concepts.md#security-hardening); [ADR-0004](../adr/0004-agent-roles.md), [ADR-0010](../adr/0010-arc42-architecture-documentation.md) |
| **Coding agents**: the lead (Claude), the implementer (a local AI model) and the assistant (GitHub Copilot) | The architecture is written down precisely enough that one issue can be built from one [brief](12-glossary.md#brief), without guessing | [ADR-0004](../adr/0004-agent-roles.md); [ADR-0008](../adr/0008-code-documentation-mapped-to-c4.md) |
| **[Relying parties](12-glossary.md#relying-party)**, the websites and services that accept passkeys | Linux Hello behaves like any standard security key and reports user verification only when it really happened | [ADR-0005](../adr/0005-provider-path.md), [ADR-0020](../adr/0020-presence-and-verification.md) |
| **Upstream projects**: KDE Plasma, KeePassXC, fprintd, Howdy and libwebauthn, a library for talking to authenticators | Linux Hello uses their published interfaces and sends changes upstream instead of keeping a private fork | [Section 2](02-constraints.md) |
| **Outside security reviewers** | An external audit of the TPM provider and the Agent happens before anyone relies on Linux Hello | Section [8, Security hardening](08-crosscutting-concepts.md#controls) |

## Where to read next

- [Section 3](03-context-and-scope.md) shows Linux Hello among the programs and people around it.
- [Section 4](04-solution-strategy.md) explains the main choices, above all the virtual security key.
- [Section 6](06-runtime-view.md) walks through what happens when a user signs in.
