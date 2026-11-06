---
type: architecture
subject: "Arc42 section 2: constraints on Linux Hello (integration layer, licence boundaries, upstream first)"
artifact: arc42-02-constraints
status: active
owner: "@atterdag"
concepts: [licensing, upstream-first, arc42]
tags: [architecture, arc42]
sources: ["README.md", "../spikes/0013-upstream-licences.md", "../adr/0002-licence-lgpl-3-or-later.md", "https://docs.arc42.org/section-2/"]
date: 2026-11-07
---

# 2. Constraints

Part of the [Arc42 architecture documentation](README.md).

| ID | Constraint | Rationale |
| :-- | :-- | :-- |
| C1 | Linux Hello is an integration layer: it reuses credentialsd, libwebauthn, KeePassXC, fprintd and Howdy and adds only providers, unlock policy, the KDE portal backend and settings UI. **credentialsd v0.3.1 has no provider API** ([spike 0005](../spikes/0005-credentialsd-provider-api.md)); [ADR-0005](../adr/0005-provider-path.md) chooses an own broker or a fork (option D) until upstream gains one, so **the provider path is an exception to this constraint** while D is in force | No reimplementation of existing upstream work, except the provider path under ADR-0005 |
| C2 | Link only to LGPL (or permissive) libraries, e.g. libwebauthn, credentialsd | LGPL permits linking from code under any licence |
| C3 | Reach GPL components only across a process boundary (D-Bus, PAM, socket, KeePassXC browser protocol), never by linking | FSF treats linking as creating a derivative work; separate programs are not |
| C4 | Modifications to an upstream component go upstream as contributions, not into a private fork. Exception: the provider path, where [ADR-0005](../adr/0005-provider-path.md) option D allows a published fork until credentialsd has a usable provider API | Keeps LGPL/GPL obligations trivial and the ecosystem shared; a published LGPL fork keeps the obligations met |
| C5 | Linux Hello itself is LGPL-3.0-or-later ([ADR-0002](../adr/0002-licence-lgpl-3-or-later.md)) | Compatible with credentialsd (LGPL-3.0-only) and other LGPL dependencies |

Licences (verified in [spike 0013](../spikes/0013-upstream-licences.md)): credentialsd LGPL-3.0-only and libwebauthn LGPL-2.1-or-later, both linked; KeePassXC GPL-2.0 or GPL-3.0 and fprintd GPL-2.0-or-later, both reached across a process boundary; Howdy MIT. Not legal advice.

The same constraints, with the no-`unsafe` and fail-closed rules, are binding for contributors as the invariants in [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md#invariants).
