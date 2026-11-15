---
type: adr
subject: pam_linuxhello is a thin synchronous client, and login falls through to the account password when Linux Hello fails
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [pam, pam-linuxhello, method-orchestrator, fail-closed, availability, account-password]
tags: [adr, pam, security]
sources: ["0014-agent-bus.md", "0016-prompt-hosts.md", "../spikes/0007-pam-dbus-method-state.md", "https://github.com/LinuxHello/linux-hello/issues/147"]
date: 2026-11-15
---

# ADR-0023: A thin PAM module, and what login does when Linux Hello fails

## Status

Accepted, 2026-11-15, on the maintainer's decision the same day (proposed 2026-11-15). Amends the `Method Orchestrator` component in [workspace.dsl](../workspace.dsl), which sits inside `pam_linuxhello`. Answers [issue 147](https://github.com/LinuxHello/linux-hello/issues/147); builds on [ADR-0014](0014-agent-bus.md) and [spike 0007](../spikes/0007-pam-dbus-method-state.md).

## Context

The model has `pam_linuxhello` run face, fingerprint and PIN in parallel itself, with an async runtime, inside `sudo` (setuid), the greeter helper (root) and the lock screen (a worker thread of the user's process). Threads, an executor, D-Bus connections and child processes inside someone else's process are where crashes, `fork` and signal hazards, leaked descriptors and environment problems come from, and the module is the one place allowed to use `unsafe`. Spike 0007 left the async runtime, connection time and `sudo`'s environment untested.

"Fail closed" is defined for policy and confinement, not for login. If the Agent is down, the profile is in complain mode, the TPM is locked or a context is unsatisfiable, nothing says whether the user still gets a password prompt. A security component that locks people out of their machine gets removed.

| Question | Option | Pros | Cons |
| :-- | :-- | :-- | :-- |
| Where do the methods run | **A. The Agent; the module is a thin synchronous client** | No threads, executor or children in a host process; the Agent already holds the prompt state | The Agent becomes a dependency of every login, so availability matters (issue 145) |
| | B. A per-request helper process | Isolates the work | One more process to start, supervise and confine |
| | C. Inside the module, async, as drawn today | Fewest parts | The hazards above, in the process of someone else |
| What login does on failure | **A. `PAM_AUTHINFO_UNAVAIL`, and the shipped PAM snippets keep `pam_unix` after it** | The user can still log in, unlock and `sudo`; the password never opens TPM keys | With Linux Hello down, a context that policy sets to two factors is satisfied by the password alone |
| | B. Linux Hello required, no fall-through | Policy is held strictly | A down Agent, a locked TPM or an unsatisfiable context locks everyone out |

## Decision

**Option A for both questions.**

1. **`pam_linuxhello` is a small synchronous client.** It opens the prompt, hands the conversation to the orchestrator in the Agent over the system bus, waits with a hard deadline and maps the answer to a PAM code. It starts no thread, no async executor and no subprocess in the host process. The `Method Orchestrator` moves from the PAM module to the Agent in `workspace.dsl`; fingerprint and Howdy are run by the Agent, not by the module.
2. **Failure contract.** When Linux Hello is unavailable (the Agent is unreachable or hangs, its profile is not enforcing, the TPM is locked, a context is unsatisfiable) the module returns `PAM_AUTHINFO_UNAVAIL`. It never returns `PAM_SUCCESS` for that case (P-20). The shipped PAM snippets keep `pam_unix` after `pam_linuxhello`, so the account password still works for login, unlock and `sudo`. The account password never unlocks TPM keys (P-17): a login by password leaves passkeys and keys locked.
3. **Deadlines.** The connection to the Agent has a limit of 250 ms. The whole conversation is bounded by policy. When either is reached the module returns `PAM_AUTHINFO_UNAVAIL`, not an error that stops the stack.
4. **Names the tests will use** (properties in `docs/security/properties.md`, written in the code issues after this ADR): `pam_returns_within_its_deadline_when_the_agent_hangs`, `login_falls_through_to_the_account_password_when_linux_hello_is_unavailable`. P-20 keeps its test, `pam_never_succeeds_when_agent_is_unreachable`.

## Consequences

**Easier:** the code in the host process is small enough to review as a whole; a login never depends on an async runtime inside `sudo`.

**Harder:**

- Every login depends on the Agent being there, so its availability is a security and stability property in its own right (issue 145: activation, ordering, restart).
- With Linux Hello down, the account password alone satisfies a context that policy sets to two factors. This is the price of never locking the user out; the audit log records the fall-through ([issue 132](https://github.com/LinuxHello/linux-hello/issues/132)).
- The lock screen runs fingerprint and smartcard as separate PAM services in parallel with the password on Plasma ([spike 0007](../spikes/0007-pam-dbus-method-state.md)); how `pam_linuxhello` sits beside them is left to the prompt-host decision of [ADR-0016](0016-prompt-hosts.md).
- `workspace.dsl` and arc42 sections 5 and 8 change: the orchestrator is an Agent component, and the PAM module has no parallel methods of its own.

**Follow-up:** briefs for the thin client with its deadlines, the Agent-side orchestrator, the shipped PAM snippets with `pam_unix` after the module, VM runs in the four contexts (login, unlock, `sudo`, console), and the model and arc42 changes.
