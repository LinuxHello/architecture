---
type: adr
subject: D-Bus names are io.github.LinuxHello.*, and the Agent is io.github.LinuxHello.Agent1
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [dbus, naming, one-way-door, governance]
tags: [adr, one-way-door, dbus]
sources: ["https://dbus.freedesktop.org/doc/dbus-specification.html", "https://docs.flathub.org/docs/for-app-authors/requirements", "https://github.com/LinuxHello/linux-hello/blob/main/crates/linuxhello-dbus/src/lib.rs", "https://github.com/LinuxHello/linux-hello/issues/17", "../spikes/0007-pam-dbus-method-state.md", "../workspace.dsl"]
date: 2026-11-06
---

# ADR-0012: D-Bus names

## Status

Accepted, 2026-11-06, on the maintainer's concurrence recorded in [issue #17](https://github.com/LinuxHello/linux-hello/issues/17#issuecomment-6696698496). On the same day the maintainer kept the mixed-case spelling and the `1` suffix after the two questions under [Context](#context) were put to them.

## Context

[GOVERNANCE.md](https://github.com/LinuxHello/linux-hello/blob/main/GOVERNANCE.md) and [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md) (invariant 7) list D-Bus names as a one-way door that needs an ADR. The Agent's names were chosen without one and are already in code: `io.github.LinuxHello.Agent1` as bus name and interface, and `/io/github/LinuxHello/Agent1` as object path ([`linuxhello-dbus`](https://github.com/LinuxHello/linux-hello/blob/main/crates/linuxhello-dbus/src/lib.rs)). The model in [workspace.dsl](../workspace.dsl) quotes the same name.

Clients, bus policy files, AppArmor profiles and the portal hard-code these names, so a name cannot change after a release without breaking every installed copy.

What the sources say, read on 2026-11-06:

- **D-Bus specification 0.43.** Interface names and well-known bus names "should start with the reversed DNS domain name of the author" (in lower-case). Each element may contain `[A-Z][a-z][0-9]_` and must not begin with a digit; a hyphen is discouraged in a new bus name; the whole name is at most 255 characters. Elements that would break these rules are fixed by replacing a hyphen with an underscore or prefixing a leading digit with an underscore.
- **Flathub's application-ID rules** (the convention for projects without a domain): a project hosted on GitHub uses the prefix `io.github.` followed by the owner. Flathub applies a hyphen-to-underscore rule to the owner and allows upper-case letters in a component. `com.github.` is reserved for the code host's own projects.
- The project owns no domain. Its code is hosted under the GitHub organisation `LinuxHello`, whose name has only letters, so no escaping is needed.

Two points the maintainer decided when they were raised:

1. **Case.** The specification's "in lower-case" would make the organisation element `linuxhello`. Mixed case is valid under the element rule, and GitHub organisation names are case-insensitive, so no other owner can hold the same name in another case. The maintainer kept `LinuxHello`, as in the code. The deviation is from the specification's recommendation ("should"), not from its grammar.
2. **Version suffix.** The `1` in `Agent1` is the interface version. The maintainer kept it.

## Decision

1. Every D-Bus name that Linux Hello defines lives under the prefix `io.github.LinuxHello.`, spelled exactly like that (upper-case `L` and `H`).
2. The Agent's well-known bus name and its interface are `io.github.LinuxHello.Agent1`, and its object path is `/io/github/LinuxHello/Agent1`. These are the values in `linuxhello-dbus` today. The trailing `1` is the interface version: a breaking change to the interface is a new name (`Agent2`) that can run beside `Agent1`, not an edit of it.
3. The names derive from the GitHub organisation name, not from the product name.
4. This ADR does not decide which bus the Agent serves. The name is the same on the session and the system bus; spike [0007](../spikes/0007-pam-dbus-method-state.md) found that the PAM module can reach the Agent in every context only on the system bus, and that choice and its bus policy are a separate ADR.

Names in the namespace other than the Agent's are not decided here. They are added to `linuxhello-dbus` when a container needs one.

## Alternatives considered

| Alternative | Why not |
| :-- | :-- |
| `io.github.linuxhello.Agent1` (the specification's lower-case form) | Valid and closer to the wording of the specification. The maintainer kept the spelling of the organisation and the code instead; see Context |
| A domain bought for the project, such as `org.<domain>.Agent1` | A recurring cost and a renewal that, if missed, hands the namespace to someone else. The project has no domain today |
| A name outside the reverse-DNS convention, such as `LinuxHello1` | Breaks the convention the specification gives and the ownership argument that makes collisions unlikely |
| A prefix someone else owns, such as `org.freedesktop.` or `org.kde.` | Not ours to use; names there are allocated by those projects |
| `com.github.` | Reserved by Flathub's rules for the code host's own projects |

## Consequences

**Easier:**

- No domain to buy, renew or lose.
- The prefix is unique because the organisation name is unique on GitHub, and the maintainer controls the organisation.
- `Agent2` can run beside `Agent1` during a migration.
- The names already in code and in `workspace.dsl` stay as they are, so nothing needs to change now.

**Harder:**

- The names are tied to the **GitHub organisation name**. If the organisation is renamed or the repository moves, the prefix stops matching where the project lives. The old names stay valid, but changing them later breaks every installed bus policy, AppArmor profile and client, so a move would mean a superseding ADR and a migration.
- The mixed-case spelling deviates from the specification's recommendation. Names are compared exactly (an assumption not checked in the `dbus` source here), so `io.github.linuxhello.Agent1` would be a different name. Tools and people that expect lower-case will mistype it, and bus policy files and AppArmor rules must spell it exactly.
- Spike [#14](https://github.com/LinuxHello/linux-hello/issues/14) (trademark risk of the product name) is still open and lists this ADR as something it blocks. Because the names come from the organisation, a different **product** name would not change them, but a different **organisation** name would. This ADR does not wait for #14. If #14 recommends a different organisation or product name, the maintainer decides before the first release, and a change is a superseding ADR.
- A breaking interface change costs a new name and a period when both versions run.

## Follow-up

A small issue after this ADR merges: make the `linuxhello-dbus` docs cite this ADR, bump the `architecture` pin in `linux-hello`, and add a test that the Agent's constants use the reserved prefix.
