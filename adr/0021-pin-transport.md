---
type: adr
subject: The PIN travels from the PAM module to the Agent on a dedicated unix socket, never as a D-Bus message
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [pin, pam, agent, unix-socket, so-peercred, tpm-sessions, zeroize]
tags: [adr, security, pin]
sources: ["0014-agent-bus.md", "../spikes/0011-tpm-root-key-change-auth.md", "https://github.com/LinuxHello/linux-hello/issues/140"]
date: 2026-11-15
---

# ADR-0021: How the PIN reaches the Agent and the TPM

## Status

Proposed, 2026-11-15. Amends [ADR-0014](0014-agent-bus.md) for the PIN only. Answers [issue 140](https://github.com/LinuxHello/linux-hello/issues/140). The maintainer chose the dedicated Agent socket (option A below) on 2026-11-15; decisions 2 to 5 are proposed in the issue and need your review.

## Context

Only the Agent and the TPM provider may open the TPM, and the PAM module verifies a PIN against the TPM root key, so the PIN has to travel from the PAM module (inside `sudo`, the greeter helper, the lock screen) to the Agent. [ADR-0014](0014-agent-bus.md) puts the Agent on the system bus, and that is the only channel defined. A PIN in a D-Bus message body passes through `dbus-daemon`, is visible to bus monitoring by root tooling and to debug logging, and sits in message buffers that are never cleared. [Spike 0011](../spikes/0011-tpm-root-key-change-auth.md) used password sessions, with the authorisation value in clear on the TPM transport, and notes that itself.

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. A dedicated unix socket of the Agent**, the caller checked with `SO_PEERCRED` | The PIN never touches the bus daemon; one small protocol that carries only the PIN; the same caller check as on the bus | A second endpoint to confine and test |
| B. A pipe or sealed memfd passed as a file descriptor over the system bus | One bus interface | The descriptor passes through `dbus-daemon`; the sender can keep and rewrite a pipe; a sealed memfd is more code than the socket it replaces |

## Decision

**Option A.**

1. **A secret never travels as a D-Bus message body.** The PIN goes over a dedicated stream socket owned by the Agent, in a directory only the Agent's user can change. The Agent reads the caller's uid and pid with `SO_PEERCRED` (and the AppArmor label where there is one) and decides from them what the caller may ask; the PIN is accepted only for the subject user the control call on the bus named. The bus keeps carrying method calls and unicast state as in ADR-0014; only the PIN moves.
2. **The TPM gets a stretched PIN, not the raw PIN.** A per-user salt stored with the root-key blob feeds a slow key-derivation function; the text is normalised (NFKC) first. A TPM bus trace or a captured command then does not reveal the PIN. The function and its cost are chosen in the follow-up brief.
3. **TPM sessions are salted HMAC sessions with parameter encryption**, bound to the storage primary, in place of the password sessions of spike 0011.
4. **Memory hygiene.** `zeroize` on every buffer that holds the PIN or the stretched value; no secret type implements `Debug`; core dumps are disabled for the Agent (the hardening issue).
5. **The PIN is checked only by the TPM** (P-12), and the Agent throttles first (the per-user counter of [#137](https://github.com/LinuxHello/linux-hello/issues/137)).
6. **Names the tests will use** (properties in `docs/security/properties.md`, written in the code issues after this ADR is accepted): `pin_is_never_a_dbus_message_body`, `tpm_sessions_encrypt_the_authorisation_value`, `pin_buffers_are_cleared_after_use`. P-12 keeps its existing test, `pin_is_never_compared_outside_the_tpm`.

## Consequences

**Easier:** the PIN is out of the bus daemon's reach, logs and buffers; one place checks the caller and the subject.

**Harder:**

- A second endpoint to confine: its socket path, its mode, its AppArmor rule and a test that a process of another user cannot connect usefully.
- The PIN verifier in the model ([workspace.dsl](../workspace.dsl), `pinVerifier` in `pam_linuxhello`, an edge to the TPM) must change: the PAM module sends the PIN to the Agent and only the Agent talks to the TPM. [Section 5](../arc42/05-building-block-view.md) follows this ADR once accepted.
- Stretching changes the stored root-key authorisation: existing blobs and the PIN-change flow of [spike 0011](../spikes/0011-tpm-root-key-change-auth.md) need the salt.
- Not measured: the cost of the key-derivation function on the target hardware and the latency it adds to a `sudo` prompt.

**Follow-up:** briefs for the socket and its protocol, the stretching, the sessions, and the properties above; model and arc42 changes after acceptance.
