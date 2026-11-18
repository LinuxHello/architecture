---
type: index
subject: Index of architecture decision records
artifact: adr-index
status: active
owner: "@atterdag"
concepts: [governance]
tags: [adr, index]
sources: ["../arc42/09-architecture-decisions.md"]
date: 2026-11-17
---

# Architecture decision records

An architecture decision record (ADR) is a short note that records one decision about Linux Hello: the problem, the options weighed, the choice, and what follows from it. This index lists every ADR in number order, with one sentence on what it decides. [Section 9 of the architecture documentation](../arc42/09-architecture-decisions.md) explains how to read an ADR and groups the same decisions by topic. An ADR marked *proposed* is not yet decided; one marked *superseded* was replaced by a later one.

- [ADR-0001: Monorepo with split guardrails](0001-monorepo-with-split-guardrails.md): all code lives in one repository, one crate per part, with rules that keep a later split easy.
- [ADR-0002: Licence LGPL-3.0-or-later](0002-licence-lgpl-3-or-later.md): all code is under the LGPL, version 3 or later, with contributions certified under the DCO.
- [ADR-0003: Destructive reset, no recovery key](0003-destructive-reset.md): a forgotten PIN is reset by deleting the user's keys; there is no recovery key.
- [ADR-0004: Roles of the coding agents](0004-agent-roles.md): which AI agent writes, reviews and documents, and that the maintainer decides and merges.
- [ADR-0005: How providers attach: a virtual CTAP authenticator, no credentialsd](0005-provider-path.md): Linux Hello appears to browsers as a USB security key created in software, with the key stores behind it.
- [ADR-0006: Attested quality gates and releases](0006-attested-quality-gates-and-releases.md) (accepted): which CI checks every commit must pass, and how releases are signed.
- [ADR-0007: Unattended agent loops](0007-unattended-agent-loops.md) (proposed): the AI agents may run in loops, sharing state only through GitHub issues.
- [ADR-0008: Code documentation mapped to the C4 model](0008-code-documentation-mapped-to-c4.md) (accepted): every piece of code is documented and names the C4 part it implements.
- [ADR-0009: A self-hosted runner on the maintainer's workstation](0009-self-hosted-runner.md) (proposed): some CI jobs run on the maintainer's workstation, none of them required.
- [ADR-0010: Architecture documentation structured by Arc42](0010-arc42-architecture-documentation.md) (accepted): the architecture documentation follows the twelve Arc42 sections.
- [ADR-0011: An architecture repository](0011-architecture-repository.md): the architecture documentation and the ADRs live in this repository, separate from the code.
- [ADR-0012: D-Bus names](0012-dbus-names.md): every D-Bus name starts with `io.github.LinuxHello.`, and the Agent is `io.github.LinuxHello.Agent1`.
- [ADR-0013: Browser path for 1.0](0013-browser-fallback.md) (superseded by ADR-0017): an earlier plan for a browser extension of Linux Hello's own.
- [ADR-0014: The Agent's bus](0014-agent-bus.md): the Agent is one system service on the D-Bus system bus and tells each caller only about its own sign-in attempts.
- [ADR-0015: Face capture, enrolment and preview](0015-face-capture-and-enrolment.md): Howdy is run as it is, and there is no live camera picture in 1.0.
- [ADR-0016: Where the authentication prompt is shown](0016-prompt-hosts.md): one shared prompt; the login screen gets Linux Hello's theme and the lock screen uses KDE's own services.
- [ADR-0017: Browser path for 1.0, after ADR-0005 option B](0017-browser-path.md): browsers reach Linux Hello only as a security key in 1.0; no extension.
- [ADR-0018: Where the user layer of the routing policy lives](0018-user-policy-layer.md): each user's rules are kept by the Agent and changed over D-Bus, not read from the home directory.
- [ADR-0019: A shared memory for the coding agents](0019-shared-agent-memory.md) (proposed): a memory service for the AI agents that returns evidence with its source, never a verdict.
- [ADR-0020: Presence and verification that a process of the same user cannot forge](0020-presence-and-verification.md) (amends ADR-0017): when a website is told that the user was present and verified.
- [ADR-0021: How the PIN reaches the Agent and the TPM](0021-pin-transport.md) (amends ADR-0014): the PIN travels over a socket of its own, never as a D-Bus message; the control call that announces it is `ExpectPin(prompt_id)`.
- [ADR-0022: Crate and package names, and what is published](0022-crate-and-package-names.md): the names stay, and nothing is published to crates.io in 1.0.
- [ADR-0023: A thin PAM module, and what login does when Linux Hello fails](0023-pam-module-and-login-failure.md) (amends the model): the PAM module only asks the Agent, and a failure falls through to the account password.
- [ADR-0024: The Agent's status interface](0024-agent-status-interface.md): the Agent says in words what is wrong for the caller, and shows file names to root only.
- [ADR-0025: One virtual security key per user and active session](0025-virtual-key-per-user-session.md) (proposed; amends ADR-0017): the virtual security key belongs to one user and exists only while that user's session is in front and unlocked.

New ADRs start from [the template](../templates/adr.md).
