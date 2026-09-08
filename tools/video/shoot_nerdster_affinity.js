#!/usr/bin/env node
// Shoot "Follow contexts" -- blocking somebody's opinions without saying
// anything about whether they are a person.
//
//   node shoot_nerdster_affinity.js
//
// Writes out/nerdster_affinity/<stamp>/nerdster_affinity.mp4 + .marks.json.
//
// THE BRIEF IS doc/video/affinity_vs_identity.md, and the storyboard is
// video/nerdster_affinity_alt.yaml. This is the answer to shoot_oneofus_block.js
// and opens on the same feed on purpose.
//
// DESTRUCTIVE, UNDOABLE. Two follow statements on nerdster.org, signed by the
// DELEGATE key -- a <nerdster> block of Tom and a <nerdster> follow of Eyal.
// Append-only hash chains, so `sections.py --restore crypto_teaser` rewinds
// them, and that is also how to get back to the state this take needs.
//
// RUN THE RESTORE FIRST, EVERY TIME. This section is alone in its file, so
// sections.py has no previous section to continue from and restores nothing by
// itself. A take that starts from the last take's leftovers opens on a feed with
// Tom already missing, which is the shot it is supposed to be building to.
//
// NO IDENTITY KEY IS INVOLVED and the phone is never opened. That is the whole
// difference from the identity block: a follow is a CONTENT statement, made by
// the delegate key the Nerdster already holds, so the Nerdster can sign it
// itself.
//
// THE ONE CONTROL WITH NO SEMANTICS NODE is the "Add context" field, so it is
// tapped by device coordinates and then TYPED into rather than picked from its
// suggestion list -- see setContext, which explains why picking does not work.
// Nothing here needed the Nerdster instrumented.

const fs = require('fs');
const path = require('path');
const { spawn, execFileSync } = require('child_process');
const { chromium } = require('playwright');
const { device, sleep } = require('./lib/device');
const {
  SEMANTICS_PROBE, enableSemantics, find, findStill, waitFor, tapNamed,
  assertVisible, attachToAvdChrome,
} = require('./lib/semantics');
const { buildDir } = require('./lib/build_dir');

const SERIAL = process.env.AVD || 'emulator-5554';
const OUT = buildDir('nerdster_affinity');
const d = device();
const TOM = /Tom@nerdster\.org/;
const EYAL = /Eyal F/;

// The Add context field, in DEVICE pixels: it has no semantics node, so it
// cannot be tapped by name. Measured off the expanded editor on a 1080x2220
// screen. Tapping it opens the suggestion list, which is reachable.
const CONTEXT_FIELD = [540, 1356];
// The follow context this section is about, exactly as follow_logic.dart spells
// it. Anything else silently makes a DIFFERENT context that the feed's own
// <nerdster> setting does not read.
const CONTEXT = '<nerdster>';
const CONTEXT_RE = /^<nerdster>$/;

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

  const tapNode = async (re, what, opts = {}) => {
    const n = await tapNamed(page, cdp, re, opts);
    const c = toDevice(n.x, n.y);
    marks.taps.push({ t: at(), x: c.x, y: c.y, what });
    mark(`tap_${what}`);
    return n;
  };
  const tapDevice = (x, y, what) => {
    d.E('shell', 'input', 'tap', String(x), String(y));
    marks.taps.push({ t: at(), x, y, what });
    mark(`tap_${what}`);
  };

  // SHOW MORE TAKES A REAL TAP, not a semantics one -- same as
  // shoot_oneofus_block.js, and the same trap: a semantics tap reports success
  // and leaves the card collapsed, so the tree reads as a feed with nobody in it.
  const showMore = async () => {
    // Nothing to expand if it is already expanded -- the card keeps its state
    // across a context switch, and a second tap would COLLAPSE it.
    if (!await find(page, /^Show more$/)) return;
    const n = await findStill(page, /^Show more$/);
    const c = toDevice(n.x, n.y);
    tapDevice(c.x, c.y, 'show_more');
    await sleep(1600);
  };

  // Filter the feed to the tag that brings the book up directly.
  //
  // IDEMPOTENT, because the take comes back here after switching contexts and the
  // filter survives that. Once a tag is on, the control is labelled with the TAG
  // -- "tech", not "Tags" -- so a second run does not find the button it is
  // looking for, and tapping "tech" in the toolbar would turn the filter off
  // rather than on. If the book is already on screen there is nothing to do.
  // WHETHER THE TAG IS ON, tracked rather than inferred. "Is the book on screen"
  // is not the same question: unfiltered, the book is often on screen anyway, so
  // inferring skipped the filtering step and then expanded the comments of some
  // other card. And the chip cannot be read either -- it is labelled with the TAG
  // once one is on ("tech", not "Tags"), and tapping the tag in the menu when it
  // is already on turns it OFF.
  let filtered = false;
  const filterToTech = async () => {
    if (filtered) return;
    await tapNode(/^(Tags|tech)$/, 'tags');
    await sleep(1200);
    await tapNode(/^tech$/, 'tech');
    await sleep(2600);
    await assertVisible(page, /Read Write Own/);
    filtered = true;
  };

  // Put the feed into a KNOWN state, whatever the last take left in this browser.
  // Clearing to All and then filtering is two menu trips and worth it: the take
  // opened once on a feed that was already filtered, skipped its own filtering
  // step, and then failed three lines later for an unrelated-looking reason.
  const resetFilter = async () => {
    await tapNode(/^(Tags|tech)$/, 'tag_menu');
    await sleep(1200);
    await tapNode(/^All$/, 'all_tags');
    await sleep(2600);
    filtered = false;
  };

  // Open somebody's NodeDetail. TWO taps: their name in the feed opens the PATH
  // -- how this identity knows them -- and their avatar in that opens the sheet.
  const openDetails = async (nameInFeed, nameInPath, who) => {
    await tapNode(nameInFeed, `${who}_name`);
    await sleep(2000);
    mark(`path_${who}`);
    await sleep(2000);
    await tapNode(nameInPath, `${who}_node`);
    await sleep(1800);
    await assertVisible(page, /How I follow\/block/);
  };

  // Set a follow context on whoever's sheet is open, and publish it.
  //
  // The editor may open collapsed or expanded depending on what came before, and
  // the header is a toggle -- tapping it when it is already open closes it, which
  // then reads as "the field is not there". Look for the row that only exists
  // when it is open, and only tap the header if it is missing.
  // `who` also prefixes the marks. BOTH people go through here, and with one set
  // of mark names the second call silently overwrote the first: the beat about
  // publishing Tom's block ended up anchored on the moment Eyal's follow
  // published, forty seconds later, and showed for no time at all.
  const setContext = async (verb, who, marksAs) => {
    if (!await find(page, /Not following in any context|^<nerdster>$/)) {
      await tapNode(/^How I follow\/block/, `${who}_expand`);
      await sleep(1400);
    }
    tapDevice(CONTEXT_FIELD[0], CONTEXT_FIELD[1], `${who}_context_field`);
    await sleep(1600);

    // TYPED, NOT PICKED FROM THE LIST, and the two are not equivalent.
    //
    // Tapping the suggestion adds the right key but leaves the field focused, so
    // the autocomplete list REOPENS on top of the row it just created -- and the
    // tap meant for Block lands on the dropdown instead. Publish stays disabled,
    // nothing publishes, and the only symptom is the feed still having Tom in it
    // two steps later.
    //
    // Typing and submitting adds the same key and closes the list, because
    // onSubmitted clears the controller. The key is LITERALLY "<nerdster>",
    // angle brackets and all (kFollowContextNerdster in follow_logic.dart), so:
    // one argument to `adb shell`, with the quotes inside it, or the device's
    // shell reads the brackets as redirection. Escaping them instead types the
    // backslashes -- that take produced a context called "\<nerdster\>". And do
    // not type it bare in lower case: the IME capitalises the first letter, which
    // is how a context called "Nerdster" got made.
    d.E('shell', `input text "${CONTEXT}"`);
    await sleep(1200);
    d.E('shell', 'input', 'keyevent', '66');          // Enter: adds it, closes the list
    await sleep(1800);
    mark(`${marksAs}_context_added`);
    const row = await findStill(page, CONTEXT_RE);
    marks[`${marksAs}ContextRowBox`] = boxOf(row);
    await sleep(1800);

    // Now the segment is not underneath anything, so a semantics tap reaches it.
    await tapNode(new RegExp(`^${verb}$`), `${marksAs}_set_${verb.toLowerCase()}`);
    await sleep(2400);

    await tapNode(/^Publish$/, `${who}_publish`);
    // Publishing is a signature and a round trip, and the feed reloads itself
    // afterwards -- which is the shot. Give it room rather than guessing.
    await sleep(9000);
    mark(`${marksAs}_published`);
  };

  // The context control at the top. Its label is a paragraph of help text, so it
  // is matched on a phrase rather than a value.
  const setFeedContext = async (which, what) => {
    await tapNode(/anyone who is someone/, `context_menu_${what}`);
    await sleep(1200);
    await tapNode(which, what);
    await sleep(4000);
  };

  await d.closeChromeTabs();

  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '180', '--bit-rate', '8000000', '/sdcard/nerdster_affinity.mp4']);
  await sleep(4000);

  let pulled = false;
  const pullTake = async () => {
    if (pulled) return;
    pulled = true;
    try { await d.stopRecording('/sdcard/nerdster_affinity.mp4'); }
    catch (e) { console.error('  (stopRecording failed:', e.message.split('\n')[0], ')'); }
    try { rec.kill(); } catch { /* already gone */ }
    try {
      d.E('pull', '/sdcard/nerdster_affinity.mp4', path.join(OUT, 'nerdster_affinity.mp4'));
      d.E('shell', 'rm', '-f', '/sdcard/nerdster_affinity.mp4');
    } catch (e) { console.error('  (pull failed:', e.message.split('\n')[0], ')'); }
    fs.writeFileSync(path.join(OUT, 'nerdster_affinity.marks.json'),
                     JSON.stringify(marks, null, 2));
    console.log(`  take saved: ${path.relative(__dirname, path.join(OUT, 'nerdster_affinity.mp4'))}`);
  };

  try {
    // Sync flash, black: light app screens throughout.
    d.E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
      '-d', 'data:text/html,%3Cbody%20style%3D%22background%3A%23000%22%3E',
      '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
    await d.waitForApp('com.android.chrome');
    t0 = await d.waitForDark();
    await sleep(600);
    marks.syncFlash = { heldMs: 600, kind: 'dark' };

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
    await waitFor(page, /Follow network: \d+ degree/, {}, 60000);
    await sleep(1200);
    mark('feed');
    await sleep(1400);

    // --- both of them, on one card ----------------------------------------
    await resetFilter();
    await filterToTech();
    await sleep(1600);          // let the filtered feed settle before measuring
    await showMore();
    await sleep(1200);
    await assertVisible(page, TOM);
    await assertVisible(page, EYAL);
    mark('both_visible');
    await sleep(2600);

    // --- ONE TRIP, from Eyal's graph ---------------------------------------
    //
    // His name in the feed opens the PATH -- Me -> Tom -> Eyal -- and in
    // <identity> both of them are nodes on it, so both follow decisions can be
    // made from here without going back to the feed for the second one.
    await tapNode(EYAL, 'eyal_name');
    await sleep(2200);
    mark('path_eyal');
    await sleep(2000);

    // <identity> first: this is the graph of who is a PERSON, which is what the
    // affinity network is about to be built on top of.
    await setFeedContext(/^<identity>$/, 'identity_context');
    mark('identity_context');
    await sleep(3600);

    // Follow Eyal, explicitly, for <nerdster>.
    await tapNode(/^Eyal F$/, 'eyal_node');
    await sleep(1800);
    await assertVisible(page, /How I follow\/block/);
    await setContext('Follow', 'eyal', 'eyal');
    mark('eyal_followed');
    await sleep(3200);
    await tapNode(/^Close$/, 'close_eyal');
    await sleep(2200);

    // And block Tom, for the same context and from the same graph.
    await tapNode(/^Tom$/, 'tom_node');
    await sleep(1800);
    await assertVisible(page, /How I follow\/block/);
    await setContext('Block', 'tom', 'tom');
    mark('tom_blocked');
    await sleep(3200);
    await tapNode(/^Close$/, 'close_tom');
    await sleep(2200);

    // --- and now the same graph, in <nerdster> ------------------------------
    // The redraw IS the argument: Tom gone from the follow network though he is
    // still a person, and Eyal no longer reached through him but followed
    // directly -- one hop. An affinity network built out of an identity one.
    await setFeedContext(/^<nerdster>$/, 'back_to_nerdster');
    mark('graph_nerdster');
    await sleep(4000);
    if (await find(page, /^Tom$/)) console.error(
      '  WARNING: Tom is still on the graph in <nerdster>. The take is recorded,\n'
      + '  but the shot it is built around did not happen -- check the block.');
    await sleep(1200);

    // --- and back to the feed ----------------------------------------------
    await tapNode(/^Back$/, 'back_to_feed');
    await sleep(3600);
    await showMore();
    await sleep(1200);
    await assertVisible(page, EYAL);
    if (await find(page, TOM)) console.error(
      '  WARNING: Tom is back in the feed at the end. The take is recorded, but\n'
      + '  its closing shot says the opposite of what it is meant to.');
    mark('final_feed');
    await sleep(2600);
    mark('done');
  } finally {
    await pullTake();
    if (browser) { try { await browser.close(); } catch { /* nothing to close */ } }
  }

  console.log(`\n${path.relative(__dirname, path.join(OUT, 'nerdster_affinity.mp4'))}\n` +
    `${path.relative(__dirname, path.join(OUT, 'nerdster_affinity.marks.json'))}  ` +
    `(${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });
