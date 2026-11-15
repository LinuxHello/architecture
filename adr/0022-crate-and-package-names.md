---
type: adr
subject: The crate and package names stay as they are and nothing is published to crates.io in 1.0
artifact: adr
status: accepted
owner: "@atterdag"
concepts: [naming, crates-io, packaging, one-way-door, trademark]
tags: [adr, naming, one-way-door]
sources: ["0012-dbus-names.md", "../spikes/0014-name-trademark-risk.md", "https://github.com/LinuxHello/linux-hello/issues/22"]
date: 2026-11-15
---

# ADR-0022: Crate and package names, and what is published

## Status

Accepted, 2026-11-15, on the maintainer's decision the same day (proposed 2026-11-15). Answers [issue 22](https://github.com/LinuxHello/linux-hello/issues/22). Builds on [spike 0014](../spikes/0014-name-trademark-risk.md) and [ADR-0012](0012-dbus-names.md).

## Context

A crates.io name cannot be reused once taken, and distributions pin package names, so the names are a one-way door. All crates are `publish = false`. [Spike 0014](../spikes/0014-name-trademark-risk.md) found no registered conflict for "Linux Hello" but rated the risk of a complaint about the shared word "Hello" (Microsoft's WINDOWS HELLO, same class of goods) as moderate, and asked for a trade mark attorney's review before the first release.

The names in use: the crates `linuxhello-agent`, `linuxhello-ctl`, `linuxhello-dbus`, `linuxhello-tpm-provider`, `linuxhello-kpxc-bridge` and `pam-linuxhello` (library `pam_linuxhello`), and the D-Bus prefix `io.github.LinuxHello.` of ADR-0012.

Availability on crates.io on 2026-11-15, by the registry's API (HTTP 404, not taken): `linux-hello`, `linuxhello`, `linuxhello-agent`, `linuxhello-ctl`, `linuxhello-dbus`, `linuxhello-tpm-provider`, `linuxhello-kpxc-bridge`, `pam-linuxhello`, `pam_linuxhello`, and the fallback names `lychgate` and `thresholdkey`. PyPI, npm, the AUR, Flathub, Repology and Debian were checked for `linux-hello` and `linuxhello` only on 2026-11-07 (spike 0014) and not again; no package of those names was found then.

| Option | Pros | Cons |
| :-- | :-- | :-- |
| **A. Keep the names; publish nothing to crates.io in 1.0** | Costs nothing; changes no one-way door; the attorney review stays the trigger for a rename | The names are not reserved, so someone else could take them |
| B. Reserve the crate names now with placeholder releases | The names cannot be taken | Locks the names before the trade mark review; leaves orphaned crates if the project is renamed |
| C. Switch to a fallback name (Lychgate) before anything is published | The safest legally | Renames the D-Bus prefix, the Flathub application ID and every crate; reopens ADR-0012 |

## Decision

**Option A.**

1. **The names stay:** the crate names above and the D-Bus prefix of ADR-0012.
2. **Nothing is published to crates.io in 1.0.** Every crate keeps `publish = false`. Distributions package from the source release, so a crates.io name is not needed to install the project.
3. **The trigger for a change is the attorney review** that spike 0014 asks for, before the first release. If it advises a rename, the choice goes to a new ADR that supersedes this one, and the fallbacks of spike 0014 are the starting point.
4. **Publishing a library crate later** (for example `linuxhello-dbus`, if another project wants the interface) needs its own ADR; availability is checked again on that day.

## Consequences

**Easier:** no change to code, packaging or the bus name now; the decision that is hard to reverse stays with the trade mark review.

**Harder:**

- Another project could take a `linuxhello*` name on crates.io before the first release. Nothing in the project depends on it: the crates are built from the repository.
- The availability data for PyPI, npm, the AUR, Flathub, Repology and Debian is the 2026-11-07 data of spike 0014 and is not current; check it again when a package is first built for a distribution.

**Follow-up:** the attorney review before the first release; the D-Bus prefix and the crate names change together if a rename follows.
