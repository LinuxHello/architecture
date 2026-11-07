---
type: adr
subject: The Agent is a system service on the system bus, and state reaches prompts by method call or addressed signal
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [dbus, system-bus, pam, agent, one-way-door]
tags: [adr, one-way-door, dbus]
sources: ["../spikes/0007-pam-dbus-method-state.md", "../spikes/0009-plasma-prompt-component.md", "../spikes/0094-virtual-ctap-end-to-end.md", "0012-dbus-names.md", "../arc42/07-deployment-view.md", "../workspace.dsl"]
date: 2026-11-08
---

# ADR-0014: The Agent's bus

## Status

Proposed, 2026-11-08.

## Context

[ADR-0012](0012-dbus-names.md) fixes the Agent's name, `io.github.LinuxHello.Agent1`, and leaves open which bus it lives on. [Spike 0007](../spikes/0007-pam-dbus-method-state.md) found that the PAM module can reach a service in every context only on the **system bus**: at SDDM, `sudo` and the console there is no session bus for the user who is signing in, and only the lock screen has one. [Spike 0009](../spikes/0009-plasma-prompt-component.md) found the same for the greeter, which runs as `sddm` (or `plasmalogin`), not as the user who signs in. [Spike 0094](../spikes/0094-virtual-ctap-end-to-end.md) adds a privileged `uhid` helper that must ask the Agent for unlock state and routing policy. The bus is a one-way door: bus policy files, AppArmor profiles and every client name it.

Constraints from the model ([workspace.dsl](../workspace.dsl)): the PAM module and the Agent stay separate processes; the Agent verifies the peer credentials of every caller; only the Agent and the TPM provider open `/dev/tpmrm0`; a broadcast signal reaches every local user, so it must not carry who is signing in or with which method.

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. One system service on the system bus**, serving all users, with state keyed by the caller's uid | Reachable from every PAM context, the greeter, the lock screen and the `uhid` helper; one place that holds the TPM; no per-user daemon to start before login | A long-running service with more privilege than a user daemon; the bus policy and the per-user separation are ours to get right |
| B. A per-user Agent on the session bus, plus a system-bus relay for PAM | Per-user isolation by process | Two components and a hand-off between them; no session bus at the greeter or at `sudo` and the console, so the relay carries the whole login path; the relay is the Agent in all but name |
| C. A per-user Agent on the session bus only | Simplest per-user model | Unreachable from SDDM, `sudo` and the console, which spike 0007 shows is where PAM runs |

## Decision

**Option A.** The Agent is a systemd system service (`linuxhello-agent.service`) running as a dedicated unprivileged user, on the **system bus**, with the name from ADR-0012.

- **Policy.** The bus policy file lets only that user own the name. Any local user may call methods; the Agent decides, from the caller's credentials (`GetConnectionCredentials`: uid, pid, and the AppArmor label where there is one), what the caller may ask. State is kept per uid.
- **Publish by calling the Agent.** `pam_linuxhello` and the other clients report state with method calls. A reader never receives another user's state: it either calls `GetState(prompt_id)` and gets the reply, or it subscribes and the Agent sends **unicast** signals to that peer only. The Agent emits no broadcast signal that names a user or a method.
- **Prompt identifier.** Every prompt has an opaque identifier that the PAM module and the prompt component can both derive (for example from the PAM service name, tty or display, and the session id). It is not carried in the PAM conversation, which is text only.
- **Other containers.** The TPM provider, the KeePassXC bridge and the `uhid` helper reach the Agent on the same bus. `linuxhello-ctl` and the settings module call it there too.
- **Confinement.** The unit uses the sandbox in [section 8](../arc42/08-crosscutting-concepts.md#security-hardening) and an enforce-mode AppArmor profile; `DeviceAllow` for `/dev/tpmrm0` stays the only device.

The user-visible Plasma pieces (Prompt UI, settings page) stay in the user's session and call the Agent over the system bus. Nothing here changes the interface name or version.

## Consequences

**Easier:** the PAM module reaches the Agent at SDDM, the lock screen, `sudo` and the console with one code path; the greeter and the `uhid` helper need no second endpoint; one process owns the TPM.

**Harder:**

- The Agent is a system service. A flaw in caller checking or in per-uid separation exposes other users' state. Each separation rule needs a security property and a test named after it before code ([AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md)).
- Per-user data (root-key blobs, user policy) is read and written by a service that is not the user: the layout of `/var/lib/linuxhello/` and the ownership of the user policy file need their own decisions.
- [Section 5](../arc42/05-building-block-view.md) and [section 7](../arc42/07-deployment-view.md) state the bus as "session" and as a gap; they follow this ADR once accepted.

Follow-ups: the signal and method schema with the prompt identifier in `linuxhello-dbus`; the bus policy file; a test VM run of the PAM module against the service in the four contexts.
