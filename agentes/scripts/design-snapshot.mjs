#!/usr/bin/env node
// design-snapshot.mjs — render gate + screenshots for the Design Team "surprise me" mode.
//
// Usage:
//   node .agents/scripts/design-snapshot.mjs <file.html> <outDir> [--dark] [--required <list.txt>]
//
//   --dark               also capture every shot with prefers-color-scheme: dark
//   --required <file>    text file, one required string per line (blank lines and
//                        lines starting with "#" ignored); each must appear in the
//                        rendered page text (case-insensitive)
//
// Output: one JSON summary on stdout:
//   { ok, consoleErrors, externalRequests, reflow320, missingRequired,
//     a11y: { checked, violations }, screenshots: [...] }
//
// Exit codes:
//   0 = gate passed
//   1 = gate failed (console/page errors, external requests, horizontal scroll
//       at 320px, missing required content, or serious/critical axe violations)
//   2 = usage error (bad arguments, input file not found)
//   3 = Playwright (or its Chromium) unavailable — caller falls back to
//       "judgment without render"
//
// Dependencies are optional and resolved at runtime (never installed by this
// script): `playwright` or `@playwright/test`, and `axe-core` for the a11y check.
// Resolution order: normal ESM import, then CommonJS resolution from the cwd,
// NODE_PATH entries and the global node_modules next to the running node binary.

import { createRequire } from 'node:module';
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const VIEWPORTS = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'mobile', width: 390, height: 844 },
];
const REFLOW_WIDTH = 320;

function printAndExit(summary, code) {
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  process.exit(code);
}

function parseArgs(argv) {
  const positional = [];
  let dark = false;
  let required = null;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dark') dark = true;
    else if (arg === '--required') required = argv[++i] ?? '';
    else positional.push(arg);
  }
  return { file: positional[0], outDir: positional[1], dark, required };
}

function candidateBaseDirs() {
  const dirs = [process.cwd()];
  for (const entry of (process.env.NODE_PATH || '').split(path.delimiter)) {
    if (entry) dirs.push(entry);
  }
  const binDir = path.dirname(process.execPath);
  dirs.push(path.resolve(binDir, '..', 'lib', 'node_modules')); // unix global prefix
  dirs.push(path.resolve(binDir, 'node_modules')); // windows global prefix
  return dirs;
}

function resolveFromBases(specifier) {
  const require = createRequire(import.meta.url);
  for (const base of candidateBaseDirs()) {
    try {
      return require.resolve(specifier, { paths: [base] });
    } catch {
      // try next base directory
    }
  }
  return null;
}

async function loadModule(name) {
  try {
    return await import(name);
  } catch {
    const resolved = resolveFromBases(name);
    if (!resolved) return null;
    try {
      return await import(pathToFileURL(resolved).href);
    } catch {
      return null;
    }
  }
}

async function loadChromium() {
  for (const name of ['playwright', '@playwright/test']) {
    const mod = await loadModule(name);
    const chromium = mod?.chromium ?? mod?.default?.chromium;
    if (chromium) return chromium;
  }
  return null;
}

function readRequired(listPath) {
  if (!listPath) return [];
  return readFileSync(listPath, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'));
}

async function main() {
  const { file, outDir, dark, required } = parseArgs(process.argv.slice(2));
  if (!file || !outDir) {
    process.stderr.write(
      'Usage: node design-snapshot.mjs <file.html> <outDir> [--dark] [--required <list.txt>]\n',
    );
    process.exit(2);
  }
  const htmlPath = path.resolve(file);
  if (!existsSync(htmlPath)) {
    process.stderr.write(`Input file not found: ${htmlPath}\n`);
    process.exit(2);
  }
  if (required !== null && (!required || !existsSync(required))) {
    process.stderr.write(`Required-content list not found: ${required}\n`);
    process.exit(2);
  }

  const summary = {
    ok: false,
    consoleErrors: [],
    externalRequests: [],
    reflow320: null,
    missingRequired: [],
    a11y: { checked: false, violations: [] },
    screenshots: [],
  };

  const chromium = await loadChromium();
  if (!chromium) {
    summary.error = 'playwright not resolvable';
    printAndExit(summary, 3);
  }

  let browser;
  try {
    browser = await chromium.launch();
  } catch (err) {
    summary.error = `chromium launch failed: ${String(err?.message || err).split('\n')[0]}`;
    printAndExit(summary, 3);
  }

  // The same page is loaded once per viewport/scheme: keep each distinct error once.
  const recordConsoleError = (text) => {
    if (!summary.consoleErrors.includes(text)) summary.consoleErrors.push(text);
  };

  const resolvedOut = path.resolve(outDir);
  mkdirSync(resolvedOut, { recursive: true });
  const url = pathToFileURL(htmlPath).href;
  const axePath = resolveFromBases('axe-core/axe.min.js');
  const schemes = dark ? ['light', 'dark'] : ['light'];

  const openPage = async (viewport, colorScheme) => {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      colorScheme,
    });
    const page = await context.newPage();
    // Self-contained HTML only: block and record anything that is not file:/data:/blob:.
    await page.route('**/*', (route) => {
      const reqUrl = route.request().url();
      if (/^(file|data|blob|about):/.test(reqUrl)) return route.continue();
      if (!summary.externalRequests.includes(reqUrl)) summary.externalRequests.push(reqUrl);
      return route.abort();
    });
    page.on('console', (msg) => {
      if (msg.type() === 'error') recordConsoleError(msg.text());
    });
    page.on('pageerror', (err) => recordConsoleError(`pageerror: ${err.message}`));
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(300); // let entrance animations settle
    return { context, page };
  };

  try {
    for (const scheme of schemes) {
      for (const viewport of VIEWPORTS) {
        const { context, page } = await openPage(viewport, scheme);
        const suffix = scheme === 'dark' ? '-dark' : '';
        for (const fullPage of [false, true]) {
          const name = `${viewport.name}-${fullPage ? 'full' : 'fold'}${suffix}.png`;
          const target = path.join(resolvedOut, name);
          await page.screenshot({ path: target, fullPage });
          summary.screenshots.push(target);
        }

        if (scheme === 'light' && viewport.name === 'desktop') {
          const requiredItems = readRequired(required);
          if (requiredItems.length) {
            const text = (await page.evaluate(() => document.body?.innerText || '')).toLowerCase();
            summary.missingRequired = requiredItems.filter((item) => !text.includes(item.toLowerCase()));
          }
          if (axePath) {
            await page.addScriptTag({ path: axePath });
            const results = await page.evaluate(async () =>
              // eslint-disable-next-line no-undef
              axe.run(document, { runOnly: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] }),
            );
            summary.a11y.checked = true;
            summary.a11y.violations = results.violations
              .filter((v) => v.impact === 'serious' || v.impact === 'critical')
              .map((v) => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.length }));
          }
        }
        await context.close();
      }
    }

    // WCAG 1.4.10 reflow: no horizontal scroll at 320 CSS px.
    const { context, page } = await openPage({ width: REFLOW_WIDTH, height: 640 }, 'light');
    const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    summary.reflow320 = scrollWidth <= REFLOW_WIDTH;
    await context.close();
  } finally {
    await browser.close();
  }

  summary.ok =
    summary.consoleErrors.length === 0 &&
    summary.externalRequests.length === 0 &&
    summary.reflow320 === true &&
    summary.missingRequired.length === 0 &&
    summary.a11y.violations.length === 0;
  printAndExit(summary, summary.ok ? 0 : 1);
}

main().catch((err) => {
  process.stderr.write(`design-snapshot failed: ${err?.stack || err}\n`);
  process.exit(1);
});
