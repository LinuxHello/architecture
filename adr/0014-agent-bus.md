---
type: adr
subject: The Agent is a system service on the system bus, and state reaches prompts by method call or addressed signal
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [dbus, system-bus, pam, agent, one-way-door]
tags: [adr, one-way-door, dbus]
sources: ["../spikes/0007-pam-dbus-method-state.md", "../spikes/0009-plasma-prompt-component.md", "../spikes/0094-virtual-ctap-end-to-end.md", "0012-dbus-names.md", "../arc42/07-deployment-view.md", "../workspace.dsl"]
date: 2026-11-08
---

# ADR-0014: The Agent's bus

## Status

Accepted, 2026-11-08, on the maintainer's decision the same day (proposed 2026-11-08). Amendment accepted 2026-11-16, on the maintainer's decision the same day: what identifies a caller (see *Amendment 2026-11-16*); it changes the *Policy* point and is the answer to [linux-hello#162](https://github.com/LinuxHello/linux-hello/issues/162). Amendment accepted 2026-11-17, on the maintainer's decision the same day (proposed 2026-11-17): the errors, the result and the contract of the interface (see *Amendment 2026-11-17*), the answer to [linux-hello#156](https://github.com/LinuxHello/linux-hello/issues/156).

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

### Amendment 2026-11-16: the Agent tells callers apart by uid and connection, not by process

The *Policy* point above says the Agent decides from the caller's uid, pid and AppArmor label. **It reads the uid and the connection's unique bus name, and decides on nothing else.** The pid and the label are not used. In particular the Agent does not try to tell `pam_linuxhello` from any other process of the same uid: the module runs inside `sudo`, the greeter helper and the lock screen, so no label or pid names "the PAM module", only its host process, and a host that runs as the user is the user's own to trust (M2 in the [threat model](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/threat-model.md)).

What the Agent enforces on the prompt calls:

- Only root, or the user the prompt is for, may open a prompt for that user.
- A prompt belongs to the uid it was opened for and is named by its identifier. A caller of another uid cannot read, report on, replace or close it.
- An open prompt is replaced only by the connection that opened it; another connection of the same uid is refused ([linux-hello#204](https://github.com/LinuxHello/linux-hello/issues/204)). Reporting, closing and subscribing are not tied to the connection.
- A reader gets only its own uid's prompts, and signals are unicast to the peer that subscribed.
- A prompt dies with its opener's connection and after five minutes without a report.

What a process of the same user can therefore do: open prompts for itself (within the per-user limit); report on, close or subscribe to any prompt of its uid whose identifier it knows, and the identifier is one the PAM module and the prompt component derive, so it can be derived; and take an identifier before the PAM module does. The indicator then shows a wrong state or none. It cannot read or change another user's prompt, and it cannot change the result of an authentication, because the PIN and the biometric checks are made by the Agent itself ([ADR-0023](0023-pam-module-and-login-failure.md)) and never by a state a client reports. **The indicator is for the user's eyes and carries no authority; nothing may decide from it.**

If a later decision needs to tell the module from other processes of one uid (for example a helper with its own uid at the lock screen), that is a new amendment; this one only records that none is enforced.

The user-visible Plasma pieces (Prompt UI, settings page) stay in the user's session and call the Agent over the system bus. Nothing here changes the interface name or version.

### Amendment 2026-11-17 (accepted): errors, results and the contract of the interface

The interface is a one-way door once the PAM module and the prompt component ship. Six gaps are cheap to close before they do ([linux-hello#156](https://github.com/LinuxHello/linux-hello/issues/156)). `Unsubscribe` and the `Closed` signal are built ([#203](https://github.com/LinuxHello/linux-hello/issues/203)); the rest is decided here.

1. **Errors have names of their own.** The Agent replies with `io.github.LinuxHello.Error.<Name>`, a closed set: `Denied`, `LimitReached`, `InvalidArgument`, `InvalidPolicy`, `Unavailable`, `Damaged`. They have the meanings of today's generic errors (`AccessDenied`, `LimitsExceeded`, `InvalidArgs`, `Failed`), and a client matches the name, never the text. The text of every error is fixed and carries nothing of the request, except `InvalidPolicy`.
2. **`InvalidPolicy` names the caller's own mistake.** `SetUserPolicy` with a layer the schema rejects returns `InvalidPolicy` with the validation message: the key or line and what is wrong. The text is the caller's own, so nothing leaks; it is built by the parser from a closed set of phrases and the offending key, never from another user's file or an admin file. Test: `invalid_user_policy_names_the_offending_key`. A refusal that would tell a caller something about a prompt, a user or a file that is not theirs stays `Denied` with the same fixed text whether or not it exists (P-04, P-05).
3. **The caller can read what applies to them.** `GetEffectivePolicy() -> (s, as)` returns the effective policy for the caller as TOML text with the keys an administrator manages listed in the array, so the Settings module can grey them out; `GetPinRules() -> (u, u, as, as)` returns the minimum and maximum length and the required and disallowed character classes, for the PIN dialog. Both answer from the merged layers and show values, never file names or the admin layers themselves.
4. **A result says why and for how long.** `Result` is `(prompt_id, result, reason, retry_after)`: `reason` is a closed set (`""`, `too-dark`, `no-face`, `not-recognised`, `cancelled`, `timeout`), `retry_after` is a number of seconds, nonzero only for `locked-out`. `GetState` returns the same two fields. The interface carries no clients yet, so changing the signature of `Result` costs nothing now and would break everyone later.
5. **Methods run in parallel, so the signal is a list.** `ActiveMethod(prompt_id, method)` becomes `ActiveMethods(prompt_id, methods)`; an empty list means none is running. `GetState` returns the list.
6. **The interface says what it is.** `GetCapabilities() -> (u, as)` returns the interface version (1) and the names of the optional members the Agent supports. A property would be natural, but the bus policy denies reading properties, so it is a method. From version 1 the rule is: **a change is additive** (a new member, a new optional field in a closed set); a change that is not is a new interface name (`Agent2`) served next to the old one.

Test names the code will use: `every_error_has_a_fixed_name_and_text`, `invalid_user_policy_names_the_offending_key`, `a_user_reads_only_its_own_effective_policy`, `a_locked_out_result_carries_the_seconds`, `active_methods_is_a_list`, `capabilities_name_the_version`. The QML component can render "locked for N min" from the contract alone.

**Easier (amendment):** the Settings page and `linuxhello-ctl policy edit` say which key is wrong; the PIN dialog shows the rules as the user types; the lock screen shows "locked for 5 min" and "too dark"; clients can tell what the Agent supports.

**Harder (amendment):** more members to confine and test (each is on the interface the profile already names); the error names are a second vocabulary clients must learn once; `Result` and `ActiveMethod` change shape, which is only free until the first client ships.

Not decided here: the status method ([ADR-0024](0024-agent-status-interface.md), accepted 2026-11-17) and the control call for the PIN socket ([ADR-0021](0021-pin-transport.md)).

## Consequences

**Easier:** the PAM module reaches the Agent at SDDM, the lock screen, `sudo` and the console with one code path; the greeter and the `uhid` helper need no second endpoint; one process owns the TPM.

**Harder:**

- The Agent is a system service. A flaw in caller checking or in per-uid separation exposes other users' state. Each separation rule needs a security property and a test named after it before code ([AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md)).
- Per-user data (root-key blobs, user policy) is read and written by a service that is not the user: the layout of `/var/lib/linuxhello/` and the ownership of the user policy file need their own decisions.
- [Section 5](../arc42/05-building-block-view.md) and [section 7](../arc42/07-deployment-view.md) state the bus as "session" and as a gap; they follow this ADR once accepted.

**Easier (amendment):** the Agent has one rule for every caller and nothing to enrol or label; P-04 and the module docs say what holds and nothing more.

**Harder (amendment):** the lock screen's indicator can be wrong or missing when a process of the same user interferes, and the interface must never show it as proof of anything; a future helper with its own uid would need its own amendment.

Follow-ups: the signal and method schema with the prompt identifier in `linuxhello-dbus`; the bus policy file; a test VM run of the PAM module against the service in the four contexts.
