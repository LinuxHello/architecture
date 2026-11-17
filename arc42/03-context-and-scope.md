---
type: architecture
subject: "Arc42 section 3: context and scope of Linux Hello (the people and programs around it, what it uses each for, and how it reaches them)"
artifact: arc42-03-context-and-scope
status: active
owner: "@atterdag"
concepts: [c4, system-context, arc42, interfaces]
tags: [architecture, arc42, c4]
sources: ["README.md", "12-glossary.md", "../workspace.dsl", "../adr/0003-destructive-reset.md", "../adr/0005-provider-path.md", "../adr/0015-face-capture-and-enrolment.md", "../adr/0016-prompt-hosts.md", "../adr/0017-browser-path.md", "../adr/0018-user-policy-layer.md", "../adr/0021-pin-transport.md", "../adr/0023-pam-module-and-login-failure.md", "../spikes/0008-howdy-interface.md", "../spikes/0012-camera-rgb-ir-concurrent.md", "../spikes/0121-uhid-helper-privilege.md", "../spikes/0138-virtual-ctap-session-binding.md", "https://docs.arc42.org/section-3/"]
date: 2026-11-17
---

# 3. Context and scope

Part of the [Arc42 architecture documentation](README.md).

This section answers two questions: where does Linux Hello end, and what is around it? Linux Hello is an integration layer. It adds a few programs of its own and reuses many that Linux already has: the fingerprint service, the face-recognition program, the security chip, the sign-in framework, the browsers. [Section 1](01-introduction-and-goals.md) says why. This section names every one of those outside programs, says what Linux Hello uses it for, and says how the two talk to each other. [Section 5](05-building-block-view.md) then opens Linux Hello itself and shows its parts. Terms that may be new to you are in the [glossary](12-glossary.md).

The section has two halves, as Arc42 asks:

- [3.1 Business context](#31-business-context): who and what Linux Hello deals with, and for what purpose, without technical detail.
- [3.2 Technical context](#32-technical-context): the actual channel to each of them: a file, a socket, a message bus, a library.

[3.3](#33-what-is-not-in-scope) closes with what Linux Hello deliberately does not do.

## 3.1 Business context

### The people

Two kinds of people use Linux Hello:

- The **desktop user** signs in to the computer, unlocks the screen, confirms `sudo`, signs in to websites and apps with [passkeys](12-glossary.md#passkey) (sign-in keys that replace passwords), and sets up a PIN, a fingerprint and the face.
- The **administrator** sets rules for every user of the computer, such as the minimum PIN length or which websites must keep their passkeys in the security chip, and can confirm, with their own password, the reset of a user who forgot their PIN; the user's own account password can confirm it too ([ADR-0003](../adr/0003-destructive-reset.md)). On a personal computer the user and the administrator are the same person.

### The diagram

The diagram below is the outermost view of the [C4 model](12-glossary.md#c4-model): Linux Hello as one white box, the people who use it, and the outside programs it deals with as grey boxes. Each arrow says in words what one asks of the other. It is generated from [workspace.dsl](../workspace.dsl) and never drawn by hand ([how](../diagrams/README.md)).

![C4 system context view of Linux Hello: the desktop user and the administrator; Linux Hello in the middle; around it the login screen, lock screen, browsers, apps and websites that ask for a sign-in, the fingerprint service, Howdy and the camera that check the user, the TPM and KeePassXC that keep keys, and the Linux services it runs on](../diagrams/Context.svg)

Notice two things. First, Linux Hello never talks to a website: the browser does, and Linux Hello only talks to the browser, the way a USB security key would. Second, Linux Hello holds no private keys of its own; they stay in the TPM or in KeePassXC. The diagram is wide because the layout is automatic; open the image on its own to zoom.

### The outside programs

The table groups the outside programs by what they do for Linux Hello. "Needed" says whether Linux Hello works without the program: **always** means Linux Hello cannot work without it, **for one method** means only one way of signing in depends on it, and **optional** means a feature is missing without it but nothing breaks.

| Outside program | What it is | What Linux Hello uses it for | Needed |
| :-- | :-- | :-- | :-- |
| **Where a sign-in is asked for** | | | |
| Login screen ([SDDM](12-glossary.md#login-manager-greeter)) | The program that shows the user list when the computer starts | Shows Linux Hello's prompt in a theme of Linux Hello's own, and asks Linux Hello, through PAM, whether the user may sign in ([ADR-0016](../adr/0016-prompt-hosts.md)) | For the login screen |
| Lock screen ([kscreenlocker](12-glossary.md#kscreenlocker)) | KDE's screen locker | Asks through PAM, as it already does for fingerprints; Linux Hello adds no window of its own there ([ADR-0016](../adr/0016-prompt-hosts.md)) | For the lock screen |
| [Browsers](12-glossary.md#webauthn) | Firefox and Chromium | Send passkey requests to Linux Hello as if it were a USB security key ([ADR-0017](../adr/0017-browser-path.md)) | For passkeys |
| [Native and Electron apps](12-glossary.md#electron-app) | Desktop apps, such as Claude Desktop, that sign in through a passkey | The same as browsers | Optional |
| [Relying parties](12-glossary.md#relying-party) | The websites and identity providers the user signs in to | Linux Hello never reaches them; they ask the browser, the browser asks Linux Hello | — |
| **What checks the user** | | | |
| [fprintd](12-glossary.md#fprintd) | The Linux service that reads fingerprint sensors | Checks a fingerprint when the Agent asks | For the fingerprint |
| [Howdy](12-glossary.md#howdy) | A program that recognises a face with an infrared camera | Checks a face when the Agent asks; records a face during setup ([spike 0008](../spikes/0008-howdy-interface.md), [ADR-0015](../adr/0015-face-capture-and-enrolment.md)) | For the face |
| Camera | A webcam with an [infrared (IR)](12-glossary.md#infrared-ir-camera) sensor | Only Howdy uses it; Linux Hello never opens it | For the face |
| **Where keys are kept** | | | |
| [TPM 2.0](12-glossary.md#tpm-tpm-20) | The security chip in the computer, which never lets a key be copied out | Keeps the user's [root key](12-glossary.md#root-key), which the PIN unlocks, and the device-bound passkeys under it | Always |
| [KeePassXC](12-glossary.md#keepassxc) | A password manager that can also store passkeys | Keeps the portable passkeys that the user wants on other computers too | Optional |
| **What Linux Hello runs on** | | | |
| [Linux-PAM](12-glossary.md#pam) | The framework through which every Linux program that signs someone in asks "is this the right person?" | Loads Linux Hello's PAM module for the login screen, the lock screen and `sudo`; checks the account password before a reset | Always |
| [uhid](12-glossary.md#uhid) and [hidraw](12-glossary.md#hidraw) | The kernel interfaces for creating a device in software and for reading such a device | Create the virtual security key that browsers see ([ADR-0005](../adr/0005-provider-path.md)) | For passkeys |
| [udev](12-glossary.md#udev) and [logind](12-glossary.md#logind) | The services that decide who may open a device file, and that know which user's session is in front and whether it is locked | Make the virtual key belong to one user and exist only while that user's session is active and unlocked ([spike 0121](../spikes/0121-uhid-helper-privilege.md), [spike 0138](../spikes/0138-virtual-ctap-session-binding.md)). Not yet in the C4 model | For passkeys |
| [D-Bus](12-glossary.md#d-bus) system bus | The message channel that programs of every user and of the system share | Carries every request to the Agent except a PIN | Always |
| [systemd](12-glossary.md#systemd-systemd-service) | The program that starts and supervises the services of a Linux system | Starts the Agent, restricts it and restarts it if it hangs ([section 7](07-deployment-view.md)) | Always |
| [AppArmor](12-glossary.md#apparmor) | A kernel feature that limits each program to the files and devices its profile lists | Confines each Linux Hello program; the Agent does not start without its profile | Always |
| KDE System Settings | The settings application of KDE Plasma, which hosts settings pages called [KCMs](12-glossary.md#kcm) | Hosts Linux Hello's own settings page; its Users page enrols fingerprints | For the settings |
| systemd-journald | The system log | Receives the Agent's audit records | Always |
| **Optional and future** | | | |
| [Tetragon](12-glossary.md#tetragon) | A monitor that watches the kernel for suspicious actions | Reports, for example, any program other than Linux Hello opening the TPM | Optional |
| Log stack | A log collector and viewer, for example Alloy, Loki and Grafana | Collects the audit records and Tetragon's reports and raises alerts | Optional |
| Device management | A service that configures many computers centrally, as Microsoft's Intune does for Windows | Would deliver the administrator's policy files. Future | Optional |
| [Secret Service](12-glossary.md#secret-service) ([KWallet](12-glossary.md#kwallet)) | The Linux store for passwords and login tokens | Linux Hello does not use it. Apps keep there the login tokens that a passkey sign-in gives them, which matters for the token problem in [section 4](04-solution-strategy.md#token-reissue-the-claude-desktop-case) | — |

## 3.2 Technical context

The business context says *what* Linux Hello exchanges with each outside program. This half says *how*: through which channel, in which direction, and what crosses it. The channel matters for security, because each one decides who else could listen or pretend to be the other side, and for licensing, because Linux Hello reaches programs under the GPL licence only across a process boundary, never by linking their code ([section 2](02-constraints.md), constraint C3).

The table lists one row per channel. "Started by" says which side opens the conversation. "State" uses the marks of [section 5](05-building-block-view.md#how-this-section-is-organised): built, code not in use, or not built.

| Outside program | Linux Hello part | Channel | What crosses it | Started by | State |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Browsers and apps | Virtual CTAP Authenticator | A virtual HID device: the authenticator creates it through `/dev/uhid`, the browser opens its `hidraw` node | [CTAP2](12-glossary.md#ctap-ctap2) messages in HID reports: create a passkey, sign a challenge, with the website's [relying-party id](12-glossary.md#relying-party) | Browser | Not built; tested in spikes |
| udev | uhid helper | A udev rule shipped with Linux Hello, matched on a field of the virtual device that names the user | Who may open the device node: only the owning user | udev, when the device appears | Not built; tested in [spike 0138](../spikes/0138-virtual-ctap-session-binding.md) |
| logind | Agent | logind's interface on the D-Bus system bus | Which session is in front, and whether it is locked; the Agent creates and removes the virtual key accordingly | Agent | Not built |
| Login screen, lock screen, `sudo` | `pam_linuxhello` | The PAM stack: a file in `/etc/pam.d/` names the module, and the program loads it as a shared library into its own process | A PAM conversation: the user name, messages to show, the typed PIN; the answer is a [PAM return code](12-glossary.md#pam-return-code) | The program | Not built; the `/etc/pam.d/` snippets are built |
| Login screen (SDDM) | Plasma Integration | A theme package that SDDM loads as QML | The theme embeds Linux Hello's prompt, which reads the Agent's state over the system bus | SDDM | Not built |
| Lock screen | PAM configuration; `pam_linuxhello` on Plasma 6.6 | On Plasma 6.8 and later, KDE's own PAM services `kde-face` and `kde-fingerprint`, which Linux Hello configures, one method each; on Plasma 6.6 the `kde` service, in which `pam_linuxhello` runs all methods ([ADR-0016](../adr/0016-prompt-hosts.md)) | Text only: which method runs and its result | Lock screen | Not built |
| KDE System Settings | Plasma Integration | A settings module (KCM), a plugin that System Settings loads | Settings, enrolment and PIN pages, which talk to the Agent over the system bus | System Settings | Not built |
| fprintd | Agent | fprintd's interface on the D-Bus system bus | A request to verify a finger, and the result | Agent | Not built |
| Howdy | Agent | A subprocess: the Agent runs Howdy's compare program and reads only its exit status; enrolment runs the root-only `howdy` command through a helper the Agent owns | Match or no match; no picture | Agent | Not built |
| Camera | (Howdy only) | [Video4Linux (V4L2)](12-glossary.md#v4l2-video4linux), the kernel's camera interface; Howdy holds the infrared stream while it checks a face ([spike 0012](../spikes/0012-camera-rgb-ir-concurrent.md)) | Infrared frames, to Howdy only | Howdy | — |
| TPM 2.0 | Agent, TPM Credential Provider | The device file `/dev/tpmrm0`, the kernel's TPM resource manager, through the `tss-esapi` library | TPM commands; the PIN travels only inside an encrypted, salted session ([ADR-0021](../adr/0021-pin-transport.md)) | Linux Hello | Not built; the Agent's unit already allows the device |
| KeePassXC | KeePassXC Provider Bridge | KeePassXC's browser protocol over a local socket, encrypted with NaCl | Requests to find, use or store a passkey | Bridge | Not built |
| Linux-PAM | Agent (Reset Coordinator) | A PAM conversation the Agent opens itself | The account password, checked before a reset deletes the keys ([ADR-0003](../adr/0003-destructive-reset.md)) | Agent | Not built |
| D-Bus system bus | Agent | The Agent owns the name `io.github.LinuxHello.Agent1`; a policy file says who may own it and who may call it | Every request to the Agent and its answers and signals, except a PIN | Callers | Built |
| systemd | Agent | The unit `linuxhello-agent.service` and the notification socket | Start, restriction, and the watchdog's "still alive" messages | systemd | Built |
| AppArmor | Agent | The profile `linuxhello-agent`, loaded into the kernel in enforce mode | What the Agent may open; the unit checks that the profile is loaded before it starts | Kernel | Built |
| systemd-journald | Agent (Audit Logger) | The journal's native socket | One structured record per refused request and per policy change; never a PIN or a caller's text | Agent | Built |
| Administrator | Agent | The files `/etc/linuxhello/policy.d/*.toml`, owned by root, which the Agent only reads ([ADR-0018](../adr/0018-user-policy-layer.md)) | The admin layer of the policy | Administrator | Built |
| Tetragon, log stack | Security Profiles | Tetragon's tracing policies; the log collector reads the journal | Security events and alerts | Tetragon, collector | Not built |

Two channels are inside Linux Hello and therefore not in this table, but they are where most of its security rules apply: the PAM module, the prompt and the settings reach the Agent over the system bus, and a PIN reaches the Agent only over the Agent's own [PIN socket](12-glossary.md#pin-socket), so that the bus daemon never sees it ([ADR-0021](../adr/0021-pin-transport.md)). [Section 5](05-building-block-view.md) describes both.

## 3.3 What is not in scope

These are left out on purpose, so that a reader does not look for them:

- **No new sign-in method.** Linux Hello reuses fprintd and Howdy and adds none of its own; it only decides when to ask them and what a match unlocks.
- **No sync of passkeys.** A passkey that should move to other computers lives in KeePassXC, which the user syncs as they already do. Linux Hello does not copy keys anywhere.
- **No browser extension and no browser change.** Browsers use Linux Hello as a security key ([ADR-0017](../adr/0017-browser-path.md)). The price is that a browser shows it as "a security key", not as "this device".
- **No replacement for the account password.** The password stays in the PAM stack behind Linux Hello. It works whenever Linux Hello cannot answer ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)), and after a forgotten PIN it is what allows the reset.
- **Other desktops and the newer Plasma Login Manager.** Version 1.0 is for KDE Plasma with SDDM. The Plasma Login Manager, new in Plasma 6.8, has no place for a theme and needs a change in KDE first ([ADR-0016](../adr/0016-prompt-hosts.md)). Other desktops, such as GNOME, are not part of 1.0.
- **Other distributions, for now.** Linux Hello is tested on Ubuntu 24.04 and 26.04, in a virtual machine with a software TPM. Other distributions are planned closer to the first release.
- **Remote sessions.** A session over `ssh` has no [seat](12-glossary.md#seat), so by the design of [spike 0138](../spikes/0138-virtual-ctap-session-binding.md) it gets no virtual key. This was not tested.
