---
type: architecture
subject: "Arc42 section 12: glossary of Linux Hello"
artifact: arc42-12-glossary
status: draft
owner: "@atterdag"
concepts: [glossary, arc42]
tags: [architecture, arc42]
sources: ["README.md", "08-crosscutting-concepts.md", "../adr/0020-presence-and-verification.md", "../adr/0023-pam-module-and-login-failure.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/security/threat-model.md", "https://www.w3.org/TR/webauthn-3/", "https://fidoalliance.org/specs/fido-v2.2-ps-20250714/fido-client-to-authenticator-protocol-v2.2-ps-20250714.html", "https://docs.arc42.org/section-12/"]
date: 2026-11-17
---

# 12. Glossary

Part of the [Arc42 architecture documentation](README.md).

This page explains the words the other pages of the architecture use. Linux Hello sits where several fields meet: passkeys on the web, keys kept in a chip, the way Linux logs a person in, and the KDE Plasma desktop. Few readers know all four, so every term that one of those fields takes for granted is explained here in everyday words, with what Linux Hello uses it for.

The terms are in five groups, alphabetical inside each group:

1. [Passkeys and the web](#passkeys-and-the-web): how a website signs a person in without a password.
2. [Keys and the TPM](#keys-and-the-tpm): the chip that keeps keys and the words around it.
3. [The Linux desktop](#the-linux-desktop): the parts of Linux and KDE Plasma that Linux Hello works with.
4. [Linux Hello's own words](#linux-hellos-own-words): the names of its parts and ideas.
5. [Words about the documentation](#words-about-the-documentation): how these notes are organised.

Every term has a heading of its own, so another note can link straight to it, for example `12-glossary.md#relying-party`. A term in *italics* inside an explanation has an entry of its own on this page.

## Passkeys and the web

### Assertion

The answer an *authenticator* gives when a website asks the user to sign in: a signature over a fresh challenge from the website, made with the private key of a *passkey*. The website checks it with the public key it stored when the passkey was created. In *CTAP* the request is called `getAssertion`.

### Authenticator

The thing that holds passkeys and signs with them. It can be built into the computer (a *platform authenticator*, such as Windows Hello) or be a separate device (a *roaming authenticator*, such as a USB security key). Linux Hello is an authenticator: the *Virtual CTAP Authenticator* makes it look like a USB security key to the browser.

### Ceremony

The *WebAuthn* name for one complete exchange between a website, the browser and an authenticator: either creating a passkey (*registration*) or using one to sign in (*assertion*). One ceremony can contain several CTAP requests, which is why Linux Hello takes care to ask the user only once per ceremony ([ADR-0020](../adr/0020-presence-and-verification.md)).

### CBOR

Concise Binary Object Representation, a compact binary format similar to JSON. *CTAP* messages are written in CBOR, so the Virtual CTAP Authenticator has to parse CBOR sent by a browser. Because that input comes from outside, every parser is fuzzed (fed with random and malformed data to find crashes) in the automatic checks that run on every change (CI, continuous integration).

### Credential

The general word for what a website stores to recognise a user. In this architecture it nearly always means a *passkey*: a key pair, its identifier (the *credential id*) and the account it belongs to.

### Credential id

An identifier the authenticator gives to a passkey when it is created. The website stores it and sends it back on the next sign-in so the authenticator can find the right key.

### CTAP, CTAP2

The Client to Authenticator Protocol, published by the *FIDO Alliance*: the language a browser speaks to an authenticator, for example over USB. CTAP2 is its current version. Linux Hello speaks CTAP2, which is why stock Firefox and Chromium can use it without any change.

### DBSC

Device Bound Session Credentials, a draft standard of the W3C (the body that writes web standards), tried out in Chrome. A website gives the browser a short-lived login token and ties it to a key that never leaves the device; the browser renews the token in the background by signing with that key. Linux Hello aims to provide such a key from the TPM, so that an app whose token expires can renew it without asking the user to sign in again ([section 4](04-solution-strategy.md)). Not built.

### Discoverable credential

Also called a *resident key*. A passkey that the authenticator itself remembers together with the account it belongs to, so the user can sign in without typing a user name first: the authenticator offers the accounts it knows for that site. Linux Hello keeps the list of such passkeys in the *Credential Index*.

### FIDO Alliance, FIDO2

The industry group that publishes *CTAP*. FIDO2 is the common name for CTAP2 together with WebAuthn.

### HID

Human Interface Device, the USB device class for keyboards, mice and also security keys. A USB security key talks CTAP inside HID reports, so a browser looks for security keys among the HID devices of the machine. Linux Hello creates such a device in software; see *uhid* and *hidraw*.

### Origin

The scheme, host and port of a web page, such as `https://bank.example`. The browser checks that a page may use a passkey for the *relying party* it names; the authenticator only sees a hash of the relying-party id and must trust the browser for that check.

### Passkey

A key pair that replaces a password for one website or app. The private key stays with the user, in an *authenticator*; the website stores only the public key. To sign in, the website sends a challenge and the authenticator signs it, after the user has shown they are present or has verified with a fingerprint, the face or a PIN. A passkey cannot be phished, because the browser uses it only on the site it was made for, and a leak of the website's database gives away no secret.

### Platform authenticator

An authenticator built into the operating system, such as Windows Hello or Apple's iCloud Keychain. Browsers present it as "this device". Linux has none, and Linux Hello does not become one: browsers see it as a *roaming authenticator*. [ADR-0005](../adr/0005-provider-path.md) explains why.

### Registration

The ceremony that creates a passkey. In *CTAP* the request is called `makeCredential`.

### Relying party

The website or app the user signs in to, which "relies" on the authenticator's answer. It is named by its *relying-party id*, normally its domain, such as `bank.example`. The routing policy of Linux Hello decides per relying party which key provider holds the passkey and how strongly the user is asked (*relying-party class*).

### Relying-party id hash

A SHA-256 hash of the relying-party id, written `rpIdHash` in CTAP. It is what the authenticator receives instead of the name. Linux Hello binds every TPM key to this hash, so a key made for one site cannot sign for another ([spike 0119](../spikes/0119-rp-bound-credential-keys.md)).

### Resident key

The older name for a *discoverable credential*.

### Roaming authenticator

An authenticator that is a device of its own and can be moved between computers, such as a USB security key. Browsers show it as "a security key". This is how Linux Hello appears to browsers, even though its keys stay on the computer.

### Security key

A small USB, NFC or Bluetooth device, such as a YubiKey, that holds passkeys and signs with them. It is the most common *roaming authenticator*, and every major browser supports it. Linux Hello imitates one so that browsers need no change. A real security key remains a fallback key provider.

### User presence (UP)

Proof that a person is at the computer and agreed to this request: in its weakest form a touch on a security key. The authenticator reports it to the website with the UP flag. In Linux Hello, presence must be a gesture that a program in the user's session cannot fake, such as a fingerprint touch or the PIN ([ADR-0020](../adr/0020-presence-and-verification.md)). A browser sometimes sends a request with `up=false`, a silent probe to learn whether a passkey exists; Linux Hello answers it without using the key.

### User verification (UV)

Proof that the person at the computer is the owner, not merely someone present: a fingerprint, a face or a PIN. The authenticator reports it to the website with the UV flag. Linux Hello sets UV only when the check was made for this request or at most 60 seconds before it, so a website is never told "verified" hours after the user last proved who they are ([ADR-0020](../adr/0020-presence-and-verification.md)).

### WebAuthn

Web Authentication, the W3C standard that lets a web page create and use passkeys through the browser. The page calls WebAuthn; the browser then speaks *CTAP* to the authenticator.

## Keys and the TPM

### Anti-hammering

The TPM's protection against guessing: after a number of wrong authorisation values it refuses all tries for a while. The TPM keeps one counter for the whole machine, so Linux Hello also counts each user's wrong PINs itself and stops them before they reach the TPM. Linux Hello never changes the TPM's own settings for this. Also called dictionary-attack protection.

### Authorisation value

A secret that must be given to the TPM before it lets a program use a key, similar to a password for that key. Linux Hello uses the PIN as the authorisation value of the user's *root key*.

### Device-bound key

A key that cannot leave the computer it was made on, because the TPM created it and will not export it. If the computer is lost or its TPM is cleared, the key is gone. Linux Hello keeps passkeys for high-value accounts this way by default. The opposite is a *portable key*.

### HMAC

A keyed hash: a short value computed from a message and a secret key, which only someone with the key can reproduce. Linux Hello sets the authorisation value of each passkey's TPM key to an HMAC of the relying-party id hash, computed inside the TPM, so the TPM itself refuses a request for another site.

### Non-exportable key

A key the TPM will use for signing but never hand out. A program receives signatures, not the key, so even a compromised program cannot copy it.

### Portable key

A key that can be copied to another computer, such as a passkey stored in a KeePassXC database that the user syncs between machines. It survives the loss of one computer, but it is a file protected by software, not by a chip. Linux Hello offers it through the *KeePassXC provider*.

### Root key

In Linux Hello: the one TPM key per user under which all of that user's device-bound passkeys are created. Its authorisation value is the PIN. Changing the PIN changes the authorisation in place and keeps the passkeys ([spike 0011](../spikes/0011-tpm-root-key-change-auth.md)); deleting the root key destroys them all (*destructive reset*).

### TPM, TPM 2.0

The Trusted Platform Module, a chip (or part of the processor's firmware) in most computers made since about 2016. It creates and keeps keys that no software can read out, signs with them on request, and limits how often a wrong authorisation value may be tried. TPM 2.0 is the current version; Windows 11 requires one. Linux reaches it through the device file `/dev/tpmrm0`, and Linux Hello uses it through the `tss-esapi` library. Linux Hello's *TPM provider* keeps passkeys in it.

### TPM policy session

A way to tell the TPM that a key may be used only when stated conditions hold, checked by the TPM itself and not by a program. The threat model relies on it so that a program claiming "the user is unlocked" is not enough to use a key. How a fingerprint match is tied to such a session is still open ([linux-hello#136](https://github.com/LinuxHello/linux-hello/issues/136)).

## The Linux desktop

### AppArmor

A Linux security module that limits what each program may do: which files, devices and sockets it may open, whatever user it runs as. Each rule set is a *profile*. A profile in *enforce* mode blocks what it does not allow; in *complain* mode it only logs. Linux Hello ships a profile in enforce mode for each of its programs, and each program refuses to start if its profile is not enforcing. Ubuntu and openSUSE use AppArmor; Fedora uses SELinux instead, which Linux Hello does not cover yet.

### BPF-LSM

A Linux kernel feature that lets small programs loaded at run time take security decisions. *Tetragon* needs it to block actions and not only report them. It is switched on with an option on the kernel command line.

### D-Bus

The message system that programs on a Linux desktop use to call each other. There are two kinds of bus. The **system bus** is one per machine and connects system services with programs of all users. The **session bus** is one per logged-in user and connects the programs of that session. Linux Hello's Agent is on the system bus, because only the system bus can be reached from every place a PAM module runs, including the login screen and `sudo` ([spike 0007](../spikes/0007-pam-dbus-method-state.md), [ADR-0014](../adr/0014-agent-bus.md)).

### Electron app

A desktop program built from web technology, with its own copy of Chromium inside, such as Slack, Visual Studio Code or Claude Desktop. It signs the user in through a browser window or the system browser, so it uses passkeys in the same way.

### fprintd

The Linux service that reads fingerprint sensors and matches a finger against the fingerprints a user has enrolled. Linux Hello asks it for a match; the fingerprint pictures stay in fprintd and are never copied.

### hidraw

The Linux interface through which a program reads and writes a *HID* device directly. Browsers find security keys through `/dev/hidraw*` devices. The device Linux Hello creates through *uhid* appears there.

### Howdy

A Linux program for face recognition with an infrared camera, similar in idea to Windows Hello's face sign-in. Linux Hello calls its match command as a separate program and its enrolment commands as root ([spike 0008](../spikes/0008-howdy-interface.md)). Howdy has no liveness check, so a good photograph may pass; the policy therefore lets an administrator require more than the face.

### Infrared (IR) camera

A camera that sees infrared light, used for face recognition because a printed photograph looks different in infrared than a real face. Many laptops have one beside the normal (RGB) camera. Howdy uses the IR camera.

### KCM

KDE Configuration Module: one page of KDE's System Settings, usually with its interface written in *QML*. Linux Hello's settings are a KCM of its own, placed next to KDE's Users page, because KDE's Users page has no place where another program can add entries ([spike 0010](../spikes/0010-kcm-users-extension-point.md)).

### KDE Plasma

A desktop environment for Linux: the panel, the windows, the login screen, the lock screen and the settings. Linux Hello is designed for Plasma first; other desktops are later.

### KeePassXC

A free password manager that keeps passwords and, since version 2.7.7, passkeys in an encrypted file (a KDBX database) that the user can sync between machines. It serves passkeys to browsers through its own browser extension. Linux Hello reaches it over that extension's protocol, through a Unix socket, so that its passkeys work outside the browser too.

### kscreenlocker

KDE Plasma's lock screen. Linux Hello does not change it: on Plasma 6.8 and later it shows the text of KDE's own face and fingerprint login services ([ADR-0016](../adr/0016-prompt-hosts.md)).

### KWallet

KDE's store for passwords and tokens, an implementation of the *Secret Service*.

### Login manager, greeter

The program that shows the login screen after boot and starts the user's session. The part the user sees is called the greeter. Plasma uses SDDM, and Plasma 6.8 brought the Plasma Login Manager, a fork of SDDM. Linux Hello adds an SDDM theme that shows which sign-in method is running; the Plasma Login Manager has no place for a theme like that, so it is not supported in 1.0 ([ADR-0016](../adr/0016-prompt-hosts.md)).

### logind

The systemd service that keeps track of who is logged in: each login is a *session*, and each session belongs to a *seat*. It tells other programs when a session comes to the front, goes to the background or sets its *locked hint* (the screen is locked). Linux Hello's Agent listens to it to decide when the virtual security key may exist ([spike 0138](../spikes/0138-virtual-ctap-session-binding.md)).

### PAM

Pluggable Authentication Modules, the Linux framework that every program asking "who are you?" uses: the login screen, the lock screen, `sudo`, `su`. Each program has a *PAM stack*, a list of modules in `/etc/pam.d/` that are tried in order. `pam_unix` is the module that checks the account password. Linux Hello adds its own module, `pam_linuxhello`, before `pam_unix`, so that the account password still works when Linux Hello does not ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)).

### PAM conversation

The way a PAM module talks to the user: it can only send text to show and ask for text back. A login screen therefore cannot learn from PAM whether the face or the fingerprint is being checked. Linux Hello adds a second channel on D-Bus for that ([section 8](08-crosscutting-concepts.md#design-consequence)).

### PAM return code

The answer a PAM module gives. `PAM_SUCCESS` means the user is authenticated. `PAM_AUTHINFO_UNAVAIL` means "this module cannot decide", so PAM moves on to the next module. `pam_linuxhello` returns `PAM_AUTHINFO_UNAVAIL` whenever Linux Hello is not working, which lets the account password take over.

### PipeWire

The Linux service for audio and video streams, through which desktop programs reach the camera. Linux Hello's own preview of the camera, which would use it, is not part of 1.0.

### ptrace, not dumpable

`ptrace` is the Linux call that lets one process read and change the memory of another; debuggers use it. A process marked *not dumpable* cannot be read this way by ordinary processes of the same user, and leaves no memory dump when it crashes. Linux Hello marks its prompt not dumpable so that another program of the user cannot read the PIN from it.

### QML

The language KDE and Qt use to describe user interfaces. Linux Hello's prompt, settings page and login-screen theme are written in QML, with the logic in Rust through *cxx-qt*, a bridge between Rust and Qt.

### Secret Service

A standard D-Bus interface for storing passwords and tokens on Linux, offered by KWallet on KDE and by GNOME Keyring on GNOME. Linux Hello uses it only to keep login tokens, never passkey private keys.

### SO_PEERCRED

A Linux socket option that tells a server which user id and process are at the other end of a Unix socket, as reported by the kernel and not by the caller. Linux Hello's *PIN socket* uses it to check who sends a PIN.

### systemd, systemd service

systemd is the program that starts and supervises the services of a Linux system. A systemd service is a background program it runs, described in a unit file. The Agent is a systemd system service; systemd restarts it if it fails and limits what it may do (its own user, read-only system files, only the TPM device).

### Tetragon

A tool that watches what processes do in the kernel, through eBPF (small programs the kernel runs safely on its own events), and can report or stop forbidden actions, such as a program other than Linux Hello opening the TPM. Linux Hello ships sample rules for it, but works without it.

### TOML

A simple text format for settings, with `key = value` lines grouped under headings in square brackets. Linux Hello's policy files, the user layer and the admin layer, are written in TOML.

### uhid

A Linux interface, the device file `/dev/uhid`, through which a program can create a *HID* device in software. The kernel then shows it to other programs as if it were plugged in. Linux Hello uses it to create its virtual security key. Because `uhid` can also create a keyboard, only one small program, the *uhid helper*, may open it ([spike 0121](../spikes/0121-uhid-helper-privilege.md)).

### seat

The set of screen, keyboard and mouse that one person sits at. On an ordinary computer there is one seat, `seat0`. Several users can be logged in on it (fast user switching), but only the session in front can use the devices of the seat.

### uaccess

A tag that udev puts on a device file so that *logind* gives the user in front on the seat permission to open it. It is how a plain user may open `/dev/hidraw*` nodes of security keys without being root. Linux Hello removes it from its virtual key, because that tag would also give the key to a user who is in front but is not the owner ([spike 0138](../spikes/0138-virtual-ctap-session-binding.md)).

### udev

The Linux service that sets up device files when a device appears, and decides who may open them. Linux Hello uses a udev rule so that only the uhid helper may open `/dev/uhid`, and another so that the devices it creates are not treated as keyboards or mice.

### uid

The number Linux uses for a user account. The Agent serves all users of the machine and keeps their data apart by uid.

### Wayland, X11

The two systems that put windows on a Linux screen. Under X11 any program of the user can read the keys typed into another window; under Wayland it cannot. A PIN typed under X11 can therefore be observed by another program of the same user, which Linux Hello documents and does not prevent ([ADR-0020](../adr/0020-presence-and-verification.md)).

### Watchdog

A timer that systemd keeps for a service. The service must report "still alive" before the timer runs out, or systemd counts it as hung and restarts it. The Agent's unit sets the timer to 30 seconds, and the Agent reports only after it has answered a call to itself over the bus, so a hung message loop leads to a restart ([agent restart](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/agent-restart.md)).

## Linux Hello's own words

### Actor

A kind of attacker in the [threat model](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/threat-model.md), named M1 to M6. The one most often meant is **M2, a malicious program running as the same user**, for example a compromised app, which can read the user's files and send fake mouse clicks to other windows. Another local user (M1) and a person with the machine in their hands (M4) are the others most often named.

### Admin layer, user layer

The two layers of *policy* files on top of the built-in defaults. The admin layer is set by the administrator in `/etc/linuxhello/policy.d/` and wins over everything else; a setting there is *managed* and shown greyed out to the user. The user layer is kept by the Agent per user in `/var/lib/linuxhello/users/<uid>/policy.toml`; the user can make the defaults stricter but never looser ([ADR-0018](../adr/0018-user-policy-layer.md)).

### Agent

The central service of Linux Hello. One Agent runs per machine, as a systemd system service under its own user `linuxhello`, and serves all users over the D-Bus system bus ([ADR-0014](../adr/0014-agent-bus.md)). It knows which methods each user has, runs the sign-in methods, decides the *policy*, talks to the TPM for the PIN, and tells the login screen and the prompt what is happening. Every other part asks the Agent. It is running and tested on Ubuntu 24.04 and 26.04 ([section 7](07-deployment-view.md)), but signs no one in yet.

### Context

The situation in which the user is asked to authenticate: `login` (the login screen), `unlock` (the lock screen), `sudo` (a command run as administrator) or `session` (using passkeys while logged in). The policy sets, per context, which methods are allowed and how many are needed.

### Credential Index

The Agent's list of the user's *discoverable credentials*: for each passkey, its credential id, the account, which provider holds it and the key in the encrypted form the TPM handed back (a wrapped key blob), which only that TPM can use. The prompt takes the names it shows from here, never from the website. Decided, not built.

### Destructive reset

What happens when the user forgets the PIN. With the account or administrator password, the user deletes the *root key* and sets a new PIN; every device-bound passkey under the old root key is lost and must be registered again with each website. There is no recovery key ([ADR-0003](../adr/0003-destructive-reset.md)). Windows Hello's default reset works the same way.

### Factor

One independent proof of identity, such as the PIN or a fingerprint. A policy that asks for two factors needs two different methods, for example a fingerprint and the PIN.

### Fail closed

When something is wrong, refuse rather than allow. For example, if a policy file cannot be read, Linux Hello does not ignore it: it falls back to the *PIN-only state*. The opposite, fail open, would let an attacker switch protection off by damaging a file. At the login screen Linux Hello says "I cannot decide" rather than "no", so the account password still works (*PAM return code*).

### Fall-through

What happens at the login screen when Linux Hello cannot decide: the PAM module answers "unavailable", PAM moves on to the next module, and the user types the account password ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)).

### KeePassXC provider

Also called the KeePassXC Provider Bridge. The part of Linux Hello that serves *portable* passkeys kept in KeePassXC to the Virtual CTAP Authenticator. Not built.

### linuxhello-ctl

The command-line tool of Linux Hello, for enrolling, changing the PIN, resetting and looking at the policy. Its Plasma counterpart is the settings page.

### Managed

A policy setting that the administrator has set in the *admin layer*. The user sees it but cannot change it, with the note "Managed by your organisation".

### Method

A way to authenticate: the PIN, a fingerprint (through fprintd) or the face (through Howdy).

### Method Orchestrator

The part of the Agent that runs the allowed methods at the same time, takes the first that succeeds and stops the others. So the user can look at the camera or touch the sensor, whichever is quicker, without waiting for one to time out ([ADR-0023](../adr/0023-pam-module-and-login-failure.md)).

### PIN

In Linux Hello, the user's main secret and the *root* of trust: the TPM checks it as the authorisation value of the root key, and it never leaves the machine. It is not the account password, which only resets the PIN. Because the TPM limits guessing, a short PIN is safe here in a way a short password is not.

### PIN-only state

The safe state the *policy* engine enters when a policy file cannot be trusted, for example because it is damaged or writable by others. Only the PIN works, biometrics are off, and passkeys need the PIN for every use. The details are in the [policy semantics](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md#fail-closed).

### PIN socket

A dedicated Unix socket of the Agent (a local connection between two programs on the same machine, reached through a file path) through which the PAM module or the prompt sends a typed PIN. The Agent checks who is sending it with *SO_PEERCRED*. The PIN never travels as a D-Bus message, where monitoring tools could see it ([ADR-0021](../adr/0021-pin-transport.md)).

### Policy, routing policy

The rules that decide, before every operation, which methods a *context* allows, which *provider* holds a relying party's passkeys and how strongly the user is asked (*prompt level*). They are written in TOML files (a plain-text format for settings) in layers (*admin layer, user layer*) and evaluated by the Routing Policy Engine in the Agent. The exact rules are in the [policy semantics](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md). The engine is built and tested.

### Presence gesture

What Linux Hello accepts as *user presence*: a fingerprint match delivered by fprintd, or the PIN checked by the TPM. A mouse click is not enough when a sensor exists, because another program of the user could fake the click (*actor* M2). On a machine without any sensor, a policy may allow a click, and the documentation says what that does not stop ([ADR-0020](../adr/0020-presence-and-verification.md)).

### Prompt

In the Agent: the record of one sign-in attempt, from the moment a program asks the Agent to check a user until the attempt succeeds, fails or is cancelled. It is named by an identifier that the PAM module and the login screen can each work out on their own, so the login screen can follow the attempt and show which method is running. A prompt belongs to the user it was opened for, and it ends when its opener disconnects or after five minutes without news ([ADR-0014](../adr/0014-agent-bus.md)). Not to be confused with the *Prompt UI*, the window that asks the user to confirm a passkey.

### Prompt level

How strongly a relying party's request is confirmed, set per *relying-party class*: `none` (no question), `presence` (a *presence gesture*) or `reverify` (verify again with a method).

### Prompt UI

The window that appears during a session when a website asks for a passkey. It shows which site is asking, which method is running and, if there are several passkeys, lets the user choose one. The Agent starts it as its own confined child process and trusts no other window to answer ([ADR-0020](../adr/0020-presence-and-verification.md)). Decided, not built.

### Property, security property

One security promise of Linux Hello, written in plain language and checked by a test with the same name, such as "a PIN never travels on D-Bus". Properties are numbered P-01, P-02 and so on in the [list of properties](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/properties.md). The maintainer reviews the properties and whether their tests pass, rather than the Rust code.

### Provider

The part of Linux Hello that actually keeps a passkey's private key and signs with it. There are two: the *TPM provider* for device-bound keys and the *KeePassXC provider* for portable keys. A real security key can serve as a third, as a fallback. The policy chooses the provider per relying party.

### Relying-party class

A named group of relying parties in the policy, matched by domain, such as `banking` for `*.bank.example`. Each class sets the provider, the prompt level and the number of factors for its sites.

### Shortcut

The role of fingerprint and face in the *trust chain*: a quicker way to do what the PIN does, never a replacement for it. If the shortcut fails or is switched off, the PIN still works.

### TPM provider

Also called the TPM Credential Provider. The part of Linux Hello that creates *device-bound* passkeys under the user's root key in the TPM and signs with them. Not built.

### Trust chain

How Linux Hello's secrets depend on each other, modelled on Windows Hello. The **root** is the PIN, checked by the TPM. Fingerprint and face are a **shortcut** to the same unlock. The account password is only for a **reset**, which destroys the TPM keys. **Recovery** of lost passkeys goes through each website's own account recovery. The full table is in [section 8](08-crosscutting-concepts.md#trust-chain).

### uhid helper

The small program that alone may open `/dev/uhid` and create the virtual security key. It runs as its own user, cannot reach the TPM, and is confined by AppArmor, because a program that can create HID devices could also create a fake keyboard ([spike 0121](../spikes/0121-uhid-helper-privilege.md)).

### Verification window

The 60 seconds after a verification during which Linux Hello may still report *user verification* to a website. The limit is a constant in the code: policy may shorten it, never lengthen it ([ADR-0020](../adr/0020-presence-and-verification.md)).

### Virtual CTAP Authenticator

The part of Linux Hello that makes the computer look like a USB *security key* to browsers and apps. It creates a HID device through the *uhid helper*, speaks *CTAP2* on it, asks the Agent whether the request is allowed and lets a *provider* sign. Because every browser already supports security keys, no browser needs a change ([ADR-0005](../adr/0005-provider-path.md)). Proven end to end with Firefox and Chromium in [spike 0094](../spikes/0094-virtual-ctap-end-to-end.md); not built as a product yet.

## Words about the documentation

### ADR

Architecture Decision Record: a short note that records one decision, the options that were weighed and why one was chosen. Once accepted, an ADR is not rewritten; a later ADR or an amendment changes it. The ADRs are in [adr/](../adr/README.md).

### Arc42

A template that divides architecture documentation into twelve fixed sections, from goals and constraints to risks and this glossary, so that a reader knows where to look. [The index](README.md) lists the sections.

### Brief

An implementation brief: the description of one piece of code work, written by the lead (Claude) for the implementer (a local AI model) under [ADR-0004](../adr/0004-agent-roles.md). Briefs live in the linux-hello repository, not here.

### C4 model

A way to draw software at four levels of detail: the **system** and the people and other systems around it (context), the **containers** inside it, the **components** inside each container, and the code. A *container* here means a part that runs or is stored on its own, such as a service, a library or a set of files; it has nothing to do with Docker containers. Linux Hello's C4 model is written as text in [workspace.dsl](../workspace.dsl), in the language of the Structurizr tool, and the diagrams are drawn from it.

### Gap

A section or part of a section that has no content yet. It is marked **Gap** rather than filled with guesses.

### Invariant

A rule that no change may break, listed in linux-hello's [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants). Examples: the PIN is the root; Linux Hello fails closed; no secret is ever written to a public repository.

### Spike

A short, time-boxed experiment that answers one question the design depends on, such as "can a virtual USB security key work with stock Firefox?". Its answer is recorded so that decisions rest on what was tried, not on guesses. The spikes are in [spikes/](../spikes/README.md), numbered by the issue that asked the question.

### Status words

How a page says how far a part has come. **Built and tested**: it exists in the code and its tests pass. **Decided, not built**: an ADR settled it but there is no code yet. **Open**: not decided. A newcomer cannot tell a design from a working program unless the text says which it is.
