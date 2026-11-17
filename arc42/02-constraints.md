---
type: architecture
subject: "Arc42 section 2: constraints on Linux Hello (licences, upstream first, what the platform gives, and how the project works)"
artifact: arc42-02-constraints
status: active
owner: "@atterdag"
concepts: [licensing, upstream-first, arc42, constraints]
tags: [architecture, arc42]
sources: ["README.md", "12-glossary.md", "../spikes/0005-credentialsd-provider-api.md", "../spikes/0008-howdy-interface.md", "../spikes/0009-plasma-prompt-component.md", "../spikes/0013-upstream-licences.md", "../adr/0001-monorepo-with-split-guardrails.md", "../adr/0002-licence-lgpl-3-or-later.md", "../adr/0004-agent-roles.md", "../adr/0005-provider-path.md", "../adr/0016-prompt-hosts.md", "../adr/0017-browser-path.md", "https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants", "https://docs.arc42.org/section-2/"]
date: 2026-11-17
---

# 2. Constraints

Part of the [Arc42 architecture documentation](README.md).

A constraint is something the design has to accept rather than choose: a licence rule, a fact about the programs Linux Hello builds on, or the way the project is run. This section lists them, says where each comes from, and says what it rules out. It matters because many decisions in the later sections look odd until you know the constraint behind them. For example, Linux Hello talks to the fingerprint service through messages instead of using its code directly, only because of a licence rule ([C3](#c3-reach-gpl-programs-only-across-a-process-boundary)). [Section 1](01-introduction-and-goals.md) says what Linux Hello is; [section 4](04-solution-strategy.md) shows the design these constraints leave room for. Terms that may be new to you are in the [glossary](12-glossary.md).

There are three kinds:

- [2.1 Licences and upstream](#21-licences-and-upstream): rules the project set for itself, C1 to C5. They are binding for every contributor as invariants 5 and 6 of [linux-hello's AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants).
- [2.2 What the platform gives](#22-what-the-platform-gives): facts about Linux, KDE, the browsers and the hardware that Linux Hello cannot change.
- [2.3 How the project works](#23-how-the-project-works): how decisions, code and sign-offs are made.

## 2.1 Licences and upstream

Linux Hello builds on other open-source projects, which the project calls [upstream](12-glossary.md#upstream). Their licences decide how Linux Hello may use their code. Two licence families matter here ([GPL, LGPL](12-glossary.md#gpl-lgpl)): the GPL requires a program that includes GPL code to be released under the GPL as a whole, while the LGPL allows any program to use a library under it, as long as changes to the library itself stay open. The five constraints below follow from that.

### C1: Reuse what exists

Linux Hello is an integration layer. It reuses [KeePassXC](12-glossary.md#keepassxc) for [portable passkeys](12-glossary.md#portable-key), fprintd for fingerprints and Howdy for faces, and adds only what is missing: the providers, the virtual security key, the policy that decides when to unlock, and the settings. The reason is that each of those programs is maintained by people who know their hardware and their protocol; a copy in Linux Hello would fall behind and carry the same bugs twice.

There is one exception. Linux Hello writes its own handling of CTAP, the protocol between a browser and a security key, inside the Virtual CTAP Authenticator. The upstream candidate, credentialsd, a proposed Linux service for passkeys, offered no way for Linux Hello to plug in its own key store ([spike 0005](../spikes/0005-credentialsd-provider-api.md)), so Linux Hello does not use it ([ADR-0005](../adr/0005-provider-path.md)).

### C2: Link only to LGPL or permissive libraries

When Linux Hello uses another project's code inside its own programs (it *links* to a library), that library must be under the LGPL or a permissive licence such as MIT or Apache-2.0. The reason is C5: Linux Hello is itself under the LGPL, and linking GPL code would force the whole program under the GPL. The continuous integration of `linux-hello` checks every dependency's licence against an allow list (`deny.toml`, checked by `cargo-deny`).

Today Linux Hello links no LGPL library. The candidate, if a CTAP library is needed, is libwebauthn (LGPL-2.1-or-later). The allow list also still names LGPL-3.0-only, which was added for credentialsd before ADR-0005 dropped it.

### C3: Reach GPL programs only across a process boundary

KeePassXC and fprintd are under the GPL. Linux Hello may use them only as separate programs that it talks to: over [D-Bus](12-glossary.md#d-bus), the Linux message bus; through [PAM](12-glossary.md#pam), the Linux sign-in framework; over a local socket; or through KeePassXC's browser protocol. It never uses them by linking their code. The Free Software Foundation, which wrote the GPL, treats linking as making one combined work, but treats two programs that exchange messages as separate works ([spike 0013](../spikes/0013-upstream-licences.md)).

This is why the Agent asks fprintd over D-Bus to check a finger, and why the KeePassXC bridge speaks KeePassXC's browser protocol over a local socket ([section 3.2](03-context-and-scope.md#32-technical-context)).

### C4: Changes to upstream go upstream

If an upstream project needs a change for Linux Hello, the change is offered to that project as a contribution. Linux Hello keeps no private fork and no patched copy. The reason is that a fork has to be kept in step with every upstream release, and the licence duties of a modified copy fall on whoever ships it. For example, the newer Plasma Login Manager has no place for a third-party prompt; Linux Hello waits for a change in KDE rather than shipping a modified login manager ([ADR-0016](../adr/0016-prompt-hosts.md)).

### C5: Linux Hello is LGPL-3.0-or-later

All code of Linux Hello is under the LGPL, version 3 or later ([ADR-0002](../adr/0002-licence-lgpl-3-or-later.md)). The LGPL lets other programs, under any licence, use Linux Hello's libraries, while changes to Linux Hello itself stay open. It is also compatible with the LGPL libraries Linux Hello may link.

### The licences of the programs Linux Hello uses

[Spike 0013](../spikes/0013-upstream-licences.md) read the licence of each upstream program. The table shows what it found and how Linux Hello reaches each one. It is not legal advice.

| Program | Licence | How Linux Hello reaches it |
| :-- | :-- | :-- |
| KeePassXC | GPL-2.0 or GPL-3.0 | As a separate program, over its browser protocol (C3) |
| fprintd | GPL-2.0-or-later | As a separate program, over D-Bus (C3). Its own library, libfprint, was not checked; Linux Hello does not link it |
| Howdy | MIT | As a separate program, run as a subprocess. Linking would be allowed but is not planned |
| libwebauthn | LGPL-2.1-or-later | Would be linked, if a CTAP library is needed (C2). Not used today |
| credentialsd | LGPL-3.0-only | Not used ([ADR-0005](../adr/0005-provider-path.md)) |

Not checked yet: the terms of the image sets behind Howdy's face models, and the licences of the libraries that Linux Hello's own dependencies pull in, which `cargo-deny` checks one by one as they are added.

## 2.2 What the platform gives

These are facts about the programs and hardware around Linux Hello. They are not choices, but each one shaped a decision.

| Fact | What it rules out or requires | Where it is recorded |
| :-- | :-- | :-- |
| Browsers speak to a USB security key, and Linux Hello cannot change the browsers. | Linux Hello must look like a security key to them; it creates one in software through the kernel's `uhid` interface. Browsers then show it as "a security key", not as "this device". | [ADR-0005](../adr/0005-provider-path.md), [ADR-0017](../adr/0017-browser-path.md) |
| Keys that can never be copied need a TPM 2.0, the security chip most current computers have. | A computer without a TPM 2.0 cannot hold device-bound passkeys or a PIN-protected root key. | [Section 1](01-introduction-and-goals.md#the-problem) |
| Howdy offers no library and no live camera picture: it answers a face check only with its exit status, and records a face only through a command that needs root. | Linux Hello runs Howdy as a program and shows no live picture during face setup in version 1.0. | [Spike 0008](../spikes/0008-howdy-interface.md), [ADR-0015](../adr/0015-face-capture-and-enrolment.md) |
| Neither KDE's login screens nor its lock screen has a place for another program's prompt. Ubuntu 26.04 ships Plasma 6.6, whose lock screen has fewer sign-in services than Plasma 6.8. | Linux Hello ships its own theme for the SDDM login screen and uses KDE's own services at the lock screen, with text only. | [Spike 0009](../spikes/0009-plasma-prompt-component.md), [ADR-0016](../adr/0016-prompt-hosts.md) |
| The TPM keeps one counter of wrong attempts for the whole computer. | Linux Hello must count wrong PINs per user itself, or one user could lock out every other user. | [Section 5](05-building-block-view.md#agent) |

## 2.3 How the project works

| Constraint | What it means | Where it is recorded |
| :-- | :-- | :-- |
| One maintainer decides and merges. | Every change waits for the maintainer's review. The maintainer also owns the architecture, the threat model and the security properties. | [ADR-0004](../adr/0004-agent-roles.md) |
| Most code and documents are written by AI agents. | A local model writes code from a brief; Claude writes briefs, reviews and documents; Copilot reviews. Each change still passes the same checks. | [ADR-0004](../adr/0004-agent-roles.md) |
| Every commit is certified by a human under the Developer Certificate of Origin ([DCO](12-glossary.md#dco)). | An agent cannot certify where code comes from, so the maintainer adds the sign-off to the agents' commits before merging. | [ADR-0004](../adr/0004-agent-roles.md) |
| Decisions that are hard to undo need an ADR. | The licence, names, D-Bus names, crate and package names, the reset model and the repository layout change only through a new decision record. | Invariant 7 of [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants) |
| The repositories are public. | No secrets, personal data or details of anyone's machines in code, documents, issues or commits. | Invariant 8 of [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants) |
| One repository for all code. | The programs live as separate crates in one repository and are coupled only through their interfaces, so that a later split stays easy. | [ADR-0001](../adr/0001-monorepo-with-split-guardrails.md) |

The licence rules above, together with the rules on `unsafe` code and on failing closed, are binding for every contributor as the invariants in [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants).

An earlier version of C1 and C4 made an exception for credentialsd, on which Linux Hello was first meant to build. Since [ADR-0005](../adr/0005-provider-path.md) Linux Hello does not use credentialsd, so the exception is gone; C1 now names Linux Hello's own CTAP handling as its one exception.
