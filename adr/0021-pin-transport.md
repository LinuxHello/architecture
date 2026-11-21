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

Accepted, 2026-11-15, on the maintainer's decision the same day (proposed 2026-11-15). Amends [ADR-0014](0014-agent-bus.md) for the PIN only. Answers [issue 140](https://github.com/LinuxHello/linux-hello/issues/140). The maintainer chose the dedicated Agent socket (option A below) and accepted decisions 2 to 5 as written. Amendment accepted 2026-11-18, on the maintainer's decision the same day (proposed 2026-11-18): the control call is `ExpectPin(prompt_id)` (see *Amendment 2026-11-18*). Amendment accepted 2026-11-19, on the maintainer's standing approval of the lead's recommendations (proposed 2026-11-19): the parameters of the PIN stretching (see *Amendment 2026-11-19*). Amendment proposed 2026-11-21: when a PIN expires and what happens then (see *Amendment 2026-11-21*).

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

### Amendment 2026-11-20 (accepted): setting and changing a PIN are `SetPin(prompt_id)` and `ChangePin(prompt_id)`

Until now a PIN could only be checked. Nothing in the bus let a person set the first one or change it, and a method name shipped to clients cannot be taken back (AGENTS.md, invariant 7), so this amendment names the two calls and fixes how they work.

In plain words: setting a PIN works like signing in. The program that asks (the settings page or the command line) opens a prompt for the user, says "this prompt is for setting a PIN" with `SetPin`, announces each PIN with `ExpectPin` and sends it on the PIN socket, exactly as for a sign-in. The Agent stretches the PIN, has the TPM make the user's root key, and reports success or failure the way a sign-in does, through the prompt's `Result` signal. Nothing new waits on the bus, and no PIN is ever a message body.

1. **The methods.** `SetPin(s prompt_id)` and `ChangePin(s prompt_id)` on `io.github.LinuxHello.Agent1`. Both return nothing at once. Success of the call means the Agent has started and now waits for PINs; the outcome arrives as the `Result` signal of the prompt (`success` or `failure`) and in `GetState`, as for `Authenticate`.
2. **The PINs, in order.** `SetPin` takes one PIN, the new one. `ChangePin` takes two: the current PIN first, then the new one. The caller announces each with its own `ExpectPin(prompt_id)` and sends it on the socket, within the 30 seconds of the socket's rules. Asking the person to type the new PIN twice and comparing the two is the client's job, before it sends anything.
3. **Who may call, and for whom.** Only the process that opened the prompt, as for `ExpectPin`, and only for the user the caller is. Root may not set or change another user's PIN: the PIN is that user's secret, and what an administrator can do is reset the user's enrolment ([ADR-0003](0003-destructive-reset.md)). A call for another user's prompt is `Denied`, with the same fixed text as elsewhere.
4. **Refusals.** From the closed set of ADR-0014: `InvalidArgument` for a malformed id, and for `SetPin` when the user already has a PIN (the fixed text says to use `ChangePin`); `Denied` as in point 3; `Unavailable` when the PIN socket, the provider or the TPM is not there. A PIN that breaks the rules of `GetPinRules` (too short, too long, not text) ends the prompt in `failure` with a reason the client can show, and nothing is written.
5. **A wrong current PIN counts.** In `ChangePin` the current PIN goes through the same per-user counter as a sign-in (decision 5): it is counted first, can lock the user out, and is refused while the user is locked. A wrong current PIN ends the prompt in `failure` and changes nothing.
6. **What happens to the key.** `SetPin` makes the root key (the provider's `Enrol`) and stores the record with a fresh salt; `ChangePin` changes the authorisation of the existing key in place and writes a new salt (the provider's `ChangeAuth`, [spike 0011](../spikes/0011-tpm-root-key-change-auth.md)). The record is replaced only after the TPM has changed the key, so a failure in between leaves the old PIN working.
7. **Version.** Both are new optional members, additive under the ADR-0014 amendment of 2026-11-17, and both appear in `GetCapabilities`.
8. **Tests the code will name:** `set_pin_enrols_the_user_and_the_pin_then_signs_in`, `set_pin_twice_is_refused`, `change_pin_with_a_wrong_current_pin_changes_nothing_and_counts`, `change_pin_while_locked_is_refused`, `a_pin_for_another_user_is_never_set`, `set_pin_and_change_pin_are_listed_in_capabilities`.

Not decided here: the command and the settings page that call these, and the reset of ADR-0003 that removes the record.

### Amendment 2026-11-20 (accepted): the PIN history

The policy has a key `pin.history`: how many earlier PINs a person may not use again. Without it a person told to change their PIN can "change" it back to the old one. Enforcing it needs the Agent to remember something about the earlier PINs, and what it remembers is stored data in a format that later versions must read, so this amendment fixes it.

In plain words: when a PIN is changed, the Agent keeps a fingerprint of the PIN that was just replaced, made with the same slow function as the PIN itself but with a salt of its own. The next time the PIN is changed, the new PIN is stretched with each remembered salt and compared with the fingerprints, and refused when it matches one. The fingerprints cannot be used to open anything, and finding the PIN behind one is as slow as guessing a PIN against the TPM's own key material offline would be.

1. **What may not be reused.** The current PIN and the last `pin.history` PINs that were replaced. With `pin.history = 0` nothing is remembered and only the current PIN is refused.
2. **What is stored.** In the user's record (`pin-root.toml`), a list of entries, newest first, each with its own random 16-byte salt and the Argon2id result (32 bytes) of the PIN with that salt and the cost the record then used. The salt of an entry is **never the salt of a root key**, so an entry is not the authorisation value of any key, present or past. An older record without the list is read as an empty history, and a record with a malformed entry is refused as untrusted, as every other malformed field is.
3. **How many.** At most 24 entries, whatever the policy says, so that a record stays small and a change stays quick: each remembered entry costs one stretching (about a tenth of a second) when a PIN is changed. A policy value above 24 is read as 24, and `GetPinRules` still reports the policy's own number.
4. **When it is checked.** Only in `ChangePin`, and only after the current PIN has been proved right to the TPM, so that nobody who does not know the current PIN can learn from the answer whether a PIN is a former one. A reused PIN ends the prompt in `failure`, nothing is changed, and the person is told the PIN was used before.
5. **When an entry is added.** After the TPM has changed the key and the record is written: the replaced PIN becomes the newest entry and the list is cut to the limit, in the same atomic write as the new blobs, so a crash leaves either the old PIN with its old list or the new PIN with the new one.
6. **`SetPin`** starts an empty history. A reset ([ADR-0003](0003-destructive-reset.md)) deletes the record and so the history with it.
7. **Expiry** (`pin.expiry_days`) is not decided here: it needs the Agent to say at sign-in that a PIN has expired, which is a decision for the sign-in flow. (Decided in the amendment of 2026-11-21.)
8. **Tests the code will name:** `a_replaced_pin_cannot_be_used_again_within_the_history`, `the_history_is_only_asked_after_the_current_pin_is_right`, `the_history_never_holds_a_key_authorisation`, `an_old_record_without_a_history_is_read`, `a_record_with_a_malformed_history_is_untrusted`, `a_change_that_fails_leaves_the_history_alone`.

### Amendment 2026-11-21 (proposed): when a PIN expires, and what happens then

The policy has a key `pin.expiry_days`: after how many days a person must change their PIN (1 to 730; without it a PIN never expires). The policy files already accept the key, but nothing acts on it. Acting on it needs two things that cannot be taken back once shipped: a date stored in the user's record, which later versions must read, and the codes that tell the person, which clients will match on ([ADR-0024](0024-agent-status-interface.md), point 3). So this amendment fixes both.

In plain words: the Agent writes down when the PIN was last set or changed. When the policy's number of days has passed since then, the PIN has expired. An expired PIN **keeps working**; the person is told, on every screen that shows the Agent's status, that the PIN has expired and should be changed. From two weeks before, they are told it will expire soon. Changing the PIN starts the count again.

| Option | What happens when the PIN has expired | Pros | Cons |
| :-- | :-- | :-- | :-- |
| **A. Tell, do not refuse** | The PIN works; `GetStatus` reports `pin-expired` until it is changed | Nobody is locked out; needs nothing from the login screen that does not exist yet; the stored data also serves B later | The setting is a strong reminder, not a guarantee: a person can ignore it |
| B. Force a change at the next session sign-in | The PIN works at the login and lock screens, and the screen then makes the person run `ChangePin` before the session opens | The rule is kept | The login and lock screens do not exist yet ([ADR-0016](0016-prompt-hosts.md)); a change that fails at that moment blocks the session |
| C. Refuse the expired PIN | The PIN fails like a wrong one | The rule is kept without help from any screen | The person falls back to the account password, which in [ADR-0003](0003-destructive-reset.md) resets the enrolment and destroys the device-bound passkeys. A policy setting must never destroy keys |

**Option A**, with the stored data chosen so that B can be added later as an additive change, once the login and lock screens can run a PIN change.

1. **What expiry means.** A PIN has expired when `pin.expiry_days` days (of 86,400 seconds each) have passed since it was last set or changed. An expired PIN is still the authorisation of the root key and is accepted as before; the `Result` of a sign-in with it is `success`, with no new reason. *Why:* refusing it would leave the person only the account password, and that is the destructive reset (option C).
2. **What is stored.** The user's record (`pin-root.toml`) gains `changed_at`: the time of the last `SetPin` or `ChangePin`, as whole seconds since 1970-01-01 UTC (a Unix time). It is written in the same atomic write as the blobs and the history, so a crash leaves the old time with the old PIN or the new time with the new one. A value that is not a whole number of zero or more makes the record untrusted, as every other malformed field does. The record's version stays 1, because an Agent that does not know the field ignores it.
3. **A record from before this amendment.** A record without `changed_at` counts from the time the file was last modified. Only `SetPin` and `ChangePin` write the file, so that is when the PIN was last set. The Agent does not write the field until the next change.
4. **Which number of days.** The user's effective policy at the moment of the check: the administrator's layer merged with the user's own, where the user can only make it shorter ([ADR-0018](0018-user-policy-layer.md)). No expiry date is stored, so a policy that lowers the number applies at once to PINs that already exist, and removing the key ends expiry for everyone.
5. **A clock that goes back.** If `changed_at` lies in the future (the clock was set back, or the record came from a machine with a different clock), the PIN counts as changed now: it has not expired, and the reminder starts later. Only root can set the clock, and root can change the policy anyway, so an earlier expiry is not something worth defending against here.
6. **How the person is told.** Two new codes of `GetStatus`, both severity `warning`, both only for the caller's own PIN, and only when the caller has a PIN record and the effective policy sets `pin.expiry_days`:
   - **`pin-expires-soon`**, from 14 days before the PIN expires: "Your PIN expires in N days. Change it with linuxhello-ctl pin change." N is the number of days left, rounded up, at least 1. The 14 days are fixed; with an expiry shorter than 14 days the reminder runs from the start.
   - **`pin-expired`**, from the moment it expires until the PIN is changed: "Your PIN has expired. It still works, but change it now with linuxhello-ctl pin change."

   Once the system settings page exists the sentences can name it; a sentence may change, a code may not (ADR-0024, points 3 and 5).
7. **What starts and ends the count.** `SetPin` writes the first `changed_at`. `ChangePin` writes a new one, only when the change succeeds; a change that fails leaves the old time, as it leaves the old PIN and the history. A reset ([ADR-0003](0003-destructive-reset.md)) deletes the record and the time with it.
8. **Where the message reaches the person.** In `linuxhello-ctl status`, and on the login and lock screens through `GetStatus` ([#213](https://github.com/LinuxHello/linux-hello/issues/213)). The PAM module is not changed: it stays the thin client of [ADR-0023](0023-pam-module-and-login-failure.md). `linuxhello-ctl doctor` reads files and checks no user's PIN, so it does not report these codes.
9. **Later, option B.** A later amendment may make the login and lock screens ask for `ChangePin` when they see `pin-expired`. That needs no change to the record or to the codes above.
10. **Tests the code will name:** `a_pin_expires_after_the_policys_days`, `an_expired_pin_still_signs_in`, `status_says_a_pin_expires_soon_from_fourteen_days_before`, `a_change_starts_the_count_again`, `a_change_that_fails_keeps_the_old_time`, `a_record_without_a_time_counts_from_the_files_modification`, `a_time_in_the_future_counts_as_now`, `a_record_with_a_malformed_time_is_untrusted`, `no_expiry_is_reported_without_the_policy_key_or_without_a_pin`.

Not decided here: option B, and the wording of the sentences in the system settings page, which does not exist yet.

## Consequences

**Easier:** the PIN is out of the bus daemon's reach, logs and buffers; one place checks the caller and the subject.

**Harder:**

- A second endpoint to confine: its socket path, its mode, its AppArmor rule and a test that a process of another user cannot connect usefully.
- The PIN verifier in the model ([workspace.dsl](../workspace.dsl), `pinVerifier` in `pam_linuxhello`, an edge to the TPM) must change: the PAM module sends the PIN to the Agent and only the Agent talks to the TPM. [Section 5](../arc42/05-building-block-view.md) follows this ADR once accepted.
- Stretching changes the stored root-key authorisation: existing blobs and the PIN-change flow of [spike 0011](../spikes/0011-tpm-root-key-change-auth.md) need the salt.
- Not measured: the cost of the key-derivation function on the target hardware and the latency it adds to a `sudo` prompt.

**Follow-up:** briefs for the socket and its protocol, the stretching, the sessions, and the properties above; model and arc42 changes after acceptance.
