---
type: architecture
subject: "Arc42 section 9: architecture decisions of Linux Hello (what an ADR is, how to read one, and the decisions grouped by topic)"
artifact: arc42-09-architecture-decisions
status: active
owner: "@atterdag"
concepts: [adr, governance, arc42]
tags: [architecture, arc42, adr]
sources: ["README.md", "12-glossary.md", "../adr/README.md", "../templates/adr.md", "https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#source-of-truth", "https://docs.arc42.org/section-9/"]
date: 2026-11-17
---

# 9. Architecture decisions

Part of the [Arc42 architecture documentation](README.md).

This section answers the question: which important decisions were taken about Linux Hello, and where are their reasons written down? The other sections describe the design as it is; the reasons for it are kept in *architecture decision records*, or [ADRs](12-glossary.md#adr). This section explains what an ADR is and how to read one, and then groups the decisions by topic, so that you can find the one behind a part of the design. The [ADR index](../adr/README.md) lists them all in number order. Terms that may be new to you are in the [glossary](12-glossary.md).

## 9.1 What an ADR is, and how to read one

An ADR is a short note that records one decision: the situation that called for it, the options that were weighed, the one that was chosen, and what follows from it. It is written when the decision is taken, and it is not rewritten later. If the decision changes, a new ADR replaces the old one, or an *amendment* is added at the end of it with its own date. This keeps a trail: a reader can see not only what was decided but what was known at the time.

Each ADR has four parts, from [the template](../templates/adr.md):

- **Status:** how far the decision has come (see the table below).
- **Context:** the problem, and why it had to be decided then.
- **Decision:** what was chosen. Many ADRs compare options named A, B, C; the Decision names the chosen letter, for example "Option A", and the letters mean nothing outside that ADR.
- **Consequences:** what becomes easier and what becomes harder.

The status words:

| Status | What it means |
| :-- | :-- |
| proposed | Written and open for review, but not yet decided by the maintainer. A proposed ADR is not yet binding. |
| accepted | Decided. Code and documentation must follow it. |
| superseded | Replaced by a later ADR, which it names. Kept so the history stays readable. |

When sources disagree, `linux-hello` resolves them in a fixed order: first the code on `main` with its tests, then the accepted ADRs, then these architecture notes ([source of truth in linux-hello's AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#source-of-truth)). So an accepted ADR wins over a section of this documentation that says something else, and such a section is a mistake to be fixed.

## 9.2 Decisions that shape the product

These ADRs decide how Linux Hello works. Each row says in one sentence what the ADR decides.

**How Linux Hello reaches browsers and apps**

| ADR | What it decides | Status |
| :-- | :-- | :-- |
| [ADR-0005](../adr/0005-provider-path.md) | Linux Hello appears to browsers as a USB security key created in software (a virtual CTAP authenticator), with the TPM and KeePassXC providers behind it, and does not build on credentialsd. | accepted |
| [ADR-0017](../adr/0017-browser-path.md) | In version 1.0 browsers reach Linux Hello only through that virtual security key; Linux Hello ships no browser extension. | accepted |
| [ADR-0013](../adr/0013-browser-fallback.md) | An earlier plan for a browser extension of Linux Hello's own. | superseded by ADR-0017 |
| [ADR-0020](../adr/0020-presence-and-verification.md) | A website is told the user was present only after a gesture another program cannot fake, and told the user was verified only for a check made for this request or at most 60 seconds before it. Amends ADR-0017. | accepted |
| [ADR-0025](../adr/0025-virtual-key-per-user-session.md) | The virtual security key belongs to one user, and exists only while that user's session is in front and unlocked, so that a second person logged in on the same computer cannot use it. Amends ADR-0017. | proposed |

**The Agent and how programs talk to it**

| ADR | What it decides | Status |
| :-- | :-- | :-- |
| [ADR-0014](../adr/0014-agent-bus.md) | The Agent is one system service on the D-Bus system bus, running as its own user, and tells each caller only about that caller's own sign-in attempts. Amended on 2026-11-16 (callers are told apart by user number and connection only) and on 2026-11-17 (named errors, results with a reason, and how the interface may change). | accepted, with both amendments |
| [ADR-0012](../adr/0012-dbus-names.md) | Every D-Bus name of Linux Hello starts with `io.github.LinuxHello.`, and the Agent is `io.github.LinuxHello.Agent1`. | accepted |
| [ADR-0021](../adr/0021-pin-transport.md) | The PIN travels from the PAM module to the Agent over a socket of its own, never as a D-Bus message, and only the Agent passes it to the TPM. Amends ADR-0014. | accepted |
| [ADR-0024](../adr/0024-agent-status-interface.md) | The Agent answers a `GetStatus` call with the problems that affect the caller, in words, and shows file names to root only. | accepted |

**Signing in to the computer**

| ADR | What it decides | Status |
| :-- | :-- | :-- |
| [ADR-0023](../adr/0023-pam-module-and-login-failure.md) | The PAM module stays small and only asks the Agent; when Linux Hello cannot answer, the login falls through to the account password. | accepted |
| [ADR-0016](../adr/0016-prompt-hosts.md) | One shared prompt component; the login screen SDDM gets a theme of Linux Hello's own, and the lock screen uses KDE's own face and fingerprint services. | accepted |
| [ADR-0015](../adr/0015-face-capture-and-enrolment.md) | Linux Hello runs Howdy as it is for face checks and face setup, and shows no live camera picture in version 1.0. | accepted |

**Keys, PIN and rules**

| ADR | What it decides | Status |
| :-- | :-- | :-- |
| [ADR-0003](../adr/0003-destructive-reset.md) | A forgotten PIN can only be reset by deleting the user's keys; there is no recovery key, and the user registers new passkeys with each website. | accepted |
| [ADR-0018](../adr/0018-user-policy-layer.md) | Each user's own rules are kept by the Agent in its state directory and changed over D-Bus, not read from the home directory. Its amendment of 2026-11-10, that a user's rules can never weaken an administrator's, is proposed but already built. | accepted; amendment proposed |

## 9.3 Decisions about the project

These ADRs decide how Linux Hello is built, licensed and documented, rather than how it works.

| ADR | What it decides | Status |
| :-- | :-- | :-- |
| [ADR-0001](../adr/0001-monorepo-with-split-guardrails.md) | All code lives in one repository, one crate per part, with rules that keep a later split easy. | accepted |
| [ADR-0002](../adr/0002-licence-lgpl-3-or-later.md) | All code is under the LGPL, version 3 or later, and every contribution is certified under the DCO. | accepted |
| [ADR-0022](../adr/0022-crate-and-package-names.md) | The crate and package names stay as they are, and nothing is published to crates.io in version 1.0. | accepted |
| [ADR-0004](../adr/0004-agent-roles.md) | Who does what: a local AI model writes code, Claude writes briefs and reviews, Copilot reviews, and the maintainer decides and merges. Amended on 2026-11-03 so that Claude works in GitHub directly. | accepted |
| [ADR-0007](../adr/0007-unattended-agent-loops.md) | The AI agents may run in loops without a person at the keyboard, sharing state only through GitHub issues and their labels. | proposed |
| [ADR-0019](../adr/0019-shared-agent-memory.md) | A memory service for the AI agents, which returns evidence with where it came from and never a verdict. | proposed |
| [ADR-0009](../adr/0009-self-hosted-runner.md) | The maintainer's workstation runs some CI jobs, none of them required and none signing anything. | proposed |
| [ADR-0006](../adr/0006-attested-quality-gates-and-releases.md) | Which CI checks every commit must pass, and how releases are signed and proven to come from reviewed code. | accepted |
| [ADR-0008](../adr/0008-code-documentation-mapped-to-c4.md) | Every piece of code is documented and names the part of the C4 model it implements. Amended on 2026-11-05 to publish the code documentation with generated diagrams. | accepted |
| [ADR-0010](../adr/0010-arc42-architecture-documentation.md) | The architecture documentation follows the twelve sections of the Arc42 template. | accepted |
| [ADR-0011](../adr/0011-architecture-repository.md) | The architecture documentation and the ADRs live in this repository, separate from the code. | accepted |

ADR-0006, ADR-0008 and ADR-0010 describe how the project already worked when they were accepted on 2026-11-18: the CI checks run, the code names its C4 parts, and this documentation follows Arc42.

## 9.4 Writing a new ADR

A decision that is hard to undo needs an ADR before the code: the licence, names, D-Bus names, crate and package names, the reset model and the repository layout (invariant 7 of [linux-hello's AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants)). A new ADR starts from [the template](../templates/adr.md), takes the next free number, and is added to the [index](../adr/README.md) and, if it shapes the product, to the tables above.

Decision LH-1 of the former target architecture, the destructive reset without a recovery key, became [ADR-0003](../adr/0003-destructive-reset.md).
