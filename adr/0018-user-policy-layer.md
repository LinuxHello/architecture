---
type: adr
subject: The user layer of the routing policy is kept by the Agent and set over D-Bus, not read from the home directory
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [policy, user-layer, agent, state, dbus]
tags: [adr, policy]
sources: ["0014-agent-bus.md", "../arc42/07-deployment-view.md", "../arc42/08-crosscutting-concepts.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md", "https://github.com/LinuxHello/linux-hello/blob/main/docs/security/threat-model.md"]
date: 2026-11-08
---

# ADR-0018: Where the user layer of the routing policy lives

## Status

Accepted, 2026-11-08, on the maintainer's decision the same day: option C (proposed 2026-11-08). Amendment proposed 2026-11-10: what a write refuses, and what a faulty user layer leaves in force (see *Amendment 2026-11-10*); it changes points 3 and 4 and is not accepted yet.

## Context

The routing policy has three layers ([policy semantics](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md)): the built-in defaults, the **user layer**, and the **admin layer** in `/etc/linuxhello/policy.d/`, which wins. The user layer can only tighten a default, never loosen it: a user may require a hardware TPM for their own account, switch face login off, or ask for the PIN more often. The admin layer is what the owner of the machine enforces on everybody.

The user layer was specified as `~/.config/linuxhello/policy.toml`, edited in Settings. That fitted a per-user session daemon, which can read its own user's home. [ADR-0014](0014-agent-bus.md) made the Agent one system service for all users, run by its own user `linuxhello`. Reading the user layer from home directories then conflicts with how the service is built and deployed ([section 7](../arc42/07-deployment-view.md)):

- **Permissions.** Home directories are mode 0750 on Ubuntu 24.04 and 26.04, and the service user cannot enter them (checked in the test VM). Loosening that for the service weakens every user's home.
- **Confinement.** The unit sets `ProtectHome=yes` and the AppArmor profile denies `/home/**`, on purpose; an exception for one file per user needs a wildcard rule over all homes.
- **Login time.** The login manager and `sudo` need the policy before, or without, the user's session; an encrypted or network home may not be mounted yet.
- **Trust.** A privileged service that opens files in a user-writable directory has to defend against symlinks, races and unexpected types on every read. The Agent otherwise reads only files it owns and the root-owned admin directory.
- **Consistency.** The user's other Linux Hello data, such as root-key blobs, is already kept by the Agent under `/var/lib/linuxhello`, not in homes.

| Option | Pros | Cons |
| :-- | :-- | :-- |
| A. Keep `~/.config/linuxhello/policy.toml` and let the Agent read it | A plain file the user edits; no new API | The Agent must enter every home (permissions, sandbox, profile all relaxed); not available before the home is mounted; the Agent opens user-controlled paths |
| B. A per-user helper reads the file and hands the text to the Agent | The Agent stays out of homes | A second component and process per session; still not there at login; the Agent trusts the helper's claim of who the user is |
| **C. The Agent keeps each user's layer in its own state and users set it over D-Bus** | Works at login and without a home; no home access, no sandbox or profile change; the caller's uid is already authenticated by the bus; validated when it is written | The user does not edit a file in their home; two new methods on the Agent interface |
| D. A root-written file per user under `/etc/linuxhello/users/` | Plain files; no new API | A user cannot change their own tightening without root, which removes the point of the layer |

## Decision

**Option C.**

1. **Storage.** The user layer of the user with uid `N` is the file `/var/lib/linuxhello/users/N/policy.toml`, in the Agent's state directory (mode 0700, owned by `linuxhello`). Only the Agent reads and writes it; it writes by creating a temporary file and renaming it, so a reader never sees half a file.
2. **API.** Two methods on `io.github.LinuxHello.Agent1` ([ADR-0012](0012-dbus-names.md) fixes the name; these are new members): `GetUserPolicy() -> s` returns the caller's layer as TOML text (empty when none), and `SetUserPolicy(s)` replaces it. The caller's uid comes from the bus peer credentials, as for every other call ([ADR-0014](0014-agent-bus.md)); a caller can read and change only its own layer, and a caller without a readable uid is refused. There is no method to read or set another user's layer; the administrator uses the admin layer for that.
3. **Validation on write.** `SetUserPolicy` parses the text with the same strict schema as every layer and refuses an unparseable text, an unknown key or an out-of-range value with `InvalidArgs`, so the stored file is always loadable. The text is limited to 64 KiB. Whether a setting loosens a default is not checked on write: the merge ignores loosening, as before ([policy semantics](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md#layering)).
4. **Loading.** The policy engine loads the user layer from that path. A file that cannot be parsed, for example after disk damage, is treated as before: fail closed, PIN only, for that user.
5. **Editing.** The Settings module and `linuxhello-ctl` call the two methods. `linuxhello-ctl policy edit` opens the user's editor on a temporary copy and submits it through `SetUserPolicy`, so editing a file stays possible. The admin layer is unchanged: root-owned files in `/etc/linuxhello/policy.d/`.
6. **No home access.** The unit and the AppArmor profile need no change; the Agent never reads `~/.config/linuxhello/`. Nothing is migrated, because no release has used the old location.

### Amendment 2026-11-10: a user layer can never lower an admin rule

Proposed. An integrity review of the code on 2026-11-09 ran probe tests against the implementation of points 3 and 4 and found that they let a user's layer weaken the policy ([linux-hello#127](https://github.com/LinuxHello/linux-hello/issues/127), [#128](https://github.com/LinuxHello/linux-hello/issues/128), [#131](https://github.com/LinuxHello/linux-hello/issues/131)):

- **Point 4 made "fail closed" weaker than the policy it replaced.** A stored layer that parses but contradicts a default (`[pin] digits = "disallowed"`) put the user in the PIN-only state, which was built from the built-in defaults. With an admin layer that set `pin.min_length = 12` and two factors for `sudo`, the result was `min_length` 6 and the PIN alone: one `SetUserPolicy` call removed the admin's rules for that user.
- **Point 3 accepted a layer that locks its user out.** A layer with `factors = 2` and only `pin` allowed for `login`, `unlock` and `sudo` parses, was stored, and left those contexts unsatisfiable. The file is in the Agent's state, so only root can remove it. Any process running as the user could do this.
- **"The merge ignores loosening" did not hold for relying-party classes.** The defaults have no class, so a user class with `prompt = "none"` took effect as written.

The storage, the two methods and who may call them (points 1, 2, 5 and 6) are unchanged. Points 3 and 4 become:

3. **Validation on write.** `SetUserPolicy` refuses with `InvalidArgs`, and keeps the previous layer, when the text
   - does not parse with the strict schema, has an unknown key or an out-of-range value, or is over 64 KiB (as before);
   - contradicts the layers it is merged with: the defaults and the admin layers on disk at that moment;
   - would leave a context needing more methods than it allows. A context that the admin layers already leave that way is not held against the user.

   When the admin layers cannot be read or contradict each other, the policy is PIN-only whatever the user stores, and the text is checked against the defaults alone. Loosening is still not refused on write: the merge ignores it, now also for relying-party classes, where a user class can only make the decision for a relying party stricter and never joins or overrides an admin class ([policy semantics, *Layering*](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md#layering)).
4. **Loading.** The policy engine loads the user layer from that path. A stored file that cannot be read or parsed, for example after disk damage, or that contradicts an admin layer written later, still fails closed for that user: PIN only, biometrics off. That PIN-only state is built on the admin layers and the defaults, and keeps their PIN rules, each context's factor count and the admin's relying-party classes, so a user's file can never lower an admin rule. A context that then needs two factors is unsatisfiable, not lowered. Only when the admin layers themselves are at fault is the state built from the built-in defaults alone, as before.

Alternatives considered for a faulty user layer:

| Option | Pros | Cons |
| :-- | :-- | :-- |
| Keep point 4: PIN-only from the defaults | Simple; one PIN-only state | A user's file removes admin rules; "fail closed" is the weaker state |
| Drop the faulty user layer and apply admin and defaults as if it were absent | The user is never locked out by a damaged file | Silently loses the user's own tightening, such as biometrics switched off; that is failing open for that user |
| **PIN-only built on the admin layers** | Never weaker than the admin layers or than the user's lost tightening; one rule to explain | A damaged file plus an admin rule of two factors leaves a context unusable through Linux Hello until the file is replaced; the account password path must remain ([linux-hello#147](https://github.com/LinuxHello/linux-hello/issues/147)) |

**Easier (amendment):** an administrator's PIN and factor rules hold whatever a user stores; a stored layer cannot lock its user out by itself; the property "the user's layer only tightens" can be stated and tested for every key.

**Harder (amendment):** `SetUserPolicy` reads the admin directory on every write, so the answer depends on the admin layers at that moment, and a later admin change can still make a stored layer contradictory (handled at load); the check counts the methods a context allows, not the methods the user has enrolled, so two factors with an unenrolled fingerprint is still accepted; the PIN-only state now has two forms, which the status shown to the user must tell apart.

Not in this amendment, and still open in [linux-hello#131](https://github.com/LinuxHello/linux-hello/issues/131): a fresh verification before a policy change, an administrator's command to clear one user's layer, and auditing the change.

Follow-ups, once accepted: the properties and tests named in [linux-hello#159](https://github.com/LinuxHello/linux-hello/pull/159) (`user_layer_contradicting_defaults_is_refused_on_write`, `user_policy_that_makes_a_context_unsatisfiable_is_refused_on_write`, `damaged_user_layer_does_not_remove_admin_rules`, `pin_only_state_is_never_weaker_than_the_admin_layer`, `user_layer_cannot_lower_rp_prompt_below_default`); the pin bump in that pull request; the "fails closed: a policy file that does not parse denies every operation except PIN" sentence in [section 8](../arc42/08-crosscutting-concepts.md#layers-and-precedence), which stays true and gains the admin-rules clause.

## Consequences

**Easier:** the user layer is there at login and in a `sudo` session without a mounted home; the Agent's sandbox and profile stay as they are; the bus checks who is calling, so no file permissions stand in for that; a malformed policy can never be stored; all per-user data of the Agent is in one place.

**Harder:**

- A user cannot keep the policy in their dotfiles or version control it with them, and it does not follow a home directory to another machine; `linuxhello-ctl policy edit` and an export are the replacement.
- The Agent interface grows two methods and a schema that clients depend on, and a limit on the text size.
- The layer is keyed by uid. If a user is deleted and the uid reused, the new user inherits the old layer. It can only tighten, so the effect is stricter, not weaker, but the layer should be removed with the user; the same question exists for the root-key blobs and is not solved here.
- State under `/var/lib/linuxhello` has to be backed up and cleaned with the users.

Follow-ups, once accepted:

- Security properties and tests named for them: `user_cannot_set_another_users_policy`, `unparseable_user_policy_is_refused_on_write`, `oversized_user_policy_is_refused_on_write`, `user_policy_is_available_without_a_home_directory`.
- Change the places that name `~/.config/linuxhello/policy.toml`: [section 5](../arc42/05-building-block-view.md) and the `User Policy` container in [workspace.dsl](../workspace.dsl), [section 8](../arc42/08-crosscutting-concepts.md) (Policy and UX7a), the layering text of the policy semantics, the threat model's asset A7, and the note in [section 7](../arc42/07-deployment-view.md) that records this question as open.
- A brief for the state-store side (`users/N/policy.toml`, atomic write, size limit) and one for the two D-Bus methods.
