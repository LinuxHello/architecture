---
type: architecture
subject: "Arc42 section 8: crosscutting concepts of Linux Hello (an overview of the trust chain, security, user experience and policy, each with a note of its own)"
artifact: arc42-08-crosscutting-concepts
status: active
owner: "@atterdag"
concepts: [trust-chain, threat-model, confinement, user-experience, policy, arc42]
tags: [architecture, arc42, security, policy]
sources: ["README.md", "08-trust-chain.md", "08-security.md", "08-user-experience.md", "08-policy.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md", "https://docs.arc42.org/section-8/"]
date: 2026-11-17
---

# 8. Crosscutting concepts

Part of the [Arc42 architecture documentation](README.md).

This section answers the question: which ideas run through every part of Linux Hello, rather than belonging to one part? Sections 5 to 7 describe the parts one by one; the ideas here apply to all of them at once. There are four, and each has a note of its own, because together they are too long for one page. This page gives each one in a few sentences and links to the full note. Terms that may be new to you are in the [glossary](12-glossary.md).

| Concept | The question it answers | Full note |
| :-- | :-- | :-- |
| Trust chain | Which proof of identity unlocks what: the PIN, a fingerprint or face, or the account password? | [08-trust-chain.md](08-trust-chain.md) |
| Security | What could an attacker try, and what stops them? | [08-security.md](08-security.md) |
| User experience | What does the user see at every prompt, and how do they set Linux Hello up? | [08-user-experience.md](08-user-experience.md) |
| Policy | Who decides which methods are allowed, where a passkey is kept, and how strict Linux Hello is? | [08-policy.md](08-policy.md) |

Two related notes live in the code repository: the [policy semantics](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md), precise enough to implement and test, and the [security properties and threat model](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md), each property with the test that checks it.

The headings below keep the names that other pages link to.

## Trust chain

The PIN is the root: it is the TPM's password for the user's root key, under which every passkey hangs. A fingerprint or face is a shortcut that saves typing the PIN but never replaces it. The account password can only authorise a reset, which deletes the keys; it never unlocks them. This is the order Windows Hello uses by default ([ADR-0003](../adr/0003-destructive-reset.md)). Full note: [the trust chain](08-trust-chain.md).

## Security hardening

Linux Hello is written in Rust to rule out most memory bugs, and treats mistakes in logic as the larger risk. Confidence comes from tests that state security properties in plain words, CI checks that block a merge, and outside reviews. Full note: [security](08-security.md).

### Threats to design against

The threats include a program pretending to be another, another user on the same computer using the virtual security key, unlocking without a real check, keys being copied out, one website's key signing for another, a taken-over helper, silent or faked confirmation, an old copy of the root key, crafted messages and a malicious dependency. Each is listed with an example, its answer and its state in [security: threats to design against](08-security.md#threats-to-design-against).

### Controls

Six rules apply to the whole code base: no `unsafe` Rust outside two audited modules, CI checks that block a merge, security properties backed by tests, a systemd sandbox for every service, key handling apart from the virtual device, and an outside audit before release. See [security: controls](08-security.md#controls).

### Runtime confinement and detection

Every Linux Hello program runs under an AppArmor profile in enforce mode and refuses to start without it; optional Tetragon rules report suspicious actions, and the reports are meant to reach a log system with alerts. See [security: confinement and detection while it runs](08-security.md#confinement-and-detection-while-it-runs).

## User experience

At every prompt the user sees which method is running, can switch to another, and always has the PIN on offer; face and fingerprint run at the same time. The full requirements UX1 to UX8 and how they are met are in [user experience](08-user-experience.md).

### Requirements

The eight requirements, from "the active method is always visible" (UX1) to "the first-run setup asks for the PIN first" (UX8), are listed in [user experience: requirements](08-user-experience.md#requirements).

### Design consequence

Because PAM talks to a login screen only in text, Linux Hello adds a second channel: the Agent runs the methods and reports their live state on D-Bus, and every prompt draws from it. See [user experience: the design these requirements force](08-user-experience.md#the-design-these-requirements-force).

### Additions to the C4 model

The user-experience design added the Method Orchestrator, the Auth State Publisher, the PAM module's Agent Client, the shared Auth Prompt, the Face Enrolment Module and the SDDM theme. [Section 5](05-building-block-view.md) describes them; [user experience: how the model changed](08-user-experience.md#how-the-model-changed) says why.

## Policy

The routing policy is a set of rules in text files that the Agent reads before every sign-in and passkey request: which methods each situation allows, where each website's passkey is kept, and how strong the prompt must be. Full note: [policy](08-policy.md).

### Layers and precedence

Built-in defaults come first, then the user's own layer, which can only make rules stricter, then the administrator's layer, which wins. A file that cannot be trusted puts Linux Hello in the PIN-only state. See [policy: three layers of rules](08-policy.md#three-layers-of-rules).
