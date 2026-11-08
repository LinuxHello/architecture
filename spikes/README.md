---
type: index
subject: Index of Milestone 0 spikes
artifact: spike-index
status: active
owner: "@atterdag"
concepts: [spikes]
tags: [spike, m0, index]
sources: []
date: 2026-11-07
---

# Spikes

| Spike | Answer | Issue |
| :-- | :-- | :-- |
| [0005: credentialsd provider API and portal on KDE Plasma](0005-credentialsd-provider-api.md) | No, not at v0.3.1; see [ADR-0005](../adr/0005-provider-path.md) | [#5](https://github.com/LinuxHello/linux-hello/issues/5) |
| [0006: Browser WebAuthn through the portal (Firefox, Chromium)](0006-browser-webauthn-portal.md) | Partly: no stock browser calls the portal; only add-ons and an experimental Firefox build | [#6](https://github.com/LinuxHello/linux-hello/issues/6) |
| [0007: PAM module publishes method state over the Agent's D-Bus API](0007-pam-dbus-method-state.md) | Partly: only the system bus is reachable in every PAM context; the Agent must serve the PAM module there (needs an ADR) | [#7](https://github.com/LinuxHello/linux-hello/issues/7) |
| [0013: Licences of libwebauthn, KeePassXC, fprintd and Howdy](0013-upstream-licences.md) | Yes: all fit C2 and C3 | [#13](https://github.com/LinuxHello/linux-hello/issues/13) |
| [0008: Howdy interface for live preview, enrolment and test](0008-howdy-interface.md) | Partly: match as a subprocess, enrolment as a root CLI, no preview or detection results | [#8](https://github.com/LinuxHello/linux-hello/issues/8) |
| [0009: Third-party prompt in the Plasma login manager and kscreenlocker](0009-plasma-prompt-component.md) | Partly: no slot in either; one shared QML module can serve all hosts (needs ADRs) | [#9](https://github.com/LinuxHello/linux-hello/issues/9) |
| [0010: Extension point in KDE's Users settings module](0010-kcm-users-extension-point.md) | No: own settings page next to Users | [#10](https://github.com/LinuxHello/linux-hello/issues/10) |
| [0011: Change the TPM root key's authorisation in place with tss-esapi](0011-tpm-root-key-change-auth.md) | Yes on swtpm, if the root key is a non-primary child; hardware TPM untested | [#11](https://github.com/LinuxHello/linux-hello/issues/11) |
| [0012: Camera streams RGB and IR at the same time](0012-camera-rgb-ir-concurrent.md) | Partly: unreliable together on the BRIO; one camera tested | [#12](https://github.com/LinuxHello/linux-hello/issues/12) |
| [0014: Trademark risk of the name Linux Hello](0014-name-trademark-risk.md) | Partly: moderate risk next to WINDOWS HELLO; not legal advice | [#14](https://github.com/LinuxHello/linux-hello/issues/14) |
| [0031: credentialsd with the patched portal and its GTK backend on Plasma](0031-credentialsd-portal-on-plasma.md) | Not planned: ADR-0005 does not use credentialsd | [#31](https://github.com/LinuxHello/linux-hello/issues/31) |
| [0094: End-to-end passkey through a virtual CTAP authenticator and the TPM](0094-virtual-ctap-end-to-end.md) | Yes for non-resident credentials without user verification: stock libfido2, Chromium 156 and Firefox 157 work; roaming-key presentation; discoverable credentials, UV and presence prompts still to build | [#94](https://github.com/LinuxHello/linux-hello/issues/94) |
| [0119: Binding each TPM credential key to its relying party inside the TPM](0119-rp-bound-credential-keys.md) | Yes on swtpm: the key's authorisation value is HMAC(H, rpIdHash) computed by the TPM, with `noDA` | [#119](https://github.com/LinuxHello/linux-hello/issues/119) |
| [0121: Privilege and attack surface of the uhid helper](0121-uhid-helper-privilege.md) | Partly: confinable to `/dev/uhid`, but the kernel does not restrict the descriptor; a udev rule hides uhid input devices | [#121](https://github.com/LinuxHello/linux-hello/issues/121) |
| [0033: Own browser extension in front of the broker: trusted origin, and native messaging from confined browsers](0033-own-extension-origin-and-confined-native-messaging.md) | Open (source read: Partly; origin solvable by design, confined Firefox needs the native-messaging proxy, untested on Plasma) | [#33](https://github.com/LinuxHello/linux-hello/issues/33) |

New spikes start from [the template](../templates/spike.md). See [index](../README.md).

## What blocks what

An arrow means the spike's answer is needed before the target can be designed or built. Green spikes are answered, amber are open. Targets are containers or features from the [building block view](../arc42/05-building-block-view.md).

```mermaid
flowchart LR
    classDef done fill:#d4edda,stroke:#2d6a3e,color:#111
    classDef open fill:#fff3cd,stroke:#8a6d00,color:#111
    classDef target fill:#eef,stroke:#446,color:#111

    S5["0005 credentialsd provider API"]:::done
    S6["0006 browser WebAuthn portal"]:::done
    S7["0007 PAM and Agent D-Bus"]:::done
    S13["0013 upstream licences"]:::done
    S8["0008 Howdy interface"]:::done
    S9["0009 Plasma prompt component"]:::done
    S10["0010 Users settings extension"]:::done
    S11["0011 TPM root key change auth"]:::done
    S12["0012 RGB and IR camera"]:::done
    S14["0014 name trademark risk"]:::done
    S31["0031 portal on Plasma (not planned)"]:::open
    S33["0033 own extension and native messaging"]:::open

    T1["Provider path (ADR-0005)"]:::target
    T2["Browser fallback decision (#33)"]:::target
    T3["PAM method state, system bus ADR"]:::target
    T4["Face method in pam-linuxhello"]:::target
    T5["Face enrolment wizard"]:::target
    T6["Plasma prompt component and UX2"]:::target
    T7["Settings UI: Face and PIN entries"]:::target
    T8["PIN change in Agent and linuxhello-ctl"]:::target
    T9["Crate and package names ADR (#22)"]:::target
    T10["D-Bus names ADR (#17)"]:::target
    T11["First release"]:::target
    T12["KDE portal backend design"]:::target
    T13["End-to-end tests per provider"]:::target

    S5 --> T1
    S94["0094 virtual CTAP end to end"]:::done
    S94 --> T2
    S94 --> T1
    S5 --> S31
    S6 --> T2
    S33 --> T2
    S7 --> T3
    S7 --> S9
    S8 --> T4
    S8 --> T5
    S12 --> T5
    S9 --> T6
    S10 --> T7
    S11 --> T8
    S14 --> T9
    S14 --> T10
    S14 --> T11
    S31 --> T12
    S31 --> T13
```

Edges come from the *Blocks* and *Why it matters* sections of the issues, plus the follow-up links in [0009](0009-plasma-prompt-component.md), [0031](0031-credentialsd-portal-on-plasma.md) and [0033](0033-own-extension-origin-and-confined-native-messaging.md). Spike 0013 blocks nothing open: it settled the licence boundaries.
