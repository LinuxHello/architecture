---
type: adr
subject: The PIN travels from the PAM module to the Agent on a dedicated unix socket, never as a D-Bus message
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [pin, pam, agent, unix-socket, so-peercred, tpm-sessions, zeroize]
tags: [adr, security, pin]
sources: ["0014-agent-bus.md", "../spikes/0011-tpm-root-key-change-auth.md", "https://github.com/LinuxHello/linux-hello/issues/140"]
date: 2026-11-15
---

# ADR-0021: How the PIN reaches the Agent and the TPM

## Status

Accepted, 2026-11-15, on the maintainer's decision the same day (proposed 2026-11-15). Amends [ADR-0014](0014-agent-bus.md) for the PIN only. Answers [issue 140](https://github.com/LinuxHello/linux-hello/issues/140). The maintainer chose the dedicated Agent socket (option A below) and accepted decisions 2 to 5 as written. Amendment accepted 2026-11-18, on the maintainer's decision the same day (proposed 2026-11-18): the control call is `ExpectPin(prompt_id)` (see *Amendment 2026-11-18*). Amendment accepted 2026-11-19, on the maintainer's standing approval of the lead's recommendations (proposed 2026-11-19): the parameters of the PIN stretching (see *Amendment 2026-11-19*).

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

### Amendment 2026-11-18 (accepted): the control call is `ExpectPin(prompt_id)`

Decision 1 says the Agent accepts a PIN on its socket only from the process that made "the control call on the bus" and only for the subject that call named. It did not name the call. This amendment does, because a method name and signature shipped to clients cannot be taken back (AGENTS.md, invariant 7).

In plain words: before a program sends a PIN on the socket, it tells the Agent over the bus "I am about to send one, for this prompt". The Agent writes down who asked and for whom, and then lets exactly that program send exactly one PIN within a short time. Anyone else who connects to the socket is turned away.

1. **The method.** `ExpectPin(s prompt_id)` on `io.github.LinuxHello.Agent1`. It returns nothing. Success means the Agent now expects one PIN from this caller.
2. **Who may call it, and for whom.** Only the process that opened the prompt (the same rule as `ReportState` and `ClosePrompt`, [ADR-0014](0014-agent-bus.md)). The subject is the user the prompt is for, which `OpenPrompt` recorded, so the caller does not name a user number and cannot name one it was not given. Because `OpenPrompt` already lets only root or the subject open a prompt for a user, a PIN for a user can come only from that user or from root.
3. **What is recorded.** The caller's user id and process id as the bus reports them, and the subject, in the table of `PinSocket::expect`. The PIN is accepted from a connection whose kernel-reported user id and process id match, once, within 30 seconds (`EXPECTATION_TTL`). A second call by the same process replaces the first.
4. **Errors**, from the closed set of ADR-0014: `Denied` for a prompt that is not the caller's, one that does not exist, and a caller whose process id the bus cannot report (the same fixed text for all three, so the answer reveals nothing about other users' prompts); `InvalidArgument` for a malformed id; `LimitReached` when 64 callers already wait; `Unavailable` when the Agent's PIN socket is not running.
5. **Version.** `ExpectPin` is a new optional member, an additive change under the rule of the ADR-0014 amendment of 2026-11-17: it is listed by `GetCapabilities`, and a client that does not find it there does not send a PIN this way.
6. **No PIN in the call.** The call carries a prompt identifier and nothing secret; `pin_is_never_a_dbus_message_body` still holds, and its list of forbidden words does not need `ExpectPin` (the word is `Pin` inside a name, so the test names this one method as it does `GetPinRules`).
7. **Tests the code will name:** `a_pin_is_accepted_only_after_expect_pin_by_the_prompt_opener`, `expect_pin_for_another_users_prompt_is_denied`, `expect_pin_is_listed_in_capabilities`, and the existing tests of the socket.

Not decided here: what consumes the PIN (the verifier and the stretching of decision 2).

### Amendment 2026-11-19 (accepted): the PIN stretching, exactly

Decision 2 said the TPM gets a stretched PIN and left "the function and its cost" to a follow-up brief. This amendment fixes them, because every root key created with them can only be opened with them (changing them later means a PIN change).

In plain words: the PIN you type is turned into a 32-byte value by a slow, memory-hungry function, and only that value is ever given to the TPM. "Slow" is the point: someone who captured it cannot try a million PINs a second.

1. **Normalisation.** The PIN must be UTF-8 text and not empty. It is normalised to Unicode NFKC, so that the same PIN typed on two keyboards is the same bytes (full-width digits equal ordinary digits, a composed letter equals a letter with a combining accent). The normal form is kept in a fixed buffer of 4 KiB that is wiped and never grows; a PIN whose normal form is longer is refused.
2. **The function.** Argon2id, version 1.3 (RFC 9106), 32 bytes of output, with a **16-byte random salt per user**, kept with the user's root-key record. The 32 bytes are the authorisation value of the root key (a SHA-256 name algorithm accepts that length).
3. **The cost.** 64 MiB of memory, 3 passes, 1 lane. Measured at about 112 milliseconds per PIN on a development workstation (release build). The budget is a tenth of a second on a laptop and not more than a quarter on a slow one; it is measured again on target hardware before 1.0, and the parameters can be raised then.
4. **The parameters travel with the record.** The root-key record stores the memory, passes and lanes it was created with, and a version number of this scheme. A PIN change may write stronger ones. A record whose parameters are below 16 MiB and 2 passes, or above 1 GiB, 16 passes and 8 lanes, is **refused**, not trusted: a damaged or forged record must not make the stretching trivial, nor make the Agent allocate gigabytes.
5. **Memory.** The stretched value and the normal form are wiped when dropped, have no `Debug`, and the memory of Argon2 is wiped after use (`pin_buffers_are_cleared_after_use`).
6. **Tests the code names:** `the_crate_matches_rfc_9106`, `the_result_for_a_known_input_does_not_change`, `equivalent_texts_are_the_same_pin`, `parameters_outside_the_accepted_range_are_refused_before_any_work`, `a_normal_form_that_does_not_fit_is_refused`.

Not decided here: how the salt and the parameters are stored with the root-key blob (the TPM provider's record format), and the TPM sessions of decision 3.

## Consequences

**Easier:** the PIN is out of the bus daemon's reach, logs and buffers; one place checks the caller and the subject.

**Harder:**

- A second endpoint to confine: its socket path, its mode, its AppArmor rule and a test that a process of another user cannot connect usefully.
- The PIN verifier in the model ([workspace.dsl](../workspace.dsl), `pinVerifier` in `pam_linuxhello`, an edge to the TPM) must change: the PAM module sends the PIN to the Agent and only the Agent talks to the TPM. [Section 5](../arc42/05-building-block-view.md) follows this ADR once accepted.
- Stretching changes the stored root-key authorisation: existing blobs and the PIN-change flow of [spike 0011](../spikes/0011-tpm-root-key-change-auth.md) need the salt.
- Not measured: the cost of the key-derivation function on the target hardware and the latency it adds to a `sudo` prompt.

**Follow-up:** briefs for the socket and its protocol, the stretching, the sessions, and the properties above; model and arc42 changes after acceptance.
