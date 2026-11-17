---
type: architecture
subject: "Arc42 section 11: risks and technical debt of Linux Hello (open questions)"
artifact: arc42-11-risks-and-technical-debt
status: draft
owner: "@atterdag"
concepts: [risks, open-questions, spikes, arc42]
tags: [architecture, arc42]
sources: ["README.md", "../spikes/README.md", "https://docs.arc42.org/section-11/"]
date: 2026-11-08
---

# 11. Risks and technical debt

Part of the [Arc42 architecture documentation](README.md). Unverified assumptions are answered by the spikes in [docs/spikes/](../spikes/README.md); implementation that depends on an open spike waits for it.

## Open questions

- Maturity and API of credentialsd and its portal on KDE Plasma — [spike 0005](../spikes/0005-credentialsd-provider-api.md): v0.3.1 has **no third-party provider API** (upstream issue is a stub) and no KDE portal backend. [ADR-0005](../adr/0005-provider-path.md) (revised 2026-11-08) does not wait for credentialsd: providers sit behind a virtual CTAP authenticator (option B) for a fail-fast end-to-end test. Browsers see a roaming key, not a platform authenticator; moving to a platform authenticator later is technical debt. A prototype ran end to end with Chromium and Firefox in a test machine ([spike 0094](../spikes/0094-virtual-ctap-end-to-end.md)).
- Whether Firefox and Chromium on Linux call a portal WebAuthn API today — [spike 0006](../spikes/0006-browser-webauthn-portal.md): **No** in current source (Firefox 161.0a1, Chromium main). With the virtual CTAP authenticator stock browsers reach Linux Hello as a USB security key ([spike 0094](../spikes/0094-virtual-ctap-end-to-end.md), [ADR-0017](../adr/0017-browser-path.md)); the own extension of ADR-0013 is superseded. Resident keys, user verification and presence work through it, also in Chrome and in the Snap packages of Chromium and Firefox ([spike 0120](../spikes/0120-resident-keys-presence-and-uv.md)), and [ADR-0020](../adr/0020-presence-and-verification.md) decides the rules. Still untested: Flatpak browsers, a real relying party, a hardware TPM and a Wayland session.
- Claude Desktop token lifetime and storage backend (KWallet vs libsecret) — observed by operator, not measured.
- Classification rule for which accounts must be device-bound — needs a data-classification rule.
- How a fingerprint or face match is tied to the TPM, so that unlocking is not just a flag in the Agent: [linux-hello#136](https://github.com/LinuxHello/linux-hello/issues/136), which blocks the TPM provider.
- What proves to the Agent that the presence prompt in the user's session is its own: a spike, [linux-hello#177](https://github.com/LinuxHello/linux-hello/issues/177).

The user-experience questions (Howdy's interfaces, third-party prompts, the Users page) are answered by spikes [0008](../spikes/0008-howdy-interface.md), [0009](../spikes/0009-plasma-prompt-component.md) and [0010](../spikes/0010-kcm-users-extension-point.md); what remains is recorded in [section 8, User experience](08-crosscutting-concepts.md#user-experience).

## Risk register and technical debt

The risks found by the spikes are rated in words from the evidence in each spike. The risks recorded as issues in the code repository carry the severity given in the issue. The list is not complete: the consequences in [section 4](04-solution-strategy.md#46-what-this-strategy-makes-easier-and-harder) and the threats in [section 8](08-crosscutting-concepts.md#threats-to-design-against) are further inputs.

| Risk | Source | Rating | Mitigation or next step |
| :-- | :-- | :-- | :-- |
| Browsers treat the virtual device as a roaming key; no per-relying-party routing from the client | [ADR-0005](../adr/0005-provider-path.md) | Low: it works end to end with stock browsers ([spike 0094](../spikes/0094-virtual-ctap-end-to-end.md), [spike 0120](../spikes/0120-resident-keys-presence-and-uv.md)) | Accepted for 1.0; routing is decided in the Agent from the relying-party id. Recorded below as technical debt |
| A privileged `uhid` helper enlarges the attack surface | ADR-0005 | Medium | Own AppArmor profile; Agent and providers stay unprivileged |
| The name "Linux Hello" shares "Hello" with Microsoft's WINDOWS HELLO registrations in the same goods | [spike 0014](../spikes/0014-name-trademark-risk.md) | Moderate; not legal advice | Trade mark attorney review before the first release; fallbacks Lychgate and Thresholdkey; the D-Bus prefix and crate names are the cost of a later rename |
| Howdy gives no preview or detection results, and its `master` beta may change the contract | [spike 0008](../spikes/0008-howdy-interface.md) | Medium | [ADR-0015](../adr/0015-face-capture-and-enrolment.md): call Howdy as it is, no live preview in 1.0; a test pins the subprocess contract; a preview needs an upstream change |
| No prompt slot in the login manager or lock screen; the lock screen differs between Plasma 6.6 and 6.8 | [spike 0009](../spikes/0009-plasma-prompt-component.md) | Medium | [ADR-0016](../adr/0016-prompt-hosts.md): shared QML module, own SDDM theme, stock lock-screen services (text only; face needs 6.8) |
| Face and PIN entries cannot sit on the Users page | [spike 0010](../spikes/0010-kcm-users-extension-point.md) | Low | Own settings page next to Users |
| An old root-key blob plus the old PIN still unlocks after a PIN change | [spike 0011](../spikes/0011-tpm-root-key-change-auth.md) | Medium | Delete the old blob; consider a counter policy; re-run on a hardware TPM |
| The virtual security key is visible to every user on the seat; nothing yet decides whose keys it serves with two sessions, or which session shows the prompt | [linux-hello#138](https://github.com/LinuxHello/linux-hello/issues/138) | High (issue) | Bind the device to one user and one active session; to be decided before the TPM provider serves keys |
| A biometric match is a yes or no from a program, which no TPM can check | [linux-hello#136](https://github.com/LinuxHello/linux-hello/issues/136) | Blocks the TPM provider (issue) | An ADR and a spike compare the options |
| Any program of the user can replace the user's policy layer, without a fresh verification, and lock the user out of every context | [linux-hello#131](https://github.com/LinuxHello/linux-hello/issues/131) | Medium (issue) | A verification before a policy change; the stored layer can already never lower an admin rule ([ADR-0018](../adr/0018-user-policy-layer.md) amendment, proposed) |
| A new account that reuses a deleted account's uid inherits its policy layer and, later, its key blobs | [linux-hello#143](https://github.com/LinuxHello/linux-hello/issues/143) | Low (issue) | Record the identity beside each state directory and quarantine on a mismatch; purge state of removed users |
| Face recognition needs a root helper for enrolment and runs Howdy's Python matcher on the login path; `face_requires_ir` cannot be checked | [linux-hello#141](https://github.com/LinuxHello/linux-hello/issues/141), [spike 0008](../spikes/0008-howdy-interface.md) | Medium (issue) | Specify and confine the helper; run the matcher unprivileged in a sandbox; enforce or drop `face_requires_ir` |
| Under X11 another program of the user can read a PIN typed into the prompt | [ADR-0020](../adr/0020-presence-and-verification.md) | Not rated | Prefer the sensor; documented, not prevented; Wayland is tested before 1.0 |
| When Linux Hello is unavailable, the account password alone logs in, also in a context the policy says needs two factors | [ADR-0023](../adr/0023-pam-module-and-login-failure.md) | Not rated | Accepted so that a broken Linux Hello never locks the user out; the password never unlocks the TPM keys |
| Only a software TPM and only Ubuntu with AppArmor have been tested | [section 7](07-deployment-view.md#74-not-yet-covered) | Not rated | Run the spikes again on a hardware TPM; decide the supported distributions (Fedora uses SELinux) |
| RGB and IR streams start unreliably together (one camera model tested) | [spike 0012](../spikes/0012-camera-rgb-ir-concurrent.md) | Low in 1.0 | Howdy alone holds the IR stream while it captures ([ADR-0015](../adr/0015-face-capture-and-enrolment.md)); test a second camera before any preview is built |

### Technical debt

| Debt | Why it was taken on | What paying it back means |
| :-- | :-- | :-- |
| Browsers show Linux Hello as a security key, not as "this device" | A virtual security key works with every browser today, without an upstream change ([ADR-0005](../adr/0005-provider-path.md)) | A platform-authenticator path once the desktop offers one |
| Part of the confinement checks still runs by hand from the maintainer's private repository | They were written for a test VM first | Run all of them in CI ([linux-hello#149](https://github.com/LinuxHello/linux-hello/issues/149); the first part runs since [linux-hello#239](https://github.com/LinuxHello/linux-hello/pull/239)) |
| The policy engine reads and parses every policy file on each decision | Simple and correct first | Keep the effective policy in memory and reload it on change ([linux-hello#151](https://github.com/LinuxHello/linux-hello/issues/151)) |
| The amendment of [ADR-0018](../adr/0018-user-policy-layer.md) (2026-11-10) is still proposed, but the policy semantics in the code repository already follow it | The code needed the rule before the decision was formally taken | Accept the amendment or change the code |
| [ADR-0008](../adr/0008-code-documentation-mapped-to-c4.md) and [ADR-0010](../adr/0010-arc42-architecture-documentation.md) are still proposed, although the project works by them (doc comments name their C4 element and CI checks it; these notes follow Arc42) | They were never formally accepted | Accept them, or record why not |
