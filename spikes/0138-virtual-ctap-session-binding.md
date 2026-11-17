---
type: spike
subject: Binding the virtual security key to one user and one active session
artifact: spike
status: answered
owner: "@atterdag"
concepts: [uhid, hidraw, udev, uaccess, logind, seat, session, virtual-ctap, fast-user-switching]
tags: [spike, m0, security]
sources: ["0094-virtual-ctap-end-to-end.md", "0121-uhid-helper-privilege.md", "../adr/0005-provider-path.md", "https://github.com/LinuxHello/linux-hello/issues/138", "https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html", "https://www.kernel.org/doc/html/latest/hid/uhid.html"]
date: 2026-11-17
issue: https://github.com/LinuxHello/linux-hello/issues/138
---

# Spike: Binding the virtual security key to one user and one active session

## Question

Linux Hello presents itself to browsers as a USB security key. It does that by creating a software device through `/dev/uhid`, which the kernel then shows as a device node such as `/dev/hidraw0` (a *hidraw* node: the file through which a browser talks to a security key). This note asks what happens when more than one person is logged in on the same computer, which is what *fast user switching* means: Alice has a session, Bob logs in on the same screen, and Alice's session stays alive in the background.

The question has four parts:

1. Whose keys does the virtual key serve when two users are logged in?
2. Can the node be limited to one user, so that Bob cannot reach Alice's unlocked key?
3. Does the node disappear when the owner locks the screen, switches away, or the program that made it dies?
4. What happens at the login screen, where no user has a session yet?

Without an answer, Bob could use a key that Alice unlocked, with only a prompt (which might appear in the wrong session) in the way. The decision that depends on this note is a new decision record (an ADR) for the virtual authenticator; the spike does not make it.

## Time box

Proposed one working day; done in one session.

## Method

The test VM (Ubuntu 24.04, kernel 6.8, systemd 255, `udev`, `logind`). Script: `make vm-test-uhid-session` in the private workstation repository (`scripts/vm-test-uhid-session.sh`), **tested** on 2026-11-17, the final form of the script passed on one run, and the earlier forms of the same checks passed on earlier runs. A small program, the *probe*, stands in for the real *uhid helper* (the one small program that is allowed to open `/dev/uhid`, see [spike 0121](0121-uhid-helper-privilege.md)). It creates a security-key device whose `uniq` field (a free text field of every HID device) holds the user's number, `linuxhello-uid-<uid>`. The kernel passes that field on to udev, the Linux service that creates device files and decides who may open them, so a udev rule can read it.

For the seat checks the script starts two real login sessions on the computer's *seat* (`seat0`, the set of screen, keyboard and mouse that one person sits at), one on virtual terminal 7 for a second user and one on terminal 8 for the first. Only one of them is in front at a time; `chvt` switches between them like Ctrl+Alt+F7 would. logind, the systemd service that tracks logins, reports which session is in front as the `Active` property of the session.

The *controller* in the test is a short Python program that listens to logind and ends the device. In the product this would be part of the Agent (the Linux Hello background service that makes the decisions); here it runs as root.

## Evidence

All 20 checks passed (`ALL PASSED`). What they show:

1. **The problem is real.** With stock rules, the node is tagged `uaccess` and `seat`. That tag tells logind to give the user who is in front on the seat a permission on the node (an access control list entry). A key created for user 1000 while a second user was in front could be opened by the second user (`by_default_the_user_in_front_on_the_seat_can_open_another_users_key`). Nothing in the kernel records which process opens the node, so this cannot be fixed inside the helper.
2. **One udev rule fixes it.** A rule that reads the `uniq` string, sets the owner of the node to that user number, the mode to `0600`, and removes the `uaccess` tag, gives the node to exactly one user. The named user can open it; a second user cannot, also when that second user is in front on the seat (`with_the_rule_the_user_in_front_on_the_seat_cannot_open_another_users_key`); the helper that created the device cannot open its own node either, which is wanted because it only uses `/dev/uhid`.
3. **Two users at once** each get their own node, owned by that user, and neither can open the other's.
4. **The rule must run after the stock rules.** The stock rule that adds the `uaccess` tag is in `70-uaccess.rules`. A rule file named `71-lh-session-key.rules` removes the tag after it and the second user was still refused. A first attempt that cleared the `ID_SECURITY_TOKEN` property before the stock rules also worked, but it removed the tags that the snap packages of Firefox and Chromium (Ubuntu's default browsers) need to be allowed to open the node. The late rule keeps those tags (`the_node_is_still_a_security_token_for_snap_browsers`).
5. **Removal is fast.** If the helper is killed, the kernel destroys the device and the node is gone after 0.04 s. When the controller reacts to logind, the node is gone 0.04 s after `LockedHint` is set and 0.05 s after the session leaves the front. logind told the controller within 0.01 s.
6. **The lock hint is available.** A session can set `LockedHint` on itself (the screen locker does this) and logind sends `PropertiesChanged` at once.

| Check | Time measured |
| :-- | :-- |
| helper killed, node gone | 0.04 s |
| `LockedHint` set, node gone | 0.04 s |
| owner's session leaves the front, node gone | 0.05 s |

## Answer

In one sentence: a virtual key can belong to exactly one user and one active session, if one udev rule gives the node to that user and the Agent ends the device whenever that session locks, leaves the front or ends.

**Yes, with one udev rule and a controller that follows logind.** All three acceptance checks of the issue hold in the VM: a second logged-in user cannot open the first user's node; switching to another session removes the node within one second (0.05 s); no node exists once the session reports a locked screen (0.04 s).

The design these results support:

- The Agent decides which session owns the device. It creates the device when that session becomes active and unlocked, and ends the device when the session locks, leaves the front, ends, or the Agent restarts. Because the kernel destroys a device when its creator closes `/dev/uhid`, a crash of the helper also ends it.
- A udev rule `71-lh-session-key.rules` (the shape is in the script) gives the node to the one user named in the `uniq` string. The package must ship it and the helper must put the user number in `uniq`.
- The prompt goes to the session that owns the device, because the Agent knows the owner from the same user number.
- At the login screen no user owns a session, so the Agent creates no device (nothing to test: it is the absence of a call).

**Not tested:**

- The real helper and the real Agent. The probe and a Python controller stand in for them, so the race between "session becomes active" and "device created" is not measured; only removal is.
- `LockedHint` set by a real screen locker (Plasma's) and the `Active` change of a graphical session. The VM uses text login sessions on virtual terminals; the property is the same, but a graphical session was not run.
- Remote sessions without a seat (ssh): they have no seat, so by the design they get no device.
- Browsers: only a plain open of the node was tried, not a real passkey ceremony, and not the snap browsers themselves.
- Ubuntu 26.04 (its test image does not boot in the VM yet), other distributions that may name the stock rules differently, and `elogind` or systems without logind.
- Whether the Agent's own AppArmor profile and unit settings allow it to listen to logind (a bus rule is needed).

## Consequences

Section 8 of the architecture notes lists the helper as a threat; this note adds a second one: *another user on the same seat uses the key*, mitigated by the udev rule and the controller. The ADR for the virtual authenticator should record the rule, the `uniq` convention and the controller's duties, and the test names above become the tests of the properties. A new Linux Hello property is needed: *a virtual key node is owned by exactly one user and exists only while that user's session is active and unlocked*.
