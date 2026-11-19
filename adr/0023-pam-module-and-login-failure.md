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

Accepted, 2026-11-15, on the maintainer's decision the same day (proposed 2026-11-15). Amends the `Method Orchestrator` component in [workspace.dsl](../workspace.dsl), which sits inside `pam_linuxhello`. Answers [issue 147](https://github.com/LinuxHello/linux-hello/issues/147); builds on [ADR-0014](0014-agent-bus.md) and [spike 0007](../spikes/0007-pam-dbus-method-state.md). Amendment accepted 2026-11-19, on the maintainer's decision the same day (proposed 2026-11-19): the method that hands the conversation to the Agent is `Authenticate(prompt_id, context)` (see *Amendment 2026-11-19*). The second part of the same amendment accepted 2026-11-19: how the fingerprint, face and PIN methods run and what more than one factor does (see *Amendment 2026-11-19, second part*).

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

### Amendment 2026-11-19 (accepted): the method that starts an authentication is `Authenticate(prompt_id, context)`

Decision 1 says the module "hands the conversation to the orchestrator in the Agent over the system bus" and does not name the call. A method name and signature shipped to clients cannot be taken back (AGENTS.md, invariant 7), so this amendment names it.

In plain words: the PAM module first opens a prompt, as it does today. When it is ready it calls `Authenticate` once. From then on the Agent runs the methods (face, fingerprint, PIN) side by side, and the module learns what happens the way every client does: from the `ActiveMethods`, `State` and `Result` signals and from `GetState`. The call itself returns at once; it does not wait for the user.

1. **The method.** `Authenticate(s prompt_id, s context)` on `io.github.LinuxHello.Agent1`. It returns nothing. Success means the Agent has started the authentication for the prompt; the outcome arrives as the `Result` signal and in `GetState` (ADR-0014, amendment 2026-11-17, point 4).
2. **Who may call it.** Only the process that opened the prompt, the same rule as `ReportState`, `ClosePrompt` and `ExpectPin` ([ADR-0021](0021-pin-transport.md)). The user being authenticated is the prompt's subject; the caller names no user.
3. **The context.** One of `login`, `unlock`, `sudo` and `session`, the four contexts of the policy schema. The Agent asks the policy of the prompt's subject which methods that context allows and how many must succeed. Any other text is `InvalidArgument`.
4. **One at a time.** A second call for a prompt whose authentication is still running is refused with `LimitReached`. After `Result` the prompt can be authenticated again.
5. **Errors**, from the closed set of ADR-0014: `Denied` for a prompt that is not the caller's, one that does not exist and one with no subject (one fixed text for all, so nothing is told about other users' prompts); `InvalidArgument` for a malformed id or an unknown context; `LimitReached` as above; `Unavailable` when the Agent has no orchestrator running.
6. **Version.** `Authenticate` is a new optional member, an additive change under the rule of the ADR-0014 amendment of 2026-11-17: it is listed by `GetCapabilities`.
7. **The deadline.** The module's wait is bounded by policy as in decision 3; when it gives up it calls `ClosePrompt`, which cancels the methods that are still running.
8. **Tests the code will name:** `authenticate_starts_the_methods_of_the_context`, `authenticate_for_another_users_prompt_is_denied`, `a_second_authenticate_is_refused_while_one_runs`, `authenticate_is_listed_in_capabilities`.

Not decided here: how Howdy is run, how a PIN is checked, and what `factors` above 1 does; they are open on [linux-hello#195](https://github.com/LinuxHello/linux-hello/issues/195).

### Amendment 2026-11-19, second part (accepted): how the methods run

[linux-hello#195](https://github.com/LinuxHello/linux-hello/issues/195) left four questions open about what the Agent's orchestrator runs. The maintainer accepted the recommended answers on 2026-11-19.

In plain words: the orchestrator runs three kinds of method. Each is a small program part with two jobs, "try to recognise this user" and "stop now". This section says how each of the three does that job and what happens when a policy asks for more than one.

1. **Fingerprint** (decision D5). The Agent is a client of `fprintd`, the fingerprint service every Linux desktop already has (bus name `net.reactivated.Fprint`). It takes the default device, claims it for the user being authenticated, starts a verification, and reads the service's `VerifyStatus` signal. A match is success; `verify-no-match` is a failure with the reason `not-recognised`; the retry results (`verify-retry-scan`, `verify-swipe-too-short`, `verify-finger-not-centered`, `verify-remove-and-retry`) keep the scan going; `verify-disconnected` and `verify-unknown-error` mean the method is unavailable. To cancel, the Agent stops the verification and releases the device. The service must let the Agent's own user claim a device for someone else: a polkit rule for the `linuxhello` user ships with the Agent and allows exactly that and nothing wider.
2. **Face** (decision D2). Howdy has no bus interface, so the Agent starts it as a **child process** with a fixed command line (the compare script that Howdy's own PAM module runs, for the user being authenticated) and reads its exit code: 0 is success, 10 means the user has no face model (the method is unavailable), 11 means no match before its own timeout (a failure, `not-recognised`), 12 means it was aborted, anything else is unavailable. The child runs under its **own AppArmor profile**, a child of the Agent's, that allows the camera device and Howdy's own files and nothing else (no network, no home directory). To cancel, the Agent ends the child. Howdy's exit codes are those of the wrapper at the time of writing; the first implementation checks them against the installed version and the tests pin them.
3. **PIN** (decision D4). The Agent never compares a PIN itself. It asks the PIN lock whether the user may try ([#180](https://github.com/LinuxHello/linux-hello/issues/180)), then hands the PIN, which arrived on the PIN socket ([ADR-0021](0021-pin-transport.md)), to the verifier that stretches it and checks it against the TPM. Until the verifier exists the PIN method reports itself unavailable.
4. **More than one factor** (decision D3). When a policy asks for two factors, the orchestrator runs the methods one after the other, each of a different kind, and all of them must succeed; the first success of the first kind does not end the attempt. With one factor (the default of every context) methods still run side by side and the first success wins.

Not decided here: the exact polkit rule text and the AppArmor profile of the child; both are written in the code issues and tested on a real machine.

## Consequences

**Easier:** the code in the host process is small enough to review as a whole; a login never depends on an async runtime inside `sudo`.

**Harder:**

- Every login depends on the Agent being there, so its availability is a security and stability property in its own right (issue 145: activation, ordering, restart).
- With Linux Hello down, the account password alone satisfies a context that policy sets to two factors. This is the price of never locking the user out; the audit log records the fall-through ([issue 132](https://github.com/LinuxHello/linux-hello/issues/132)).
- The lock screen runs fingerprint and smartcard as separate PAM services in parallel with the password on Plasma ([spike 0007](../spikes/0007-pam-dbus-method-state.md)); how `pam_linuxhello` sits beside them is left to the prompt-host decision of [ADR-0016](0016-prompt-hosts.md).
- `workspace.dsl` and arc42 sections 5 and 8 change: the orchestrator is an Agent component, and the PAM module has no parallel methods of its own.

**Follow-up:** briefs for the thin client with its deadlines, the Agent-side orchestrator, the shipped PAM snippets with `pam_unix` after the module, VM runs in the four contexts (login, unlock, `sudo`, console), and the model and arc42 changes.
