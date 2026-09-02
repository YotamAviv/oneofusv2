#!/usr/bin/env node
// Shoot the Nerdster feed basics: filter to books, sort by comments, swipe one
// card away to snooze, swipe the next away for good, then react to a third --
// like it and leave a comment. One continuous take, on the emulator, against
// production, signed in with the delegate key shoot.sh created.
//
//   adb forward tcp:9222 localabstract:chrome_devtools_remote
//   node shoot_nerdster.js
//
// Writes out/nerdster/<stamp>/nerdster.mp4 + .marks.json, the same contract shoot.sh's
// take uses, so overlay_taps.js draws the indicators the same way.
//
// THIS TAKE PUBLISHES. Three statements land under the delegate key on
// nerdster.org: the snooze, the dismiss, and the rating. shoot_nerdster.sh
// clears them first so a reshoot starts from the same feed -- it touches
// nerdster.org only, leaving the one-of-us.net vouch and delegate alone, so
// sign-in doesn't have to be reshot to reshoot this.
//
// Everything here is driven off the accessibility tree (lib/semantics.js): the
// controls are found by what they say, and the take asserts before it acts. The
// exceptions are the three unlabelled controls in the rate dialog, whose
// positions are DERIVED from labelled neighbours rather than hardcoded -- see
// thumbsUp() and commentField().

const fs = require('fs');
const path = require('path');
const { execFileSync, spawn } = require('child_process');
const { chromium } = require('playwright');
const {
  SEMANTICS_PROBE, sleep, enableSemantics, find, findAll, findStill, waitFor,
  assertAbsent, tapNamed, tapAt, drag, typeText, attachToAvdChrome,
} = require('./lib/semantics');
const { delegatesOf } = require('./truncate_statements');

const SERIAL = process.env.AVD || 'emulator-5554';
const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('nerdster');
// Which book ends up on top depends on the feed, so the copy stays about
// reading rather than about a particular book. COMMENT= overrides it.
const COMMENT = process.env.COMMENT || 'Read it twice. #recommended';
const E = (...a) => execFileSync('adb', ['-s', SERIAL, ...a], { stdio: 'ignore' });
const Eout = (...a) => execFileSync('adb', ['-s', SERIAL, ...a]).toString();

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

async function forwardDevtools(port = 9222) {
  try { E('forward', '--remove-all'); } catch { /* nothing forwarded yet */ }
  E('forward', `tcp:${port}`, 'localabstract:chrome_devtools_remote');
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://localhost:${port}/json/version`);
      if (r.ok) return;
    } catch { /* not up yet */ }
    await sleep(500);
  }
  throw new Error('Chrome devtools never came up on localhost:' + port);
}

// Browser coordinates are CSS viewport pixels; the recording is device pixels.
// Convert, so the marks file is one coordinate space and overlay_taps.js can use
// it directly.
let VIEW2DEV = null;
async function calibrate(page) {
  const vp = await page.evaluate(() => ({ w: innerWidth, h: innerHeight }));
  const size = Eout('shell', 'wm', 'size').match(/(\d+)x(\d+)/);
  const dw = +size[1], dh = +size[2];
  const scale = dw / vp.w;
  VIEW2DEV = { scale, offY: Math.round(dh - vp.h * scale - 67) };  // 67 = gesture bar
  return VIEW2DEV;
}
const toDevice = (x, y) => ({
  x: Math.round(x * VIEW2DEV.scale),
  y: Math.round(y * VIEW2DEV.scale + VIEW2DEV.offY),
});

/// The feed's cards, top to bottom.
///
/// A card has no label of its own, but every one carries a "Mark to
/// Relate/Equate" button in the top right of its image. That button is the
/// handle: it identifies a card and locates its image, which is the part that
/// swipes.
async function cards(page) {
  const marks = await findAll(page, /^Mark to Relate\/Equate$/, { role: 'button' });
  return marks.sort((a, b) => a.y - b.y);
}

/// The top card: where to swipe it, and what it is.
///
/// The title is what makes the swipe checkable -- "did a card go away" is not a
/// usable condition, because the feed lazily renders and the count moves on its
/// own. "Did THIS book go away" is.
///
/// The swipe point is inside the card's image, which is the Dismissible; the
/// rest of the card is not, and a swipe starting below it scrolls the feed
/// instead -- recording a take in which nothing happens.
async function topCard(page) {
  const all = await cards(page);
  if (!all.length) throw new Error('no cards in the feed');
  const [top, next] = all;
  const limit = next ? next.y : Infinity;
  // The title is the widest plain button between this card's handle and the next
  // card's. Everything else down there is a control, a moniker or a tag.
  const titles = (await findAll(page, /./, { role: 'button' }))
    .filter(n => n.y > top.y && n.y < limit && n.w > 80 &&
                 !/^(React|Show more|Mark to Relate\/Equate)$/.test(n.text) &&
                 !n.text.includes('@') && !n.text.startsWith('#'))
    .sort((a, b) => b.w - a.w);
  const vw = await page.evaluate(() => innerWidth);
  return {
    title: titles[0]?.text ?? '(untitled)',
    y: Math.round(top.y + 90),
    vw,
  };
}

/// The top card, once the feed has stopped rearranging under it.
///
/// A publish triggers a full reload, so for a second or two afterwards the top
/// card is whatever happens to be drawn. Acting on that reads as the take
/// working -- the assertions pass, the swipe goes somewhere -- and publishes
/// nothing.
async function settledTopCard(page, quiet = 3) {
  let last = null, same = 0;
  for (let i = 0; i < 100; i++) {
    const card = await topCard(page).catch(() => null);
    if (card && card.title === last?.title) {
      if (++same >= quiet) return card;
    } else {
      same = 0;
      last = card;
    }
    await sleep(300);
  }
  throw new Error('the feed never settled');
}

/// The rate dialog's thumbs-up. The two thumb buttons are unlabelled, but the
/// pair sits inside a node that says "Like or dislike": like is its left half.
async function thumbsUp(page) {
  const n = await findStill(page, /^Like or dislike$/);
  return { x: n.x - n.w / 4, y: n.y };
}

/// The rate dialog's comment field, which is likewise unlabelled -- it is the
/// space between the thumbs row and the buttons at the bottom.
async function commentField(page) {
  const like = await findStill(page, /^Like or dislike$/);
  const publish = await findStill(page, /^Publish$/, { role: 'button' });
  return { x: like.x, y: Math.round((like.y + publish.y) / 2) };
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const marks = { taps: [], swipes: [] };
  const t0 = Date.now();
  let recT0 = null;
  const at = () => +((Date.now() - (recT0 ?? t0)) / 1000).toFixed(2);
  const mark = k => { marks[k] = at(); console.log(`  ${k} @${marks[k]}s`); };
  const tapped = (what, n) => {
    marks.taps.push({ t: at(), ...toDevice(n.x, n.y), what });
    mark(`tap_${what}`);
  };

  // --- stage: land on the feed before recording starts ---
  E('shell', 'am', 'force-stop', 'com.android.chrome');
  E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'https://nerdster.org/app',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await waitForApp('com.android.chrome');

  // Re-forward AFTER the restart. Chrome's devtools socket is new, and a forward
  // set up against the old one still looks fine but hangs up when connected to.
  await forwardDevtools();

  let { browser, page, cdp } = await attachToAvdChrome(chromium);
  for (let i = 0; i < 80; i++) {
    const ready = await page.evaluate(
      () => !!document.querySelector('flt-semantics-placeholder')).catch(() => false);
    if (ready) break;
    await sleep(250);
  }
  await page.evaluate(SEMANTICS_PROBE);
  await enableSemantics(page, cdp);
  await calibrate(page);
  marks.viewportToDevice = VIEW2DEV;
  console.log('attached:', page.url());

  // The take is worthless if the delegate is gone -- every action below would
  // hit the sign-in dialog instead of publishing.
  await waitFor(page, /Signed in with Identity and Delegate/, {}, 45000);
  console.log('  verified: signed in');

  await waitFor(page, /^Mark to Relate\/Equate$/, { role: 'button' }, 60000);

  /// Pick from one of the two popup menus above the feed, and wait for the feed
  /// to come back. Used by the take and, before it, to warm the same path.
  /// `log` names the pair of taps in the marks file. Timestamps are taken at the
  /// tap, not after the wait that follows it, or the indicators land late.
  async function choose(menu, item, log = null) {
    const m = await waitFor(page, new RegExp(`^${menu}: `), { role: 'button' });
    await tapAt(cdp, m.x, m.y);
    if (log) tapped(`${log}_menu`, m);
    const n = await tapNamed(page, cdp, new RegExp(`^${item}$`), { role: 'menuitem' });
    if (log) tapped(`${log}_${item}`, n);
    await waitFor(page, new RegExp(`^${menu}: ${item}$`), { role: 'button' });
    await waitFor(page, /^Mark to Relate\/Equate$/, { role: 'button' }, 60000);
  }

  // WARM THE FEED, then put it back. Changing a filter and publishing a swipe
  // both end in the same full reload, and on a cold page that reload can take
  // most of a minute -- long enough that the swiped card sits there unchanged
  // and the take fails on its own assertion. Running the cycle here, before the
  // recording starts, costs staging time nobody sees.
  await choose('Type', 'book');
  await choose('Sort', 'Comments');
  await choose('Type', 'All');
  await choose('Sort', 'Recent');
  console.log('  feed loaded and warm, filters clear');

  // --- record ---
  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '120', '--bit-rate', '8000000', '/sdcard/nerdster.mp4']);

  // SYNC FLASH -- see shoot_signin.js. screenrecord keeps capturing for seconds
  // after the process spawns, so the clock is zeroed on a white frame that
  // find_flash.js can locate in the footage instead.
  await sleep(4000);
  await page.evaluate(() => {
    const f = document.createElement('div');
    f.id = '__syncflash';
    f.style.cssText = 'position:fixed;inset:0;background:#fff;z-index:2147483647;pointer-events:none';
    document.body.appendChild(f);
  });
  recT0 = Date.now();
  await sleep(400);
  await page.evaluate(() => document.getElementById('__syncflash')?.remove());
  marks.syncFlash = { heldMs: 400 };
  await sleep(900);

  // --- filter to books ---
  await choose('Type', 'book', 'type');
  mark('books_only');
  await sleep(700);

  // --- order by comments ---
  await choose('Sort', 'Comments', 'sort');
  mark('by_comments');
  await sleep(900);

  /// Swipe the top card away and prove it went. Right is snooze, left is
  /// forever; both publish, and "Hide dismissed" being on by default is what
  /// makes the card leave -- so the disappearance is the write landing, not an
  /// animation.
  ///
  /// The stroke crosses most of the width and is released in motion. A short
  /// stroke, or one paused before release, publishes nothing: Flutter needs the
  /// drag past its threshold, and on video a card that springs back is
  /// indistinguishable from a tap that missed.
  async function swipeTopCard(what, dir) {
    const card = await settledTopCard(page);
    const from = { x: Math.round(card.vw * (dir > 0 ? 0.15 : 0.85)), y: card.y };
    // Timestamped before the drag, not after: the stroke takes about half a
    // second, and an indicator that starts when it ENDS chases the card off
    // screen instead of pushing it.
    const t = at();
    const d = await drag(cdp, from.x, from.y, dir * Math.round(card.vw * 0.6), { holdMs: 0 });
    marks.swipes.push({ t, what,
                        from: toDevice(d.from.x, d.from.y), to: toDevice(d.to.x, d.to.y), ms: d.ms });
    mark(`swipe_${what}`);
    // Watch the TOP OF THE FEED, not the whole page: a title also appears inside
    // other cards as a related-subject link, so "is that text still anywhere"
    // stays true long after the card itself has gone.
    const t0 = Date.now();
    const budget = +(process.env.SWIPE_TIMEOUT_MS || 30000);
    while (Date.now() - t0 < budget) {
      const now = await topCard(page).catch(() => null);
      if (now && now.title !== card.title) {
        console.log(`  ${what}d "${card.title}" (gone in ${((Date.now() - t0) / 1000).toFixed(1)}s)`);
        return card;
      }
      await sleep(300);
    }
    throw new Error(`${what}: "${card.title}" is still the top card — the swipe was ` +
      'probably read as a scroll, or the write failed');
  }

  // --- swipe right: snooze, then swipe left: dismiss for good ---
  await swipeTopCard('snooze', 1);
  await swipeTopCard('dismiss', -1);

  // --- react: like and comment ---
  await settledTopCard(page);
  const [top] = await cards(page);
  const react = (await findAll(page, /^React$/, { role: 'button' }))
    .filter(n => n.y > top.y - 40).sort((a, b) => a.y - b.y)[0];
  if (!react) throw new Error('no React button on the top card');
  await tapAt(cdp, react.x, react.y);
  tapped('react', react);
  await waitFor(page, /^Rate & Comment$/, {}, 15000);
  // Each card carries a React of its own plus one per statement on it. Landing
  // on the wrong one opens the same dialog aimed at somebody's reaction rather
  // than the book, and the take would look right and mean nothing.
  await assertAbsent(page, /Reacting to a reaction/);

  const up = await thumbsUp(page);
  await tapAt(cdp, up.x, up.y);
  tapped('like', up);
  await sleep(500);

  const field = await commentField(page);
  await tapAt(cdp, field.x, field.y);
  tapped('comment_field', field);
  await sleep(400);
  await typeText(cdp, COMMENT);
  // Prove the text landed. Typing into nothing is silent: the take runs to the
  // end and publishes a rating with no comment on it.
  const typed = await page.evaluate(() => document.querySelector('textarea')?.value ?? '');
  if (typed !== COMMENT) {
    throw new Error(`the comment did not reach the field: got ${JSON.stringify(typed)}`);
  }
  mark('typed');
  await sleep(600);

  tapped('publish', await tapNamed(page, cdp, /^Publish$/, { role: 'button' }));
  await assertGone(page, /^Rate & Comment$/, 20000);
  mark('published');

  // End on the feed with the reaction on it, not on a dialog closing.
  await sleep(2200);
  mark('done');

  // The screen is not the record; the statements are. Every failure so far has
  // been a take that looked right and published something else -- a rating with
  // no thumbs-up on it, a swipe read as a scroll -- so check what actually
  // landed before calling this a take.
  await verifyPublished();

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/nerdster.mp4');
  rec.kill();
  await browser.close();

  // The stamp is on the build directory (lib/build_dir.js), so the take
  // inside it is named for what it is and nothing else.
  const name = 'nerdster';
  E('pull', '/sdcard/nerdster.mp4', path.join(OUT, `${name}.mp4`));
  // Off the device once it is safely here. Every take used to leave its
  // recording behind, and they were quietly filling /data -- enough that an
  // apk install eventually failed for want of space.
  E('shell', 'rm', '-f', '/sdcard/nerdster.mp4');
  fs.writeFileSync(path.join(OUT, `${name}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${name}.mp4`))}\n${path.relative(__dirname, path.join(OUT, `${name}.marks.json`))}  ` +
              `(${marks.taps.length} taps, ${marks.swipes.length} swipes)`);
})().catch(e => {
  console.error('\nTAKE FAILED:', e.message);
  process.exit(1);
});

/// The three statements this take exists to produce, read back from
/// nerdster.org: a snooze, a dismissal, and a rating that is both a like and a
/// comment. Anything else means the video shows something that did not happen.
async function verifyPublished() {
  const identity = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'demo_identity.json'), 'utf8'));
  const [id] = Object.values(identity.demoTokens);
  const [delegate] = await delegatesOf(id, 'nerdster.org');
  if (!delegate) throw new Error('the demo identity has no nerdster.org delegate');

  for (let i = 0; i < 20; i++) {                 // the write is a round trip
    const res = await fetch(
      `https://export.nerdster.org/?spec=${delegate}&includeId=true`);
    const stmts = (await res.json())[delegate] || [];
    const dis = v => stmts.some(s => s.statement === 'org.nerdster.dis' && s.with?.dismiss === v);
    const rating = stmts.find(s => s.statement === 'org.nerdster' && s.comment);
    const missing = [
      !dis('snooze') && 'the snooze',
      !dis('forever') && 'the dismissal',
      !rating && 'the comment',
      rating && rating.with?.recommend !== true && 'the like (the thumbs-up tap missed)',
    ].filter(Boolean);
    if (!missing.length) {
      console.log(`  published: snooze, dismiss, and "${rating.comment}" on ` +
                  `"${rating.rate.title ?? rating.rate}"`);
      return;
    }
    if (i === 19) {
      throw new Error(`the take is missing ${missing.join(' and ')} — ` +
        `${stmts.length} statement(s) under ${delegate.slice(0, 12)}`);
    }
    await sleep(1500);
  }
}

async function assertGone(page, re, timeout) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (!await find(page, re)) return;
    await sleep(300);
  }
  throw new Error(`ASSERT FAILED: ${re} is still on screen`);
}
