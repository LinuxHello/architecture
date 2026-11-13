---
type: adr
subject: A shared memory for the coding agents that returns evidence with its provenance and never a verdict
artifact: adr
status: proposed
owner: "@atterdag"
concepts: [agents, memory, retrieval, consistency, governance]
tags: [adr, agents, memory]
sources: ["0004-agent-roles.md", "0007-unattended-agent-loops.md", "0009-self-hosted-runner.md", "https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md"]
date: 2026-11-13
---

# ADR-0019: A shared memory for the coding agents

## Status

Proposed, 2026-11-13.

## Context

The coding agents ([ADR-0004](0004-agent-roles.md), [ADR-0007](0007-unattended-agent-loops.md)) work one issue at a time and start each run with nothing. Each re-derives what the others already settled, and they disagree: two drafts of one brief scoped the same issue differently, and a draft invented a method that does not exist. The maintainer wants the agents to share one memory so they stay consistent.

Consistency is half the requirement. The agents must also **apply critical thinking**: a memory that every agent trusts spreads one wrong entry to all of them, and a model that reads "the project decided X" tends to repeat it rather than check it. So the memory must help an agent find what is known without becoming an authority the agent stops questioning.

Facts that shape the design:

1. **Sources disagree.** The maintainer's notes, the issues, the ADRs and the code describe the same things at different dates, and some notes are out of date. A retrieval that returns the nearest text hides this.
2. **Part of the material is private.** The maintainer keeps private notes that name machines, models and paths. This repository, `linux-hello` and its issues are public ([AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md), invariant 8). An agent that drafts a public brief and can retrieve private text can publish it.
3. **Agents write too.** Model output stored as knowledge becomes a fact the next run cites. The invented method in a draft would then be "known".
4. **The authority already exists.** Issues, pull requests, ADRs and code on GitHub, and the workstation's configuration in git, are where a decision is made and reviewed. A second store of truth would drift from them.

## Decision

The workstation hosts a **memory service** backed by an embedded vector database (LanceDB). It is a **rebuildable index with an append-only agent log, not a source of truth.** Everything in it is evidence, and every answer says where the evidence came from.

### What the memory holds

| Kind | Source | Written by | Trust |
| :-- | :-- | :-- | :-- |
| `decision` | accepted ADRs, merged pull requests | the indexer | highest of the prose kinds; reviewed by a human |
| `code` | the repositories at a commit | the indexer | what the repository contains, nothing about intent |
| `issue` | issues and comments, briefs | the indexer | a claim by its author, with date |
| `note` | the maintainer's private notes | the indexer, read-only | the maintainer's thinking at a date; may be superseded |
| `agent` | what an agent concluded or learned in a run | the agent, through the service | **unverified** until a human or a passing test promotes it |

Every row carries: the kind, the source and its location, the commit or modification time it was read at, the document's own status and date where it has them, the embedding model and its dimension, and for `agent` rows the writing agent, the run and the issue. Embeddings come from the local embedding model; a row whose model differs from the current one is excluded from search until it is re-embedded.

### What it does not hold

- **Coordination state** (who works on which issue, what is claimed or blocked) stays in GitHub labels and the issue thread ([ADR-0007](0007-unattended-agent-loops.md)). LanceDB has no locks or queues, and a second copy would disagree.
- **Decisions.** A decision is made by an ADR or a reviewed pull request. The memory indexes it afterwards.
- **Credentials**, and anything the indexer is not allowed to read.

### How an agent reads it

Agents reach the memory only through the service, never the files. The service:

- **Returns evidence, not answers.** Each hit shows its kind, source, date, status and the text. No summary, no "the project does X".
- **Surfaces disagreement.** When hits on the same topic come from different kinds or dates and differ, the service returns them together and marks the conflict. Older material is ranked below newer, and a `decision` above a `note`, but nothing is dropped.
- **Ranks by authority, then similarity.** Live configuration and the code outrank any note about them.
- **Combines keyword and vector search.** Identifiers, file names and error strings are matched exactly; prose is matched by meaning.
- **Applies the tier of the caller** (next section).

### How critical thinking is kept

A prompt that says "be critical" does not hold against a model that has just read a confident note. The harness holds it, with checks that do not involve the model:

1. **Cite or do not claim.** A brief or a refine round that states a fact about the repository or the project names its source. The harness checks that a cited file, identifier or issue exists at the commit the agent works from, as `lh-draft` already checks names ([ADR-0007](0007-unattended-agent-loops.md)).
2. **Verify before use.** A `note` or `agent` hit is a lead to check against `code` or `decision`, not a premise. The harness shows the agent when such a hit conflicts with the repository and requires the brief to say which it followed and why.
3. **Agent writes are quarantined.** An `agent` row is returned labelled unverified, ranked last, and never used to satisfy check 1. A human, or a test that passes, promotes it; otherwise it expires.
4. **Contradictions go to the lead.** When the service reports a conflict the agent cannot settle from the code, the draft lists it under "Open questions for the lead" ([ADR-0004](0004-agent-roles.md)) rather than picking one side.
5. **Staleness is visible.** Every hit shows its age and whether its source has changed since it was read. A changed source is re-indexed; a deleted one is removed.

The checks cannot catch every wrong inference. The lead's review ([ADR-0004](0004-agent-roles.md)) stays the last gate.

### Private and public tiers

The memory has two tiers, and the caller's tier is fixed by the harness that starts the agent, not by the agent or its prompt:

- **public**: `decision`, `code`, `issue` from public repositories, and `agent` rows written by public-tier runs.
- **private**: everything in public, plus `note` and anything else the maintainer marks private.

An agent that writes to a public repository (drafting briefs, ADRs, issues, pull requests) is public-tier and cannot query the private tier. Private-tier agents may read both. A write inherits the tier of the run that made it, and a private row never becomes public by promotion. If the same text must be public, it is written again through a public source.

### Where it lives

LanceDB data sits on the workstation's encrypted volume, in its own directory, separate from any application's store. Retrieval runs as a local service on loopback with the same confinement as the other agent tooling ([ADR-0007](0007-unattended-agent-loops.md)). The indexer is a deterministic job and reads the notes and repositories read-only. The configuration, the schema, the indexer and the service live in the private workstation repository (invariant 8); this ADR records only the contract above.

### First scope

The first indexer reads the maintainer's private notes (text only; images, audio and video are skipped) and this organisation's repositories. Notes written by earlier model runs are left out until the provenance check above exists, because they are the largest source of unreviewed claims. Other agents' notes and the maintainer's other projects join later, one source at a time.

## Consequences

**Easier:**

- Agents start from what is already settled instead of re-deriving it, and cite where it came from.
- A wrong note or agent conclusion is visible as such and cannot satisfy a check by repetition.
- The index is disposable: rebuilding it from the sources recovers everything except `agent` rows, which are unverified by design.

**Harder:**

- The service, the indexer and the tier rule are new code that sits between the maintainer's private notes and public drafts. A flaw in the tier check leaks private text into public artefacts, so the tier rule needs a security property and a test named after it before code ([AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md)).
- Conflict detection is heuristic: same topic, different kind and date. It will miss some conflicts and flag some that are not.
- Notes carry no reliable status today. The index treats an unmarked note as undated evidence until the maintainer marks it, so some retrieval will be down-ranked until then.
- Changing the embedding model re-embeds everything.

Follow-ups: the table schema and the tier rule with their tests; the indexer for notes and repositories; the retrieval service, with the check that cited names exist; how `lh-draft` and the implementer call it; promotion and expiry of `agent` rows.
