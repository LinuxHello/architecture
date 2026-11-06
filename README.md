# Linux Hello architecture

The architecture of [Linux Hello](https://github.com/LinuxHello/linux-hello) at the system context, container and component levels, and the decisions behind it ([ADR-0011](https://github.com/LinuxHello/linux-hello/blob/main/docs/adr/0011-architecture-repository.md)):

- the Arc42 sections, one note per section;
- the C4 model, `workspace.dsl` (Structurizr DSL), levels 1 to 3;
- the architecture decision records;
- the spikes.

The code level stays with the code, in `linux-hello`'s doc comments, and `linux-hello` pins this repository as a submodule to check them against the C4 model. The security properties and the policy semantics also stay in `linux-hello`, because tests and code quote them.

The content moved here from `linux-hello` at commit [`3212f15`](https://github.com/LinuxHello/linux-hello/tree/3212f15/docs) ([#71](https://github.com/LinuxHello/linux-hello/issues/71)). Its earlier history is in `linux-hello`: `git log -- docs/adr docs/architecture docs/spikes`. Issues are tracked in [`linux-hello`](https://github.com/LinuxHello/linux-hello/issues).

## Contents

| Path | What |
| :-- | :-- |
| [arc42/](arc42/README.md) | One note per Arc42 section, with the index of sections and their state ([ADR-0010](adr/0010-arc42-architecture-documentation.md)) |
| [workspace.dsl](workspace.dsl) | The C4 model in Structurizr DSL: system context, containers, components |
| [diagrams/](diagrams/README.md) | SVG renderings of every C4 view, generated from `workspace.dsl` |
| [adr/](adr/README.md) | Architecture decision records |
| [spikes/](spikes/README.md) | Spikes that test the assumptions the architecture rests on |
| [templates/](templates/) | Templates for ADRs, spikes and notes |

The repository is an Obsidian vault. Links are relative Markdown links, never wikilinks, so the notes render on GitHub too.

## Checks

| Check | What it checks | Required |
| :-- | :-- | :-- |
| `dco` | every commit is signed off | yes |
| `notes` | frontmatter, relative links, no wikilinks ([scripts/check-docs.py](scripts/check-docs.py)) | yes |
| `dsl` | `workspace.dsl` parses (Structurizr CLI) | yes |
| `diagrams` | the images in [diagrams/](diagrams/README.md) say the same words as a fresh render of `workspace.dsl` | no: add it to the branch rules after it has run green a few times |
| `c4-code (advisory)` | `linux-hello`'s crates still name elements of the proposed model | no: the code may follow in its own pull request |

## Contributing

The rules of `linux-hello`'s [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md) and [CONTRIBUTING.md](https://github.com/LinuxHello/linux-hello/blob/main/CONTRIBUTING.md) apply: changes reach `main` by pull request and squash merge, every commit is signed off (`git commit -s`, [DCO](https://developercertificate.org/)), and no secrets, personal data or machine details go into this public repository.

## Licence

LGPL-3.0-or-later, as `linux-hello` ([ADR-0002](https://github.com/LinuxHello/linux-hello/blob/main/docs/adr/0002-licence-lgpl-3-or-later.md)).
