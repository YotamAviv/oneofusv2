#!/usr/bin/env node
// Shoot the ADVANCED tab: what the app offers when a key is lost or
// compromised, rather than deliberately withdrawn.
//
//   node shoot_advanced.js
//
// Writes out/advanced/<stamp>/advanced.mp4 + .marks.json.
//
// SPLIT OUT OF delegates, which used to carry on into this screen once the
// clear had been published. Nothing here is about closing anything, and it read
// as an appendix to a section that had already made its point.
//
// Nothing is published and nothing is deleted, so this take can be re-recorded
// as often as the words change. It needs an identity on the phone and nothing
// else -- the screen is read, not used.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { device, sleep } = require('./lib/device');

const APP = 'net.oneofus.app';
const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('advanced');
const d = device();

// APP-BLIND: coordinates on a 1080x2220 screen, measured off screenshots.
//
// NAVIGATED, NOT SWIPED. The tabs can also be reached by swiping, and the take
// used to arrive at ADVANCED that way -- opening on a screen the viewer has no
// route to, which reads as a jump cut. Going through the menu shows where the
// screen lives.
const AT = {
  menu: [925, 2061],        // the hamburger, bottom right of the main screen
  advanced: [357, 1568],    // ADVANCED in the menu sheet
};

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const marks = { taps: [] };
  let t0 = Date.now();
  const at = () => +((Date.now() - t0) / 1000).toFixed(2);
  const mark = k => { marks[k] = at(); console.log(`  ${k} @${marks[k]}s`); };
  const tap = (what, [x, y]) => {
    marks.taps.push({ t: at(), x, y, what });
    d.tap(x, y);
    mark(`tap_${what}`);
  };

  d.E('shell', 'am', 'force-stop', APP);
  d.E('shell', 'am', 'force-stop', 'com.android.chrome');
  await sleep(1500);

  // Chrome opens a tab per VIEW intent and nothing closed them; thirty had
  // piled up, and enough of them throttle screenrecord. Swept before the
  // camera, so a crashed take is cleaned up by the next one.
  await d.closeChromeTabs();

  // Warm the identity app BEFORE the camera. A cold start reloads everything
  // the identity has published and takes about nine seconds; paid here it costs
  // nothing, paid on camera it is dead air.
  await d.warmUp(APP);

  const rec = spawn('adb', ['-s', process.env.AVD || 'emulator-5554', 'shell',
    'screenrecord', '--time-limit', '90', '--bit-rate', '8000000',
    '/sdcard/advanced.mp4']);
  await sleep(4000);

  // SYNC FLASH, black: this take is made of light app screens, so white would
  // not beat the median. See find_flash.js --dark.
  d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
    '-d', 'data:text/html,%3Cbody%20style%3D%22background%3A%23000%22%3E',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await d.waitForApp('com.android.chrome');
  t0 = await d.waitForDark();
  await sleep(600);
  marks.syncFlash = { heldMs: 600, kind: 'dark' };

  d.launch(APP);
  await d.waitForApp(APP);
  // A cold start reloads everything the identity has published and takes about
  // eight seconds to settle; the taps below hit nothing until it has.
  await sleep(9500);
  mark('main_screen');
  // The section opens here, on the card, so the viewer knows which app this is
  // before anything is navigated.
  await sleep(2200);

  tap('menu', AT.menu);
  await sleep(1600);                    // the sheet slides up and settles
  mark('menu_open');
  await sleep(1400);                    // long enough to read what is on it

  tap('advanced', AT.advanced);
  await sleep(1600);
  mark('advanced');
  // Long: the screen is the whole section, and its line is anchored on arriving.
  await sleep(7000);
  mark('done');

  // Stop it on the DEVICE and let the file settle. Killing the local adb first
  // severs the shell before screenrecord can write its moov atom, and what
  // comes back is then not a video at all.
  await device().stopRecording('/sdcard/advanced.mp4');
  rec.kill();
  const name = 'advanced';
  d.E('pull', '/sdcard/advanced.mp4', path.join(OUT, `${name}.mp4`));
  d.E('shell', 'rm', '-f', '/sdcard/advanced.mp4');
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${name}.mp4`))}\n` +
    `${path.relative(__dirname, path.join(OUT, `${name}.marks.json`))}  ` +
    `(${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
