---
type: adr
subject: The Agent answers GetStatus with the conditions that affect the caller, and shows file names to root only
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [dbus, status, conditions, doctor, lock-screen, one-way-door]
tags: [adr, one-way-door, dbus, ux]
sources: ["0014-agent-bus.md", "0023-pam-module-and-login-failure.md", "https://github.com/LinuxHello/linux-hello/issues/214", "https://github.com/LinuxHello/linux-hello/issues/155", "https://github.com/LinuxHello/linux-hello/issues/156", "https://github.com/LinuxHello/linux-hello/issues/192", "https://github.com/LinuxHello/linux-hello/issues/213"]
date: 2026-11-17
---

# ADR-0024: The Agent's status interface

## Status

Proposed, 2026-11-17. Answers [linux-hello#214](https://github.com/LinuxHello/linux-hello/issues/214), the interface behind [#155](https://github.com/LinuxHello/linux-hello/issues/155) (the offline `linuxhello-ctl status` and `doctor`, built) and [#213](https://github.com/LinuxHello/linux-hello/issues/213) (status on the login and lock screens). A new D-Bus method is a one-way door (AGENTS.md invariant 7), so it waits for the maintainer's decision.

## Context

`linuxhello-ctl status` and `doctor` read the policy files and report conditions: `policy-pin-only`, `context-unsatisfiable: <context>`, `status-fact-unreadable: the state directory`. Each has a stable code, a severity and one fixed sentence, and `status` never prints a file name. That works offline, for an administrator, from the files alone. It cannot say what only the running Agent knows (the PIN is locked for this user, the TPM is unavailable), and a user at the login or lock screen cannot read the admin policy directory at all. The screens need the same conditions from the Agent, over the bus, scoped to the person looking.

The bus policy lets any user call the Agent's methods and **denies reading properties** (checked on a real system bus by the confinement run), so a `Status` property is not available without changing that rule.

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. A method `GetStatus` that returns the caller's conditions** | One call; answers from what the Agent knows; scoped by the caller's uid like every other call; no change of bus policy | A new method on the interface |
| B. A property with `PropertiesChanged` | Change notification for free | The bus policy denies property reads; opening it widens the policy for every user |
| C. Each client computes status from the files, as `linuxhello-ctl` does | No new method | A user cannot read the admin layers, and no client knows the lock or TPM state |

## Decision

**Option A.**

1. **The method.** `GetStatus()` on `io.github.LinuxHello.Agent1` returns `a(sss)`: a list of conditions, each `(code, severity, sentence)`. An empty list means nothing to report. It always answers a caller whose uid the bus gave, whatever is wrong: a fault is a condition, not an error. A caller without a readable uid is refused like every other call (P-02).
2. **Whose conditions.** Those that affect the caller: the caller's own policy layer and PIN lock, and machine-wide faults that change what the caller can do (an admin policy that failed to load, a context that cannot be satisfied, the TPM unavailable). It never names another user and never says whether another user exists.
3. **Codes.** A closed, stable set of lowercase words in kebab case, optionally followed by one parameter from a closed set (a context name such as `login`, `unlock`, `sudo`). A code is never renamed; a new one is an additive change. A client that does not know a code shows the sentence. The first codes are those of `linuxhello-ctl status`; `tpm-locked` follows with #215.
4. **Severity.** One of `info`, `warning`, `severe`. `severe` is the word `linuxhello-ctl` prints today.
5. **Sentence.** One fixed English sentence per code, written for the user. It carries no file name, no path and no text from any file; a number the Agent computes (minutes of lockout) is the one thing that may vary. A client may translate by code.
6. **File names.** `GetStatusDetails()` returns `a(ssss)`: the same conditions plus a fourth field with the detail the loader gives (the file and what is wrong with it). Only root may call it (uid 0, from the bus credentials); any other caller is refused with the same `AccessDenied` as for any request that is not theirs. `GetStatus` never carries the detail field, so no caller learns a path by omission or by error text.
7. **Health call (#192).** `GetStatus` is the Agent's health call. Liveness stays the standard `org.freedesktop.DBus.Peer.Ping`, which the watchdog of #191 already uses. `linuxhello-ctl status` calls `GetStatus` when the Agent answers and falls back to the offline files when it does not; the fallback adds `agent-unreachable` (severe), a condition **the client** computes, never the Agent.
8. **Errors and version (#156).** `GetStatus` follows the error names and the capability call decided for #156; it adds none of its own. The capability list names `GetStatus` and `GetStatusDetails`.
9. **No signal in this decision.** A client calls `GetStatus` when it shows the screen and after the restart rule (`linuxhello_dbus::restart`). A `StatusChanged` signal can be added later without breaking anything; it would carry no payload and be unicast.
10. **Tests the code will name:** `status_is_scoped_to_the_caller`, `status_never_carries_a_file_name`, `status_details_are_for_root_only`, `status_codes_are_a_closed_set`, and a bus test that a user and root get the answers above.

## Consequences

**Easier:** the login and lock screens, the Settings page and `linuxhello-ctl` show one set of conditions with one vocabulary; a user sees what concerns them and nothing about anyone else; the interface stays additive.

**Harder:**

- Every condition now has two producers: the offline files (`linuxhello-ctl`) and the running Agent. They must keep the same codes and sentences; one table in `linuxhello_dbus` is the source for both.
- The sentences are English only; a translation is the client's job by code.
- Without a signal, a screen that stays open shows stale status until it asks again.
- `GetStatusDetails` is a second method to confine; it needs the same bus-policy and profile coverage as the first (both are on the interface the profile already names).

Not decided here: the exact list of codes beyond the three above, the lockout seconds in `tpm-locked`, and how the greeter and the lock screen lay the conditions out ([#213](https://github.com/LinuxHello/linux-hello/issues/213)).
