# Linux Hello architecture

The architecture of [Linux Hello](https://github.com/LinuxHello/linux-hello) at the system context, container and component levels, and the decisions behind it ([ADR-0011](https://github.com/LinuxHello/linux-hello/blob/main/docs/adr/0011-architecture-repository.md)):

- the Arc42 sections, one note per section;
- the C4 model, `workspace.dsl` (Structurizr DSL), levels 1 to 3;
- the architecture decision records;
- the spikes.

The code level stays with the code, in `linux-hello`'s doc comments, and `linux-hello` pins this repository as a submodule to check them against the C4 model. The security properties and the policy semantics also stay in `linux-hello`, because tests and code quote them.

The content moves here from `linux-hello` with its history ([#71](https://github.com/LinuxHello/linux-hello/issues/71)). Issues are tracked in [`linux-hello`](https://github.com/LinuxHello/linux-hello/issues).

## Contributing

The rules of `linux-hello`'s [AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md) and [CONTRIBUTING.md](https://github.com/LinuxHello/linux-hello/blob/main/CONTRIBUTING.md) apply: changes reach `main` by pull request and squash merge, every commit is signed off (`git commit -s`, [DCO](https://developercertificate.org/)), and no secrets, personal data or machine details go into this public repository.

## Licence

LGPL-3.0-or-later, as `linux-hello` ([ADR-0002](https://github.com/LinuxHello/linux-hello/blob/main/docs/adr/0002-licence-lgpl-3-or-later.md)).
