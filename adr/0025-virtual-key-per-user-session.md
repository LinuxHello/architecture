---
type: adr
subject: The virtual security key belongs to one user and exists only while that user's session is in front and unlocked
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [virtual-ctap, uhid, hidraw, udev, uaccess, logind, seat, session, fast-user-switching]
tags: [adr, security, virtual-ctap]
sources: ["0005-provider-path.md", "0014-agent-bus.md", "0017-browser-path.md", "0020-presence-and-verification.md", "../spikes/0121-uhid-helper-privilege.md", "../spikes/0138-virtual-ctap-session-binding.md", "../spikes/0177-prompt-identity-in-the-users-session.md", "../arc42/08-security.md", "https://github.com/LinuxHello/linux-hello/issues/138"]
date: 2026-11-18
---

# ADR-0025: One virtual security key per user and active session

## Status

Proposed, 2026-11-18. Records the design that [spike 0138](../spikes/0138-virtual-ctap-session-binding.md) tested, and answers [linux-hello#138](https://github.com/LinuxHello/linux-hello/issues/138). It amends [ADR-0017](0017-browser-path.md), which made the virtual security key the only way browsers reach Linux Hello in version 1.0. The name of the udev rule file and the convention for the device's `uniq` field become something packages and other programs rely on, so changing them later is hard; that is why this needs the maintainer's decision.

## Context

Linux Hello lets a person sign in to websites with a [passkey](../arc42/12-glossary.md#passkey) that is kept in the computer's security chip. Browsers already know how to use a USB [security key](../arc42/12-glossary.md#security-key), so Linux Hello pretends to be one ([ADR-0005](0005-provider-path.md), [ADR-0017](0017-browser-path.md)). A small program, the [uhid helper](../arc42/12-glossary.md#uhid-helper), creates a security key in software through [`/dev/uhid`](../arc42/12-glossary.md#uhid), a Linux interface for making such devices. The kernel then shows the device to browsers as a file such as `/dev/hidraw0` (a [hidraw](../arc42/12-glossary.md#hidraw) node), exactly as it would show a real key that was plugged in. The [Agent](../arc42/12-glossary.md#agent), the Linux Hello background service that makes every decision, holds the keys and answers what the browser asks through that device.

**The problem: two people on one computer.** Linux lets several people be logged in on the same screen at once: Alice has a session, Bob logs in from the lock screen, and Alice's session stays alive in the background. This is called [fast user switching](../arc42/12-glossary.md#fast-user-switching). With the system's stock rules, a security-key file is given to whoever is in front on the [seat](../arc42/12-glossary.md#seat) (the screen, keyboard and mouse one person sits at). That is done by the [`uaccess`](../arc42/12-glossary.md#uaccess) tag, which [udev](../arc42/12-glossary.md#udev), the service that creates device files, puts on the file, and which tells [logind](../arc42/12-glossary.md#logind), the service that tracks logins, to give the user in front permission to open it. Spike 0138 showed that a virtual key made for Alice could be opened by Bob while Bob was in front. Bob would then reach the key that Alice had unlocked, with only a prompt in the way, and that prompt might even appear in Alice's session instead of his.

The kernel does not tell the helper which program opened the device file, so the helper alone cannot refuse Bob. The answer has to come from who may open the file and from when the file exists.

**Why decide now.** Nothing about the virtual key is built yet beyond the prototype of [spike 0094](../spikes/0094-virtual-ctap-end-to-end.md). The helper, the Agent's side and the package all depend on this answer, and the threat "another user on the same computer uses the virtual security key" in [section 8](../arc42/08-security.md#threats-to-design-against) has no decided answer until this ADR is accepted.

| Option | What it means | Why it was or was not chosen |
| :-- | :-- | :-- |
| **A. One key per user, only while that user's session is in front and unlocked** | A udev rule gives the device file to one user; the Agent creates the device when that user's session is in front and unlocked, and removes it otherwise | Chosen. Spike 0138 tested every part of it on a machine with two sessions on one seat |
| B. One shared key; the prompt decides whose keys it serves | The device file stays with whoever is in front, and the Agent works out from the prompt who is asking | The Agent would have to trust the prompt to say which user is asking, which [spike 0177](../spikes/0177-prompt-identity-in-the-users-session.md) found it must never do; and Bob could still send requests to Alice's unlocked key |
| C. No virtual key while more than one person is logged in | Turn the feature off on shared computers | Safe but surprising: passkeys would stop working whenever someone else is logged in in the background |

## Decision

**A virtual security key belongs to exactly one user and exists only while that user's session is in front on its seat and not locked.** Concretely:

1. **The helper names the user in the device.** When it creates the device, the uhid helper writes the user's number into the device's `uniq` field (a free text field every HID device has) as `linuxhello-uid-<uid>`, for example `linuxhello-uid-1000`. The kernel passes the field to udev.
2. **A udev rule gives the device file to that user only.** Linux Hello ships the rule file `71-lh-session-key.rules`. It matches the virtual key by its `uniq` field, sets the owner of the hidraw file to that user number, sets the mode to `0600` (only the owner may read and write) and removes the `uaccess` tag. The file name puts the rule after the stock file `70-uaccess.rules`, which adds the tag; a rule that ran earlier would have to clear the property `ID_SECURITY_TOKEN` instead, and that also removes the tags that the snap packages of Firefox and Chromium need to open a security key. So the rule must run after the stock rules and must keep `ID_SECURITY_TOKEN`.
3. **The Agent decides when the device exists.** The Agent listens to logind on the D-Bus system bus. It asks the helper to create the device when a user's session becomes the one in front on its seat and is not locked. It asks the helper to remove the device when that session locks (logind's `LockedHint` property, which the screen locker sets), leaves the front, or ends. A user always has at most one device.
4. **A failure removes the device.** The kernel destroys a uhid device as soon as the program that created it closes `/dev/uhid`, so a crash of the helper removes it. When the Agent starts, or restarts after a crash, it creates no device until it has read the current state from logind.
5. **No seat, no device.** At the login screen no user has a session yet, and a remote session over `ssh` has no seat, so in neither case does the Agent create a device.
6. **The prompt goes to the owner.** The Agent shows the presence and verification prompt of [ADR-0020](0020-presence-and-verification.md) in the session of the user named in the device, because it learns that user from the same number.
7. **A new security property.** "A virtual key's device file is owned by exactly one user and exists only while that user's session is in front and unlocked." Its tests are named after the checks of spike 0138: `with_the_rule_the_user_in_front_on_the_seat_cannot_open_another_users_key`, `the_node_is_still_a_security_token_for_snap_browsers`, and a test that the device is gone after the owner's session locks or switches away.

*Example.* Alice is signed in and unlocked, so her virtual key exists and belongs to her. She locks the screen and Bob signs in on the same computer. Within a tenth of a second of Alice's lock (0.04 s in the spike), her device is gone. When Bob's session comes to the front, the Agent creates a new device that belongs to Bob and serves only Bob's passkeys. Bob never sees Alice's key, and Alice's browser tabs, running in the background, see no key at all until she is back in front and unlocked.

## Consequences

**Easier:**

- Each user only ever sees their own key, so the Agent never has to guess whose passkeys a request is for.
- Locking the screen also takes the key away: a program left running in the background cannot use it while the user is away.
- The rule relies only on udev and logind, which every systemd-based distribution has.

**Harder:**

- The Agent must listen to logind. Its D-Bus policy and its AppArmor profile need a rule that allows this, which spike 0138 did not test.
- A browser tab that is waiting for a security key when the session locks loses the device and its request fails; the user starts again after unlocking.
- The race between "session comes to the front" and "device created" was not measured, only the removal was. A website that asks in that moment may briefly see no key.
- Distributions without logind, for example those using `elogind`, or whose stock rule file is not called `70-uaccess.rules`, need the rule checked or adapted. Only Ubuntu 24.04 was tested.
- Not tested yet: the real helper and Agent (a probe and a short Python program stood in for them), the Plasma screen locker setting `LockedHint` in a graphical session, and a real passkey sign-in in the snap browsers.

## What exists today

Decided in this ADR, not built: the helper, the rule file and the Agent's logind listener. Tested in a virtual machine with stand-ins: every step above, in spike 0138.
