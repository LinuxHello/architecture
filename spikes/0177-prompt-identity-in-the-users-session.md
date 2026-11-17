---
type: spike
subject: What tells the Agent that a connection comes from the real presence prompt in the user's session
artifact: spike
status: answered
owner: "@atterdag"
concepts: [prompt-ui, apparmor, cgroup, systemd-user, peer-credentials, impostor, same-user-attacker]
tags: [spike, m0, security]
sources: ["0120-resident-keys-presence-and-uv.md", "../adr/0020-presence-and-verification.md", "../adr/0021-pin-transport.md", "https://github.com/LinuxHello/linux-hello/issues/177", "https://github.com/LinuxHello/linux-hello/issues/175"]
date: 2026-11-17
issue: https://github.com/LinuxHello/linux-hello/issues/177
---

# Spike: What tells the Agent that a connection comes from the real presence prompt

## Question

When a website asks a passkey to sign, Linux Hello shows a small window, the *prompt* ([Prompt UI](../arc42/12-glossary.md)), that names the website and asks the person to confirm: a click, a PIN typed into it, or a touch on the fingerprint reader. The Agent (the Linux Hello background service that makes the decisions) must be sure that an answer such as "the person confirmed" comes from that window and not from some other program pretending to be it.

In the earlier experiment ([spike 0120](0120-resident-keys-presence-and-uv.md)) the Agent started the prompt itself, so it knew the prompt's process number and could check its AppArmor label (the name of the security profile the kernel confines a program with). In the real design the prompt must run inside the user's desktop session, where the Agent cannot be its parent. This note asks which other ways of telling the prompt apart there are, and what a hostile program that runs as the same user (for example a malicious browser extension helper or a downloaded program) can still do against each. The answer decides how the confined prompt of issue 175 is built ([ADR-0020](../adr/0020-presence-and-verification.md), point 6).

## Time box

One working day; done in one session.

## Method

The test VM (Ubuntu 24.04, kernel 6.8, systemd 255, AppArmor). Script: `make vm-test-prompt-identity` in the private workstation repository (`scripts/vm-test-prompt-identity.sh`), **tested** on 2026-11-17: 11 checks, `ALL PASSED`. A check whose name ends in `is_possible` passes when the *attack* works, so it documents a hole the option does not close.

- **The Agent stand-in** is a root program that listens on a socket every user may connect to, as the real Agent's socket would be. For each connection it records the user, the AppArmor label of the peer (read with `SO_PEERSEC`, the socket option that returns it) and the control group of the peer. A *control group* (cgroup) is the Linux mechanism that systemd uses to keep the processes of one service together; the Agent reads it from `/proc/<pid>/cgroup`.
- **The prompt stand-in** is a copy of the Python interpreter under its own AppArmor profile, started as a systemd unit in the user's own systemd (`systemd-run --user`). This is the way a prompt would be started in the user's session.
- **Impostors** run as the same user, and are started in ways that are realistic: a plain program from a login shell, a program started with `aa-exec` (the tool that runs a command under a named AppArmor profile), a program started from the user's systemd (as every application that a desktop menu launches is), and a program that first writes its own process number into the prompt's cgroup.

## Evidence

| Impostor, same user | Passes the label check | Passes the cgroup check |
| :-- | :-- | :-- |
| none: the real prompt, started in the user's systemd | yes | yes |
| a plain program started from a login session | no | no |
| a program started with `aa-exec -p <the prompt's profile>` | **yes** | no |
| a program started by the user's systemd that moves itself into the prompt's cgroup | no | **yes** |
| the same program started under the profile as well | **yes** | **yes** |

What this shows:

1. **The label alone can be taken.** `aa-exec` lets any unconfined program of the user put itself under a loaded profile. The impostor is then confined by the prompt's profile, which limits what else it can do, but the Agent sees the right label.
2. **The cgroup alone can be taken, but not from everywhere.** A program started inside the user's login session (a terminal, an `ssh` login) was refused when it tried to enter the prompt's cgroup: it lacks write access to the common parent of the two groups. A program started by the user's systemd, which includes every application launched from a desktop menu or autostart, was allowed in. The directory is owned by the user and writable.
3. **Both together can be taken** by a program that the user's systemd starts. Peer checks that rely on the user's own permissions cannot separate the prompt from other code that runs as the same user and has been launched by the desktop.
4. **A descriptor handed to the prompt cannot be taken.** When the prompt holds an open socket and has marked itself non-dumpable, another program of the same user could not take it with `pidfd_getfd` (the system call that copies a descriptor from another process): refused with "operation not permitted". Two things may be responsible, and the test did not separate them: the kernel setting `ptrace_scope=1` that Ubuntu uses (a program may only take over its own children) and the non-dumpable flag.
5. **A socket in the user's runtime directory is open to the whole user.** Any program of the user can connect to it. A socket does not distinguish the prompt from an impostor.

## Answer

In one sentence: no check that the Agent can make on a connection from the user's session separates the real prompt from hostile code running as the same user, so the design must not let the prompt's word alone authorise a signature.

| Option | Verdict |
| :-- | :-- |
| A. Label of the peer | **Partly.** Stops ordinary programs and mistakes; forgeable with `aa-exec`. |
| B1. A socket only the prompt can reach, by path | **No.** Any program of the user can connect. |
| B2. A descriptor the prompt inherits | **Yes** against taking it from the prompt. Not tested: how a parent that is not in the session gets a descriptor into a process in the user's systemd. |
| C. A unit in the user's systemd, checked by its cgroup | **Partly.** Stops programs started in a login session; forgeable by programs the user's systemd starts. |
| A and C together | **Partly.** One more hurdle; the same forgery works. |

**Recommendation for the confined prompt (issue 175):**

1. Use label and cgroup together as a check against mistakes and ordinary software, and say in the design that it does not stop hostile same-user code.
2. Do not let a click in the prompt be the only proof of presence when a policy asks for more. When the policy asks for a verified person, the evidence comes from the sensor or from the PIN path that the Agent checks itself (the PIN socket of [ADR-0021](../adr/0021-pin-transport.md)), as [ADR-0020](../adr/0020-presence-and-verification.md) already says. Then an impostor prompt can at most change what is shown, not what is signed, and the risk that remains is a wrong relying-party name on screen.
3. Keep the prompt non-dumpable and under its own profile (as in spike 0120), so it cannot be inspected or controlled by other programs of the user.
4. Run a follow-up spike on the one open part: how the Agent gets a descriptor into the prompt (option B2), for example through the user's systemd with socket activation.

**Not tested:** the real Agent and prompt (stand-ins only), a graphical desktop session and Plasma's own way of launching applications, snap-confined programs, and Ubuntu 26.04. The ways the real prompt would be started (unit file location, who may override it) are not tested.

## Consequences

The threat model keeps "hostile program of the same user" (actor M2) as a risk that the prompt cannot remove. The properties for the prompt state what the prompt can and cannot do: it displays, and it passes on a PIN; it does not decide. Issue 175 can be briefed with the five items above.
