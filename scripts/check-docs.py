#!/usr/bin/env python3
"""Check the notes of this repository (ADR-0011, the rules of linux-hello's AGENTS.md):

1. Every note has frontmatter with the keys type, subject, artifact, status, owner,
   concepts, tags, sources and date. Templates, the root README and LICENSE are exempt.
2. Every relative Markdown link and every relative frontmatter source resolves to a
   file or directory in this repository. Anchors and URLs are not checked.
3. No note uses an Obsidian [[wikilink]].

Usage: scripts/check-docs.py [root]   (default: the repository root). Exits 1 on any failure.
"""
import re
import sys
from pathlib import Path

KEYS = ["type", "subject", "artifact", "status", "owner", "concepts", "tags", "sources", "date"]
root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
failures = []


def fail(path, msg):
    failures.append(f"{path.relative_to(root)}: {msg}")


def check_target(note, target, what):
    if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#") or not target:
        return
    path = target.split("#", 1)[0]
    if path and not (note.parent / path).exists():
        fail(note, f"{what} {target} does not resolve")


notes = sorted(p for p in root.rglob("*.md")
               if ".git" not in p.parts and "node_modules" not in p.parts)
for note in notes:
    rel = note.relative_to(root)
    text = note.read_text(encoding="utf-8")
    exempt = rel.parts[0] == "templates" or rel == Path("README.md")
    if not exempt:
        m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
        if not m:
            fail(note, "no frontmatter")
        else:
            present = {line.split(":", 1)[0] for line in m.group(1).splitlines() if ":" in line}
            missing = [k for k in KEYS if k not in present]
            if missing:
                fail(note, "frontmatter lacks " + ", ".join(missing))
            src = re.search(r'^sources: \[(.*)\]$', m.group(1), re.M)
            for s in re.findall(r'"([^"]*)"', src.group(1) if src else ""):
                check_target(note, s, "source")
    body = re.sub(r"```.*?```", "", text, flags=re.S)   # code blocks hold examples, not links
    for target in re.findall(r"\]\(([^)\s]+)\)", body):
        check_target(note, target, "link")
    if re.search(r"\[\[[^\]]+\]\]", body):
        fail(note, "uses a [[wikilink]]; use a relative Markdown link")

for f in failures:
    print(f"::error::{f}")
print(f"{len(notes)} notes checked, {len(failures)} failures")
sys.exit(1 if failures else 0)
