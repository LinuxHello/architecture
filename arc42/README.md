---
type: index
subject: Linux Hello architecture documentation, structured by the Arc42 template
artifact: architecture-index
status: active
owner: "@atterdag"
concepts: [arc42, c4, architecture]
tags: [architecture, arc42, index]
sources: ["../workspace.dsl", "../adr/0010-arc42-architecture-documentation.md", "../adr/0008-code-documentation-mapped-to-c4.md", "https://arc42.org/overview"]
date: 2026-11-05
---

# Linux Hello architecture (Arc42)

This is the architecture documentation of Linux Hello, a program that lets a person sign in to their Linux computer, and to websites and apps with passkeys, using their face, their fingerprint or a PIN. It follows the twelve sections of the [Arc42 template](https://arc42.org/overview), a common way to split architecture documentation so that every reader knows where to look ([ADR-0010](../adr/0010-arc42-architecture-documentation.md)). Start with [section 1](01-introduction-and-goals.md); the table below says what each section holds. C4 diagrams live only in [workspace.dsl](../workspace.dsl) ([ADR-0008](../adr/0008-code-documentation-mapped-to-c4.md)); sections 3, 5 and 7 name its views and do not redraw them. Decisions stay in [docs/adr/](../adr/README.md).

If passkeys, the TPM, PAM or D-Bus are new to you, keep the [glossary](12-glossary.md) open beside the other sections: it explains each of their terms in everyday words and says what Linux Hello uses it for.

A section marked **gap** has no content yet; nothing has been invented to fill it.

| Arc42 section | Note | State |
| :-- | :-- | :-- |
| 1. Introduction and goals | [01-introduction-and-goals.md](01-introduction-and-goals.md) | Written: Linux Hello in five minutes and what works today, the main requirements, ranked quality goals, stakeholders. Start here |
| 2. Constraints | [02-constraints.md](02-constraints.md) | Written: the licence and upstream rules C1 to C5 with their reasons, the licences of the programs Linux Hello uses, the facts about the platform it must accept, and how the project works |
| 3. Context and scope | [03-context-and-scope.md](03-context-and-scope.md) | Written: the people and the outside programs Linux Hello uses, what for and whether each is needed; the channel to each and whether it is built; what is not in scope |
| 4. Solution strategy | [04-solution-strategy.md](04-solution-strategy.md) | Written: the idea in one paragraph, the five layers a request passes, the design rules with their reasons, signing in again without the user, and why this approach over the alternatives |
| 5. Building block view | [05-building-block-view.md](05-building-block-view.md) | Written: the ten parts of Linux Hello and the pieces inside each, what each does and why it is separate, and which are built |
| 6. Runtime view | [06-runtime-view.md](06-runtime-view.md) | Written: four walkthroughs with sequence diagrams (signing in with a fingerprint, signing in when Linux Hello is not working, a passkey on a website, resetting a forgotten PIN), each saying what is built |
| 7. Deployment view | [07-deployment-view.md](07-deployment-view.md) | Written: every file the Agent installs and what it is for, how the Agent starts, is confined and comes back after a failure, and what was tested on Ubuntu 24.04 and 26.04 |
| 8. Crosscutting concepts | [08-crosscutting-concepts.md](08-crosscutting-concepts.md), an overview, with one note per concept: [trust chain](08-trust-chain.md), [security](08-security.md), [user experience](08-user-experience.md) and [policy](08-policy.md). In the code repository: [policy-semantics.md](https://github.com/LinuxHello/linux-hello/blob/main/docs/architecture/policy-semantics.md) and [docs/security/](https://github.com/LinuxHello/linux-hello/blob/main/docs/security/README.md) | Written: which proof unlocks what, the threats and their answers, what the user sees at every prompt, and the rules an administrator and a user can set |
| 9. Architecture decisions | [09-architecture-decisions.md](09-architecture-decisions.md), with the full list in the [ADR index](../adr/README.md) | Written: what a decision record is and how to read one, and every decision grouped by topic with one sentence on what it decides |
| 10. Quality requirements | [10-quality-requirements.md](10-quality-requirements.md) | Written: the four quality goals as checks, the security properties, what must happen when something fails (A1 to A3), and the time budgets (L1 to L5), none measured yet |
| 11. Risks and technical debt | [11-risks-and-technical-debt.md](11-risks-and-technical-debt.md) | Written: the open questions and which part each blocks, the risk register with an example and rating per risk, and the shortcuts taken knowingly |
| 12. Glossary | [12-glossary.md](12-glossary.md) | Written: passkeys and the web, keys and the TPM, the Linux desktop, Linux Hello's own words, and words about the documentation |

New section content goes into the matching note. A crosscutting concept large enough for its own note sits beside the others as `08-<concept>.md`, and the overview in section 8 links it.

[target-architecture.md](target-architecture.md) is the former single architecture note; it now only says where each of its parts went.
