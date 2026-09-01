#!/usr/bin/env node
// Shoot the invitation: share a link that carries your public key, so somebody
// who cannot scan your phone can still vouch for you.
//
//   node shoot_invite.js
//
// Writes out/invite_<stamp>.mp4 + .marks.json.
//
// It stops at the share sheet. The link is the point and it is on screen there,
// in full, with the key in it -- sending it is not, and this identity's
// invitation should not actually go anywhere.
//
// Nothing is wiped and nothing is published, so this take can be re-recorded as
// often as the words change. It does need an identity on the phone: run
// restore_demo_identity.sh if the vouch take has been through recently.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { device, sleep } = require('./lib/device');

const APP = 'net.oneofus.app';
const OUT = path.join(__dirname, 'out');
const d = device();

// APP-BLIND: coordinates on a 1080x2220 screen, measured off screenshots.
const AT = {
  share: [117, 2061],       // the share icon, bottom left of the main screen
  invitation: [540, 1767],  // "Share Invitation Link" in the app's own sheet
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

  const rec = spawn('adb', ['-s', process.env.AVD || 'emulator-5554', 'shell', 'screenrecord',
    '--time-limit', '90', '--bit-rate', '8000000', '/sdcard/invite.mp4']);
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
  // A cold start reloads everything the identity has published, and takes about
  // eight seconds to settle. The mark is what the scene is trimmed to, so it has
  // to land on the loaded screen and not on the spinner.
  await sleep(9500);
  mark('main_screen');
  await sleep(1600);

  tap('share', AT.share);
  await sleep(1800);                    // the app's sheet slides up
  mark('sheet');
  await sleep(1400);                    // "Includes App Link, key QR code and Text"

  tap('invitation', AT.invitation);
  await sleep(3000);                    // the system share sheet, with the text
  mark('link');
  // Long. The link is the argument -- it is a URL with a public key in it, and
  // the viewer should have time to see that it is just that.
  await sleep(5000);
  mark('done');

  await require('./lib/device').device().stopRecording('/sdcard/invite.mp4');
  rec.kill();
  const dt = new Date(), p2 = n => String(n).padStart(2, '0');
  const stamp = `${dt.getFullYear()}${p2(dt.getMonth() + 1)}${p2(dt.getDate())}-` +
                `${p2(dt.getHours())}${p2(dt.getMinutes())}${p2(dt.getSeconds())}`;
  const name = `invite_${stamp}`;
  d.E('pull', '/sdcard/invite.mp4', path.join(OUT, `${name}.mp4`));
  d.E('shell', 'rm', '-f', '/sdcard/invite.mp4');
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\nout/${name}.mp4\nout/${name}.marks.json  (${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
