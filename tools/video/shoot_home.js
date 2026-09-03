#!/usr/bin/env node
// Shoot the home screen and the tap that starts the app. Three seconds.
//
//   node shoot_home.js
//
// Its own take rather than the head of the vouch take, because the vouch take
// wipes the app's keys to run and this doesn't. Re-recording the way somebody
// opens the app should not cost an identity.
//
// The icon was dragged out of the app drawer once, by hand, and stays put.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { device, sleep } = require('./lib/device');

const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('home');
const d = device();
const APP_ICON = [536, 818];        // ONE-OF-US.NET on the home screen

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const marks = { taps: [] };
  let t0 = Date.now();
  const at = () => +((Date.now() - t0) / 1000).toFixed(2);
  const mark = k => { marks[k] = at(); console.log(`  ${k} @${marks[k]}s`); };

  // Everything the other takes leave in front, put away -- the Play Store above
  // all, since the browser take ends by opening it and it is still there.
  d.E('shell', 'am', 'force-stop', 'net.oneofus.app');
  d.E('shell', 'am', 'force-stop', 'com.android.chrome');
  d.E('shell', 'am', 'force-stop', 'com.android.vending');
  d.E('shell', 'input', 'keyevent', '3');   // HOME, before the camera is rolling
  await sleep(2500);

  // Chrome opens a tab per VIEW intent and nothing closed them; thirty had
  // piled up, and enough of them throttle screenrecord. Swept before the
  // camera, so a crashed take is cleaned up by the next one.
  await d.closeChromeTabs();

  const rec = spawn('adb', ['-s', process.env.AVD || 'emulator-5554', 'shell', 'screenrecord',
    '--time-limit', '60', '--bit-rate', '8000000', '/sdcard/home.mp4']);
  await sleep(4000);

  // SYNC FLASH, white: this take is a dark wallpaper, so white is what stands
  // out from its median. Chrome paints it, then HOME puts it away -- and the
  // half-second of Chrome sliding off is why the join trims a little more off
  // the front of this clip than the flash alone accounts for.
  d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'about:blank',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await d.waitForApp('com.android.chrome');
  t0 = await d.waitForBright();
  await sleep(600);
  marks.syncFlash = { heldMs: 600 };

  d.E('shell', 'input', 'keyevent', '3');   // HOME
  await sleep(1400);
  mark('home_screen');
  await sleep(600);                         // a beat to find the icon

  marks.taps.push({ t: at(), x: APP_ICON[0], y: APP_ICON[1], what: 'app_icon' });
  d.tap(...APP_ICON);
  mark('tap_app_icon');
  await sleep(1000);                        // the app starting to open: the cut
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/home.mp4');
  rec.kill();
  // The stamp is on the build directory (lib/build_dir.js), so the take
  // inside it is named for what it is and nothing else.
  const name = 'home';
  d.E('pull', '/sdcard/home.mp4', path.join(OUT, `${name}.mp4`));
  d.E('shell', 'rm', '-f', '/sdcard/home.mp4');
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${name}.mp4`))}\n${path.relative(__dirname, path.join(OUT, `${name}.marks.json`))}`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
