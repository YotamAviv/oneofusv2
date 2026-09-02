#!/usr/bin/env node
// Shoot the opening beat: a phone with no keys on it becomes a phone that has
// vouched for somebody.
//
//   node shoot_vouch.js
//
// Launch the app with nothing in it, CREATE NEW IDENTITY KEY, acknowledge the
// congratulations, open the scanner, see Tom's phone, name him. Writes
// out/vouch/<stamp>/vouch.mp4 + .marks.json.
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
const { spawn, execFileSync } = require('child_process');
const { device, sleep } = require('./lib/device');

// WHY THE WAITS BELOW ARE SLEEPS, against this project's own rule. There is no
// accessibility tree in the native app, and the two fallbacks don't work here
// either: screencap is not byte-stable on this emulator (the same static screen
// hashes differently every grab), and the scanner has a live camera preview
// behind its dialogs, so "the screen has stopped changing" is never true. What
// is left is that these transitions are fast and deterministic. Each sleep below
// is the shortest that was reliable, plus what the shot needs for reading time.

const APP = 'net.oneofus.app';
const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('vouch');
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
  publish: [761, 1716],         // PUBLISH, once a moniker makes it tappable
};

// How long the scanner sits there with nothing happening. Match it to the
// footage being composited in, so the rendered room is never on screen: the
// composite covers exactly this window, and the app leaves the scanner at the
// moment the footage ends -- which is the moment the real phone's scanner
// captured the card, so the cut lands where the app itself would have moved on.
const SCAN_HOLD = +(process.env.SCAN_HOLD || 2900);

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
  // BLACK, not white. The flash sits in the trimmed head, but not all of it
  // gets trimmed -- whatever is left shows for a beat at the top of the scene,
  // and a white browser page there reads as the browser coming back rather than
  // as a cut. Black reads as a cut. It also beats the median more convincingly
  // than white does on a take made of light app screens.
  d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
    '-d', 'data:text/html,%3Cbody%20style%3D%22background%3A%23000%22%3E',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  // Zero on the white ACTUALLY arriving, not on a sleep long enough to assume
  // it has. Chrome takes its own time to paint, find_flash.js locks onto the
  // first bright frame, and a clock zeroed later than that frame puts every
  // touch indicator early by the difference -- which is how the first version
  // of this take drew the camera-permission tap over a screen that had not got
  // there yet.
  t0 = await d.waitForDark();
  await sleep(600);                    // hold it for find_flash.js
  marks.syncFlash = { heldMs: 600, kind: 'dark' };

  // --- launch the app ---
  // Off camera. The home screen and the tap on the icon are shoot_home.js, a
  // separate three-second take: this one wipes the app's keys to run, and
  // re-recording how somebody opens an app should not cost an identity.
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
  await sleep(1800);                   // camera starting up
  mark('scanner');

  // The beat the footage goes into. Nothing happens on the device here on
  // purpose: whatever the emulator's camera is looking at gets replaced.
  marks.scanWindow = { start: at(), ms: SCAN_HOLD };
  await sleep(SCAN_HOLD);
  mark('scan_hold_done');

  // SALVAGE THE RECORDING, whatever happens next.
  //
  // The take used to pull the file only on the happy path, so a failure threw
  // the footage away along with the error -- including the run where the publish
  // was completed by hand and worked, which is exactly the run worth keeping.
  // Called on the way out either way; the build still fails loudly, it just
  // fails with the evidence on disk.
  let pulled = false;
  const pullTake = async () => {
    if (pulled) return;
    pulled = true;
    // Stop it on the DEVICE and wait for the file to settle. Killing the local
    // adb first severs the shell before screenrecord can write its moov atom,
    // and the pulled file is then not a video at all.
    try { await require('./lib/device').device().stopRecording('/sdcard/vouch.mp4'); }
    catch (e) { console.error('  (stopRecording failed:', e.message.split('\n')[0], ')'); }
    try { rec.kill(); } catch { /* already gone */ }
    // The stamp is on the build directory (lib/build_dir.js), so the take
    // inside it is named for what it is and nothing else.
    const name = 'vouch';
    try {
      d.E('pull', '/sdcard/vouch.mp4', path.join(OUT, `${name}.mp4`));
      // Off the device once it is safely here. Every take used to leave its
      // recording behind, and they were quietly filling /data.
      d.E('shell', 'rm', '-f', '/sdcard/vouch.mp4');
    } catch (e) { console.error('  (pull failed:', e.message.split('\n')[0], ')'); }
    // The snackbar's moments, read out of the take. Video time minus the sync
    // flash offset gives the script clock the rest of the marks are on.
    const take = path.join(OUT, `${name}.mp4`);
    try {
      const off = JSON.parse(execFileSync('node',
        [path.join(__dirname, 'find_flash.js'), take], { encoding: 'utf8' })).offset;
      const sb = JSON.parse(execFileSync('node',
        [path.join(__dirname, 'find_snackbar.js'), take], { encoding: 'utf8' }));
      marks.published = +(sb.appeared - off).toFixed(2);
      if (sb.cleared !== null) marks.success_cleared = +(sb.cleared - off).toFixed(2);
      console.log(`  published @${marks.published}s, success_cleared ` +
                  `@${marks.success_cleared ?? '(still up at the end)'}s  (from the footage)`);
    } catch (e) {
      console.error('  COULD NOT FIND THE SNACKBAR:', e.message.split('\n')[0]);
      console.error('  The take is kept. Watch it: if "Trusted: Success" is there, '
        + 'find_snackbar.js needs its band checked against a frame of it.');
    }
    fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
    console.log(`\n${path.relative(__dirname, path.join(OUT, `${name}.mp4`))}\n` +
                `${path.relative(__dirname, path.join(OUT, `${name}.marks.json`))}  ` +
                `(${marks.taps.length} taps)`);
  };

  // --- the key arrives, as if scanned ---
  // Leave the scanner FIRST. A real scan pops it and shows the dialog over the
  // main screen -- that is what the Aug 11 footage does -- whereas the deep link
  // on its own leaves the scanner underneath. Which is both wrong and the reason
  // the emulator's rendered room was visible around the dialog for the rest of
  // the take: the composite has ended by then and there is nothing over it.
  d.E('shell', 'input', 'keyevent', '4');
  await sleep(1000);
  mark('left_scanner');

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
  // The keyboard away BEFORE reaching for PUBLISH. With it up the dialog rides
  // higher and the tap below lands on the keyboard -- it hit `j`, which is how a
  // take came back with the moniker "Tomj" and PUBLISH never pressed.
  if (await d.hideKeyboard()) {
    console.log('  keyboard dismissed before PUBLISH');
    await sleep(700);
  }
  await sleep(1800);                   // a beat on the name, then commit to it

  tap('publish', AT.publish);
  // WAIT FOR IT, don't sleep through it. This was a blind sleep(4500) and the
  // take ended with the spinner still turning: the dialog was never seen to
  // close and the success never appeared, so the payoff of the whole section
  // was a form with a spinner on it.
  //
  // The identity app is native, so there is no semantics tree to wait on. The
  // screen settling is a good proxy here precisely because the thing moving IS
  // the spinner -- once signing and publishing finish, the dialog closes and
  // the screen stops changing.
  // HOLD, then find the moment in the footage afterwards.
  //
  // Not by watching the live screen. Three detectors were written that way --
  // hashing for stillness, for motion, and for colour -- and the reason the last
  // one failed is worth keeping: its band sat 115px too high, caught only the
  // snackbar's top edge, and read green-minus-red of 21 against a threshold of
  // 25. The bar was plainly on screen and the script reported nothing, twice,
  // for minutes at a time.
  //
  // find_snackbar.js reads the recording instead, at every frame rather than one
  // sample every 250ms, and cannot be fooled by whatever adb screencap does
  // while screenrecord holds the display. Same shape as find_flash.js: the take
  // records, the moment is found in what it recorded.
  //
  // 18s covers it with room to spare -- measured, the snackbar arrives about 6s
  // after Publish and clears about 10s after.
  await sleep(18000);

  await pullTake();
  console.log(`scan window: ${marks.scanWindow.start}s + ${SCAN_HOLD / 1000}s (script clock)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
