---
type: architecture
subject: "Arc42 section 8, trust chain: what the PIN, the fingerprint, the face and the account password each may unlock in Linux Hello"
artifact: arc42-08-trust-chain
status: active
owner: "@atterdag"
concepts: [trust-chain, pin, tpm, destructive-reset, arc42]
tags: [architecture, arc42, security]
sources: ["08-crosscutting-concepts.md", "12-glossary.md", "../adr/0003-destructive-reset.md", "../adr/0020-presence-and-verification.md", "../spikes/0011-tpm-root-key-change-auth.md", "https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants"]
date: 2026-11-17
---

# 8. Crosscutting concepts: the trust chain

Part of [section 8](08-crosscutting-concepts.md) of the [Arc42 architecture documentation](README.md).

This note answers the question: which proof of identity unlocks what? Linux Hello accepts three proofs, the PIN, a fingerprint or face, and the account password, and they are deliberately not equal. The order between them is called the [trust chain](12-glossary.md#trust-chain), and every part of Linux Hello follows it. After reading this note you know why the PIN matters most, what a fingerprint may and may not do, and why forgetting the PIN deletes the user's passkeys. Terms that may be new to you are in the [glossary](12-glossary.md).

## The chain in three sentences

The **PIN is the root**: it unlocks the user's keys in the TPM, the computer's security chip. A **fingerprint or face is a shortcut**: it saves typing the PIN, but it never replaces it. The **account password is only for a reset**: it can authorise deleting the keys and choosing a new PIN, but it never unlocks a key. This is the same order Windows Hello uses by default.

## Each link of the chain

**The PIN.** When the user first sets up Linux Hello, the TPM creates a [root key](12-glossary.md#root-key) for that user, and the PIN becomes the key's [authorisation value](12-glossary.md#authorisation-value): the TPM uses the root key only when it is given the right PIN. Every passkey the TPM provider creates for that user hangs under the root key, so without the PIN none of them can be used. Because the TPM checks the PIN itself, no program can unlock the keys by setting a flag. Two counters limit guessing: the Agent counts wrong PINs per user and locks that user for a while, and the TPM has its own counter for the whole machine ([anti-hammering](12-glossary.md#anti-hammering)), which the Agent's counter stops a user from reaching. The PIN never leaves the computer.

*Example:* a four-digit PIN sounds weak, but it is useless away from this computer's TPM, and after five wrong tries (the default) the Agent locks the user for 15 minutes ([policy](08-policy.md)).

**A fingerprint or face.** fprintd, the Linux fingerprint service, and Howdy, the Linux face-recognition program, report a match to the Agent. The match confirms the user instead of the PIN, so the user can touch the sensor rather than type. It is never the root: if the sensor fails or is missing, the PIN is always offered. How a match is tied to the TPM is still open: a match is a yes or no from a program, which the TPM cannot check by itself, and the design forbids turning it into a flag in the Agent's memory (invariant 1 of [linux-hello's AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants); [linux-hello#136](https://github.com/LinuxHello/linux-hello/issues/136)).

**Passkeys.** The TPM provider keeps each website's passkey as a key under the root key, and the Virtual CTAP Authenticator offers it to browsers as a USB security key would. A passkey is used only after the user is checked and only to sign; the private key never leaves the TPM.

**The account password, for a reset.** A user who forgets the PIN can reset it with their account password, or an administrator with theirs. The reset deletes the root key and every passkey under it, then lets the user choose a new PIN. The password never unlocks the old keys. Changing the PIN while the user still knows it is not a reset: the TPM changes the root key's authorisation in place and every passkey survives ([spike 0011](../spikes/0011-tpm-root-key-change-auth.md)).

**Recovery.** There is no recovery key. After a reset the user registers a new passkey with each website, through that website's own account recovery or with a second passkey they registered earlier, for example on a USB security key or a phone.

## Why a reset deletes the keys

A gentler reset would need a second way into the root key, such as a recovery key printed on paper. For that, the root key would have to be made outside the TPM or be copyable, which weakens the one property the TPM gives: that the key cannot leave the chip. The decision is recorded as [ADR-0003](../adr/0003-destructive-reset.md). Its cost is that a forgotten PIN means registering passkeys again, which is why the PIN dialog warns before a reset.

## The same chain on Windows

| Link | Linux Hello | Windows Hello |
| :-- | :-- | :-- |
| Root | The PIN is the TPM authorisation of a per-user root key; every passkey hangs under it; the TPM and the Agent limit guessing; the PIN never leaves the computer | The PIN unlocks the TPM-protected Windows Hello container; the TPM limits guessing |
| Shortcut | fprintd or Howdy confirm the user instead of the PIN; never the root; a failure falls back to the PIN. How a match is tied to the TPM is open | The Windows Biometric Framework, with fingerprint and face data kept on the computer only; a match releases the container |
| Passkeys | Kept by the TPM provider, offered through the Virtual CTAP Authenticator | Kept in the Windows Hello container, offered by Windows' own WebAuthn service |
| Reset | The account or administrator password authorises deleting the root key and choosing a new PIN; it never unlocks keys | "I forgot my PIN" signs in to the Microsoft or Entra account again; by default the reset deletes the container |
| Recovery | Through each website: register a new passkey, using its account recovery or a second passkey | The same; Microsoft Entra's non-destructive PIN reset service is the exception |

## What exists today

Code, not in use: the Agent's per-user counter of wrong PINs exists with tests, but nothing calls it yet. Decided, not built: the root key, the PIN check against the TPM, the PIN change and the reset. Open: how a fingerprint or face match is tied to the TPM ([linux-hello#136](https://github.com/LinuxHello/linux-hello/issues/136)).

This chain was first written down as decision LH-1 of the former target architecture; it is now [ADR-0003](../adr/0003-destructive-reset.md).
