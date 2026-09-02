#!/usr/bin/env node
// Shoot the crypto TEASER for the intro: turn Show Crypto on in shot, open one
// vouch and read it both ways -- as the Nerdster renders it and as the signed
// thing it actually is -- then follow that key out to its statements, published
// on the open web. Three beats and out.
//
// The full walk (identity key, delegate key, the delegation tying them together)
// is shoot_crypto.js, and belongs to the "How it works" video. This one exists
// to show that the crypto is REAL and then get out of the way: the intro has
// about two minutes for twelve sections.
//
//   node shoot_crypto_teaser.js
//
// Writes out/crypto_teaser_<stamp>.mp4 + .marks.json.
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
const OUT = path.join(__dirname, 'out');
const E = (...a) => execFileSync('adb', ['-s', SERIAL, ...a], { stdio: 'ignore' });
const Eout = (...a) => execFileSync('adb', ['-s', SERIAL, ...a]).toString();

// Who the sequence is about: THE IDENTITY THIS PHONE ACTUALLY VOUCHED FOR.
//
// The opposite of shoot_crypto.js, which deliberately picks a stranger to show
// the chain reaching someone it never signed for. This section opens MY vouch,
// so it has to be somebody I vouched for -- and the shield is the null "nothing
// to show" placeholder for anyone else, which is how the first run of this
// failed against Hillel. state/demo_vouches_tom.json is that vouch.
const SUBJECT = /^Tom@/;

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
  // Old tabs left over from earlier takes get in the way twice: the script can
  // attach to the wrong one, and the link out to the statements has to be able
  // to tell its new tab from the rest.
  for (const p of ctx.pages()) if (p !== page) { try { await p.close(); } catch {} }

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
      .map(n => n.text).find(t => SUBJECT.test(t));
    if (!who) { await drag(cdp, 200, 600, 0, { dy: -500, holdMs: 0 }); await sleep(900); }
  }
  if (!who) {
    throw new Error('the identity this phone vouched for is not in the feed. This take '
      + 'opens MY vouch, so it needs them: see state/demo_vouches_tom.json.');
  }
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
  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '180', '--bit-rate', '8000000', '/sdcard/crypto_teaser.mp4']);
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

  // --- turn the crypto on, in shot ---
  // The section's whole subject. Everything after this is invisible with Show
  // Crypto off, so the viewer sees the ordinary app first and then sees what
  // turning it on reveals. setShowCrypto guaranteed it was off, above.
  tapped('menu', await tapNamed(page, cdp, /^Menu$/, { role: 'button' }));
  await sleep(1400);
  // findStill and tapAt, and the CHECKBOX rather than the label: MyCheckbox
  // renders Row([Checkbox, Text(title)]) and the words are not a button.
  const cryptoBox = await menuCheckbox(page, /^Show Crypto$/);
  await tapAt(cdp, cryptoBox.x, cryptoBox.y);
  tapped('show_crypto', cryptoBox);
  await sleep(1200);
  if (!await showCryptoOn(page)) throw new Error('Show Crypto did not turn on in shot');
  mark('crypto_on');
  await sleep(2600);
  E('shell', 'input', 'keyevent', '4');            // close the menu
  await sleep(1600);

  // --- somebody's node, and the vouch that reaches them ---
  // Scrolled to on camera: the app bar the menu lives in only exists at the top
  // of the feed, so the take cannot start already scrolled.
  for (let i = 0; i < 14; i++) {
    const n = await find(page, new RegExp(`^${esc(who)}$`), { role: 'button' });
    if (n && n.y > 150 && n.y < 560) break;
    await drag(cdp, 200, 600, 0, { dy: -520, holdMs: 0 });
    await sleep(420);
  }
  tapped('moniker', await tapNamed(page, cdp, new RegExp(`^${esc(who)}$`), { role: 'button' }));
  await waitFor(page, new RegExp(`^${esc(name)}$`), { role: 'button' }, 20000);
  mark('graph');
  await sleep(1600);

  tapped('node', await tapNamed(page, cdp, new RegExp(`^${esc(name)}$`), { role: 'button' }));
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  mark('node_details');
  await sleep(2000);

  // --- the vouch, as the Nerdster reads it and as it was signed ---
  // "Vouch statement" rather than the default "Signed statement": this screen
  // carries a shield per follow row as well, and they are told apart by label.
  tapped('vouch_shield', await tapNamed(page, cdp, /^Vouch statement$/, {}));
  await waitFor(page, /Interpreted → Raw/, {}, 15000);
  mark('vouch_shown');
  await sleep(4200);

  tapped('vouch_raw', await tapNamed(page, cdp, /Interpreted → Raw/, { role: 'button' }));
  await waitFor(page, /"signature"|"crv"|"statement"/, {}, 15000);
  mark('vouch_raw_shown');
  await sleep(4600);

  // Barrier tap, never BACK: BACK is Chrome's navigation and on a tab launched
  // straight into /app it closes the tab and the take dies.
  await dismissDialog(page, cdp);
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  await sleep(1400);

  // --- out to the statements themselves ---
  // The key's own view carries the link. WHOSE key does not matter here: the
  // point is only that what the app shows was fetched from the open web, so the
  // identity tab is enough and the delegate tab's distinctions are not.
  tapped('identity_tab', await tapNamed(page, cdp, /^identity$/, { role: 'button' }));
  await sleep(1600);
  tapped('identity_key', await tapNamed(page, cdp, new RegExp(`^${esc(name)}`), { role: 'button' }));
  // The key view opens interpreted, so the JSON reads as the label the Nerdster
  // knows this key by -- literally `"Tom"`.
  await waitFor(page, new RegExp(`^"${esc(name)}"$`), {}, 15000);
  mark('key_shown');
  await sleep(2800);

  // Found by name. shoot_crypto.js taps this link by where it sits, because an
  // InkWell round a Text reaches the semantics tree unnamed -- and that offset
  // is measured from the JSON above it, so it misses whenever the JSON is short.
  // The link carries a Semantics label now; shoot_crypto.js should follow.
  tapped('published_statements',
         await tapNamed(page, cdp, /^Signed, Published Statements$/, {}));

  // A SECOND CHROME TAB, and the only thing in the intro that leaves the app.
  // It was the suspect for the recording ceiling before device memory explained
  // that better. If takes start dying at a fixed length, this is the line to
  // suspect first -- see doc/video/capture_manual.md §10.
  let json = null;
  for (let i = 0; i < 60 && !json; i++) {
    json = ctx.pages().find(p => p.url().includes('export.nerdster.org'));
    await sleep(250);
  }
  if (!json) throw new Error('the published-statements link did not open a tab');
  await json.waitForLoadState('domcontentloaded').catch(() => {});
  mark('statements_tab');

  // Long enough for the card spliced in at statements_tab+3.0 to have footage
  // under it, and for the page to read as a page rather than a flash.
  await sleep(5200);
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/crypto_teaser.mp4');
  rec.kill();
  await browser.close();

  const d = new Date(), p2 = n => String(n).padStart(2, '0');
  const stamp = `${d.getFullYear()}${p2(d.getMonth() + 1)}${p2(d.getDate())}-` +
                `${p2(d.getHours())}${p2(d.getMinutes())}${p2(d.getSeconds())}`;
  const nm = `crypto_teaser_${stamp}`;
  E('pull', '/sdcard/crypto_teaser.mp4', path.join(OUT, `${nm}.mp4`));
  // Off the device once it is safely here. Every take used to leave its
  // recording behind, and they were quietly filling /data -- enough that an
  // apk install eventually failed for want of space.
  E('shell', 'rm', '-f', '/sdcard/crypto_teaser.mp4');
  fs.writeFileSync(path.join(OUT, `${nm}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\nout/${nm}.mp4\nout/${nm}.marks.json  (${marks.taps.length} taps)`);
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
