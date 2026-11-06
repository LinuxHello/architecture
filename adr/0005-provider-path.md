---
type: adr
subject: How the TPM provider and the KeePassXC bridge attach while credentialsd has no provider API
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [credentialsd, provider-api, upstream, tpm, keepassxc]
tags: [adr, upstream]
sources: ["../spikes/0005-credentialsd-provider-api.md", "../arc42/02-constraints.md", "https://github.com/linux-credentials/credentialsd/issues/26"]
date: 2026-11-07
---

# ADR-0005: How providers attach while credentialsd has no provider API

## Status

Accepted, 2026-11-01 (option A). Revised 2026-11-07: option D, with a trigger to return to A (see Decision).

## Context

[Spike 0005](../spikes/0005-credentialsd-provider-api.md) answered No: credentialsd v0.3.1 has no interface for third-party credential providers, and no KDE portal backend. Its authenticators (hybrid, NFC, USB) are compiled into the daemon. The credentialsd maintainer has drafted a provider API in [credentialsd#26](https://github.com/linux-credentials/credentialsd/issues/26): a `CredentialProvider` interface credentialsd calls, a `CredentialProviderManager` providers register with, a privileged interface so only a trusted settings app enables providers, and a Noise-protected channel. No implementation exists.

Constraint C1 assumed Linux Hello only adds providers to an existing API. Both the TPM provider and the KeePassXC bridge are blocked until one of the options below is chosen. KeePassXC is GPL, so it must stay across a process boundary whatever the choice (C3).

The options:

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. Contribute the provider API upstream**, starting from the maintainer's draft in #26, then build both providers against it | Keeps C1 and C4; one mechanism for TPM and KeePassXC; KeePassXC stays out of process; the trusted-registration design matches our threat model; other password managers benefit | Critical path runs through upstream review and release; the Noise handshake and registration add design work; credentialsd is pre-release, so the API can still move |
| **B. Virtual CTAP authenticator** (`uhid`) backed by the TPM or KeePassXC, as kpasskey and tpm-fido do | Works with unmodified browsers today; reachable through credentialsd's USB transport too (assumption, untested) | Browsers treat it as a roaming security key, not a platform authenticator; creating `uhid` devices needs privilege, enlarging the attack surface; no clean place for per-relying-party routing; a second mechanism to retire later |
| **C. In-process backends contributed to credentialsd** | TPM as a first-party platform authenticator fits credentialsd's own "nice-to-have" goal | Impossible for KeePassXC (GPL, C3); puts our TPM code under upstream's LGPL-3.0-only and release cycle; still needs A for KeePassXC |
| **D. Own broker or a fork** | Full control; the TPM provider and the KeePassXC bridge do not wait for upstream review or a release; can be replaced by A later | Breaks C1 and C4 while it is in force; duplicates upstream's CTAP and portal work; a fork must track credentialsd, which is pre-release |

## Decision

**Option D, for now.** Linux Hello builds its own broker, or a fork of credentialsd, so that the TPM provider and the KeePassXC bridge are not blocked on upstream. Option A, which this ADR first chose on 2026-11-01, stays the intended end state: if credentialsd later gains a provider API that Linux Hello can use, Linux Hello moves to it and retires the broker or fork. That change needs a new ADR that supersedes this one.

Return to A when **both** hold:

- credentialsd ships a third-party provider API (the `CredentialProvider` and `CredentialProviderManager` design in [credentialsd#26](https://github.com/linux-credentials/credentialsd/issues/26), or its successor) in a release, and
- that API can carry the TPM provider and the KeePassXC bridge across a process boundary (C3).

Build D so that return stays cheap: keep the provider logic (TPM, KeePassXC bridge, routing policy) in its own crates behind an interface shaped like the #26 draft, and keep the broker or fork thin. Keep **B** (a virtual CTAP authenticator) off the product path.

Upstream engagement started on 2026-11-01 with an offer to implement the draft and three questions on design, PR sequencing and an in-tree TPM authenticator ([comment on credentialsd#26](https://github.com/linux-credentials/credentialsd/issues/26#issuecomment-6559782108)). That offer stands. The answer is recorded here when it arrives.

While D is in force, constraints C1 and C4 in [arc42 section 2](../arc42/02-constraints.md) do not hold for the provider path. A fork of credentialsd stays LGPL-3.0 and is published, so C2 and C5 are unaffected.

Work that does not depend on the provider path continues as before: routing policy, PIN and TPM root key (spike on in-place auth change), PAM and Agent, Plasma prompts.

## Consequences

**Easier:** the TPM provider and the KeePassXC bridge can be built now; Linux Hello controls the interface and its release timing; moving to upstream later stays possible.

**Harder:** Linux Hello owns the broker or fork and must keep up with credentialsd and libwebauthn changes; CTAP and portal work is partly duplicated; C1 and C4 need an exception recorded in the constraints; the KDE portal backend remains a separate gap, owned by the Plasma spikes; a later move to A costs a migration.
