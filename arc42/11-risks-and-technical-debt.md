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

- Maturity and API of credentialsd and its portal on KDE Plasma — [spike 0005](../spikes/0005-credentialsd-provider-api.md): v0.3.1 has **no third-party provider API** (upstream issue is a stub) and no KDE portal backend. [ADR-0005](../adr/0005-provider-path.md) (revised 2026-11-08) does not wait for credentialsd: providers sit behind a virtual CTAP authenticator (option B) for a fail-fast end-to-end test. Browsers see a roaming key, not a platform authenticator; moving to a platform authenticator later is technical debt. Build and run untested.
- Whether Firefox and Chromium on Linux call a portal WebAuthn API today — [spike 0006](../spikes/0006-browser-webauthn-portal.md): **No** in current source (Firefox 161.0a1, Chromium main). With the virtual CTAP authenticator stock browsers reach Linux Hello as a USB security key ([spike 0094](../spikes/0094-virtual-ctap-end-to-end.md), [ADR-0017](../adr/0017-browser-path.md)); the own extension of ADR-0013 is superseded. What remains: resident keys, user verification and presence prompts, and Snap, Flatpak and a real relying party (untested).
- Claude Desktop token lifetime and storage backend (KWallet vs libsecret) — observed by operator, not measured.
- Classification rule for which accounts must be device-bound — needs a data-classification rule.
- Who owns the threat model and the security property list.

The user-experience questions (Howdy's interfaces, third-party prompts, the Users page) are answered by spikes [0008](../spikes/0008-howdy-interface.md), [0009](../spikes/0009-plasma-prompt-component.md) and [0010](../spikes/0010-kcm-users-extension-point.md); what remains is recorded in [section 8, User experience](08-crosscutting-concepts.md#user-experience).

## Risk register and technical debt

Only the risks found by the spikes are listed, with a rating in words from the evidence in each spike. The list is not complete: the consequences in [section 4](04-solution-strategy.md#consequences) and the threats in [section 8](08-crosscutting-concepts.md#threats-to-design-against) are further inputs.

| Risk | Source | Rating | Mitigation or next step |
| :-- | :-- | :-- | :-- |
| Browsers treat the virtual device as a roaming key; no per-relying-party routing from the client | [ADR-0005](../adr/0005-provider-path.md) | High until tested | Spike #94 end to end in the test VM (`make vm-up` in `linux-hello-workstation`) |
| A privileged `uhid` helper enlarges the attack surface | ADR-0005 | Medium | Own AppArmor profile; Agent and providers stay unprivileged |
| The name "Linux Hello" shares "Hello" with Microsoft's WINDOWS HELLO registrations in the same goods | [spike 0014](../spikes/0014-name-trademark-risk.md) | Moderate; not legal advice | Trade mark attorney review before the first release; fallbacks Lychgate and Thresholdkey; the D-Bus prefix and crate names are the cost of a later rename |
| Howdy gives no preview or detection results, and its `master` beta may change the contract | [spike 0008](../spikes/0008-howdy-interface.md) | Medium | [ADR-0015](../adr/0015-face-capture-and-enrolment.md): call Howdy as it is, no live preview in 1.0; a test pins the subprocess contract; a preview needs an upstream change |
| No prompt slot in the login manager or lock screen; the lock screen differs between Plasma 6.6 and 6.8 | [spike 0009](../spikes/0009-plasma-prompt-component.md) | Medium | [ADR-0016](../adr/0016-prompt-hosts.md): shared QML module, own SDDM theme, stock lock-screen services (text only; face needs 6.8) |
| Face and PIN entries cannot sit on the Users page | [spike 0010](../spikes/0010-kcm-users-extension-point.md) | Low | Own settings page next to Users |
| An old root-key blob plus the old PIN still unlocks after a PIN change | [spike 0011](../spikes/0011-tpm-root-key-change-auth.md) | Medium | Delete the old blob; consider a counter policy; re-run on a hardware TPM |
| RGB and IR streams start unreliably together (one camera model tested) | [spike 0012](../spikes/0012-camera-rgb-ir-concurrent.md) | Low in 1.0 | Howdy alone holds the IR stream while it captures ([ADR-0015](../adr/0015-face-capture-and-enrolment.md)); test a second camera before any preview is built |

No technical debt is recorded yet.
