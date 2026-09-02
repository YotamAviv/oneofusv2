#!/usr/bin/env node
// Scripted, re-runnable screen recording of the Nerdster web app at phone size.
//
//   node record_nerdster.js --scene identity-bar --pov milhouse
//
// Writes out/<name>.webm plus out/<name>.marks.json (the timestamps build.sh
// trims on). See README.md.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { chromium } = require('playwright');
const { OVERLAY, sleep, tap, swipe } = require('./lib/touch');

const OUT = path.join(__dirname, 'out');

// Phone-sized CSS viewport. Output pixels = these times the device scale
// factor forced on the browser below, so 432x768 @2.5 = 1080x1920.
const VIEW = { width: 432, height: 768 };
const SCALE = 2.5;

// Coordinates are CSS pixels in the viewport above. They are stable as long as
// VIEW and the app's toolbar layout don't change; re-probe with a screenshot if
// either does.
const HIT = {
  hamburger: [408, 60],
  identityBar: [356, 200],
  mode: { permissive: [200, 200], standard: [200, 240], strict: [200, 280] },
  dismiss: [110, 700], // menu barrier, not content
  feed: 216, // x for swipes
};

function arg(name, fallback) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

function povKey(name) {
  const inline = arg('pov-key');
  if (inline) return JSON.parse(inline);
  const keysPath = arg('keys', path.join(os.homedir(), 'src/github/simpsonsPublicKeys.json'));
  const keys = JSON.parse(fs.readFileSync(keysPath, 'utf8'));
  if (!keys[name]) throw new Error(`No key '${name}' in ${keysPath}`);
  return keys[name];
}

// ---------------------------------------------------------------- scenes ---

// Browse a few results, change the Identity bar from permissive to standard,
// browse the same results again. The point: under permissive the identity bar
// reads "4-Eyes" (a moniker a bad actor chose for Milhouse) and the clown
// movies carry bot-farm likers; under standard he is "Milhouse" again and the
// bogus likers are gone.
async function identityBar(p, cdp, mark) {
  const browse = async () => {
    for (let i = 0; i < 3; i++) { await swipe(cdp, HIT.feed, 620, 210, 300, 16); await sleep(1500); }
  };
  const backToTop = async () => {
    // Over-swipe deliberately; Flutter clamps at the top, so this lands in a
    // known position without needing to measure scroll offset.
    for (let i = 0; i < 5; i++) { await swipe(cdp, HIT.feed, 200, 640, 260, 14); await sleep(420); }
  };

  await sleep(1800);
  await browse();
  await sleep(1600);
  await backToTop();
  await sleep(1800);

  mark('menu');
  await tap(cdp, p, ...HIT.hamburger);        await sleep(1500);
  await tap(cdp, p, ...HIT.identityBar);      await sleep(1900);
  mark('mode-change');
  await tap(cdp, p, ...HIT.mode.standard);    await sleep(2800);
  await tap(cdp, p, ...HIT.dismiss);          await sleep(7000);
  mark('settled');
  await sleep(2200);
  await browse();
  await sleep(2500);
}

const SCENES = { 'identity-bar': identityBar };

// ------------------------------------------------------------------ main ---

(async () => {
  const sceneName = arg('scene', 'identity-bar');
  const pov = arg('pov', 'milhouse');
  const name = arg('out', `${pov}_${sceneName}`);
  const scene = SCENES[sceneName];
  if (!scene) throw new Error(`Unknown scene '${sceneName}'. Have: ${Object.keys(SCENES).join(', ')}`);

  // The PoV goes in the URL as a public key — the same mechanism behind the
  // "Milhouse's view" button on nerdster.org. No sign-in, no private key.
  const url = 'https://nerdster.org/app?pov=' + encodeURIComponent(JSON.stringify(povKey(pov)));

  fs.mkdirSync(OUT, { recursive: true });

  // Forcing the scale factor at the browser level rather than per-context: a
  // context-level deviceScaleFactor gets dropped partway through the recording
  // when Flutter re-creates its canvas, and the rest of the video renders at 1x.
  const browser = await chromium.launch({
    args: ['--force-device-scale-factor=' + SCALE, '--high-dpi-support=1'],
  });
  const ctx = await browser.newContext({
    viewport: VIEW,
    hasTouch: true,
    recordVideo: { dir: OUT, size: { width: VIEW.width * SCALE, height: VIEW.height * SCALE } },
  });
  await ctx.addInitScript(OVERLAY);

  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);

  const t0 = Date.now();
  const marks = { scene: sceneName, pov, url };
  const mark = k => { marks[k] = (Date.now() - t0) / 1000; };

  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await sleep(20000); // trust pipeline + poster images
  mark('start');

  await scene(page, cdp, mark);
  mark('end');

  await ctx.close();
  await browser.close();

  // Playwright names the file by an internal hash; rename to something we chose.
  const webm = fs.readdirSync(OUT).filter(f => f.endsWith('.webm')).map(f => ({
    f, t: fs.statSync(path.join(OUT, f)).mtimeMs,
  })).sort((a, b) => b.t - a.t)[0].f;
  fs.renameSync(path.join(OUT, webm), path.join(OUT, `${name}.webm`));
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));

  console.log(`out/${name}.webm`);
  console.log(JSON.stringify(marks, null, 2));
})();
