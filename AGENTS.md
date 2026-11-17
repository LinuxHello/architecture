# AGENTS.md

Rules for every coding agent that writes in this repository: Claude Code (cloud or pointed at a local model), GitHub Copilot, and any other tool that reads `AGENTS.md`. Human contributors follow the same rules.

The binding rules are in [`linux-hello`'s AGENTS.md](https://github.com/LinuxHello/linux-hello/blob/main/AGENTS.md): the roles, the source of truth, the invariants, commits and sign-off. This file does not repeat them. It adds what an agent needs here, where the work is writing documents and not code.

## What this repository is

The architecture of Linux Hello, a program that lets a person sign in to websites and apps on a Linux desktop with their face, their fingerprint or a PIN. It holds the Arc42 sections in `arc42/` (Arc42 is a template that splits architecture documentation into twelve fixed sections), the C4 model in `workspace.dsl` (C4 is a way to draw a system at four levels of detail), the decision records in `adr/` and the experiments in `spikes/`. [README.md](README.md) lists the paths and the checks.

## Write for a reader who is new to the subject

The maintainer's rule: a person with no earlier knowledge of the subject must be able to read a document and understand what is going on.

This section is a copy of the section with the same name in `linux-hello`'s AGENTS.md, so that an agent working here has it without following a link. Change it there first, then here.

**Where it applies.** Every note in this repository: the Arc42 sections, the ADRs, the spikes, the indexes and the READMEs.

**The reader to write for.** Someone who uses Linux and has programmed, but has never worked with passkeys, a TPM, PAM, D-Bus or the inside of KDE, and has not read any other page of the project. They arrive on this page from a link or a search and read it once, from the top.

1. **Start with what and why.** The first paragraph of a note says in everyday words what the note is about, which problem it deals with and what the reader knows after reading it. It comes before any table, diagram or identifier.
2. **Explain a term where it first appears in the note.** Give one clause or one sentence, and link the [glossary](arc42/12-glossary.md). Spell an abbreviation out the first time: "the Trusted Platform Module (TPM), a chip that keeps keys so that no software can copy them". Do this in every note, because the reader may start on any page.
3. **Say what an outside program or standard is, and what Linux Hello uses it for,** the first time the note names it: "fprintd, the Linux service that reads fingerprint sensors".
4. **Give every identifier its meaning in words.** Never write a bare `P-12`, `M2`, `UX3`, `L1`, `#139`, "spike 0120", "ADR-0020" or "option B" as if it explained itself. Say what it states, then give the identifier as the reference: "a malicious program running as the same user (actor M2 in the threat model)".
5. **Give the reason and an example.** For every rule and decision say why it exists and what goes wrong without it. Show each new idea once with a concrete case: a real site, a real command, a real prompt.
6. **Write full sentences.** Use a table for things the reader compares or looks up, and prose for reasoning. No fragments, no arrows (`→`) in place of verbs, and no brackets holding three references in a row.
7. **Introduce every diagram.** One sentence before it says what it shows and how to read it; one sentence after it says what to notice. A diagram never stands alone under a heading.
8. **Say what exists today.** Mark each part as built and tested, decided but not built, or still open. A newcomer cannot tell a design from a working program unless the text says so.
9. **Describe the present design first.** What an earlier design was, and why it changed, belongs in the ADR or in one short paragraph at the end of the section, not inside the description.
10. **Stay exact.** Plain does not mean vague. Keep the names, paths, commands and numbers, and put them after the explanation. Never drop a fact to make a text simpler; add the sentence that makes the fact understandable.
11. **A new term goes into the glossary** in the same pull request.

An example of the change this asks for.

Before:

> UV=1 only for a verification of this request or within a window of at most 60 s (ADR-0020).

After:

> A website can ask for *user verification*: proof that the person was checked just now, with a fingerprint, the face or the PIN, and is not merely sitting at the machine. Linux Hello answers "verified" (the UV flag of the CTAP protocol, the language a browser speaks to a security key) only when that check was made for this request, or at most 60 seconds before it. Without the limit a website would be told "verified" hours after the user last proved who they are ([ADR-0020](adr/0020-presence-and-verification.md)).

**Before you call a document done,** read it as that reader. For every term, identifier and name, ask: is it explained on this page, or one link away? If a paragraph can only be understood by someone who took part in the work that led to it, rewrite the paragraph.

### How the rule applies to each kind of note

| Note | What the newcomer needs first |
| :-- | :-- |
| Arc42 section | One paragraph that says which question this section answers and how it connects to the sections before it. Then the content, with the present design first. |
| ADR | A Context that a newcomer can follow: what the parts involved are, what the problem is and why it has to be decided now. The Decision in one plain sentence before its numbered details. |
| Spike | The Question in everyday words and why its answer matters for the design, before the method. The Answer repeated in one plain sentence at the end. |
| Index or README | One sentence per entry that says what the reader finds there, not only its title. |

## Rules of this repository

- Every note opens with frontmatter: `type`, `subject`, `artifact`, `status`, `owner`, `concepts`, `tags`, `sources`, `date`. Start from [templates/](templates/).
- Links are relative Markdown links, never `[[wikilinks]]`.
- C4 diagrams are defined only in `workspace.dsl`; the images in `diagrams/` are rendered from it and never edited by hand. Other diagrams are Mermaid.
- A note that names credentialsd also names ADR-0005 or a spike, because Linux Hello does not build on it.
- Run `python3 scripts/check-docs.py` before you report a change as done, and quote its last line.
- No secrets, personal data or details of anyone's machines: this repository is public.
- Branch, open a pull request, squash merge. Every commit is signed off by the human who submits it (`git commit -s`).
