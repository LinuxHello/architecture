---
type: spike
subject: Privilege and attack surface of the uhid helper
artifact: spike
status: answered
owner: "@atterdag"
concepts: [uhid, helper, apparmor, udev, libinput, attack-surface, virtual-ctap]
tags: [spike, m0, security]
sources: ["0094-virtual-ctap-end-to-end.md", "https://www.kernel.org/doc/html/latest/hid/uhid.html", "../adr/0005-provider-path.md"]
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/121
---

# Spike: Privilege and attack surface of the uhid helper

## Question

What does the `uhid` helper cost in privilege and attack surface, and can it run confined: its own user, an AppArmor profile and no more device access than `/dev/uhid` and the Agent's socket?

## Time box

Proposed two working days; done in one session.

## Method

The test VM (Ubuntu 24.04.5, kernel 6.8, AppArmor, systemd 255). Script: `make vm-test-uhid` in `linux-hello-workstation` (`scripts/vm-test-uhid.sh`), **tested** on 2026-11-08, twice in a row with the same result. A small Rust program (`scripts/uhid-probe.rs`, standard library only, built static with `rustc`) stands in for the helper (`fido`) and for a compromised one (`keyboard`, `swap`). It speaks no CTAP: the question is what the process can reach, not what it answers.

## Evidence

All checks passed (`ALL PASSED`):

1. **Default.** `/dev/uhid` is `root:root` mode 0600; an unprivileged user cannot create a device.
2. **Minimal grant.** One udev rule, `KERNEL=="uhid", GROUP="lhctap", MODE="0660"`, gives the helper's group the device and nobody else; the unprivileged helper then creates a FIDO device that `fido2-token -L` lists.
3. **AppArmor profile.** A profile that grants only `/dev/uhid rw` plus the base abstraction and denies network, capabilities, ptrace, `/home/**` and `/root/**`: the helper runs in enforce mode (`lh-uhid-probe (enforce)`), still creates its device, and the same binary run as root is denied `/dev/tpmrm0`, `/home/lh/.bashrc`, `/etc/shadow` and any network socket. The denials appear in the kernel log.
4. **Systemd sandbox.** `DevicePolicy=closed` with `DeviceAllow=/dev/uhid rw`, `PrivateNetwork=yes`, `NoNewPrivileges=yes`, `ProtectHome=yes`, `ProtectSystem=strict` and an empty capability set still lets the helper create its device.
5. **What a compromised helper can still do.** The kernel does not look at the report descriptor, so the profile cannot tell a security key from a keyboard:
   - a second device on a live file descriptor is refused, but after `UHID_DESTROY` a different device can be created on the same descriptor, so passing in an already-created descriptor does not remove the capability;
   - a boot-keyboard device under the profile appears as an input device (`ID_INPUT_KEYBOARD=1`) and is tagged for the seat (`CURRENT_TAGS=:seat:`), which makes it a keyboard for the desktop session.
6. **Mitigation outside the helper.** A udev rule `72-lh-uhid-no-input.rules` for `SUBSYSTEM=="input"` with `DEVPATH=="*/virtual/misc/uhid/*"` clears the `ID_INPUT*` properties, sets `LIBINPUT_IGNORE_DEVICE=1` and removes the `seat`, `uaccess` and `power-switch` tags. With it, the same keyboard is ignored by libinput and is off the seat. The FIDO device is unaffected: it is a `hidraw` device and has no input node.

## Answer

**Partly.** The helper can be confined to what the Agent's profile style already does, and a compromised helper can no longer type into a session if the udev rule is shipped; it still can create any other HID device the kernel accepts.

- **Privilege needed:** the right to open `/dev/uhid` (a group on one udev rule, not root) and the Agent's socket. It needs no TPM access: the Agent holds the keys, the helper relays CTAP messages.
- **Confinement that works:** dedicated user, the udev grant, an AppArmor profile (`/dev/uhid rw`, nothing else), the systemd settings above.
- **Cannot be closed by the profile:** the choice of descriptor. Mitigated, not removed, by the input rule, which covers every input device made through `uhid` (keyboard, pointer, gamepad); a `hidraw` device that is not an input device, such as a second, fake security key, is not covered.
- **Not tested:** the real helper (CTAPHID, the Agent connection), Ubuntu 26.04, a graphical session with a real libinput consumer, other distributions, and whether a hardened kernel (`kernel.modules_disabled`, Lockdown) changes `/dev/uhid` access.

Consequences for the design: the `Virtual CTAP Authenticator` container gets its own user and profile like the Agent; the package ships both udev rules; section 8 lists the helper as a threat (below). The helper must not be given access to the TPM or the user's files.
