#!/usr/bin/env node
// Shoot "Close account?" -- the question with no answer, because there is no
// account. What can be undone is undone here, from the phone, by the identity
// key, without asking anyone's permission.
//
//   node shoot_close_account.js
//
// Writes out/close_account/<stamp>/close_account.mp4 + .marks.json.
//
// DESTRUCTIVE, but UNDOABLE. Everything this take changes on the network is one
// appended statement -- these streams are append-only hash chains, so a take
// cannot modify or remove anything, only add. Snapshot the head first, rewind
// to it afterwards, and the clear never happened:
//
//   node snapshot_statements.js --token <identity> --project oneofus --prod > before.json
//   ...shoot...
//   node truncate_statements.js --token <identity> --project oneofus --prod \
//     --keep <the head from before.json>
//
// Proven on 2026-09-02: the take published a clear, the rewind removed it, and
// the stream went back to exactly the head and count it had before.
//
// DO NOT "restore" BY RESHOOTING SIGN-IN. It gets you *a* delegate key, not
// *the* delegate key: the likes in `nerdster` and `crypto_teaser` were signed by
// the delegate that existed when those takes were shot, and a new one leaves
// them orphaned -- signed by a key no statement ties to the identity -- so they
// vanish from the feed. Worse, shoot_signin.sh's first step truncates the
// existing delegate statements, so reshooting it is itself what orphans them.
//
// ONE THING THE REWIND DOES NOT BRING BACK. Deleting the local private key is a
// separate act from clearing -- the "Remove Local Key?" dialog -- and it is
// local and permanent.
//
// The two halves come apart, and the resulting state is a confusing one to
// debug if you do not expect it: rewind the statements without the key and the
// delegation stands again, so the RATINGS SIGNED BY THAT KEY COME BACK AND ARE
// VISIBLE -- but nothing can sign in as that delegate any more, because the
// private key is gone. Readable, not writable. The phone will offer to claim a
// new delegate instead, and that is a different key with a different token. The network statement comes back; the phone's copy
// does not. The browser keeps its own copy, so the Nerdster still works. To make
// this take truly repeatable the phone's keyring needs snapshotting too --
// `adb backup` of the app, or a restore_demo_identity.sh that also re-claims the
// delegate. NOT DONE; see video/intro.yaml.
//
// NOT YET SHOT END TO END. The ONE-OF-US.NET half works, including the clear.
// The Nerdster half stops at the degrees-of-separation slider: it is a real
// slider in a popup and it does not take the keyboard, so it needs a measured
// drag along its track. That is the next thing.
//
// IDEAS FOR AFTER V1 (Yotam, 2026-09-02), kept here rather than lost:
//
//   - ORDER. Show the exported keys BEFORE clearing the delegate, and consider
//     clearing the vouch for Tom too. Cheap to try once the rewind above is
//     wired into the build rather than run by hand.
//   - THE INTERESTING SHOT: set the Nerdster's follow network to 1 degree, so
//     the feed is only my own ratings, and then clear the delegate. What is left
//     is everybody else's ratings and none of mine -- the point made visually.
//   - A LIKE DISAPPEARING IN REAL TIME. Put a highlight around one of my likes,
//     then refresh: the like goes, because the key that signed it no longer
//     speaks for me. Nothing was deleted -- a statement was withdrawn -- and
//     this is the one shot that shows the difference. Needs the highlight to
//     survive across a refresh rather than being a frozen beat, so it is
//     probably a new cue kind: a box held on live footage.
//
// The five tabs are Me / PEOPLE / SERVICES / IMPORT-EXPORT / ADVANCED, in that
// order, reached by swiping. All five were confirmed on the device; the
// coordinates below were measured off those screenshots.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { chromium } = require('playwright');
const { device, sleep } = require('./lib/device');
const {
  SEMANTICS_PROBE, enableSemantics, find, findStill, waitFor, tapNamed, tapAt,
  assertVisible, attachToAvdChrome,
} = require('./lib/semantics');
const { execFileSync } = require('child_process');

const APP = 'net.oneofus.app';
const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('close_account');
const d = device();

// APP-BLIND: coordinates on a 1080x2220 screen, measured off screenshots of
// each tab. The identity app is Flutter NATIVE -- its semantics tree is not
// reachable over CDP the way the web apps' is -- so this half is pixels, like
// shoot_vouch.js and shoot_invite.js.
const AT = {
  peopleClear: [887, 478],      // CLEAR on the Tom card, PEOPLE tab
  servicesClear: [887, 527],    // CLEAR on the Me@nerdster.org card, SERVICES tab
  exportButton: [294, 1717],    // EXPORT, IMPORT/EXPORT tab
  // CLEAR does confirm: ClearStatementDialog, "Clear Delegation", asking about
  // "nerdster.org", with CANCEL and an orange CLEAR. Measured off the dialog on
  // the device -- opened and then cancelled, so nothing was cleared to find out.
  confirmClear: [777, 1350],    // CLEAR in the "Clear Delegation" dialog
  // A SECOND dialog, about a DIFFERENT thing. Clearing is publishing a `clear`
  // statement, after which the identity is no longer associated with that
  // delegate key. Deleting the local private key is separate, and that is what
  // "Remove Local Key?" (CANCEL / CLEAR & DELETE) asks about -- it only comes up
  // because this delegation is one whose private key the phone happens to hold.
  //
  // It matters here because the app GATES THE PUBLISH behind it: its own text
  // says the key goes "after the network statement is published". Abandoning
  // this dialog aborts before anything is published at all, which is what
  // happened on the first two takes -- they looked destructive and changed
  // nothing. app_shell.dart:920.
  confirmDelete: [719, 1428],   // CLEAR & DELETE in the "Remove Local Key?" dialog
};
// A tab change. Right-to-left travel moves to the NEXT tab; the pause before
// release is what stops Flutter reading it as a flick that springs back.
const SWIPE = { from: [900, 1200], to: [180, 1200], ms: 320 };

// Semantics coordinates are VIEWPORT coordinates, and the viewport starts below
// Chrome's URL bar. Scaling by width alone put the key beat on the toolbar --
// on the refresh button, with the crossed-out key it was meant to point at
// sitting just underneath. Same calibration as shoot_crypto_teaser.js.
let VIEW2DEV = null;
async function calibrate(page) {
  const vp = await page.evaluate(() => ({ w: innerWidth, h: innerHeight }));
  const size = d.Eout('shell', 'wm', 'size').match(/(\d+)x(\d+)/);
  const scale = +size[1] / vp.w;
  VIEW2DEV = { scale, offY: Math.round(+size[2] - vp.h * scale - 67) };
}
const toDevice = (x, y) => ({
  x: Math.round(x * VIEW2DEV.scale),
  y: Math.round(y * VIEW2DEV.scale + VIEW2DEV.offY),
});

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const marks = { taps: [], swipes: [] };
  let t0 = Date.now();
  const at = () => +((Date.now() - t0) / 1000).toFixed(2);
  const mark = k => { marks[k] = at(); console.log(`  ${k} @${marks[k]}s`); };
  const tap = (what, [x, y]) => {
    marks.taps.push({ t: at(), x, y, what });
    d.tap(x, y);
    mark(`tap_${what}`);
  };
  // `y` because a swipe has to start somewhere that is not itself scrollable.
  // The default 1200 is empty space on most tabs, but on IMPORT/EXPORT it is
  // inside the keys panel -- a scrollable text area, which swallowed the drag
  // and left the take sitting on the same tab.
  const swipeTab = async (what, y = 1200) => {
    const { ms } = SWIPE;
    const from = [SWIPE.from[0], y], to = [SWIPE.to[0], y];
    marks.swipes.push({ t: at(), from: { x: from[0], y: from[1] },
                        to: { x: to[0], y: to[1] }, ms });
    d.E('shell', 'input', 'swipe', String(from[0]), String(from[1]),
        String(to[0]), String(to[1]), String(ms));
    await sleep(1400);                  // the page settles before it is marked
    mark(what);
  };

  // The degrees control is a slider in a popup. It does not take the keyboard,
  // but it takes a tap anywhere on its track, and the thumb sits at x=127 for 1
  // and x=355 for 6 in a 392px viewport -- 45.6px a step. Two measured points
  // and the value it currently reads give any other position.
  const STEP = 45.6;
  let page, cdp, browser;
  const degrees = async () => {
    const n = await find(page, /^Degrees of separation: \d+$/);
    return n ? +n.text.match(/(\d+)$/)[1] : null;
  };
  const setDegrees = async target => {
    await tapNamed(page, cdp, /Follow network: \d+ degree/);
    await sleep(900);
    for (let i = 0; i < 8 && (await degrees()) !== target; i++) {
      const t = await find(page, /^[1-6]$/);
      const v = await degrees();
      if (!t || v === null) throw new Error('the degrees popup did not open');
      await tapAt(cdp, t.x + (target - v) * STEP, t.y);
      await sleep(600);
    }
    const got = await degrees();
    if (got !== target) {
      throw new Error(`could not set degrees of separation to ${target} -- it reads ${got}.`);
    }
    await page.keyboard.press('Escape');
    await sleep(800);
  };

  d.E('shell', 'am', 'force-stop', APP);
  d.E('shell', 'am', 'force-stop', 'com.android.chrome');
  await sleep(1500);

  // Chrome opens a tab per VIEW intent and nothing closed them; thirty had
  // piled up, and enough of them throttle screenrecord. Swept before the
  // camera, so a crashed take is cleaned up by the next one.
  await d.closeChromeTabs();

  const rec = spawn('adb', ['-s', process.env.AVD || 'emulator-5554', 'shell', 'screenrecord',
    '--time-limit', '180', '--bit-rate', '8000000', '/sdcard/close_account.mp4']);
  await sleep(4000);

  // KEEP THE FOOTAGE WHEN THE TAKE FAILS. This section clears the delegate key
  // partway through, so a failure after that point cannot simply be retried:
  // the state it needs is gone, and getting it back costs a reshoot of `signin`.
  // The first attempt died at the Nerdster and threw away a recording of the
  // whole ONE-OF-US.NET half, which had gone perfectly. The build still fails
  // loudly; it just fails with the evidence on disk.
  let pulled = false;
  const pullTake = async () => {
    if (pulled) return;
    pulled = true;
    // Stop it on the DEVICE and let the file settle. Killing the local adb
    // first severs the shell before screenrecord can write its moov atom, and
    // what comes back is then not a video at all.
    try { await require('./lib/device').device().stopRecording('/sdcard/close_account.mp4'); }
    catch (e) { console.error('  (stopRecording failed:', e.message.split('\n')[0], ')'); }
    try { rec.kill(); } catch { /* already gone */ }
    try {
      d.E('pull', '/sdcard/close_account.mp4', path.join(OUT, 'close_account.mp4'));
      d.E('shell', 'rm', '-f', '/sdcard/close_account.mp4');
    } catch (e) { console.error('  (pull failed:', e.message.split('\n')[0], ')'); }
    fs.writeFileSync(path.join(OUT, 'close_account.marks.json'),
                     JSON.stringify(marks, null, 2));
    console.log(`  take saved: ${path.relative(__dirname, path.join(OUT, 'close_account.mp4'))}`);
  };
  try {

  // SYNC FLASH, black: this take is made of light app screens, so white would
  // not beat the median. See find_flash.js --dark.
  d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
    '-d', 'data:text/html,%3Cbody%20style%3D%22background%3A%23000%22%3E',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await d.waitForApp('com.android.chrome');
  t0 = await d.waitForDark();
  await sleep(600);
  marks.syncFlash = { heldMs: 600, kind: 'dark' };

  // LOAD THE NERDSTER FIRST, before anything is cleared, and leave it loaded.
  //
  // This is the whole trick of the second half. The take used to come to the
  // Nerdster only after the clear, navigating to it fresh -- so it loaded from
  // scratch, already knew the delegate was gone, and there was nothing to see
  // happen. Loaded BEFORE, it is still showing the world as it was; the take
  // returns to it by resuming Chrome rather than reloading, and the refresh is
  // then the moment the rating and the key actually go.
  //
  // All of this is in the take's head, before `opening`, and is trimmed off.
  // DO NOT force-stop Chrome to get here, and do not open the URL with an
  // intent. The Nerdster's sign-in does not survive Chrome being killed, so a
  // take that restarts it arrives at the sign-in screen instead of a feed --
  // which is what happened, twice. Attach to the Chrome that is already running
  // (the sync flash started it) and navigate the tab from inside. That also
  // avoids attaching to the flash's black data: page, which is a separate way
  // this went wrong.
  d.E('shell', 'am', 'start', '-n',
      'com.android.chrome/com.google.android.apps.chrome.Main');
  await d.waitForApp('com.android.chrome');
  await d.forwardDevtools();
  ({ browser, page, cdp } = await attachToAvdChrome(chromium));
  await page.goto('https://nerdster.org/app', { waitUntil: 'domcontentloaded' });
  for (let i = 0; i < 80; i++) {
    if (await page.evaluate(() => !!document.querySelector('flt-semantics-placeholder'))
        .catch(() => false)) break;
    await sleep(250);
  }
  await page.evaluate(SEMANTICS_PROBE);
  await enableSemantics(page, cdp);
  await calibrate(page);
  marks.viewportToDevice = VIEW2DEV;
  // Wait for a control that is ALWAYS there. "Mark to Relate/Equate" is a feed
  // item, and the feed can legitimately be empty -- the follow network setting
  // survives between sessions, so a take that left it at 1 leaves the next one
  // opening on "No content found" and waiting forever for a card.
  await waitFor(page, /Follow network: \d+ degree/, {}, 60000);

  // START AT 6. The shot is the reduction from 6 to 1, so 6 has to be where it
  // starts, whatever the last take left behind.
  await setDegrees(6);
  console.log('  nerdster loaded at 6 degrees, and left loaded');

  d.launch(APP);
  await d.waitForApp(APP);
  // A cold start reloads everything the identity has published and takes about
  // eight seconds. The section is trimmed to `opening` and the opening card is
  // spliced there, so this mark has to land on the loaded screen, not a spinner.
  await sleep(9500);
  mark('opening');
  await sleep(1200);

  // --- PEOPLE: the vouches I have made, and can unmake -------------------
  await swipeTab('people');
  await sleep(2600);
  mark('people_read');
  await sleep(2800);
  mark('people_read_2');
  await sleep(3200);

  // --- SERVICES: the delegate keys, and clearing the Nerdster's ----------
  await swipeTab('services');
  await sleep(2600);

  tap('servicesClear', AT.servicesClear);
  // FIXED WAITS, not waitForStillScreen. The app bar carries a red recording dot
  // that sits inside the region waitForStillScreen compares, so the screen is
  // never still and every one of these ran to its timeout -- nine seconds for a
  // dialog that opens in one, and twenty-six for the publish.
  await sleep(1200);
  mark('clear_dialog');
  // "Are you sure you want to remove your delegation for nerdster.org?" -- worth
  // a moment on screen. It is the whole argument in one sentence: a statement
  // being withdrawn, by me, from here.
  await sleep(2400);

  tap('confirmClear', AT.confirmClear);
  await sleep(1200);
  mark('delete_dialog');
  await sleep(2400);

  tap('confirmDelete', AT.confirmDelete);
  // Signing and publishing the clear statement, which ends with the card gone
  // and "No Authorized Delegates" in its place.
  await sleep(7000);
  mark('cleared');
  await sleep(1800);

  // --- the Nerdster, where that key has just stopped speaking for me ------
  // RESUME Chrome. No force-stop and no URL: both would reload the page, and a
  // reloaded page fetches the statements again and already knows the delegate
  // is cleared. What has to survive the trip to the identity app is the view as
  // it was BEFORE the clear.
  d.E('shell', 'am', 'start', '-n',
      'com.android.chrome/com.google.android.apps.chrome.Main');
  await d.waitForApp('com.android.chrome');
  await sleep(2000);
  // Still the same page, still loaded? If Android evicted Chrome while the
  // identity app was in front, it came back reloaded and the shot is gone --
  // better to know than to film it.
  await assertVisible(page, /Follow network: \d+ degree/);

  // Network distance 6 -> 1: just my own ratings, on a page that still shows
  // the world as it was before the clear.
  await setDegrees(1);
  mark('distance_1');
  await sleep(1200);
  // Only my own ratings now -- and they are still here, because this page was
  // loaded before the clear.
  mark('my_rating');
  await sleep(1600);

  // MEASURE both the key and the refresh button, now, while the delegation
  // still stands. The key reads "(active)" here and "(not associated with
  // identity)" after -- same node, same place, opposite meaning, which is the
  // whole point of the pair of highlights.
  const okKey = await findStill(page, /Signed in with Identity/);
  const okc = toDevice(okKey.x, okKey.y);
  marks.keyOkBox = { x: okc.x, y: okc.y,
    w: Math.round(okKey.w * VIEW2DEV.scale), h: Math.round(okKey.h * VIEW2DEV.scale) };
  const refreshNode = await findStill(page, /^Refresh$/);
  const rc = toDevice(refreshNode.x, refreshNode.y);
  marks.refreshBox = { x: rc.x, y: rc.y,
    w: Math.round(refreshNode.w * VIEW2DEV.scale), h: Math.round(refreshNode.h * VIEW2DEV.scale) };
  mark('before_refresh');
  await sleep(2200);

  // RECORD THE TAP, not just perform it. tapNamed drives the page over CDP and
  // nothing lands in marks.taps, so overlay_taps drew no indicator and the most
  // important click in the section happened invisibly -- the feed simply changed
  // by itself.
  const r = await tapNamed(page, cdp, /^Refresh$/);
  const rd = toDevice(r.x, r.y);
  marks.taps.push({ t: at(), x: rd.x, y: rd.y, what: 'refresh' });
  mark('tap_refresh');
  await page.waitForTimeout(6000);
  // ...and now they are not. Nothing was deleted; a statement was withdrawn.
  mark('nerdster_refreshed');

  // MEASURE the key indicator rather than typing a rectangle for it: it sits in
  // a header that moves with the window. It reads "Signed in with Identity and
  // Delegate (active)" while the delegation stands, and it is the thing that
  // changes when the delegate statement is withdrawn.
  const key = await findStill(page, /Signed in with Identity/);
  const c = toDevice(key.x, key.y);
  marks.keyIssueBox = {
    x: c.x, y: c.y,
    w: Math.round(key.w * VIEW2DEV.scale), h: Math.round(key.h * VIEW2DEV.scale),
  };
  console.log(`  keyIssueBox ${JSON.stringify(marks.keyIssueBox)}  "${key.text}"`);
  await sleep(4200);

  await browser.close();

  // --- back to the app: my keys, and the advanced stuff -------------------
  d.launch(APP);
  await d.waitForApp(APP);
  await sleep(3000);
  // Back where it was left, on SERVICES.
  await swipeTab('export_shown');
  await sleep(2000);

  // SHOWS THE PRIVATE KEY JSON. This identity's secret goes on screen here and
  // the video is public -- see the todo in video/intro.yaml. Keep the beat on
  // the buttons and mask the panel, or cut this tap.
  tap('export', AT.exportButton);
  // Long enough for the keys to be on screen and for the line about them to be
  // read, since that line is anchored here rather than on arriving at the tab.
  await sleep(5200);

  // Below the EXPORT/COPY/PASTE/IMPORT buttons, on the footer text, which is the
  // only part of this tab that neither scrolls nor is a control.
  await swipeTab('advanced', 2060);
  await sleep(5000);
  mark('done');

  } finally {
    await pullTake();
  }
  const name = 'close_account';
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${name}.mp4`))}\n` +
    `${path.relative(__dirname, path.join(OUT, `${name}.marks.json`))}  ` +
    `(${marks.taps.length} taps, ${marks.swipes.length} swipes)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
