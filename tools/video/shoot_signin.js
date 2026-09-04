#!/usr/bin/env node
// Shoot the sign-in sequence: Nerdster home -> web app -> ONE-OF-US.NET app ->
// create delegate -> back, signed in. One continuous take, one device, live data.
//
//   adb forward tcp:9222 localabstract:chrome_devtools_remote
//   node shoot_signin.js
//
// Writes out/signin_<stamp>.mp4 and out/signin_<stamp>.marks.json (tap times and
// coordinates, which post-production needs to draw the touch indicators).
//
// WHY THIS LOOKS DIFFERENT FROM THE OLD SCRIPT. It has no hardcoded tap
// coordinates and no sleeps that are guesses. Everything on the browser side
// goes through the Flutter accessibility tree (lib/semantics.js): tap by what a
// control *says*, wait until it exists, and assert the expected screen before
// continuing. A take that hits the wrong dialog now stops with a message
// instead of recording a valid-looking file of the wrong thing.
//
// The identity app half is still blind — native Flutter surfaces its nodes only
// through an Android accessibility service — so its taps remain coordinates.
// They are marked APP-BLIND below.

const fs = require('fs');
const path = require('path');
const { execFileSync, spawn } = require('child_process');
const { chromium } = require('playwright');
const {
  SEMANTICS_PROBE, sleep, enableSemantics, waitFor, assertVisible, assertAbsent,
  tapNamed, attachToAvdChrome,
} = require('./lib/semantics');

const SERIAL = process.env.AVD || 'emulator-5554';
const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('signin');
const E = (...a) => execFileSync('adb', ['-s', SERIAL, ...a], { stdio: 'ignore' });
const Eout = (...a) => execFileSync('adb', ['-s', SERIAL, ...a]).toString();

/// Wait until the screen stops changing. The identity app is native Flutter with
/// no accessibility tree to query, so this is the closest thing to a condition:
/// grab frames and compare. Covers the case waitForApp cannot -- the app is
/// foreground but still on its splash screen, where a tap hits nothing.
async function waitForStillScreen(timeout = 15000, quietMs = 900) {
  const grab = () => execFileSync('bash',
    ['-c', `adb -s ${SERIAL} exec-out screencap -p | md5sum | cut -d' ' -f1`],
    { encoding: 'utf8' }).trim();
  const t0 = Date.now();
  let last = '', since = Date.now();
  while (Date.now() - t0 < timeout) {
    const now = grab();
    if (now === last) { if (Date.now() - since >= quietMs) return true; }
    else { last = now; since = Date.now(); }
    await sleep(250);
  }
  return false;                              // caller asserts on content anyway
}

/// Which app is in front. Lets the app-side waits be conditions rather than
/// generous sleeps -- the whole point is that the video moves along.
function foregroundApp() {
  const out = Eout('shell', 'dumpsys', 'activity', 'activities');
  const m = out.match(/topResumedActivity=ActivityRecord\{\S+ \S+ (\S+?)\//);
  return m ? m[1] : '';
}
async function waitForApp(pkg, timeout = 20000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (foregroundApp() === pkg) return true;
    await sleep(250);
  }
  throw new Error(`timeout waiting for ${pkg} to come to the front`);
}

// APP-BLIND: coordinates in the identity app, on a 1080x2220 screen.
const APP = { yesCreateDelegate: [693, 1532] };

// Browser taps come from the semantics tree in CSS viewport pixels; app taps and
// the recording are in device screen pixels. Convert, so signin_marks.json is
// one coordinate space and post-production can use it directly.
//   scale  = deviceWidth / innerWidth
//   offset = Chrome's toolbar, which sits above the viewport
let VIEW2DEV = null;
async function calibrate(page) {
  const vp = await page.evaluate(() => ({ w: innerWidth, h: innerHeight }));
  const size = Eout('shell', 'wm', 'size').match(/(\d+)x(\d+)/);
  const dw = +size[1], dh = +size[2];
  const scale = dw / vp.w;
  VIEW2DEV = { scale, offY: Math.round(dh - vp.h * scale - 67) };  // 67 = gesture bar
  return VIEW2DEV;
}
const toDevice = (x, y) => VIEW2DEV
  ? { x: Math.round(x * VIEW2DEV.scale), y: Math.round(y * VIEW2DEV.scale + VIEW2DEV.offY) }
  : { x: Math.round(x), y: Math.round(y) };

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const marks = { taps: [] };
  const t0 = Date.now();
  let recT0 = null;                    // set when screenrecord starts
  const at = () => +((Date.now() - (recT0 ?? t0)) / 1000).toFixed(2);
  const mark = k => { marks[k] = at(); console.log(`  ${k} @${marks[k]}s`); };

  // --- stage: browser and app both up, so no launcher flash mid-take ---
  E('shell', 'am', 'force-stop', 'com.android.chrome');
  E('shell', 'am', 'force-stop', 'net.oneofus.app');
  E('shell', 'monkey', '-p', 'net.oneofus.app', '-c', 'android.intent.category.LAUNCHER', '1');
  await waitForApp('net.oneofus.app');
  E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'https://nerdster.org',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await waitForApp('com.android.chrome');
  // Re-forward AFTER the restart above. shoot.sh sets the forward up before it
  // runs this, and force-stopping Chrome invalidates it -- which surfaces later
  // as "socket hang up" from connectOverCDP, several steps from the cause.
  await require('./lib/device').device().forwardDevtools();
  await sleep(1200);                       // let the home page paint

  let { browser, page, cdp } = await attachToAvdChrome(chromium);
  console.log('attached:', page.url());

  // --- record ---
  // Chrome opens a tab per VIEW intent and nothing closed them; thirty had
  // piled up, and enough of them throttle screenrecord. Swept before the
  // camera, so a crashed take is cleaned up by the next one.
  await require('./lib/device').device().closeChromeTabs();



  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '90', '--bit-rate', '8000000', '/sdcard/signin.mp4']);

  // SYNC FLASH. screenrecord keeps capturing for a couple of seconds after the
  // process spawns, so a clock zeroed at spawn runs ~2.5s ahead of the footage
  // and every touch indicator lands early. Instead: wait until capture is
  // definitely running, paint the screen white for a few frames, and zero the
  // clock there. find_flash.js locates that frame in the video, which gives the
  // true offset between this clock and the recording.
  await sleep(4000);
  await page.evaluate(() => {
    const f = document.createElement('div');
    f.id = '__syncflash';
    f.style.cssText = 'position:fixed;inset:0;background:#fff;z-index:2147483647;pointer-events:none';
    document.body.appendChild(f);
  });
  recT0 = Date.now();                       // t=0 is the first white frame
  await sleep(400);                         // ~10 frames of white to find
  await page.evaluate(() => document.getElementById('__syncflash')?.remove());
  marks.syncFlash = { heldMs: 400 };
  await sleep(600);

  // --- home page ---
  await page.evaluate(() => {}); // ensure attached
  const launch = await page.waitForSelector('a.web-app-link, a[href*="/app"]', { timeout: 20000 });
  // Where the SECTION starts, as opposed to where the recording does. Every take
  // opens with a launch and a sync flash that are staging, not content, and
  // sections.py trims to a named mark -- so the home page needs a name, or the
  // trim has to go to tap_launch and cut the page the section opens on.
  mark('home');
  await sleep(1800);                        // let the page be looked at
  const lb = await launch.boundingBox();
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart',
    touchPoints: [{ x: Math.round(lb.x + lb.width / 2), y: Math.round(lb.y + lb.height / 2),
                    radiusX: 20, radiusY: 20, force: 1 }] });
  await sleep(110);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await calibrate(page);
  marks.viewportToDevice = VIEW2DEV;
  marks.taps.push({ t: at(), ...toDevice(lb.x + lb.width / 2, lb.y + lb.height / 2), what: 'launch' });
  mark('tap_launch');

  // --- web app: wait for it, don't guess ---
  // No sleep here. The waitFor below polls until the dialog exists, so anything
  // slept is dead screen time -- there used to be 6s of it, which was most of
  // the take. Do not add one back; if this needs to wait, wait on a condition.
  // Navigation wipes anything injected into the old document, so the probe goes
  // in again here rather than only at attach time.
  // Re-attach after navigation: a CDP session bound to the pre-navigation target
  // still reports fine but its input events go nowhere.
  const ctx2 = browser.contexts()[0];
  // Poll for the /app tab rather than sleeping: the tap navigates, and the new
  // document has to exist before the probe or the semantics placeholder do.
  for (let i = 0; i < 60; i++) {
    const cand = ctx2.pages().find(p => p.url().includes('/app'));
    if (cand) { page = cand; break; }
    await sleep(250);
  }
  cdp = await ctx2.newCDPSession(page);
  // The placeholder only exists once Flutter has bootstrapped.
  for (let i = 0; i < 80; i++) {
    const ready = await page.evaluate(
      () => !!document.querySelector('flt-semantics-placeholder')).catch(() => false);
    if (ready) break;
    await sleep(250);
  }
  await page.evaluate(SEMANTICS_PROBE);
  await enableSemantics(page, cdp);
  await waitFor(page, /Sign in using your Identity App/, {}, 45000);
  mark('app_ready');
  // HOLDS, NOT SETTLING TIME. capture_manual bans sleeping to "let it settle" --
  // that hides a missing wait and pads the take with dead screen. These are the
  // opposite: they come AFTER the condition has been waited on, and exist so the
  // prompter line anchored here can actually be read. The take ran 13s with
  // eight lines on it, which is about half the time a person needs.
  await sleep(2600);

  // The reset must have left us signed out; if not, the take is worthless.
  await assertVisible(page, /Identity\s*not present/);
  await assertVisible(page, /Delegate\s*not present/);
  console.log('  verified: signed out');

  const btn = await tapNamed(page, cdp, /one-of-us\.net/, { role: 'button' });
  marks.taps.push({ t: at(), ...toDevice(btn.x, btn.y), what: 'signin' });
  mark('tap_signin');

  // --- identity app (APP-BLIND) ---
  await waitForApp('net.oneofus.app', 25000);
  await waitForStillScreen();              // past the splash, dialog drawn
  const shot = path.join(OUT, 'signin_dialog.png');
  execFileSync('bash', ['-c', `adb -s ${SERIAL} exec-out screencap -p > ${shot}`]);
  // Cheap proxy for an assertion on the app side: the reset should have produced
  // the create prompt, not the rotate one. Checked from the pulled frame below.
  E('shell', 'input', 'tap', String(APP.yesCreateDelegate[0]), String(APP.yesCreateDelegate[1]));
  marks.taps.push({ t: at(), x: APP.yesCreateDelegate[0], y: APP.yesCreateDelegate[1], what: 'yes_create' });
  mark('tap_yes');

  await sleep(2200);               // the "Sent ... key pair" animation, no longer
  mark('animation');
  E('shell', 'input', 'keyevent', '4');
  mark('back_to_browser');

  // --- back in the browser: wait for the real thing, then prove it ---
  await waitFor(page, /Delegate\s*present/, {}, 60000);
  await assertVisible(page, /Identity\s*present/);
  await assertAbsent(page, /Existing Delegate Found/);
  mark('signed_in');
  await sleep(2800);                       // hold: the sign-in status is the point
  console.log('  verified: both keys present');

  await sleep(500);
  await page.evaluate(() => window.scrollTo(0, 0));
  // Dismiss by tapping the scrim above the dialog. Logged like every other tap,
  // so the touch indicator gets drawn here too.
  const dz = toDevice(216, 120);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart',
    touchPoints: [{ x: 216, y: 120, radiusX: 20, radiusY: 20, force: 1 }] });
  await sleep(110);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  marks.taps.push({ t: at(), ...dz, what: 'dismiss' });
  mark('dismiss');
  await sleep(2600);                       // hold, so the closing line is readable
  // Hold long enough for the feed to finish loading, so the take ends on content
  // rather than "Loading delegate content...". Waits on the condition, with a
  // short beat after so it doesn't cut the instant the last card paints.
  await waitFor(page, /The Apartment|Sot-Weed/, {}, 12000).catch(() => {});
  await sleep(1200);
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/signin.mp4');
  rec.kill();
  await browser.close();
  // Never overwrite: every take is kept, stamped, so a good one can't be lost
  // to a later bad one. (One reshoot was already forced by a deleted raw.)
  // The stamp is on the build directory (lib/build_dir.js), so the take
  // inside it is named for what it is and nothing else.
  const name = 'signin';
  E('pull', '/sdcard/signin.mp4', path.join(OUT, `${name}.mp4`));
  // Off the device once it is safely here. Every take used to leave its
  // recording behind, and they were quietly filling /data -- enough that an
  // apk install eventually failed for want of space.
  E('shell', 'rm', '-f', '/sdcard/signin.mp4');
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${name}.mp4`))}\n${path.relative(__dirname, path.join(OUT, `${name}.marks.json`))}  (${marks.taps.length} taps logged)`);
})().catch(e => {
  // Loud failure is the point. Previously a wrong take produced a normal file.
  console.error('\nTAKE FAILED:', e.message);
  process.exit(1);
});
