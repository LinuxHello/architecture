// Compares two directories of rendered diagrams by their text, not their bytes.
//
// The geometry and the line wrapping of a Structurizr SVG depend on the font the
// browser measures with, so two renders of the same DSL on different machines differ
// in bytes. The words and their order do not: every element name, description,
// technology and relationship label is text in the SVG. A changed model changes the
// words; a different font does not.
//
// Usage: node compare.mjs <committed-dir> <rendered-dir>   exits 1 on any difference.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** The SVG without its <style> blocks. */
function withoutStyles(svg) {
  let out = '';
  let from = 0;
  for (;;) {
    const start = svg.indexOf('<style', from);
    if (start === -1) return out + svg.slice(from);
    const end = svg.indexOf('</style>', start);
    if (end === -1) return out + svg.slice(from, start);
    out += svg.slice(from, start);
    from = end + '</style>'.length;
  }
}

// The export's hidden metadata line, a date such as "Friday, 6 November 2026 at 21:20 ...",
// whose format depends on the browser's locale. It says nothing about the model.
const TIMESTAMP = /^(Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day, /;

/** The words of an SVG in document order, with <style> blocks, markup and the timestamp left out. */
export function words(svg) {
  const body = withoutStyles(svg);
  const out = [];
  let i = 0;
  while ((i = body.indexOf('>', i)) !== -1) {
    const j = body.indexOf('<', i + 1);
    if (j === -1) break;
    const text = body.slice(i + 1, j).trim();
    if (text && !TIMESTAMP.test(text)) out.push(...text.split(/\s+/));
    i = j;
  }
  return out;
}

/** True when both SVGs say the same words in the same order. */
export function sameWords(a, b) {
  const x = words(a);
  const y = words(b);
  return x.length === y.length && x.every((w, i) => w === y[i]);
}

/** Problems between two directories of .svg files, as human-readable lines. */
export function compareDirs(committed, rendered) {
  const list = (d) => readdirSync(d).filter((f) => f.endsWith('.svg')).sort();
  const a = list(committed);
  const b = list(rendered);
  const problems = [];
  for (const f of a.filter((f) => !b.includes(f))) problems.push(`${f}: committed, but the DSL no longer has this view`);
  for (const f of b.filter((f) => !a.includes(f))) problems.push(`${f}: the DSL has this view, but no image is committed`);
  for (const f of a.filter((f) => b.includes(f))) {
    const x = words(readFileSync(join(committed, f), 'utf8'));
    const y = words(readFileSync(join(rendered, f), 'utf8'));
    const i = x.findIndex((w, k) => w !== y[k]);
    if (i !== -1 || x.length !== y.length) {
      const at = i === -1 ? Math.min(x.length, y.length) : i;
      problems.push(`${f}: text differs near word ${at + 1} (committed "${x[at] ?? '(end)'}", rendered "${y[at] ?? '(end)'}")`);
    }
  }
  return problems;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [committed, rendered] = process.argv.slice(2);
  if (!committed || !rendered) {
    console.error('usage: node compare.mjs <committed-dir> <rendered-dir>');
    process.exit(2);
  }
  const problems = compareDirs(committed, rendered);
  for (const p of problems) console.error(`::error::${p}`);
  process.exit(problems.length ? 1 : 0);
}
