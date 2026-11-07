---
type: adr
subject: How the TPM provider and the KeePassXC bridge attach: a virtual CTAP authenticator, no credentialsd
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [credentialsd, provider-api, upstream, tpm, keepassxc]
tags: [adr, upstream]
sources: ["../spikes/0005-credentialsd-provider-api.md", "../arc42/02-constraints.md", "https://github.com/linux-credentials/credentialsd/issues/26"]
date: 2026-11-08
---

# ADR-0005: How providers attach: a virtual CTAP authenticator, no credentialsd

## Status

Accepted, 2026-11-01 (option A). Revised 2026-11-07: option D. Revised again 2026-11-08: option B for the first end-to-end test, with no dependency on credentialsd.

## Context

[Spike 0005](../spikes/0005-credentialsd-provider-api.md) answered No: credentialsd v0.3.1 has no interface for third-party credential providers, and no KDE portal backend. Its authenticators (hybrid, NFC, USB) are compiled into the daemon. The credentialsd maintainer has drafted a provider API in [credentialsd#26](https://github.com/linux-credentials/credentialsd/issues/26): a `CredentialProvider` interface credentialsd calls, a `CredentialProviderManager` providers register with, a privileged interface so only a trusted settings app enables providers, and a Noise-protected channel. No implementation exists.

Constraint C1 assumed Linux Hello only adds providers to an existing API. Both the TPM provider and the KeePassXC bridge are blocked until one of the options below is chosen. KeePassXC is GPL, so it must stay across a process boundary whatever the choice (C3).

The options:

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. Contribute the provider API upstream**, starting from the maintainer's draft in #26, then build both providers against it | Keeps C1 and C4; one mechanism for TPM and KeePassXC; KeePassXC stays out of process; the trusted-registration design matches our threat model; other password managers benefit | Critical path runs through upstream review and release; the Noise handshake and registration add design work; credentialsd is pre-release, so the API can still move |
| **B. Virtual CTAP authenticator** (`uhid`) backed by the TPM or KeePassXC, as kpasskey and tpm-fido do | Works with unmodified browsers today; needs nothing from credentialsd or a portal; the quickest path to a test of whether Linux Hello works | Browsers treat it as a roaming security key, not a platform authenticator; creating `uhid` devices needs privilege, enlarging the attack surface; no clean place for per-relying-party routing; a second mechanism to retire later |
| **C. In-process backends contributed to credentialsd** | TPM as a first-party platform authenticator fits credentialsd's own "nice-to-have" goal | Impossible for KeePassXC (GPL, C3); puts our TPM code under upstream's LGPL-3.0-only and release cycle; still needs A for KeePassXC |
| D. Own broker or a fork | Full control; the TPM provider and the KeePassXC bridge do not wait for upstream review or a release; can be replaced by A later | Breaks C1 and C4 while it is in force; duplicates upstream's CTAP and portal work; a fork must track credentialsd, which is pre-release |

## Decision

**Option B for the first end-to-end test, and Linux Hello does not depend on credentialsd.** The aim is to fail fast: reach a state where Linux Hello can be tried with unmodified Firefox and Chromium, and learn whether it works, without waiting for an upstream maintainer. Linux Hello runs a virtual CTAP authenticator (`uhid`) that the TPM provider, and later the KeePassXC bridge, sit behind. Option A (the upstream provider API) is no longer planned, and neither is a fork of credentialsd.

Constraints on the build:

- The `uhid` device is created by a small privileged helper with its own AppArmor profile; the Agent and the providers stay unprivileged and talk to it over D-Bus ([ADR-0012](0012-dbus-names.md) names).
- Provider logic (TPM, KeePassXC bridge, routing policy) lives in its own crates and does not know about `uhid`, so a different front end can replace it.
- KeePassXC stays across a process boundary (C3).

What B costs, accepted for now: browsers treat the device as a roaming security key and not a platform authenticator, and there is no clean place for per-relying-party routing. Whether that is acceptable for a real release is a question the first test answers. If it is not, a later ADR chooses a platform-authenticator path (an own portal backend, or credentialsd if it supports Linux Hello by then).

[credentialsd#26](https://github.com/linux-credentials/credentialsd/issues/26) is no longer on the critical path. The offer made there on 2026-11-01 is not pursued, and no answer is awaited.

Work that does not depend on the provider path continues as before: routing policy, PIN and TPM root key (spike on in-place auth change), PAM and Agent, Plasma prompts.

## Consequences

**Easier:** nothing upstream is on the critical path; the TPM provider can be tried end to end with stock browsers soon; Linux Hello controls its own release timing.

**Harder:** a privileged `uhid` helper enlarges the attack surface and needs confining; the device is a roaming key to browsers, so platform-authenticator behaviour and per-relying-party routing are not available; Linux Hello does its own CTAP handling; constraints C1, C2 and C4 no longer describe the provider path; a later move to a platform authenticator costs a migration; the KDE portal backend remains a separate gap, owned by the Plasma spikes.
