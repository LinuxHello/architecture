// Drives a running Structurizr (local mode) in headless Chrome and writes one SVG per view.
// Usage: node render.mjs <structurizr-base-url> <output-dir>
// Environment: CHROME_BIN (default: google-chrome).
import { chromium } from 'playwright-core';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [base, outDir] = process.argv.slice(2);
if (!base || !outDir) {
  console.error('usage: node render.mjs <structurizr-base-url> <output-dir>');
  process.exit(2);
}
mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: process.env.CHROME_BIN || 'google-chrome',
  headless: true,
  // The hosted runner's Ubuntu restricts unprivileged user namespaces, which Chrome's sandbox needs.
  args: process.env.CI ? ['--no-sandbox'] : [],
});
try {
  // A fixed locale and time zone keep the export's date line the same on every machine.
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 }, locale: 'en-GB', timezoneId: 'UTC' });
  await page.goto(`${base}/workspace/1/diagrams`);
  await page.waitForFunction(() => window.structurizr?.scripting?.getViews, null, { timeout: 30000 });

  // Structurizr v2026.09.19 draws a view whose saved dimensions are null (the first one to
  // load, in practice) with NaN sizes. Give such views the size their elements need.
  const keys = await page.evaluate(() => {
    const w = structurizr.workspace.workspace || structurizr.workspace;
    for (const list of Object.values(w.views)) {
      if (!Array.isArray(list)) continue;
      for (const v of list) {
        if (!v.elements || (v.dimensions && v.dimensions.width != null)) continue;
        v.dimensions = {
          width: Math.max(...v.elements.map((e) => e.x || 0)) + 450,
          height: Math.max(...v.elements.map((e) => e.y || 0)) + 300,
        };
      }
    }
    return structurizr.scripting.getViews().map((v) => v.key || v);
  });
  if (!keys.length) throw new Error('Structurizr reports no views');

  for (const key of keys) {
    const svg = await page.evaluate(async (k) => {
      try {
        structurizr.scripting.changeView(k);
      } catch (e) {
        // A view that was drawn while another failed can still throw here; the export decides.
      }
      for (let i = 0; i < 60 && !structurizr.scripting.isDiagramRendered(); i++) await new Promise((r) => setTimeout(r, 250));
      await new Promise((r) => setTimeout(r, 500));
      return structurizr.scripting.exportCurrentDiagramToSVG({ includeMetadata: false });
    }, key);
    if (typeof svg !== 'string' || svg.includes('NaN')) throw new Error(`view ${key}: the export is empty or has NaN sizes`);
    // The export carries a hidden timestamp; drop it so an unchanged model gives an unchanged file.
    const clean = svg.replace(/>(?:Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day, [^<]*</g, '><');
    writeFileSync(join(outDir, `${key}.svg`), clean);
    console.log(`rendered ${key} (${clean.length} bytes)`);
  }
} finally {
  await browser.close();
}
