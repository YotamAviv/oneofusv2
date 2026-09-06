#!/usr/bin/env node
// Shoot the ALTERNATE HabloTengo section: the same route in, signed in WITH a
// delegate key, and then writing something only a delegate key can write.
//
// The sibling take (shoot_hablotengo.js) signs in with the identity alone and
// ends on being refused. That makes the point that a second, unrelated service
// rides on the same identity network. This one makes the OTHER half of the
// point: the identity gets you recognised, the delegate key gets you a voice.
// Access is still denied on the stranger's card -- that never depended on the
// delegate -- and the take carries on past it to fill in our own, where having
// the key is what puts an Edit button on the screen at all.
//
//   node shoot_hablotengo_delegate.js
//
// Writes out/hablotengo_delegate/<stamp>/hablotengo_delegate.mp4 + .marks.json.
//
// NOT A PROTOTYPE IN THE SAME SENSE AS ITS SIBLING -- it is less proven. The
// sibling calls its HabloTengo half "UNVERIFIED ... written from an outline";
// everything here past the sign-in goes further into that app than any script
// has, into a bottom sheet, an entry editor and a three-segment control that
// carries no labels. Every selector below was read out of the HabloTengo source
// (lib/app.dart, lib/my_contact_screen.dart, lib/visibility_picker.dart and
// packages/nerdster_common/lib/ui/sign_in_dialog.dart) rather than off a device.
// Expect a pass on the emulator; the failure messages are written to say which
// assumption broke.
//
// IT PUBLISHES. Unlike its sibling, which only reads, this take mints a
// hablotengo.com delegate key for the demo identity and saves a contact card
// with a phone number on it. Both are real, signed, and stay published. See
// `side_effects` in video/hablotengo_alt.yaml.

const fs = require('fs');
const path = require('path');
const { execFileSync, spawn } = require('child_process');
const { chromium } = require('playwright');
const {
  SEMANTICS_PROBE, sleep, enableSemantics, findAll, findStill, waitFor,
  tapNamed, tapAt, typeText, attachToAvdChrome,
} = require('./lib/semantics');

const SERIAL = process.env.AVD || 'emulator-5554';
const { buildDir } = require('./lib/build_dir');
const { device } = require('./lib/device');

/// The identity this section is about. Not just anybody: the Nerdster only draws
/// the HabloTengo link on a node that HAS a hablotengo.com delegate key, and
/// Hillel is the one who does.
const SUBJECT = /^Hillel/;
/// What gets typed into the new entry. A number nobody can call.
const PHONE = process.env.PHONE || '555-0142';

const d = device();
const OUT = buildDir('hablotengo_delegate');
const E = (...a) => execFileSync('adb', ['-s', SERIAL, ...a], { stdio: 'ignore' });
const Eout = (...a) => execFileSync('adb', ['-s', SERIAL, ...a]).toString();

// APP-BLIND: a coordinate in the identity app, on a 1080x2220 screen. Shared
// with shoot_signin.js, which has used it for weeks. Its neighbour one button
// down -- "No, just identity" at [733, 1400] -- is what the sibling take presses
// instead, and the two must be re-measured together if that dialog is restyled.
const APP = { yesCreateDelegate: [693, 1532] };

function foregroundApp() {
  const m = Eout('shell', 'dumpsys', 'activity', 'activities')
    .match(/topResumedActivity=ActivityRecord\{\S+ \S+ (\S+?)\//);
  return m ? m[1] : '';
}
async function waitForApp(pkg, timeout = 20000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (foregroundApp() === pkg) return true;
    await sleep(250);
  }
  throw new Error(`timeout waiting for ${pkg}`);
}

async function forwardDevtools(port = 9222) {
  try { E('forward', '--remove-all'); } catch { /* none yet */ }
  E('forward', `tcp:${port}`, 'localabstract:chrome_devtools_remote');
  for (let i = 0; i < 40; i++) {
    try { if ((await fetch(`http://localhost:${port}/json/version`)).ok) return; } catch {}
    await sleep(500);
  }
  throw new Error('Chrome devtools never came up');
}

let VIEW2DEV = null;
async function calibrate(page) {
  const vp = await page.evaluate(() => ({ w: innerWidth, h: innerHeight }));
  const size = Eout('shell', 'wm', 'size').match(/(\d+)x(\d+)/);
  const scale = +size[1] / vp.w;
  VIEW2DEV = { scale, offY: Math.round(+size[2] - vp.h * scale - 67) };
}
const toDevice = (x, y) => ({
  x: Math.round(x * VIEW2DEV.scale),
  y: Math.round(y * VIEW2DEV.scale + VIEW2DEV.offY),
});
/// A semantics node's rectangle in device pixels, for beats to point at.
const boxOf = n => ({
  x: Math.round(n.x * VIEW2DEV.scale), y: Math.round(n.y * VIEW2DEV.scale + VIEW2DEV.offY),
  w: Math.round(n.w * VIEW2DEV.scale), h: Math.round(n.h * VIEW2DEV.scale),
});

/// Wait for a modal dialog in the NATIVE app to appear (`up`) or go away.
///
/// Blind, which is all the native app allows: a dialog dims everything behind
/// it, so the strip along the bottom reads flat grey (~109) with one up and
/// near-white (~237) without. Copied from shoot_hablotengo.js; the wording of
/// the failure is the only thing that differs, because the choice differs.
async function waitForDialog(up, timeout) {
  const shot = path.join(OUT, '_scrim.png');
  const dark = () => {
    execFileSync('bash', ['-c', `adb -s ${SERIAL} exec-out screencap -p > ${shot}`]);
    const raw = execFileSync('ffmpeg', ['-v', 'error', '-i', shot,
      '-vf', 'crop=1000:120:40:2060,scale=1:1', '-pix_fmt', 'rgb24',
      '-f', 'rawvideo', '-'], { maxBuffer: 1 << 20 });
    return raw[0] < 180;
  };
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    if (dark() === up) { fs.rmSync(shot, { force: true }); return true; }
    await sleep(600);
  }
  fs.rmSync(shot, { force: true });
  throw new Error(up
    ? 'the "Create Delegate Key?" dialog never appeared in the identity app'
    : 'the "Create Delegate Key?" dialog did not go away -- "Yes, create delegate" '
      + 'was not registered, so HabloTengo is still waiting for an answer');
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const marks = { taps: [] };
  const t0 = Date.now();
  let recT0 = null;
  const at = () => +((Date.now() - (recT0 ?? t0)) / 1000).toFixed(2);
  const mark = k => { marks[k] = at(); console.log(`  ${k} @${marks[k]}s`); };
  const tapped = (what, n) => { marks.taps.push({ t: at(), ...toDevice(n.x, n.y), what }); mark(`tap_${what}`); };

  // --- stage ---
  E('shell', 'am', 'force-stop', 'com.android.chrome');
  E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'https://nerdster.org/app',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await waitForApp('com.android.chrome');
  await forwardDevtools();

  let { browser, page, cdp } = await attachToAvdChrome(chromium);

  // --- reset: HabloTengo must start SIGNED OUT ---
  //
  // Through the storage service, not removeItem: Chrome flushes localStorage
  // lazily and this take force-stops it, so unflushed deletes are lost.
  //
  // AND THE SERVICE WORKER, not just localStorage. A Flutter web build installs
  // one and it serves the app from cache, so Chrome happily runs the previous
  // deploy for as long as that worker lives. After instrumenting HabloTengo and
  // deploying it, this take looked for the controls it had just named and found
  // the old anonymous ones -- the deploy was live and the emulator had never
  // fetched it. Clearing the worker and its caches makes each take fetch what is
  // actually deployed.
  await cdp.send('Storage.clearDataForOrigin', {
    origin: 'https://hablotengo.com',
    storageTypes: 'local_storage,service_workers,cache_storage',
  });
  // AND THE HTTP CACHE, which is the one that actually pins the code. Hosting
  // serves **/*.js as `max-age=31536000, immutable` (hablotengo firebase.json)
  // and main.dart.js has no content hash in its name, so a browser that has ever
  // loaded the app keeps that exact file for a year and does not revalidate.
  // Clearing localStorage, the service worker and its caches does NOT touch it:
  // after deploying an instrumented HabloTengo, this take kept driving the
  // previous build with the deploy verifiably live.
  await cdp.send('Network.enable');
  await cdp.send('Network.clearBrowserCache');
  console.log('  cleared hablotengo.com storage, service worker, and the HTTP cache');
  const ctx = browser.contexts()[0];

  for (let i = 0; i < 80; i++) {
    if (await page.evaluate(() => !!document.querySelector('flt-semantics-placeholder')).catch(() => false)) break;
    await sleep(250);
  }
  await page.evaluate(SEMANTICS_PROBE);
  await enableSemantics(page, cdp);
  await calibrate(page);
  marks.viewportToDevice = VIEW2DEV;
  await waitFor(page, /^Mark to Relate\/Equate$/, { role: 'button' }, 60000);

  await d.closeChromeTabs();
  // FORCE-STOP FIRST, so the warm-up is also a REFETCH.
  //
  // warmUp only launches an app that is not running, so an app already up keeps
  // whatever it last fetched. This take's precondition -- no hablotengo.com
  // delegate statement in production -- is about what the app BELIEVES, and the
  // teardown that satisfies it deletes from production behind the app's back. An
  // app left running across that still believes the statement is there and
  // offers "Existing Delegate Found / ROTATE KEY" instead of creating a key,
  // which is not a failure and films the wrong thing. Cold start, every take.
  E('shell', 'am', 'force-stop', 'net.oneofus.app');
  // Warm the identity app BEFORE the camera: a cold start reloads everything the
  // identity has published and takes about nine seconds. Paid here it costs
  // nothing; paid on camera it is dead air, and it is what made the sibling take
  // tap a dialog that had not been drawn yet.
  await d.warmUp('net.oneofus.app');

  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '240', '--bit-rate', '8000000', '/sdcard/hablotengo_delegate.mp4']);
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

  mark('feed');
  await sleep(1600);

  // --- narrow the feed to him, instead of scrolling to him ---
  // POV FIRST -- filtering by context from "Me" does not surface him.
  tapped('pov', await tapNamed(page, cdp, /^Point of View/, { role: 'button' }));
  await sleep(1200);
  tapped('pov_tom', await tapNamed(page, cdp, /^Tom$/, { role: 'menuitem' }));
  await sleep(2200);
  mark('pov_set');

  tapped('context', await tapNamed(page, cdp, /Other follow contexts/, { role: 'button' }));
  await sleep(1200);
  tapped('context_family', await tapNamed(page, cdp, /^family$/, { role: 'menuitem' }));
  await sleep(2200);
  tapped('tags', await tapNamed(page, cdp, /^Tags$/, { role: 'button' }));
  await sleep(1400);
  tapped('tag_ai', await tapNamed(page, cdp, /^ai$/, { role: 'button' }));
  await sleep(2400);
  E('shell', 'input', 'keyevent', '4');
  await sleep(1000);
  mark('filtered');
  await sleep(1200);

  const who = (await findAll(page, /@nerdster\.org$/, { role: 'button' }))
    .map(n => n.text).find(t => SUBJECT.test(t));
  if (!who) {
    throw new Error(`nobody matching ${SUBJECT} in the feed under PoV Tom, `
      + 'context family, tag ai. Those filters are what this take uses instead '
      + 'of scrolling, and without a hablotengo.com delegate key the Nerdster '
      + 'draws no HabloTengo link at all.');
  }
  const name = who.split('@')[0];
  marks.subject = who;
  console.log(`  following ${who}`);

  tapped('moniker', await tapNamed(page, cdp, new RegExp(`^${esc(who)}$`), { role: 'button' }));
  await waitFor(page, new RegExp(`^${esc(name)}$`), { role: 'button' }, 20000);
  mark('graph');
  await sleep(2400);

  tapped('node', await tapNamed(page, cdp, new RegExp(`^${esc(name)}$`), { role: 'button' }));
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  mark('node_details');
  await sleep(3800);

  // --- out to that other service ---
  const hablo = await findStill(page, /^HabloTengo$/, {});
  marks.habloButtonBox = boxOf(hablo);
  mark('hablotengo_link_shown');
  await sleep(2800);

  await tapAt(cdp, hablo.x, hablo.y);
  tapped('hablotengo', hablo);

  // node_details.dart opens hablotengo.com/app?target=<identity> with
  // LaunchMode.externalApplication, so it arrives as a NEW TAB.
  let hab = null;
  for (let i = 0; i < 80 && !hab; i++) {
    hab = ctx.pages().find(p => /hablotengo/.test(p.url()));
    await sleep(250);
  }
  if (!hab) throw new Error('the HabloTengo link did not open a tab');
  await hab.waitForLoadState('domcontentloaded').catch(() => {});
  const hcdp = await ctx.newCDPSession(hab);
  for (let i = 0; i < 80; i++) {
    if (await hab.evaluate(() => !!document.querySelector('flt-semantics-placeholder'))
        .catch(() => false)) break;
    await sleep(250);
  }
  await hab.evaluate(SEMANTICS_PROBE);
  await enableSemantics(hab, hcdp);
  mark('hablotengo_open');
  await sleep(3600);

  // --- sign in, WITH a delegate key ---
  const signin = await waitFor(hab, /Link to your ONE-OF-US\.NET app/, { role: 'button' }, 30000);
  await tapAt(hcdp, signin.x, signin.y);
  tapped('hablo_signin', signin);
  mark('signin_open');

  await waitForApp('net.oneofus.app', 25000);
  // WAIT FOR THE DIALOG, not for the app. waitForApp returns when the app is
  // FOREGROUND, which is not when the dialog is drawn -- a cold start takes about
  // eight seconds to get there, and a tap that lands on the splash screen makes
  // no choice at all. Not waitForStillScreen either: the scanner behind this
  // dialog is a live camera preview, so the screen never settles.
  await waitForDialog(true, 30000);
  mark('identity_app');
  await sleep(1800);                       // long enough to read the choice

  // "Yes, create delegate" -- THE WHOLE POINT OF THIS ALTERNATE.
  //
  // The sibling take presses "No, just identity" one button below, and ends on
  // being refused. This one takes the key, which is what later puts an Edit
  // button on our own card (my_contact_screen.dart draws it only
  // `if (signInState.hasDelegate)`).
  E('shell', 'input', 'tap', String(APP.yesCreateDelegate[0]), String(APP.yesCreateDelegate[1]));
  marks.taps.push({ t: at(), x: APP.yesCreateDelegate[0], y: APP.yesCreateDelegate[1], what: 'yes_create' });
  mark('tap_yes_create');
  // AND CHECK THE CHOICE REGISTERED. If the dialog is still up the tap missed,
  // and everything after this is a take of nothing.
  await waitForDialog(false, 15000);
  await sleep(1400);

  // Back to the browser explicitly, not with BACK: BACK moves around inside the
  // identity app, which "Yes, create delegate" has returned to its own screen.
  E('shell', 'am', 'start', '-a', 'android.intent.action.MAIN',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await waitForApp('com.android.chrome', 25000);
  mark('back_to_browser');

  // --- refused, and the sign-in dialog behind it ---
  //
  // ORDER MATTERS, AND IT IS NOT THE ORDER YOU WOULD GUESS. HabloTengo was
  // opened with ?target=<identity>, so on sign-in it slides that contact up as a
  // modal bottom sheet -- ON TOP of the sign-in dialog, which app.dart leaves
  // open on purpose ("No auto-close: user sees key arrival animation and closes
  // manually"). A Flutter modal route blocks the semantics of everything under
  // it, so while the sheet is up the status table is not in the tree at all:
  // waiting for "Delegate" first times out on a dialog that is plainly on screen
  // behind the sheet, which is exactly how this take failed twice.
  //
  // And it is refused WITH a delegate key, which is the point worth making: the
  // key gets you a voice, not an audience. Hillel's visibility rules decide.
  await waitFor(hab, /Access denied/i, {}, 60000);
  // findStill, not the node waitFor just returned: the sheet slides up and
  // waitFor returns the instant the node EXISTS, which is mid-animation.
  marks.deniedBox = boxOf(await findStill(hab, /Access denied/i));
  mark('denied');
  await sleep(4000);

  // Dismiss the sheet by its barrier, high on the screen where neither it nor
  // the dialog below has any body. NOT the BACK key: Chrome treats BACK as its
  // own navigation and this tab was launched straight into /app, so there is
  // nothing behind it -- the tab closes and the take dies with "Target page has
  // been closed".
  const w = await hab.evaluate(() => innerWidth);
  await tapAt(hcdp, Math.round(w / 2), 40);
  marks.taps.push({ t: at(), ...toDevice(Math.round(w / 2), 40), what: 'dismiss_contact' });
  mark('dismiss_contact');
  await sleep(1600);

  // --- and now the status table, which says which keys arrived ---
  //
  // Two columns, Identity and Delegate (sign_in_dialog.dart _buildStatusTable).
  // With the key taken both read "present" -- the difference from the sibling
  // take in one picture.
  // "Delegate present", not "Delegate". _buildStatusColumn puts the label and the
  // state in one node, so the tree reads "Identity present" / "Delegate present"
  // -- matching the label alone finds nothing on a dialog that is on screen.
  // Matching the whole thing also ASSERTS the key arrived: "Delegate absent"
  // does not match, and a take that signed in without one should not continue.
  await waitFor(hab, /^Delegate present$/, {}, 30000);
  await sleep(600);
  marks.delegateColumnBox = boxOf(await findStill(hab, /^Delegate present$/));
  mark('delegate_arrived');
  await sleep(4000);                       // hold: the status table is the point

  // DOWN THE SIDE, not at the "Dismiss" node and not at the top.
  //
  // "Dismiss" in the tree is not a button: it is Flutter's a11y label for the
  // MODAL BARRIER, so its box is the whole screen and its centre is the middle
  // of the dialog -- tapping it pressed "QR Code" and opened the QR sign-in
  // dialog. (The contact sheet's barrier shows up as "Scrim", same idea.)
  //
  // And not the top edge either: this dialog reaches it. The dialog is centred
  // with a margin on both sides, so the left gutter at mid-height is barrier and
  // nothing else. NOT the BACK key -- Chrome would close the tab.
  const h = await hab.evaluate(() => innerHeight);
  await tapAt(hcdp, 8, Math.round(h / 2));
  marks.taps.push({ t: at(), ...toDevice(8, Math.round(h / 2)), what: 'dismiss_signin' });
  mark('dismiss_signin');
  await sleep(1800);

  // --- our own card, which the delegate key lets us write ---
  //
  // The person icon in the app bar, by its tooltip. It had none until now, so
  // this used to be "the rightmost unnamed button left of Sign out".
  const person = await findStill(hab, /^My card$/, {});
  await tapAt(hcdp, person.x, person.y);
  tapped('my_card', person);
  // The sheet is a showModalBottomSheet; "Add entry" only exists in edit mode,
  // so what proves the sheet is open is its own Edit button.
  await waitFor(hab, /^Edit$/, {}, 20000);
  mark('my_card');
  await sleep(2600);

  // THE EDIT BUTTON IS THE EVIDENCE. my_contact_screen.dart draws it inside
  // `if (signInState.hasDelegate)`, so on the sibling take -- identity only --
  // this button is not on the screen at all. It is the cleanest thing in either
  // app to point a beat at.
  //
  // TAP THE findStill NODE, NOT THE waitFor ONE. This is a modal bottom sheet
  // and it SLIDES UP; waitFor returns the instant the node exists, which is
  // mid-animation, so its coordinates are wherever the sheet happened to be.
  // Tapping those hit nothing and the take sat waiting for an edit mode it had
  // never entered. Same lesson as the sign-in link and the Access denied card.
  const edit = await findStill(hab, /^Edit$/, {});
  marks.editButtonBox = boxOf(edit);
  await sleep(1600);
  await tapAt(hcdp, edit.x, edit.y);
  tapped('edit', edit);
  const addEntry = await waitFor(hab, /^Add entry$/, {}, 15000);
  mark('editing');
  await sleep(1800);

  // --- a phone number ---
  await tapAt(hcdp, addEntry.x, addEntry.y);
  tapped('add_entry', addEntry);
  // _TechPickerDialog: a Wrap of ActionChips, 'phone' among them, over a
  // "Or type a custom type" field. The chip is the fast way and it reads better.
  const phoneChip = await waitFor(hab, /^phone$/, {}, 15000);
  await sleep(1400);
  await tapAt(hcdp, phoneChip.x, phoneChip.y);
  tapped('phone_type', phoneChip);
  await sleep(1600);
  mark('entry_added');

  // The new row, BY NAME. HabloTengo names these now -- the value field is
  // "phone value", the visibility segments are "Permissive/Standard/Strict for
  // phone", the star and the delete icon are named too. Before that they were
  // anonymous boxes and this block read the row by shape: five unnamed buttons
  // left to right, take the fourth. That worked and would have broken the first
  // time anyone restyled the row, which is the whole argument for naming things.
  // See hablotengo lib/visibility_picker.dart (forField) and _EditEntryRow.
  //
  // THE ONE THING STILL FOUND BY POSITION, and not for want of a label:
  // HabloTengo names it "phone value", but a Flutter text field renders as an
  // <input> INSIDE its flt-semantics element, and SEMANTICS_PROBE reads
  // textContent || aria-label off the element itself -- so a field's name is
  // invisible to every script in this directory. Teaching the probe to look
  // inside would name nodes that are unnamed today, and shoot_hablotengo.js's
  // menuCheckbox deliberately keys on `!n.text`, so that is not a free change.
  //
  // So: anchored on a NAMED neighbour rather than on pixels. The star sits
  // immediately right of the field on the same row, and the field is the widest
  // thing left of it. Restyle the row and this still holds; it only breaks if
  // the star moves off the row, which would change what the take means anyway.
  const star = await findStill(hab, /^Preferred phone$/, {});
  const field = (await hab.evaluate(() => window.__sem()))
    .filter(n => Math.abs(n.y - star.y) < 26 && n.x + n.w / 2 <= star.x - star.w / 2
                 && !n.text && n.w > 100)
    .sort((a, b) => b.w - a.w)[0];
  if (!field) throw new Error(
    'no value field left of "Preferred phone" on the entry row. The field is the '
    + 'widest unnamed node on that row; if the row has been restyled, or the '
    + 'probe now reads input labels, this is the line to revisit.');
  await tapAt(hcdp, field.x, field.y);
  tapped('phone_field', field);
  await sleep(900);
  await typeText(hcdp, PHONE);
  mark('typed_phone');
  await sleep(1800);

  // --- and mark it strict ---
  //
  // Named per field, so this is the phone row's segment and not the form's own
  // "Default visibility" picker further down, which carries the same three
  // words. With several entries on a card they stay distinct too.
  const strict = await findStill(hab, /^Strict for phone$/, {});
  marks.strictBox = boxOf(strict);
  const permissive = await findStill(hab, /^Permissive for phone$/, {});
  // The whole three-segment control, for a beat to point at: from the left edge
  // of permissive to the right edge of strict.
  marks.visibilityBarBox = boxOf({
    x: (permissive.x - permissive.w / 2 + strict.x + strict.w / 2) / 2,
    y: strict.y,
    w: (strict.x + strict.w / 2) - (permissive.x - permissive.w / 2),
    h: strict.h,
  });
  await tapAt(hcdp, strict.x, strict.y);
  tapped('strict', strict);
  mark('strict_set');
  await sleep(2600);                       // hold: the segment turns red

  // --- publish it ---
  const save = await findStill(hab, /^Save$/, { role: 'button' });
  await tapAt(hcdp, save.x, save.y);
  tapped('save', save);
  // Back to view mode, with the number on the card. The sheet returns to the
  // read-only view when the save lands, so the Edit button coming back is what
  // says the write went through.
  await waitFor(hab, /^Edit$/, {}, 30000);
  mark('saved');
  await sleep(4200);
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local adb
  // first severs the shell before screenrecord can write its moov atom, and the
  // pulled file is then not a video at all.
  await device().stopRecording('/sdcard/hablotengo_delegate.mp4');
  rec.kill();
  await browser.close();

  const nm = 'hablotengo_delegate';
  E('pull', `/sdcard/${nm}.mp4`, path.join(OUT, `${nm}.mp4`));
  E('shell', 'rm', '-f', `/sdcard/${nm}.mp4`);
  fs.writeFileSync(path.join(OUT, `${nm}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${nm}.mp4`))}\n${path.relative(__dirname, path.join(OUT, `${nm}.marks.json`))}  (${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });

const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
