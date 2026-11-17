---
type: spike
subject: Starting the presence prompt for a user from the Agent, in a way a same-user impostor cannot copy
artifact: spike
status: answered
owner: "@atterdag"
concepts: [prompt-ui, systemd, polkit, cgroup, apparmor, agent, impostor, same-user-attacker]
tags: [spike, m0, security]
sources: ["0177-prompt-identity-in-the-users-session.md", "0120-resident-keys-presence-and-uv.md", "../adr/0020-presence-and-verification.md", "https://github.com/LinuxHello/linux-hello/issues/177", "https://github.com/LinuxHello/linux-hello/issues/175"]
date: 2026-11-17
issue: https://github.com/LinuxHello/linux-hello/issues/177
---

# Spike: Starting the presence prompt from the Agent, so that an impostor cannot copy the start

## Question

The presence prompt is the small window in which a person confirms that a passkey may be used ([the first note of this spike](0177-prompt-identity-in-the-users-session.md) explains why the Agent, the Linux Hello background service, must be able to tell it from an impostor). That note found that the usual checks on a connection (the AppArmor label, the control group that systemd keeps the process in) can each be forged by a program that runs as the same user, as long as the prompt lives in the user's own systemd. It found one thing that cannot be forged, a descriptor that only the prompt holds, and left one question open: **how does the Agent, which runs as its own unprivileged user and is not root, start a prompt for another user at all?**

This note tests one answer: the Agent asks the system's systemd to start a *template unit* `linuxhello-prompt@<uid>.service`, which runs the prompt as that user. A *template unit* is one unit file that systemd can start many times with a different name after the `@`, here the user number. The prompt then lives in a control group that belongs to the system, which the user cannot change, so the "enter the prompt's group" forgery of the first note should fail. The question is whether that works, and what it costs.

## Time box

Half a working day; done in one session.

## Method

The test VM (Ubuntu 24.04, systemd 255, polkit 124, AppArmor). Script: `make vm-test-prompt-launch` in the private workstation repository (`scripts/vm-test-prompt-launch.sh`), **tested** on 2026-11-17: 12 checks, `ALL PASSED`. A check whose name ends in `is_possible` passes when something unwelcome *can* be done.

- **The Agent's user** is an ordinary system user (`lhagent`), not root, as the real Agent's user would be. It starts the unit with `systemctl start`, which asks the system's systemd over D-Bus. polkit, the Linux service that decides whether such a request may go through, is configured with one narrow rule: this user may *start* and *stop* units named `linuxhello-prompt@<number of 1000 or more>.service`, and nothing else.
- **The unit** runs the prompt stand-in as the user in its name (`User=%i`, where `%i` is the part after the `@`), under an AppArmor profile, with `NoNewPrivileges=yes` and `PrivateNetwork=yes`. The runtime directory and a display variable are set as environment variables.
- **The display** is a fake socket in the user's runtime directory, standing in for the Wayland socket that a real window would use. The prompt stand-in connects to it.
- **The Agent stand-in** (root program) checks the peer's user, label and control group, as in the first note, and accepts the group only if it is exactly `system.slice/system-linuxhello\x2dprompt.slice/linuxhello-prompt@<uid>.service`.

## Evidence

1. **The Agent can start the prompt without being root.** With the narrow rule, the Agent's user started the unit for the test user. It could not restart another service (`ssh.service`), and with the number limit of 1000 or more in the rule it could not start a prompt for root either. Without the number limit, the first version of the rule let it start one for root (`the_rule_alone_lets_the_agent_start_a_prompt_for_root_is_possible` was in the first run; the rule was tightened and the check turned into `the_rule_does_not_let_the_agent_start_a_prompt_for_root`).
2. **The Agent sees the right peer.** The prompt ran as the user, with the AppArmor label and in the expected system control group.
3. **The prompt still reaches the user's display.** Although it is a system unit, it connected to a socket in the user's runtime directory and the other end received the data. This is what a Wayland window needs; a real window was not run.
4. **The forgery of the first note no longer works.** The control group of the prompt is owned by root. A program of the same user, started from a login session or from the user's own systemd, could not write its process number into it ("permission denied"). A program that took the label with `aa-exec` still failed the group check, and so did a unit named like the prompt in the user's own systemd.
5. **The user cannot end the prompt through systemd,** and cannot open its memory. The user can send it a signal (it is the same user), so a person's own program can *end* the prompt; that is a way to refuse service, not to forge an answer.
6. **A hurdle in the AppArmor profile:** with `PrivateNetwork=yes` systemd sets up a separate file system view, and the profile needs `flags=(attach_disconnected)` and access to `/dev/null`, or the prompt dies at start with a "disconnected path" denial. The real profile must have both.

## Answer

In one sentence: starting the prompt as a system unit from the Agent, with a narrow polkit rule, works and takes away the cgroup forgery; the one thing a same-user program can still do is the label, which the cgroup check makes irrelevant.

- The Agent accepts a prompt connection only when label and cgroup match: `system.slice/system-linuxhello\x2dprompt.slice/linuxhello-prompt@<uid>.service`, where `<uid>` is the user of the connection.
- polkit rule: `start` and `stop` of `linuxhello-prompt@<uid>.service` for the Agent's user, with a uid of 1000 or more, and nothing else.
- Unit: runs as `%i`, with its own AppArmor profile (`attach_disconnected`), `NoNewPrivileges=yes`, `PrivateNetwork=yes`, and the display environment from the user's session.
- The Agent only expects a prompt connection after it started one, so a prompt that someone else started has nothing to connect to.

This is stronger than anything in the first note. It still does not make the prompt the judge: a program of the same user can end the prompt, and it can draw its own window that looks like it. So the recommendation of the first note stays: the prompt displays and forwards a PIN, and a verified presence comes from the sensor or the Agent's PIN path.

**Not tested:**

- A real window under Wayland or X11, and how the unit gets the right display variables when several people are logged in (the VM text sessions have none). The Agent could read them from logind, but this is a guess.
- The real Agent (a stand-in was used) and its confinement: the Agent's own AppArmor profile must allow talking to systemd, and the Agent's bus policy must allow it. Both are rules to write.
- A stopped or restarted user session: whether the unit should end with the session (`BindsTo` the user's runtime directory is one idea).
- Ubuntu 26.04 and other distributions; other polkit versions (older ones use `.pkla` files, not JavaScript rules).
- The effect of `PrivateNetwork=yes` on a real toolkit that talks to a compositor with a socket under the user's runtime directory; the stand-in connected, a real toolkit may need more.

## Consequences

Issue 175 (the confined prompt) is briefed with: a template unit, a polkit rule, a prompt profile with `attach_disconnected`, a peer check on label and cgroup together, and the rule that the Agent expects a prompt only after it started one. The threat model keeps one line about the prompt: *a program of the same user can end the prompt or imitate its appearance*. A new property is *a prompt connection is accepted only from the system control group of the unit the Agent started*.
