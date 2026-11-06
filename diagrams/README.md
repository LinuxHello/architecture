---
type: note
subject: Rendered C4 diagrams and how they are produced
artifact: diagrams-index
status: draft
owner: "@atterdag"
concepts: [c4, structurizr, diagrams]
tags: [architecture, c4, diagrams]
sources: ["../workspace.dsl", "../adr/0008-code-documentation-mapped-to-c4.md"]
date: 2026-11-06
---

# Rendered C4 diagrams

Every file here is generated from [workspace.dsl](../workspace.dsl), which stays the only source ([ADR-0008](../adr/0008-code-documentation-mapped-to-c4.md)). **Never edit an SVG by hand; change the DSL and render again.** The files are named after the Structurizr view keys.

| File | View | Embedded in |
| :-- | :-- | :-- |
| [Context.svg](Context.svg) | `systemContext linuxHello "Context"` | [Section 3](../arc42/03-context-and-scope.md) |
| [Containers.svg](Containers.svg) | `container linuxHello "Containers"` | [Section 5.1](../arc42/05-building-block-view.md#51-level-1-containers) |
| [Agent.svg](Agent.svg), [PAM.svg](PAM.svg), [TPMProvider.svg](TPMProvider.svg), [KeePassXCBridge.svg](KeePassXCBridge.svg), [Plasma.svg](Plasma.svg), [CLI.svg](CLI.svg), [SecurityProfiles.svg](SecurityProfiles.svg) | one component view per container | [Section 5.2](../arc42/05-building-block-view.md#52-level-2-components) |

The diagrams are large because the auto-layout spreads each view over many ranks. They are vector images: open one on its own to zoom.

## Rendering

After you change [workspace.dsl](../workspace.dsl), render again and commit the result:

```bash
scripts/render-diagrams.sh
```

The script checks its own prerequisites (docker or podman, node and npm, Chrome). It starts the pinned `structurizr/structurizr` image (v2026.09.19, `local` mode) on a scratch copy of the DSL, so Structurizr cannot write into this repository. It then drives the diagram page in headless Chrome with Playwright, exports each view with `structurizr.scripting.exportCurrentDiagramToSVG`, and writes `diagrams/<view key>.svg`.

Two workarounds are in [scripts/render/render.mjs](../scripts/render/render.mjs):

- At this Structurizr version a view with no saved dimensions (the first to load, in practice `Context`) is drawn with `NaN` sizes. The script gives such views the size their elements need, and fails if any export still contains `NaN`.
- The export carries a hidden timestamp. The script removes it, so an unchanged model gives an unchanged file.

## Check in CI

`scripts/render-diagrams.sh --check` renders to a temporary directory and compares it with `diagrams/`. The `diagrams` job in [docs.yml](../.github/workflows/docs.yml) runs it on every pull request. It compares **words, not bytes**: an element's name, description and technology and every relationship label are text in the SVG, so a changed model changes the words, while the font on the machine only changes geometry and line wrapping. On failure the job uploads the fresh render as the `rendered-diagrams` artifact.

What the check does not catch: a change that moves or restyles an element without changing any text, such as a new `styles` rule or a layout setting. Render again by hand after those.

## Open

- **Tested:** the script and the comparison ran locally (Chrome 157, Node 22, rootless podman). A changed description in the DSL made the check fail, and the committed images pass.
- **Not tested:** the `diagrams` job on a GitHub-hosted runner (Docker, the runner's Chrome, `--no-sandbox`), and how GitHub and Obsidian display the SVGs. Fonts fall back from Tahoma to what the viewer has.
- **Not tracked by Dependabot:** the Structurizr image digest in `scripts/render-diagrams.sh`. Update it by hand when you upgrade Structurizr, then render again.
