#!/usr/bin/env node
// Shoot the opening beat: a phone with no keys on it becomes a phone that has
// vouched for somebody.
//
//   node shoot_vouch.js
//
// Launch the app with nothing in it, CREATE NEW IDENTITY KEY, acknowledge the
// congratulations, open the scanner, see Tom's phone, name him. Writes
// out/vouch_<stamp>.mp4 + .marks.json.
//
// PROTOTYPE.
//
// IT WIPES THE APP. `pm clear` is the only way to get back to "You have no keys
// on this device", and it destroys the identity private key in secure storage --
// there is no root on this image, so there is no backing it up first. Every take
// therefore mints a NEW identity, which has vouched for nobody and delegated
// nothing, so shoot.sh and shoot_nerdster.sh need their setup redone afterwards
// (a vouch for Tom, and demo_identity.json pointed at the new token).
//
// TWO THINGS ARE FAKED, both in the same place.
//
// The camera never sees anything: the emulator's camera renders a room with a
// bookshelf in it. So the scanner is held on screen for a beat with nothing
// happening, and composite_scan.sh later drops real footage of Tom's phone into
// that window. `scanWindow` in the marks file says where it is.
//
// And the scan itself is a keymeid://vouch# deep link carrying Tom's public key,
// which is the same path a scan takes once the QR is decoded -- the dialog that
// comes up is the app's own, with the real key in it, and what it publishes is a
// real statement. What is faked is the light hitting the lens, not the crypto.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { device, sleep } = require('./lib/device');

// WHY THE WAITS BELOW ARE SLEEPS, against this project's own rule. There is no
// accessibility tree in the native app, and the two fallbacks don't work here
// either: screencap is not byte-stable on this emulator (the same static screen
// hashes differently every grab), and the scanner has a live camera preview
// behind its dialogs, so "the screen has stopped changing" is never true. What
// is left is that these transitions are fast and deterministic. Each sleep below
// is the shortest that was reliable, plus what the shot needs for reading time.

const APP = 'net.oneofus.app';
const OUT = path.join(__dirname, 'out');
const d = device();

// Whose key gets vouched for, and what he gets called. Tom's identity key, the
// one his phone shows as a QR in the footage.
const TOM = { crv: 'Ed25519', kty: 'OKP', x: 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo' };
const MONIKER = process.env.MONIKER || 'Tom';

// APP-BLIND: coordinates on a 1080x2220 screen, measured off screenshots. A
// layout change moves them, and the take will look fine and do nothing.
const AT = {
  createKey: [540, 1056],       // CREATE NEW IDENTITY KEY, on the welcome screen
  okay: [540, 1930],            // "Okay", on the congratulations screen
  scan: [541, 1983],            // the QR button, bottom centre of the main screen
  allowCamera: [538, 1109],     // "While using the app" -- the system dialog
  moniker: [540, 918],          // the name field in "Who's Key is This?"
};

const SCAN_HOLD = 4000;         // how long the scanner sits there for the footage

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

  // --- stage: a phone with nothing on it ---
  console.log('wiping', APP);
  d.clear(APP);
  d.E('shell', 'am', 'force-stop', 'com.android.chrome');
  await sleep(1500);

  const rec = spawn('adb', ['-s', process.env.AVD || 'emulator-5554', 'shell', 'screenrecord',
    '--time-limit', '120', '--bit-rate', '8000000', '/sdcard/vouch.mp4']);

  // SYNC FLASH. The browser takes paint a white frame from inside the page;
  // there is no page here, but there doesn't need to be -- the flash only has to
  // be a bright frame at a known instant, and it happens before the app is even
  // launched, in the head that gets trimmed off anyway. So: Chrome on a blank
  // page, which is as white as this screen ever gets, then the app launches over
  // the top of it.
  //
  // Without this the marks are on the script's clock, which runs seconds ahead
  // of the footage: the touch indicators land early and every cue time in the
  // annotation is wrong.
  await sleep(4000);
  d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'about:blank',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await sleep(2500);                   // Chrome up and painted white
  t0 = Date.now();
  await sleep(600);                    // hold the white for find_flash.js
  marks.syncFlash = { heldMs: 600 };

  // --- launch the app ---
  d.launch(APP);
  await d.waitForApp(APP);
  await sleep(3800);                   // splash, then the welcome screen
  mark('welcome');
  await sleep(1400);

  // --- a key of one's own ---
  tap('create_key', AT.createKey);
  await sleep(2200);                   // minting the key, then the new screen
  mark('congratulations');
  await sleep(2600);                   // long enough to read the headline

  tap('okay', AT.okay);
  await sleep(1400);
  mark('main_screen');
  await sleep(1600);                   // the new identity's own QR, on screen

  // --- the scan ---
  tap('scan', AT.scan);
  await sleep(1500);
  tap('allow_camera', AT.allowCamera);  // fresh install, so the ask always comes
  await sleep(2200);                   // camera starting up
  mark('scanner');

  // The beat the footage goes into. Nothing happens on the device here on
  // purpose: whatever the emulator's camera is looking at gets replaced.
  marks.scanWindow = { start: at(), ms: SCAN_HOLD };
  await sleep(SCAN_HOLD);
  mark('scan_hold_done');

  // --- the key arrives, as if scanned ---
  const payload = Buffer.from(JSON.stringify({ key: TOM })).toString('base64url');
  d.open(`keymeid://vouch#${payload}`);
  await sleep(1800);
  mark('whos_key_is_this');
  await sleep(1400);

  tap('moniker_field', AT.moniker);
  await sleep(900);
  // Typed, not pasted: a name appearing all at once reads as a script filling in
  // a form, which is what it is, and the whole point is that a person is naming
  // somebody they know.
  await d.typeSlow(MONIKER, 220);
  mark('typed_moniker');
  await sleep(2600);                   // hold on the name, before Publish

  rec.kill('SIGINT');
  await sleep(7000);                   // screenrecord finishes writing after this
  const dt = new Date(), p2 = n => String(n).padStart(2, '0');
  const stamp = `${dt.getFullYear()}${p2(dt.getMonth() + 1)}${p2(dt.getDate())}-` +
                `${p2(dt.getHours())}${p2(dt.getMinutes())}${p2(dt.getSeconds())}`;
  const name = `vouch_${stamp}`;
  d.E('pull', '/sdcard/vouch.mp4', path.join(OUT, `${name}.mp4`));
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\nout/${name}.mp4\nout/${name}.marks.json  (${marks.taps.length} taps)`);
  console.log(`scan window: ${marks.scanWindow.start}s + ${SCAN_HOLD / 1000}s (script clock)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
