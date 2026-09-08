#!/usr/bin/env node
// Shoot "Block" -- taking a person out of the network, which the web app cannot
// do on its own because a block is an identity-layer statement.
//
//   node shoot_oneofus_block.js
//
// Writes out/oneofus_block/<stamp>/oneofus_block.mp4 + .marks.json.
//
// DESTRUCTIVE, but UNDOABLE, exactly like shoot_delegates.js: the take appends
// ONE statement -- a block of Eyal, signed by the identity key -- and these
// streams are append-only hash chains, so snapshot the head first and rewind to
// it after and the block never happened.
//
//   node snapshot_statements.js --token <identity> --project oneofus --prod > before.json
//   ...shoot...
//   I_MEAN_IT=yes node truncate_statements.js --token <identity> --project oneofus \
//     --prod --keep <the head from before.json>
//
// `sections.py --build oneofus_block` does the snapshot side for you; the rewind
// is `sections.py --restore crypto_teaser`, which is also the right way to get
// BACK to the state this take starts from.
//
// NOTHING ON THE PHONE CHANGES. Unlike `delegates`, no key is created or
// deleted -- the identity key signs and stays where it is -- so there is no
// app_state.sh half to this one.
//
// THE ROUTE, all of it walked by hand on the device before this was written:
//
//   Tags -> tech                      one filter; the demo identity's own
//                                     comment on the book carries #tech
//   Show more                         the card is collapsed to two comments and
//                                     Eyal is the third. SEMANTICS TAPS DO NOT
//                                     WORK ON IT -- see showMore() below
//   Eyal F@nerdster.org               opens a PATH view, not the details:
//                                     Me -> Tom -> Eyal F, which is how this
//                                     identity knows him at all
//   Eyal F (in the path)              opens the NodeDetail
//   Block this identity               -> "⚠️ Blocking is Harsh!"
//   Block anyway                      -> hands off to the phone
//
// THE HANDOFF is a magic link, not a dialog: node_details.dart launches
// https://one-of-us.net/block#<base64url key json> directly, because this
// browser signed in with the same-device transport. The app routes /block# to
// its ordinary scan handler with the verb locked to block (app_shell.dart), so
// what comes up is a "New Block" dialog: "Block this key.", a REASON field that
// is only RECOMMENDED, CANCEL, and a filled RED "BLOCK KEY". Red, not the teal
// PUBLISH the vouch dialog has -- blocking is the destructive one and the app
// says so in the button. Looking for teal here finds the CANCEL text instead and
// calls a 375px word a button, which is how the first take failed.
//
// LEAVE THE BROWSER LOADED. Same trick as `delegates`: the Nerdster is loaded
// BEFORE the block is published and never reloaded, so it is still showing the
// world as it was. The refresh at the end is the moment Eyal actually goes.

const fs = require('fs');
const path = require('path');
const { spawn, execFileSync } = require('child_process');
const { chromium } = require('playwright');
const { device, sleep } = require('./lib/device');
const {
  SEMANTICS_PROBE, enableSemantics, find, findStill, waitFor, tapNamed,
  assertVisible, attachToAvdChrome,
} = require('./lib/semantics');
const { findFilledButton } = require('./lib/filled_button');
const { buildDir } = require('./lib/build_dir');

const APP = 'net.oneofus.app';
const SERIAL = process.env.AVD || 'emulator-5554';
const OUT = buildDir('oneofus_block');
const d = device();
const TARGET = /Eyal F/;

// Semantics coordinates are VIEWPORT coordinates and the viewport starts below
// Chrome's URL bar. Same calibration as shoot_delegates.js and
// shoot_crypto_teaser.js; scaling by width alone puts every box on the toolbar.
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
const boxOf = node => {
  const c = toDevice(node.x, node.y);
  return { x: c.x, y: c.y,
           w: Math.round(node.w * VIEW2DEV.scale),
           h: Math.round(node.h * VIEW2DEV.scale) };
};

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const marks = { taps: [], swipes: [] };
  let t0 = Date.now();
  const at = () => +((Date.now() - t0) / 1000).toFixed(2);
  const mark = k => { marks[k] = at(); console.log(`  ${k} @${marks[k]}s`); };

  let page, cdp, browser;

  // Tap a semantics node and RECORD it, so overlay_taps draws an indicator.
  // tapNamed drives the page over CDP and lands nothing in marks.taps by itself;
  // the refresh in `delegates` was invisible for exactly that reason.
  const tapNode = async (re, what, opts = {}) => {
    const n = await tapNamed(page, cdp, re, opts);
    const c = toDevice(n.x, n.y);
    marks.taps.push({ t: at(), x: c.x, y: c.y, what });
    mark(`tap_${what}`);
    return n;
  };

  // SHOW MORE TAKES A REAL TAP, not a semantics one. tapNamed finds the node and
  // reports success, and the card stays collapsed -- so the tree afterwards looks
  // exactly like a feed that has no Eyal in it, which is how this section was
  // first written up as impossible. Tap its own device coordinates with
  // `input tap`, then ASSERT the comment arrived rather than trusting either.
  const showMore = async () => {
    const n = await findStill(page, /^Show more$/);
    const c = toDevice(n.x, n.y);
    d.E('shell', 'input', 'tap', String(c.x), String(c.y));
    marks.taps.push({ t: at(), x: c.x, y: c.y, what: 'show_more' });
    mark('tap_show_more');
    await sleep(1600);
    // The proof, and the reason this take exists. If Eyal is not on the card the
    // rest of the section has nothing to remove.
    await assertVisible(page, TARGET);
  };

  // Is a name in the point-of-view list? Opens the menu, reads it, closes it.
  // WITHOUT SWITCHING: choosing a point of view reloads the feed, which is the
  // one thing this take must not do before the refresh.
  const povHas = async () => {
    await tapNode(/^Point of View/, 'pov');
    await sleep(1200);
    const found = await find(page, TARGET);
    return found;
  };
  const povClose = async () => {
    await page.keyboard.press('Escape').catch(() => {});
    await sleep(900);
  };

  const screenHash = () => execFileSync('bash', ['-c',
    `adb -s ${SERIAL} exec-out screencap -p | md5sum | cut -d' ' -f1`],
    { encoding: 'utf8' }).trim();

  await d.closeChromeTabs();
  // Warm the identity app BEFORE the camera. A cold start reloads everything the
  // identity has published, about nine seconds, and paid on camera it is dead
  // air -- and it is what made hablotengo tap a dialog not yet drawn.
  await d.warmUp(APP);

  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '180', '--bit-rate', '8000000', '/sdcard/oneofus_block.mp4']);
  await sleep(4000);

  // KEEP THE FOOTAGE WHEN THE TAKE FAILS. Past the publish this cannot simply be
  // retried -- the state it needs is a network without the block in it, and
  // getting back costs a restore. Same reasoning as shoot_delegates.js.
  let pulled = false;
  const pullTake = async () => {
    if (pulled) return;
    pulled = true;
    try { await d.stopRecording('/sdcard/oneofus_block.mp4'); }
    catch (e) { console.error('  (stopRecording failed:', e.message.split('\n')[0], ')'); }
    try { rec.kill(); } catch { /* already gone */ }
    try {
      d.E('pull', '/sdcard/oneofus_block.mp4', path.join(OUT, 'oneofus_block.mp4'));
      d.E('shell', 'rm', '-f', '/sdcard/oneofus_block.mp4');
    } catch (e) { console.error('  (pull failed:', e.message.split('\n')[0], ')'); }
    fs.writeFileSync(path.join(OUT, 'oneofus_block.marks.json'),
                     JSON.stringify(marks, null, 2));
    console.log(`  take saved: ${path.relative(__dirname, path.join(OUT, 'oneofus_block.mp4'))}`);
  };

  try {
    // SYNC FLASH, black: this take is made of light app screens, so a white one
    // would not beat the median. find_flash.js --dark.
    d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
      '-d', 'data:text/html,%3Cbody%20style%3D%22background%3A%23000%22%3E',
      '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
    await d.waitForApp('com.android.chrome');
    t0 = await d.waitForDark();
    await sleep(600);
    marks.syncFlash = { heldMs: 600, kind: 'dark' };

    // ATTACH to the Chrome that is already running and navigate the tab from
    // inside. Do NOT force-stop Chrome and do NOT open the URL with an intent:
    // the Nerdster's sign-in does not survive Chrome being killed, and a take
    // that restarts it arrives at a sign-in screen instead of a feed.
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
    // Wait for a control that is ALWAYS there, not a feed item: the feed can
    // legitimately be empty, and a take that waits for a card then waits forever.
    await waitFor(page, /Follow network: \d+ degree/, {}, 60000);
    await sleep(1200);
    mark('feed');
    await sleep(1400);

    // --- find the book, and Eyal on it -----------------------------------
    await tapNode(/^Tags$/, 'tags');
    await sleep(1200);
    await tapNode(/^tech$/, 'tech');
    await sleep(2600);
    await assertVisible(page, /Read Write Own/);
    mark('eyal_book');
    await sleep(1800);

    await showMore();
    const comment = await findStill(page, TARGET);
    marks.eyalCommentBox = boxOf(comment);
    mark('eyal_comment');
    await sleep(2200);

    // His name opens the PATH -- Me -> Tom -> Eyal F -- and the avatar in THAT
    // opens the details. Two taps, and the first one is worth its own beat: it
    // is the answer to "why is he in my feed at all".
    await tapNode(TARGET, 'eyal_name');
    await sleep(2000);
    mark('path_shown');
    await sleep(2400);

    await tapNode(/^Eyal F$/, 'eyal_node');
    await sleep(1800);
    await assertVisible(page, /How I follow\/block/);
    const blockBtn = await findStill(page, /^Block this identity$/);
    marks.blockButtonBox = boxOf(blockBtn);
    mark('node_details');
    await sleep(2600);

    // --- the block ---------------------------------------------------------
    await tapNode(/^Block this identity$/, 'block');
    await sleep(1600);
    await assertVisible(page, /Blocking is Harsh/);
    const harsh = await findStill(page, /Blocking is Harsh/);
    marks.harshDialogBox = boxOf(harsh);
    mark('harsh_dialog');
    await sleep(3400);

    // "Block anyway" launches https://one-of-us.net/block#<key> directly. From
    // here the browser is done until the very end -- and it is deliberately left
    // exactly as it is, loaded, so the refresh later has something to change.
    const appScreen = screenHash();
    await tapNode(/^Block anyway$/, 'block_anyway');
    await d.waitForApp(APP, 25000);
    await sleep(2000);
    mark('identity_app');
    await sleep(2600);

    // "New Block", verb locked. The REASON field is RECOMMENDED, not required,
    // so BLOCK KEY is live straight away and the take leaves the reason empty --
    // this is a real statement about a real person and there is nothing to say
    // in it that is true. Measured, not typed: a docked keyboard moves the dialog
    // and a fixed coordinate then lands on a key.
    const shot = path.join(OUT, 'block_dialog.png');
    execFileSync('bash', ['-c', `adb -s ${SERIAL} exec-out screencap -p > ${shot}`]);
    const pub = findFilledButton(shot, { what: 'BLOCK KEY button', hue: 'red' });
    console.log(`  BLOCK KEY at ${pub.x},${pub.y} (${pub.area} px)`);
    d.E('shell', 'input', 'tap', String(pub.x), String(pub.y));
    marks.taps.push({ t: at(), x: pub.x, y: pub.y, what: 'block_key' });
    mark('tap_block_key');
    // Publishing is a signature and a network round trip. Poll for the screen to
    // stop being the dialog rather than sleeping a guess at it.
    let published = false;
    for (let i = 0; i < 20 && !published; i++) {
      await sleep(1000);
      published = screenHash() !== appScreen;
    }
    await sleep(1500);
    mark('block_published');
    await sleep(2600);

    // --- back to the browser, which has not been refreshed ------------------
    const beforeSwitch = screenHash();
    d.E('shell', 'am', 'start', '-n',
        'com.android.chrome/com.google.android.apps.chrome.Main');
    const tSwitch = Date.now();
    while (Date.now() - tSwitch < 20000 && screenHash() === beforeSwitch) { /* spin */ }
    mark('back_to_browser');
    await d.waitForApp('com.android.chrome');
    await sleep(2200);
    // CLOSE THE SHEET FIRST. Chrome comes back exactly as it was left, which is
    // with Eyal's NodeDetail still open over the path view -- and the header the
    // assert below looks for is behind it, so asserting first reads as "the page
    // reloaded" when nothing of the kind happened.
    await tapNode(/^Close$/, 'close_details');
    await sleep(1600);
    // Still the same page, still loaded? If Android evicted Chrome while the
    // identity app was in front it came back reloaded, and the whole point of
    // the second half is gone -- better to know than to film it.
    await assertVisible(page, /Follow network: \d+ degree/);
    // Back out of the path view to the feed, where his comment is.
    await tapNode(/^Back$/, 'back_to_feed');
    await sleep(2200);
    await assertVisible(page, /Read Write Own/);
    mark('feed_again');
    await sleep(1600);

    // He is STILL offered as a point of view, because this page is showing the
    // world as it was before the block existed.
    const still = await povHas();
    if (!still) throw new Error(
      'Eyal is already gone from the point-of-view list, before any refresh.\n'
      + '  That means the page reloaded between the block and here, and the shot\n'
      + '  this section is built on -- the same page changing under a refresh --\n'
      + '  cannot be filmed from this take.');
    marks.povListBox = boxOf(still);
    mark('pov_before');
    await sleep(3200);
    await povClose();
    await sleep(1200);

    const refreshNode = await findStill(page, /^Refresh$/);
    marks.refreshBox = boxOf(refreshNode);
    mark('before_refresh');
    await sleep(2200);

    await tapNode(/^Refresh$/, 'refresh');
    await page.waitForTimeout(7000);
    mark('refreshed');
    await sleep(1200);

    // ...and now he is not. Nothing was deleted; a claim was withdrawn.
    const gone = await povHas();
    if (gone) console.error(
      '  WARNING: Eyal is STILL in the point-of-view list after the refresh.\n'
      + '  The take is recorded, but its payoff is not on it -- check whether the\n'
      + '  block actually published before cutting this.');
    const povNode = await find(page, /^Point of View/);
    if (povNode) marks.povGoneBox = boxOf(povNode);
    await povClose();
    await sleep(2400);
    mark('done');
  } finally {
    await pullTake();
    if (browser) { try { await browser.close(); } catch { /* nothing to close */ } }
  }

  console.log(`\n${path.relative(__dirname, path.join(OUT, 'oneofus_block.mp4'))}\n` +
    `${path.relative(__dirname, path.join(OUT, 'oneofus_block.marks.json'))}  ` +
    `(${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
