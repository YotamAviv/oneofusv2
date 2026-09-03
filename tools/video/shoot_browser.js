#!/usr/bin/env node
// Shoot the opening: the app's own page in a browser, and the tap on the Play
// Store badge.
//
//   node shoot_browser.js
//
// Writes out/browser/<stamp>/browser.mp4 + .marks.json. Ends on a tap that is drawn but
// never dispatched -- see below.
//
// It opens on the page rather than typing the address in. People can navigate to
// a web page and install an app without being shown how, and the seconds spent
// demonstrating it are seconds not spent on what the app is for.
//
// PROTOTYPE.
//
// THE PLAY STORE IS NEVER OPENED. It is not our UI, it interrupts with sign-in
// prompts, offers and update-all nags, it changes without notice, and on this
// device it shows "Update" over a red internal-tester warning rather than the
// "Install" the story wants. So the tap is drawn and not dispatched, and the
// card that follows says what would have happened.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { device, sleep } = require('./lib/device');

const CHROME = 'com.android.chrome';
const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('browser');
const URL = process.env.URL || 'one-of-us.net';
const d = device();

// APP-BLIND: coordinates on a 1080x2220 screen, measured off screenshots.
const AT = {
  playBadge: [536, 999],        // "GET IT ON Google Play" on one-of-us.net
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

  d.E('shell', 'am', 'force-stop', CHROME);
  await sleep(1500);

  // Chrome opens a tab per VIEW intent and nothing closed them; thirty had

  // piled up, and enough of them throttle screenrecord. Swept before the

  // camera, so a crashed take is cleaned up by the next one.

  await d.closeChromeTabs();


  const rec = spawn('adb', ['-s', process.env.AVD || 'emulator-5554', 'shell', 'screenrecord',
    '--time-limit', '120', '--bit-rate', '8000000', '/sdcard/browser.mp4']);
  await sleep(4000);

  // SYNC FLASH, and the browser has to be started anyway -- so start it on a
  // page of one flat colour, zero the clock when that colour actually arrives,
  // and open the tab the take really begins on.
  //
  // BLACK, not white. This take is a browser: a new tab page and a light web
  // page, so its median frame is already near white and a white flash cannot
  // beat it -- find_flash.js reported no clear flash and every touch indicator
  // was mistimed. Black is unmistakable here.
  // Chrome named explicitly: nothing claims the data: scheme by default, so
  // `am start` without a component just fails.
  d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
      '-d', 'data:text/html,%3Cbody%20style%3D%22background%3A%23000%22%3E',
      '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await d.waitForApp(CHROME);
  t0 = await d.waitForDark();
  await sleep(900);
  marks.syncFlash = { heldMs: 900, kind: 'dark' };

  d.open(`https://${URL}`);
  await sleep(4000);                    // load -- head, and trimmed off
  mark('page');
  await sleep(1100);                    // the page, and the two badges

  // SHOWN, NOT TAPPED. overlay_taps.js draws from the marks, not from the touch,
  // so logging one without dispatching it puts the finger on the badge and
  // leaves the browser where it is. The Play Store never opens, the take never
  // leaves the page, and re-recording it costs no cleanup -- which is the whole
  // reason this is its own scene.
  //
  // What happens after the tap is the card's job to say, not the store's.
  marks.taps.push({ t: at(), x: AT.playBadge[0], y: AT.playBadge[1], what: 'play_badge' });
  mark('show_play_tap');
  await sleep(900);
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/browser.mp4');
  rec.kill();
  // The stamp is on the build directory (lib/build_dir.js), so the take
  // inside it is named for what it is and nothing else.
  const name = 'browser';
  d.E('pull', '/sdcard/browser.mp4', path.join(OUT, `${name}.mp4`));
  // Off the device once it is safely here; see the other shoot scripts.
  d.E('shell', 'rm', '-f', '/sdcard/browser.mp4');
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${name}.mp4`))}\n${path.relative(__dirname, path.join(OUT, `${name}.marks.json`))}  (${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
