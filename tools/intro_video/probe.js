#!/usr/bin/env node
// Dump the Flutter accessibility tree of whatever is on screen in the emulator's
// Chrome. The one tool that answers "what is this control actually called?",
// which is what every tapNamed in a shoot script depends on.
//
//   adb forward tcp:9222 localabstract:chrome_devtools_remote
//   node probe.js                      # dump the tree
//   node probe.js --url https://nerdster.org/app   # navigate there first
//
// Optional --tap <regex> taps a node and dumps the tree again, so a menu can be
// explored one level at a time without writing a script for it.
const { chromium } = require('playwright');
const {
  SEMANTICS_PROBE, sleep, enableSemantics, tapNamed, attachToAvdChrome,
} = require('./lib/semantics');

const arg = (n, d) => { const i = process.argv.indexOf('--' + n); return i >= 0 ? process.argv[i + 1] : d; };

(async () => {
  let { browser, page, cdp } = await attachToAvdChrome(chromium);
  const url = arg('url');
  if (url) {
    await page.goto(url);
    for (let i = 0; i < 80; i++) {
      const ready = await page.evaluate(
        () => !!document.querySelector('flt-semantics-placeholder')).catch(() => false);
      if (ready) break;
      await sleep(250);
    }
    await page.evaluate(SEMANTICS_PROBE);
  }
  console.log('url:', page.url());
  await enableSemantics(page, cdp);

  const dump = async label => {
    const nodes = await page.evaluate(() => window.__sem());
    console.log(`\n--- ${label}: ${nodes.length} nodes ---`);
    for (const n of nodes) {
      if (!n.text && !process.argv.includes('--all')) continue;
      console.log(`  ${String(n.role || '-').padEnd(8)} ${Math.round(n.x)},${Math.round(n.y)} ` +
                  `${Math.round(n.w)}x${Math.round(n.h)}  ${n.text.slice(0, 90)}`);
    }
  };
  await dump('initial');

  const xy = arg('tapxy');
  if (xy) {
    const [x, y] = xy.split(',').map(Number);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart',
      touchPoints: [{ x, y, radiusX: 20, radiusY: 20, force: 1 }] });
    await sleep(110);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await sleep(1200);
    await dump(`after tapping ${xy}`);
  }

  const tap = arg('tap');
  if (tap) {
    await tapNamed(page, cdp, new RegExp(tap));
    await sleep(900);
    await dump(`after tapping /${tap}/`);
  }
  await browser.close();
})().catch(e => { console.error('PROBE FAILED:', e.message); process.exit(1); });
