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

Accepted, 2026-11-08, on the maintainer's decision the same day: option C (proposed 2026-11-08).

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
