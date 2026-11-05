#!/usr/bin/env python3
"""Tests for check-docs.py against small fixture repositories.

Usage: scripts/test-check-docs.py   Exits 1 if any test fails.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

CHECK = Path(__file__).resolve().parent / "check-docs.py"
FRONT = ('---\ntype: note\nsubject: s\nartifact: note\nstatus: active\nowner: "@o"\n'
         'concepts: []\ntags: []\nsources: []\ndate: 2026-11-05\n---\n\n')
failed = 0


def run(name, body, want_exit, want_text="", extra=None):
    """Write one note with `body` (and `extra` files), run the check, compare."""
    global failed
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "note.md").write_text(body)
        (root / "other.md").write_text(FRONT + "# Other\n")
        for path, text in (extra or {}).items():
            (root / path).write_text(text)
        r = subprocess.run([sys.executable, "-I", str(CHECK), d], capture_output=True, text=True)
        ok = r.returncode == want_exit and want_text in r.stdout
        print(("ok   " if ok else "FAIL ") + name)
        if not ok:
            failed += 1
            print("     exit", r.returncode, "want", want_exit, "\n     " + r.stdout.replace("\n", "\n     "))


run("documented_notes_pass", FRONT + "See [other](other.md).\n", 0)
run("note_without_frontmatter_is_refused", "# No frontmatter\n", 1, "no frontmatter")
run("missing_frontmatter_key_is_refused", FRONT.replace('owner: "@o"\n', ""), 1, "lacks owner")
run("broken_relative_link_is_refused", FRONT + "See [x](missing.md).\n", 1, "link missing.md")
run("broken_source_is_refused", FRONT.replace("sources: []", 'sources: ["missing.md"]'), 1, "source missing.md")
run("wikilink_in_text_is_refused", FRONT + "See [[other]].\n", 1, "wikilink")
run("wikilink_in_inline_code_is_allowed", FRONT + "Never use `[[wikilinks]]` here.\n", 0)
run("wikilink_in_double_backtick_code_is_allowed", FRONT + "Write ``[[x]] `y` `` as text.\n", 0)
run("link_in_code_block_is_ignored", FRONT + "```md\n[x](missing.md) [[y]]\n```\n", 0)
run("link_in_inline_code_is_ignored", FRONT + "Write `[x](missing.md)` like this.\n", 0)
run("text_after_inline_code_is_still_checked", FRONT + "Use `x`, see [[other]].\n", 1, "wikilink")
run("url_links_are_not_checked", FRONT + "See [x](https://example.org/missing.md).\n", 0)

print(f"{12 - failed} passed, {failed} failed")
sys.exit(1 if failed else 0)
