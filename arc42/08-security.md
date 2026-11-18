---
type: architecture
subject: "Arc42 section 8, security: the threats Linux Hello designs against, the controls that answer them, and how its programs are confined and watched"
artifact: arc42-08-security
status: active
owner: "@atterdag"
concepts: [threat-model, confinement, apparmor, tetragon, security-properties, arc42]
tags: [architecture, arc42, security]
sources: ["08-crosscutting-concepts.md", "12-glossary.md", "../adr/0004-agent-roles.md", "../adr/0005-provider-path.md", "../adr/0018-user-policy-layer.md", "../adr/0020-presence-and-verification.md", "../spikes/0011-tpm-root-key-change-auth.md", "../spikes/0119-rp-bound-credential-keys.md", "../spikes/0120-resident-keys-presence-and-uv.md", "../spikes/0121-uhid-helper-privilege.md", "../spikes/0138-virtual-ctap-session-binding.md", "../spikes/0177-prompt-identity-in-the-users-session.md", "../spikes/0177-prompt-launch-by-the-system-manager.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md", "https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants"]
date: 2026-11-17
---

# 8. Crosscutting concepts: security

Part of [section 8](08-crosscutting-concepts.md) of the [Arc42 architecture documentation](README.md).

This note answers the question: what could an attacker try against Linux Hello, and what stops them? Linux Hello guards the keys that sign a user in to websites and to their own computer, so a flaw in it is worth more to an attacker than a flaw in most desktop programs. The note explains the approach, then lists the threats with an example and the answer to each, then the general controls, and finally how every Linux Hello program is confined and watched while it runs. The full threat model, with its actors and trust boundaries, is in [docs/security of linux-hello](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md). Terms that may be new to you are in the [glossary](12-glossary.md).

## The approach

Linux Hello is written in Rust. A service that runs for a long time, holds key material and reads messages from programs it does not trust is where bugs in memory handling do the most harm, and Rust rules most of them out. Rust also matches the libraries Linux Hello uses for the TPM (`tss-esapi`) and D-Bus (`zbus`).

Rust does not prevent mistakes in logic, such as accepting a request that should have been refused. Those are the larger risk here. The maintainer reviews behaviour rather than Rust code, so confidence has to come from three places: tests that state a security property in plain words, CI checks that block a merge, and reviews by outside experts before anyone relies on Linux Hello.

## Threats to design against

Each row names a threat, gives an example, and says what answers it and whether that answer exists yet.

| Threat | Example | What answers it | State |
| :-- | :-- | :-- | :-- |
| A program pretends to be someone it is not | A program on D-Bus claims to be the login screen, or claims to ask for another website | The Agent reads each caller's user number from the bus itself, never from the message, and answers only about that user's own sign-in attempts. Through the virtual security key a program sends only a hash of the website's name; checking that the page really belongs to that website stays in the browser. Linux Hello never trusts a website name that an unprivileged program supplies | Built for the bus; the rest decided |
| Another user on the same computer uses the virtual security key | Bob, signed in on the same computer, opens the virtual key that Alice unlocked | A udev rule gives the key to the one user named in it, and the Agent removes the key when that user's session locks, leaves the screen or ends; this worked in a test machine with two sessions on one seat ([spike 0138](../spikes/0138-virtual-ctap-session-binding.md), [ADR-0025](../adr/0025-virtual-key-per-user-session.md), proposed; [linux-hello#138](https://github.com/LinuxHello/linux-hello/issues/138)) | Designed, not built |
| Unlocking without a real check | A fingerprint "match" is accepted although nobody touched the sensor | Unlocking is to be proven by the TPM, never by a flag in the Agent's memory. How a fingerprint match satisfies the TPM is open ([linux-hello#136](https://github.com/LinuxHello/linux-hello/issues/136)) | Open |
| A private key is copied out | Malware asks Linux Hello for a passkey's private key | Keys in the TPM cannot be exported; Linux Hello only ever receives signatures | Decided |
| One website's key signs for another | A bug, or a lookalike name, makes the key of `bank.example` sign for `evil.example` | The TPM itself refuses: each passkey's authorisation is computed by the TPM from the website's name, so another website's request does not fit, and the key is marked so that such a refusal does not count as a wrong PIN ([spike 0119](../spikes/0119-rp-bound-credential-keys.md)) | Tested in a spike |
| The helper that creates the virtual key is taken over | The helper creates a fake keyboard and types commands into the session | The helper runs as its own user, may open `/dev/uhid` and nothing else, has its own AppArmor profile and no TPM access; a udev rule stops any keyboard or mouse it creates from reaching the session. It could still create other devices that are not keyboards or mice ([spike 0121](../spikes/0121-uhid-helper-privilege.md)) | Tested in a spike |
| A passkey is used without the user knowing | A program asks the virtual key to sign a login in the background | Every request needs a gesture, asked for in the Prompt UI, a window outside the calling program: one prompt and one signature per request. A browser's silent probe, which checks whether a key exists without asking the user, is answered without using the key ([spike 0120](../spikes/0120-resident-keys-presence-and-uv.md)) | Tested in a spike |
| Presence or verification is faked | A program of the same user clicks "Allow" in the prompt with synthetic input, or reads the PIN typed into it; an unlock from hours ago is reported as fresh | Presence must be a gesture the session cannot fake: a fingerprint match delivered to the Agent, or the PIN, checked by the TPM. A click alone counts only for websites the policy marks as needing mere presence, on a computer without a sensor, and the documentation says it does not stop a program of the same user. A website is told the user was *verified* only for a check made for this request or at most 60 seconds before it, a limit the policy may shorten but never raise. The prompt is confined, cannot be inspected by other programs, and shows only the website's name from the request and the labels Linux Hello stored, never text the requesting program sent ([ADR-0020](../adr/0020-presence-and-verification.md)). No check can tell the real prompt from a copy drawn by a program of the same user, so the prompt never decides on its own; starting it as a system service from the Agent removes one way of faking it ([spike 0177](../spikes/0177-prompt-identity-in-the-users-session.md), [follow-up](../spikes/0177-prompt-launch-by-the-system-manager.md)) | Decided; tested in spikes |
| An old copy of the root key is used | Someone saved the root key's file before a PIN change and knows the old PIN | The PIN change deletes the old file. A stronger guarantee would need a TPM counter that every change increases, which was not tried ([spike 0011](../spikes/0011-tpm-root-key-change-auth.md)) | Decided |
| A malformed message crashes or takes over a parser | A crafted CTAP message, the binary format a browser sends to a security key, or a crafted D-Bus message | [Fuzzing](12-glossary.md#fuzzing) of every parser, and no `unsafe` code in parsers | Fuzzing runs for the Agent's parsers |
| A dependency is malicious or has a known flaw | A crate in the build is taken over by an attacker | Dependencies are pinned in `Cargo.lock` and checked by `cargo-audit` and `cargo-deny` | Built |

## Controls

These rules apply to the whole code base:

1. **No `unsafe` Rust**, except in one small, audited module each in the TPM provider and the PAM module, which need it to call C libraries. Every other crate forbids it, and the CI job `unsafe-policy` fails on any exception that is not on the allow list `scripts/ci/unsafe-allowlist.txt` (invariant 4 of [linux-hello's AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants)).
2. **CI checks that block a merge:** `clippy` with every warning treated as an error, `cargo-audit` for known vulnerabilities, `cargo-deny` for licences and advisories, and fuzzing of every parser.
3. **Security properties in plain words**, each backed by a test whose name states it, for example `caller_without_peer_credentials_is_refused`. The maintainer reviews the properties and the test results, not the code ([section 10.2](10-quality-requirements.md)).
4. **A systemd sandbox for every service**: its own user, a read-only system, no new privileges, only local sockets, and only the devices it needs ([section 7](07-deployment-view.md)), plus an AppArmor profile.
5. **Key handling apart from the device.** The providers live in their own crates behind an interface that knows nothing about `uhid`; only the small helper creates the virtual device ([ADR-0005](../adr/0005-provider-path.md)).
6. **An outside security audit** of the TPM provider and the Agent before anyone relies on Linux Hello.

## Confinement and detection while it runs

### AppArmor, required

[AppArmor](12-glossary.md#apparmor) is the kernel feature that limits each program to the files and devices its profile lists. Linux Hello ships one profile per service and one for `linuxhello-ctl`, all in enforce mode, in which AppArmor blocks what the profile does not allow. The profiles say:

- Only the TPM provider and the Agent may open the TPM, `/dev/tpmrm0`. Only the Agent's face path may run Howdy, and only Howdy, started by the Agent's helper, may open the camera. Only the `uhid` helper may open `/dev/uhid`.
- Every profile may read the administrator's policy files but not change them. The user's own policy layer is kept by the Agent in its state directory and changed over D-Bus, so no other program needs to write it ([ADR-0018](../adr/0018-user-policy-layer.md)).
- No other program may inspect the Agent or the providers, for example with `ptrace` or by reading `/proc/<pid>/mem`.
- CI loads every profile, runs the property tests under them, and fails on any blocked action or on a profile left in a mode that only logs.

Each service checks at start that its profile is loaded in enforce mode, and refuses to start otherwise. A Linux Hello that is missing is safer than one running without its limits: the account password still works.

*State:* the Agent's profile is built and tested on Ubuntu 24.04 and 26.04, and its checks run in CI ([section 7](07-deployment-view.md)). The other profiles are not written yet.

### Tetragon, optional

[Tetragon](12-glossary.md#tetragon) is a monitor that watches the kernel and can report or stop suspicious actions. Linux Hello ships sample rules for it as a second line of defence, but must work without it. The sample rules:

- report any program other than the Agent or the TPM provider opening the TPM;
- report writes to the administrator's policy files in `/etc/linuxhello/policy.d/` or to the PAM configuration in `/etc/pam.d/`;
- stop any Linux Hello program that opens a network connection beyond the local machine, since none of them needs the network;
- report any attempt to inspect the memory of the Agent or the providers.

Tracing and stopping programs work on today's kernels. Tetragon's strongest hooks need [BPF-LSM](12-glossary.md#bpf-lsm), which has to be switched on in the kernel's boot settings; each installation documents that change. In CI the rules are to be loaded in a test machine, and each report triggered once on purpose.

*State:* not built.

### Watching the reports

Detection only helps if someone looks. Tetragon's reports and the Agent's audit records are to be shipped to a log system, for example Alloy, Loki and Grafana, with rules that raise an alert, rather than only written to disk. *State:* the Agent writes its audit records to the system journal; shipping and alert rules are not built.

## Who owns what

The maintainer owns the [threat model](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/threat-model.md) and the [list of security properties](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/properties.md); the lead agent writes and reviews the tests ([ADR-0004](../adr/0004-agent-roles.md)).
