#!/usr/bin/env node
// Shoot the delegation sequence: turn Show Crypto on in shot, pick somebody in
// the feed who isn't me, follow them to their node in the graph, look at their
// identity key and then the delegate key it authorised, and open the shield on
// that delegate to see the signed statement in which one named the other --
// toggling interpreted and raw at each key, because the readable version is the
// Nerdster's reading and the raw one is the thing itself.
//
// REQUESTED CHANGES -- Yotam, 1 Sep 2026. Built, NEVER RUN: written against a
// dead emulator, so every selector below is read off the Nerdster source rather
// than off a running app. Expect the first pass to need fixing, and see the
// notes at the end of this comment for the parts most likely to be wrong.
//
// The old sequence moves too quickly to follow, and it ends outside the app in
// Chrome. The new one stays in the Nerdster and walks the delegation itself,
// slowly. It may not end up in the brief Intro at all, so it is not bound by the
// Intro's budget: put enough time between actions that a normal human can keep
// up with the prompter text.
//
// Depends on a Nerdster change, made alongside this and tested and pushed by
// Yotam: the crypto shield icon that already sits to the right of vouches now
// also sits to the right of DELEGATE KEYS when Show Crypto is on, showing that
// Hillel's identity key delegated those keys. The point of the whole section is
// a complete cryptographic signature chain to every piece of data on screen, and
// the delegate keys were the missing link in it.
//
//   1. Turn on "Show Crypto" right at the start.
//   2. Navigate to Hillel's NodeDetail.
//   3. Show his IDENTITY key. Click back and forth between the interpreted and
//      un-interpreted views, and say in the prompter that the Nerdster
//      interprets known keys to make them readable.
//   4. Show Hillel's delegate key -- the CURRENT one, not his old delegate key.
//   5. Click the crypto shield on it, toggle interpreted / un-interpreted again,
//      and explain that Hillel delegated this key to nerdster.org using his
//      identity app, and that the delegation is signed by his identity key --
//      the key Tom vouched for.
//
// The take STOPS THERE. Everything the old sequence did after the delegate key
// -- the published statements in Chrome, the pretty-print, the Verify dialog and
// the VERIFIED verdict -- is not part of this. Whether it comes back as its own
// section is a later question.
//
// UNVERIFIED, in rough order of how likely it is to bite:
//
//   - The shield's tooltip reaching the semantics tree as a findable name. It
//     should, by the same route the mode button's "Interpreted → Raw" does, but
//     that one is a FloatingActionButton's own tooltip and this is a Tooltip
//     wrapped round an Icon. If /^Delegation statement$/ is not found, that is
//     why, and the fix is a Semantics(label:) in CryptoShieldButton.
//     NEEDS THE DEPLOYED NERDSTER: the tooltip is a change of 1 Sep 2026.
//   - BACK closing the key dialogs. showDialog is barrier-dismissible and BACK
//     should pop it, but BACK in Chrome is also a navigation; each one waits for
//     the tabs to reappear rather than assuming.
//   - Whether this take still truncates. The old one stopped recording at 26.5s;
//     the best explanation is device memory pressure -- sixty-odd Chrome tabs
//     open on the emulator -- and restarting the AVD cleared it. This records
//     60.7s. If it comes back, the seams between the identity key, the delegate
//     key and the delegation are where this splits into separate takes, the way
//     build_preamble.sh joins three. See doc/video/capture_manual.md §10.
//
//   node shoot_crypto.js
//
// Writes out/crypto/<stamp>/crypto.mp4 + .marks.json.
//
// PROTOTYPE. It publishes nothing, so it needs no reset and can be re-run at
// will -- the whole sequence is reading and verifying what other people signed.
//
// The point of the sequence is that every step is a real link in a real chain:
// my vouch names the person, the person's identity key names their delegate key,
// the delegate key signed the statement, and the statement verifies. Nothing
// here is a mock-up of that; it is that.

const fs = require('fs');
const path = require('path');
const { execFileSync, spawn } = require('child_process');
const { chromium } = require('playwright');
const {
  SEMANTICS_PROBE, sleep, enableSemantics, find, findAll, findStill, waitFor,
  tapNamed, tapAt, drag, attachToAvdChrome,
} = require('./lib/semantics');

const SERIAL = process.env.AVD || 'emulator-5554';
const { buildDir } = require('./lib/build_dir');
const OUT = buildDir('crypto');
const E = (...a) => execFileSync('adb', ['-s', SERIAL, ...a], { stdio: 'ignore' });
const Eout = (...a) => execFileSync('adb', ['-s', SERIAL, ...a]).toString();

// Who the sequence is about. Anyone in the feed who is neither me nor the
// identity this phone vouched for -- the point is that the chain reaches people
// I did not sign for myself.
const SKIP = /^(Me|Tom)@/;

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

  // OFF before the recording starts. The take's first act is turning it on, and
  // it can only do that from a known state -- see setShowCrypto.
  await setShowCrypto(page, cdp, false);

  // Somebody else has to be on screen for the sequence to mean anything, and
  // the top card is usually just me and Tom -- so scroll until a third name
  // shows up. Done before recording: the video starts where the point is.
  let who = null;
  for (let i = 0; i < 16 && !who; i++) {
    who = (await findAll(page, /@nerdster\.org$/, { role: 'button' }))
      .map(n => n.text).find(t => !SKIP.test(t));
    if (!who) { await drag(cdp, 200, 600, 0, { dy: -500, holdMs: 0 }); await sleep(900); }
  }
  if (!who) throw new Error('nobody in the feed but me and the identity I vouched for');
  // Back to the top before recording. The app bar HIDES WHEN THE FEED SCROLLS,
  // and the Show Crypto menu lives in it -- so a take that opens on the scrolled
  // feed cannot reach the menu at all, which is exactly how the first run of
  // this sequence failed. Finding their name again is done on camera below,
  // after the crypto is on.
  for (let i = 0; i < 14; i++) {
    if (await find(page, /^Menu$/, { role: 'button' })) break;
    await drag(cdp, 200, 300, 0, { dy: 600, holdMs: 0 });
    await sleep(500);
  }
  if (!await find(page, /^Menu$/, { role: 'button' })) {
    throw new Error('could not scroll back to the top: the app bar never reappeared');
  }
  const name = who.split('@')[0];
  console.log(`  following ${who}`);
  marks.subject = who;

  // --- record ---
  // Chrome opens a tab per VIEW intent and nothing closed them; thirty had
  // piled up, and enough of them throttle screenrecord. Swept before the
  // camera, so a crashed take is cleaned up by the next one.
  await require('./lib/device').device().closeChromeTabs();

  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '180', '--bit-rate', '8000000', '/sdcard/crypto.mp4']);
  await sleep(4000); // TODO: Reduce
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

  // --- turn the crypto on, before anything else ---
  // Everything this section claims is invisible with Show Crypto off: the
  // shields are what carry the chain. Doing it on camera, first, means the
  // viewer sees the ordinary app and then sees what turning it on reveals,
  // rather than wondering why their own Nerdster looks different from this one.
  tapped('menu', await tapNamed(page, cdp, /^Menu$/, { role: 'button' }));
  await sleep(1400);
  // findStill and tapAt rather than tapNamed, for the same reason setShowCrypto
  // uses them: the menu is still animating, and a coordinate read mid-flight
  // lands on whatever has slid into that spot by the time the tap arrives.
  const cryptoBox = await menuCheckbox(page, /^Show Crypto$/);
  await tapAt(cdp, cryptoBox.x, cryptoBox.y);
  tapped('show_crypto', cryptoBox);
  await sleep(1200);
  if (!await showCryptoOn(page)) throw new Error('Show Crypto did not turn on in shot');
  mark('crypto_on');
  await sleep(1800);
  E('shell', 'input', 'keyevent', '4');            // close the menu
  await sleep(1600);

  // --- their name in my feed -> their node in the graph ---
  // Scrolled to on camera, because the app bar the menu lives in is only there
  // at the top. Their name is usually near the bottom edge when it first shows,
  // which is where a tap lands on the browser's own chrome instead, so this
  // keeps going until it sits in the middle of the screen.
  for (let i = 0; i < 18; i++) {
    const n = await find(page, new RegExp(`^${esc(who)}$`), { role: 'button' });
    if (n && n.y > 150 && n.y < 560) break;
    await drag(cdp, 200, 600, 0, { dy: -520, holdMs: 0 });
    await sleep(420);
  }
  mark('scrolled_to_them');
  await sleep(1400);

  tapped('moniker', await tapNamed(page, cdp, new RegExp(`^${esc(who)}$`), { role: 'button' }));
  await waitFor(page, new RegExp(`^${esc(name)}$`), { role: 'button' }, 20000);
  mark('graph');
  await sleep(2200);

  tapped('node', await tapNamed(page, cdp, new RegExp(`^${esc(name)}$`), { role: 'button' }));
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  mark('node_details');
  await sleep(2400);

  // --- his identity key, and what "interpreted" means ---
  // The identity tab's rows are labelled with the plain label and a trailing
  // space -- '$label ${isCanonical ? "" : "(Replaced)"}' -- so this is a prefix
  // match, not an anchored one.
  tapped('identity_tab', await tapNamed(page, cdp, /^identity$/, { role: 'button' }));
  await sleep(1800);
  tapped('identity_key', await tapNamed(page, cdp, new RegExp(`^${esc(name)}`), { role: 'button' }));
  // KeyInfoView opens interpreted, so the mode button offers the other way.
  await waitFor(page, /Interpreted → Raw/, {}, 15000);
  mark('identity_key_shown');
  await sleep(3400);

  tapped('identity_raw', await tapNamed(page, cdp, /Interpreted → Raw/, { role: 'button' }));
  await waitFor(page, /"crv"/, {}, 15000);
  mark('identity_raw_shown');
  await sleep(4000);

  tapped('identity_interpreted', await tapNamed(page, cdp, /Raw → Interpreted/, { role: 'button' }));
  await waitFor(page, /Interpreted → Raw/, {}, 15000);
  mark('identity_interpreted_shown');
  await sleep(3600);

  // Wait for the tabs to prove we are back in NodeDetails, not merely that a tap
  // went out.
  await dismissDialog(page, cdp);
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  await sleep(1600);

  // --- his delegate key ---
  // He has two live nerdster.org delegates, and the labeller tells them apart by
  // suffixing one with " (2)". NEITHER is revoked -- Yotam, 1 Sep 2026 -- so
  // this is a choice of which to film, not a correctness question, and the
  // anchored match takes the unsuffixed one because that is the one to show.
  tapped('delegate_tab', await tapNamed(page, cdp, /^delegate$/, { role: 'button' }));
  await sleep(1800);
  tapped('delegate_key', await tapNamed(page, cdp, new RegExp(`^${esc(who)}$`), { role: 'button' }));
  await waitFor(page, /Interpreted → Raw/, {}, 15000);
  mark('delegate_key_shown');
  await sleep(4000);

  await dismissDialog(page, cdp);
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  await sleep(1600);

  // --- the delegation itself: who said this key speaks for them ---
  // Found by name. The shield used to be an unnamed Icon and had to be tapped at
  // a computed corner of its row; it now carries a Tooltip, which is both its
  // accessible name and what makes it reachable from here. The delegate rows say
  // "Delegation statement" so they can be told apart from the vouch and follow
  // shields on the same screen, which keep the generic label.
  tapped('shield', await tapNamed(page, cdp, /^Delegation statement$/, {}));
  await waitFor(page, /Interpreted → Raw/, {}, 15000);
  mark('delegation_shown');
  await sleep(3600);

  tapped('delegation_raw', await tapNamed(page, cdp, /Interpreted → Raw/, { role: 'button' }));
  await waitFor(page, /"statement"|"I"|"crv"/, {}, 15000);
  mark('delegation_raw_shown');
  await sleep(4200);

  tapped('delegation_interpreted', await tapNamed(page, cdp, /Raw → Interpreted/, { role: 'button' }));
  mark('delegation_interpreted_shown');

  // The take ends here, on the delegation. Everything the old sequence did next
  // -- out to export.nerdster.org, pretty-print, the Verify dialog, VERIFIED --
  // is deliberately not part of this one.
  await sleep(4500);
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/crypto.mp4');
  rec.kill();
  await browser.close();

  // The stamp is on the build directory (lib/build_dir.js), so the take
  // inside it is named for what it is and nothing else.
  const nm = 'crypto';
  E('pull', '/sdcard/crypto.mp4', path.join(OUT, `${nm}.mp4`));
  // Off the device once it is safely here. Every take used to leave its
  // recording behind, and they were quietly filling /data -- enough that an
  // apk install eventually failed for want of space.
  E('shell', 'rm', '-f', '/sdcard/crypto.mp4');
  fs.writeFileSync(path.join(OUT, `${nm}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${nm}.mp4`))}\n${path.relative(__dirname, path.join(OUT, `${nm}.marks.json`))}  (${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });

const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/// The tappable half of a MyCheckbox in the feed menu.
///
/// MyCheckbox renders Row([Checkbox, Text(title)]) when it shows its title, so
/// THE LABEL IS NOT A BUTTON -- it is a Text, and tapping it does nothing at
/// all. That is how this used to "turn on" Show Crypto without turning anything
/// on: it tapped the words, and the check that followed was looking for
/// unlabelled 48x48 buttons which the feed has anyway, so it always agreed.
/// The checkbox is the unnamed node immediately left of the label, same row.
async function menuCheckbox(page, label) {
  const item = await findStill(page, label);
  const all = await page.evaluate(() => window.__sem());
  const box = all
    .filter(n => !n.text && n.x < item.x && Math.abs(n.y - item.y) < 26 && n.w < 70)
    .sort((a, b) => b.x - a.x)[0];
  if (!box) throw new Error(`no checkbox beside "${label}" in the menu`);
  return box;
}

/// Close a key dialog by tapping its barrier.
///
/// NOT the BACK key. Both of these are showDialog(), so BACK ought to pop the
/// Flutter route -- but Chrome also treats BACK as its own navigation, and on a
/// tab launched straight into /app there is nothing behind it, so the tab closes
/// and the take dies with "Target page has been closed". The barrier covers the
/// page and swallows the tap, so anywhere outside the dialog works; the top
/// strip is furthest from both dialogs' bodies. (The feed MENU is different --
/// MenuAnchor consumes BACK itself, and those two sites still use it.)
async function dismissDialog(page, cdp) {
  const w = await page.evaluate(() => innerWidth);
  await tapAt(cdp, Math.round(w / 2), 40);
  await sleep(900);
}

/// Whether Show Crypto is on: are there shields in the feed.
///
/// Not the URL. SettingType.showCrypto is declared `param: true`, which means it
/// can be READ from the query string at load -- it is not written back when the
/// checkbox is toggled, so the address bar says nothing about the live state.
///
/// Not unlabelled 48x48 buttons either, which is what this used to look for
/// when the shield was a nameless Icon: the feed has other icon buttons that
/// size, so it answered "on" whatever the truth was. The shields carry their
/// Tooltip into the semantics tree as a name, so just count the name.
async function showCryptoOn(page) {
  return (await findAll(page, /^Signed statement$/, {})).length > 0;
}

/// Put Show Crypto into a known state, off camera.
///
/// This used to only ever turn it ON, before recording, on the reasoning that a
/// menu trip says nothing. That was right while the shields were plumbing. They
/// are the SUBJECT of this section now -- the whole point is what turning it on
/// reveals -- so the take starts with it OFF and turns it on in shot, and this
/// is what guarantees the starting state.
async function setShowCrypto(page, cdp, want) {
  if ((await showCryptoOn(page)) === want) {
    console.log(`  Show Crypto already ${want ? 'on' : 'off'}`);
    return;
  }
  await tapNamed(page, cdp, /^Menu$/, { role: 'button' });
  const box = await menuCheckbox(page, /^Show Crypto$/);
  await tapAt(cdp, box.x, box.y);
  await sleep(1200);
  if ((await showCryptoOn(page)) !== want) {
    throw new Error(`Show Crypto would not turn ${want ? 'on' : 'off'}`);
  }
  console.log(`  Show Crypto turned ${want ? 'on' : 'off'}`);
  E('shell', 'input', 'keyevent', '4');       // close the menu
  await sleep(700);
}

/// The Verify dialog's input: the largest node in it with nothing to say.
async function biggestBlank(page) {
  const all = await page.evaluate(() => window.__sem());
  const blank = all.filter(n => !n.text && n.w > 200 && n.h > 200)
    .sort((a, b) => b.w * b.h - a.w * a.h);
  if (!blank.length) throw new Error('no input box in the Verify dialog');
  return blank[0];
}
