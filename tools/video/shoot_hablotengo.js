#!/usr/bin/env node
// Shoot the HABLOTENGO section: from a stranger two hops away in the Nerdster,
// to his keys -- two for nerdster.org and one for hablotengo.com -- and out
// along that link to HabloTengo itself, which recognises the identity and
// refuses it anyway.
//
// The point is that a SECOND, unrelated service rides on the same identity
// network, and that being grounded there is what lets it keep things private as
// well as authentic. Being refused is the feature, not a failure of the take.
//
// NEVER RUN AGAINST HABLOTENGO. The Nerdster half reuses selectors this
// repository has exercised for weeks; everything after the link out is written
// from an outline and is expected to need a pass on the device.
//
//   node shoot_hablotengo.js
//
// Writes out/hablotengo/<stamp>/hablotengo.mp4 + .marks.json.
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
  tapNamed, tapAt, drag, assertAbsent, attachToAvdChrome,
} = require('./lib/semantics');

const SERIAL = process.env.AVD || 'emulator-5554';
const { buildDir } = require('./lib/build_dir');
const { device } = require('./lib/device');

/// The identity this section is about. Not just anybody: the Nerdster only draws
/// the HabloTengo link on a node that HAS a hablotengo.com delegate key, and
/// Hillel is the one who does -- two nerdster.org delegates and one there.
const SUBJECT = /^Hillel/;
const d = device();
const OUT = buildDir('hablotengo');
const E = (...a) => execFileSync('adb', ['-s', SERIAL, ...a], { stdio: 'ignore' });
const Eout = (...a) => execFileSync('adb', ['-s', SERIAL, ...a]).toString();


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

  // --- reset: HabloTengo must start SIGNED OUT ---
  //
  // The section ends on being refused. Run it twice without this and the second
  // take arrives at an app that already knows you, never reaches Access Denied,
  // and quietly films the wrong ending.
  //
  // Through the storage service, not removeItem: Chrome flushes localStorage
  // lazily and this take force-stops it, so unflushed deletes are lost -- which
  // is exactly how reset_browser.js used to "verify" a sign-out that came back.
  await cdp.send('Storage.clearDataForOrigin',
                 { origin: 'https://hablotengo.com', storageTypes: 'local_storage' });
  console.log('  cleared hablotengo.com sign-in state');
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

  // Who this is about. The HabloTengo link only exists on a node that has a
  // hablotengo.com delegate key, so it cannot be just anybody -- it is Hillel,
  // who has two nerdster.org delegates and one for hablotengo.com.
  let who = null;
  for (let i = 0; i < 16 && !who; i++) {
    who = (await findAll(page, /@nerdster\.org$/, { role: 'button' }))
      .map(n => n.text).find(t => SUBJECT.test(t));
    if (!who) { await drag(cdp, 200, 600, 0, { dy: -500, holdMs: 0 }); await sleep(900); }
  }
  if (!who) {
    throw new Error(`nobody matching ${SUBJECT} in the feed. This section needs an `
      + 'identity with a hablotengo.com delegate key; without one the Nerdster '
      + 'does not draw the HabloTengo link at all.');
  }
  const name = who.split('@')[0];
  console.log(`  following ${who}`);
  marks.subject = who;

  // Back to the top: the app bar hides when the feed scrolls.
  for (let i = 0; i < 14; i++) {
    if (await find(page, /^Menu$/, { role: 'button' })) break;
    await drag(cdp, 200, 300, 0, { dy: 600, holdMs: 0 });
    await sleep(500);
  }
  if (!await find(page, /^Menu$/, { role: 'button' })) {
    throw new Error('could not scroll back to the top: the app bar never reappeared');
  }

  // --- record ---
  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '180', '--bit-rate', '8000000', '/sdcard/hablotengo.mp4']);
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
  await sleep(2600);

  // --- somebody two hops away, and their node ---
  // Scrolled to on camera. He was found before recording so the take knows who
  // it is about, but the feed was then put back to the top, so he is off screen
  // again by the time it starts.
  for (let i = 0; i < 14; i++) {
    const n = await find(page, new RegExp(`^${esc(who)}$`), { role: 'button' });
    if (n && n.y > 150 && n.y < 560) break;
    await drag(cdp, 200, 600, 0, { dy: -520, holdMs: 0 });
    await sleep(420);
  }
  mark('scrolled_to_him');
  await sleep(1400);

  tapped('moniker', await tapNamed(page, cdp, new RegExp(`^${esc(who)}$`), { role: 'button' }));
  await waitFor(page, new RegExp(`^${esc(name)}$`), { role: 'button' }, 20000);
  mark('graph');
  await sleep(2400);

  tapped('node', await tapNamed(page, cdp, new RegExp(`^${esc(name)}$`), { role: 'button' }));
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  mark('node_details');
  await sleep(4600);

  // --- his keys: two for one service, one for another ---
  tapped('delegate_tab', await tapNamed(page, cdp, /^delegate$/, { role: 'button' }));
  await waitFor(page, /hablotengo\.com$/, {}, 15000);
  mark('delegates_shown');
  await sleep(4800);

  // --- the shortcut out to that other service ---
  // The link only exists on a node that HAS a hablotengo.com delegate, which is
  // why this section is about Hillel and not about anyone nearer.
  const hablo = await findStill(page, /^HabloTengo$/, {});
  const v = marks.viewportToDevice;
  marks.habloButtonBox = {
    x: Math.round(hablo.x * v.scale), y: Math.round(hablo.y * v.scale + v.offY),
    w: Math.round(hablo.w * v.scale), h: Math.round(hablo.h * v.scale),
  };
  mark('hablotengo_link_shown');
  await sleep(3400);

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
  // Wait for Flutter to bootstrap before turning the tree on. The placeholder
  // only exists once it has, and enabling too early leaves __sem() empty for the
  // rest of the take -- which surfaced as "timeout waiting for the sign-in" on a
  // screen that was plainly showing it. Not swallowed: a failure here makes
  // everything after it meaningless.
  for (let i = 0; i < 80; i++) {
    if (await hab.evaluate(() => !!document.querySelector('flt-semantics-placeholder'))
        .catch(() => false)) break;
    await sleep(250);
  }
  await hab.evaluate(SEMANTICS_PROBE);
  await enableSemantics(hab, hcdp);
  mark('hablotengo_open');
  await sleep(4200);

  // --- sign in with the identity app, and no delegate key ---
  //
  // UNVERIFIED. HabloTengo has never been driven by a script. The names below
  // are the Nerdster's, on the assumption the two sign-in flows are the same
  // widget -- they are the same paradigm and probably the same code. If this
  // fails, dump the tree with probe.js against the hablotengo tab and fix the
  // names here; nothing else in the take depends on them.
  // The button, by what it says. HabloTengo's sign-in is the same widget as the
  // Nerdster's: "Identity app on this device" over a button whose label is the
  // link plus "Link to your ONE-OF-US.NET app".
  const signin = await waitFor(hab, /Link to your ONE-OF-US\.NET app/, { role: 'button' }, 30000);
  await tapAt(hcdp, signin.x, signin.y);
  tapped('hablo_signin', signin);
  mark('signin_open');

  // The identity app comes forward. "No, just identity" is the one that signs in
  // WITHOUT minting a delegate key, which is the state this section needs: an
  // identity HabloTengo can recognise and still refuse.
  await waitForApp('net.oneofus.app', 25000);
  await d.waitForStillScreen(20000, 900);
  mark('identity_app');
  await sleep(2600);

  // "No, just identity" -- NOT "Yes, create delegate".
  //
  // The section is about being recognised and refused anyway, so it signs in
  // with the identity alone and takes no delegate key. Device pixels, because
  // the identity app is native and has no semantics tree to ask: it sits one
  // button above "Yes, create delegate", which shoot_signin.js has long had at
  // [693, 1532]. Re-measure both together if that dialog is ever restyled.
  const JUST_IDENTITY = [733, 1400];
  E('shell', 'input', 'tap', String(JUST_IDENTITY[0]), String(JUST_IDENTITY[1]));
  marks.taps.push({ t: at(), x: JUST_IDENTITY[0], y: JUST_IDENTITY[1], what: 'just_identity' });
  mark('tap_just_identity');
  await sleep(2400);

  // Back to the browser, where HabloTengo decides what to do with an identity it
  // can verify and has no reason to trust.
  //
  // Brought forward explicitly, not with BACK. shoot_signin.js uses BACK and it
  // works there, but that flow leaves the identity app on the screen it was
  // deep-linked into; "No, just identity" returns the app to its own main
  // screen first, and BACK then just moves around inside it.
  E('shell', 'am', 'start', '-a', 'android.intent.action.MAIN',
    '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await waitForApp('com.android.chrome', 25000);
  mark('back_to_browser');
  await sleep(1800);

  // --- refused ---
  const denied = await waitFor(hab, /Access Denied/i, {}, 45000);
  marks.deniedBox = {
    x: Math.round(denied.x * v.scale), y: Math.round(denied.y * v.scale + v.offY),
    w: Math.round(denied.w * v.scale), h: Math.round(denied.h * v.scale),
  };
  mark('denied');
  await sleep(5200);
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/hablotengo.mp4');
  rec.kill();
  await browser.close();

  // The stamp is on the build directory (lib/build_dir.js), so the take
  // inside it is named for what it is and nothing else.
  const nm = 'hablotengo';
  E('pull', '/sdcard/hablotengo.mp4', path.join(OUT, `${nm}.mp4`));
  // Off the device once it is safely here. Every take used to leave its
  // recording behind, and they were quietly filling /data -- enough that an
  // apk install eventually failed for want of space.
  E('shell', 'rm', '-f', '/sdcard/hablotengo.mp4');
  fs.writeFileSync(path.join(OUT, `${nm}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\n${path.relative(__dirname, path.join(OUT, `${nm}.mp4`))}\n${path.relative(__dirname, path.join(OUT, `${nm}.marks.json`))}  (${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });

const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/// The rate dialog's thumbs-up. The two thumb buttons are unlabelled, but the
/// pair sits inside a node that says "Like or dislike": like is its left half.
/// Lifted from shoot_nerdster.js, which reacts to a card the same way.
async function thumbsUp(page) {
  const n = await findStill(page, /^Like or dislike$/);
  return { x: n.x - n.w / 4, y: n.y };
}

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
