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

## Rendering procedure

Rendered 2026-11-06 with Structurizr v2026.09.19 (`structurizr/structurizr` container image, `local` mode, DSL only), from the `workspace.dsl` of this repository at the commit that introduced these files. The procedure was **run by hand, not scripted, and is not checked in CI**, so an image can drift from the DSL until someone renders again.

1. Start Structurizr in `local` mode on a copy of `workspace.dsl`, so it cannot write into this repository.
2. Open `/workspace/1/diagrams` in a browser with a viewport of at least 1600 by 1000.
3. For each view key, call `structurizr.scripting.changeView(key)`, wait for `structurizr.scripting.isDiagramRendered()`, then `await structurizr.scripting.exportCurrentDiagramToSVG({includeMetadata: false})`.
4. Delete the hidden export timestamp (a `display="none"` text) so a render of an unchanged DSL gives an unchanged file.

Known quirk at this Structurizr version: the first view to load (`Context`) came out empty (`NaN` size) until its `dimensions` were set, in the page, to 4500 by 3800 before switching to it. Check every file for `NaN` after rendering.

## Open

- **Not tested:** how GitHub's renderer and Obsidian display these files. Fonts fall back from Tahoma to what the viewer has.
- **Gap:** no CI check that the images match the DSL. A scripted headless export (`structurizr export` with a PNG or SVG format needs a Structurizr URL and a headless browser) would close it.
