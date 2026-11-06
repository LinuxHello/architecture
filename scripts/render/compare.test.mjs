import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { words, sameWords, compareDirs } from './compare.mjs';

const svg = (...lines) => `<svg><style>.a{fill:red}</style>${lines.map((l) => `<text><tspan>${l}</tspan></text>`).join('')}</svg>`;

test('line wrapping and geometry do not count as a difference', () => {
  const a = svg('Linux Hello Agent');
  const b = '<svg width="9"><style>.b{}</style><text><tspan>Linux Hello</tspan><tspan>Agent</tspan></text></svg>';
  assert.ok(sameWords(a, b));
});

test('a changed word is a difference', () => {
  assert.ok(!sameWords(svg('Routing Policy Engine'), svg('Routing Policy Manager')));
});

test('an added element is a difference', () => {
  assert.ok(!sameWords(svg('PIN Manager'), svg('PIN Manager', 'Reset Coordinator')));
});

test('the export timestamp is not a word, in any locale', () => {
  const stamped = (t) => `<svg><text><tspan display="none">${t}</tspan><tspan>Agent</tspan></text></svg>`;
  assert.ok(sameWords(stamped('Friday, 6 November 2026 at 21:20 Central European Standard Time'),
    stamped('Friday, November 6, 2026 at 8:45 PM Coordinated Universal Time')));
  assert.ok(sameWords(stamped('Friday, November 6, 2026 at 8:45 PM Coordinated Universal Time'), '<svg><text><tspan>Agent</tspan></text></svg>'));
});

test('style rules are not words', () => {
  assert.deepEqual(words(svg('Agent')), ['Agent']);
});

test('missing, extra and changed files are each reported', () => {
  const dir = () => mkdtempSync(join(tmpdir(), 'cmp-'));
  const [c, r] = [dir(), dir()];
  writeFileSync(join(c, 'same.svg'), svg('One'));
  writeFileSync(join(r, 'same.svg'), svg('One'));
  writeFileSync(join(c, 'old.svg'), svg('Old'));
  writeFileSync(join(r, 'new.svg'), svg('New'));
  writeFileSync(join(c, 'changed.svg'), svg('Before'));
  writeFileSync(join(r, 'changed.svg'), svg('After'));
  const p = compareDirs(c, r);
  assert.equal(p.length, 3);
  assert.ok(p.some((l) => l.startsWith('old.svg')));
  assert.ok(p.some((l) => l.startsWith('new.svg')));
  assert.ok(p.some((l) => l.startsWith('changed.svg') && l.includes('Before') && l.includes('After')));
});
