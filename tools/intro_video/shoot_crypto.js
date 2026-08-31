#!/usr/bin/env node
// Shoot the signature-chain sequence: pick somebody in the feed who isn't me,
// follow them to their node in the graph, open the delegate key their Nerdster
// statements are signed with, follow that to the signed statements themselves in
// Chrome, pretty-print them, take their like, and verify its signature in the
// Nerdster's own Verify dialog.
//
//   node shoot_crypto.js
//
// Writes out/crypto_<stamp>.mp4 + .marks.json.
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

  // Show Crypto has to be on before the recording starts: the shields, the key
  // views and the Verify dialog all hang off it, and toggling it on camera is a
  // menu trip that says nothing.
  await ensureShowCrypto(page, cdp);

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
  // Scrolling stops the moment their name appears, which is usually at the very
  // bottom edge -- where a tap lands on the browser's own chrome instead. Nudge
  // it into the middle of the screen before recording.
  for (let i = 0; i < 6; i++) {
    const n = await find(page, new RegExp(`^${esc(who)}$`), { role: 'button' });
    if (n && n.y > 150 && n.y < 560) break;
    await drag(cdp, 200, 600, 0, { dy: -180, holdMs: 0 });
    await sleep(800);
  }
  const name = who.split('@')[0];
  console.log(`  following ${who}`);
  marks.subject = who;

  // --- record ---
  const rec = spawn('adb', ['-s', SERIAL, 'shell', 'screenrecord',
    '--time-limit', '180', '--bit-rate', '8000000', '/sdcard/crypto.mp4']);
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

  // --- their name in my feed -> their node in the graph ---
  tapped('moniker', await tapNamed(page, cdp, new RegExp(`^${esc(who)}$`), { role: 'button' }));
  const node = await waitFor(page, new RegExp(`^${esc(name)}$`), { role: 'button' }, 20000);
  mark('graph');
  await sleep(900);

  tapped('node', await tapNamed(page, cdp, new RegExp(`^${esc(name)}$`), { role: 'button' }));
  await waitFor(page, /^delegate$/, { role: 'button' }, 15000);
  mark('node_details');
  await sleep(700);

  // --- the delegate key their Nerdster statements are signed with ---
  tapped('delegate_tab', await tapNamed(page, cdp, /^delegate$/, { role: 'button' }));
  tapped('delegate_key', await tapNamed(page, cdp, new RegExp(`^${esc(who)}$`), { role: 'button' }));
  // The key opens showing what it MEANS -- "Hillel TT@nerdster.org". One tap
  // turns that back into the thing itself, which is the point of the sequence.
  tapped('raw', await tapNamed(page, cdp, /Interpreted → Raw/, { role: 'button' }));
  const keyJson = await waitFor(page, /"crv"/, {}, 15000);
  mark('delegate_key_shown');
  await sleep(2000);                       // let the key and its QR be readable

  // --- out to the signed statements themselves ---
  // The link has no name in the tree, so it is reached by where it sits: just
  // under the key it belongs to.
  const link = { x: keyJson.x, y: keyJson.y + keyJson.h / 2 + 26 };
  await tapAt(cdp, link.x, link.y);
  tapped('published_statements', link);

  let json = null;
  for (let i = 0; i < 60 && !json; i++) {
    json = ctx.pages().find(p => p.url().includes('export.nerdster.org'));
    await sleep(250);
  }
  if (!json) throw new Error('the published-statements link did not open a tab');
  await json.waitForLoadState('domcontentloaded').catch(() => {});
  const jcdp = await ctx.newCDPSession(json);
  mark('statements_tab');
  await sleep(1200);

  // Chrome renders raw JSON as one long line. Pretty-print is the difference
  // between a wall of text and something a viewer can read a statement out of.
  const box = await json.evaluate(() => {
    const cb = document.querySelector('input[type=checkbox]');
    if (!cb) return null;
    const r = cb.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (box) {
    await tapAt(jcdp, box.x, box.y);
    marks.taps.push({ t: at(), ...toDevice(box.x, box.y), what: 'pretty_print' });
  } else {
    // Chrome's JSON viewer isn't part of the page's DOM, so the checkbox can't
    // be found or tapped through CDP. It is always in the same place, though --
    // the first row under the toolbar -- so tap the device there instead.
    const pt = { x: 117, y: VIEW2DEV.offY + 15 };
    E('shell', 'input', 'tap', String(pt.x), String(pt.y));
    marks.taps.push({ t: at(), ...pt, what: 'pretty_print' });
  }
  mark('tap_pretty_print');
  await sleep(1500);

  // Their statement about the book, found in the page rather than fetched
  // separately, and highlighted so the viewer can see which one is meant.
  const statement = await json.evaluate(() => {
    const body = document.body.innerText;
    const data = JSON.parse(body.replace(/^Pretty-print\s*/i, ''));
    const stmts = Object.values(data)[0] || [];
    const s = stmts.find(x => x.statement === 'org.nerdster' && (x.comment || x.with)) || stmts[0];
    if (!s) return null;
    // Select it on the page: scroll to the line its time appears on and paint
    // the selection, so the copy is something the viewer watches happen.
    const walk = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let n = walk.nextNode(); n; n = walk.nextNode()) {
      const i = n.nodeValue.indexOf(s.time);
      if (i < 0) continue;
      const r = document.createRange();
      r.setStart(n, Math.max(0, i - 400));
      r.setEnd(n, Math.min(n.nodeValue.length, i + 900));
      const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r);
      n.parentElement?.scrollIntoView({ block: 'center' });
      break;
    }
    return s;
  });
  if (!statement) throw new Error('no statement to verify on that page');
  console.log(`  verifying their ${statement.statement} of ${statement.time}`);
  mark('statement_selected');
  await sleep(1200);

  // Pinch in on it. A page of JSON at phone size is unreadable, and this is the
  // moment the video is asking the viewer to actually read something -- so zoom
  // the way a person would rather than leaving it to a crop in post.
  await jcdp.send('Input.synthesizePinchGesture',
    { x: 196, y: 380, scaleFactor: 2.6, relativeSpeed: 500 }).catch(e =>
      console.log('  pinch unavailable:', e.message));
  mark('zoomed');
  await sleep(3000);

  // --- back into the Nerdster, and verify it ---
  E('shell', 'input', 'keyevent', '4');
  await sleep(1500);
  mark('back');
  await page.bringToFront().catch(() => {});
  await page.evaluate(SEMANTICS_PROBE);

  // The key popup is still open behind the tab switch, and the node dialog
  // under that. Back dismisses them one at a time -- tapping the scrim doesn't,
  // since it reports a bounding box the size of the screen and its centre is
  // the popup itself.
  for (let i = 0; i < 3; i++) {
    if (await find(page, /^Menu$/, { role: 'button' })) break;
    E('shell', 'input', 'keyevent', '4');
    await sleep(900);
  }

  tapped('menu', await tapNamed(page, cdp, /^Menu$/, { role: 'button' }));
  tapped('just_verify', await tapNamed(page, cdp, /^Just Verify$/, { role: 'button' }));
  await waitFor(page, /Verify, Tokenize/, {}, 15000);
  mark('verify_open');
  await sleep(700);

  // The input is the big unlabelled box in the middle of the dialog.
  const field = await biggestBlank(page);
  await tapAt(cdp, field.x, field.y);
  tapped('paste_field', field);
  await sleep(400);
  await jcdp.detach().catch(() => {});
  await cdp.send('Input.insertText', { text: JSON.stringify(statement, null, 2) });
  mark('pasted');
  // Leave the keyboard alone. BACK hides it but Chrome also treats it as a
  // navigation and slides its history sheet over the verdict; ESC clears the
  // field outright. The results route replaces the whole dialog anyway, so the
  // keyboard is gone by the time the verdict is on screen.
  await sleep(600);

  tapped('verify', await tapNamed(page, cdp, /Verify, Tokenize/, { role: 'button' }));
  await sleep(2500);
  mark('verified');

  // "✔ VERIFIED!" is the whole point of the sequence, and it is what the take
  // ends on.
  await waitFor(page, /VERIFIED/, {}, 15000);
  mark('shown_verified');
  await sleep(3500);
  mark('done');

  rec.kill('SIGINT');
  // screenrecord finishes writing after it is asked to stop, and pulling too
  // early truncates the take -- which shows up as a video that ends before the
  // thing it was made to show.
  await sleep(7000);
  await browser.close();

  const d = new Date(), p2 = n => String(n).padStart(2, '0');
  const stamp = `${d.getFullYear()}${p2(d.getMonth() + 1)}${p2(d.getDate())}-` +
                `${p2(d.getHours())}${p2(d.getMinutes())}${p2(d.getSeconds())}`;
  const nm = `crypto_${stamp}`;
  E('pull', '/sdcard/crypto.mp4', path.join(OUT, `${nm}.mp4`));
  // Off the device once it is safely here. Every take used to leave its
  // recording behind, and they were quietly filling /data -- enough that an
  // apk install eventually failed for want of space.
  E('shell', 'rm', '-f', '/sdcard/crypto.mp4');
  fs.writeFileSync(path.join(OUT, `${nm}.marks.json`), JSON.stringify(marks, null, 2));
  console.log(`\nout/${nm}.mp4\nout/${nm}.marks.json  (${marks.taps.length} taps)`);
})().catch(e => { console.error('\nTAKE FAILED:', e.message); process.exit(1); });

const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/// Turn Show Crypto on if it is off. The menu item carries no state in the
/// tree, so this checks for a shield in the feed instead and only toggles when
/// there isn't one.
async function ensureShowCrypto(page, cdp) {
  const shields = async () => (await findAll(page, /^$/, { role: 'button' }))
    .filter(n => Math.round(n.w) === 48 && Math.round(n.h) === 48).length;
  if (await shields()) { console.log('  Show Crypto already on'); return; }
  await tapNamed(page, cdp, /^Menu$/, { role: 'button' });
  const item = await findStill(page, /^Show Crypto$/);
  await tapAt(cdp, item.x, item.y);
  await sleep(900);
  if (!await shields()) throw new Error('Show Crypto would not turn on');
  console.log('  Show Crypto turned on');
}

/// The Verify dialog's input: the largest node in it with nothing to say.
async function biggestBlank(page) {
  const all = await page.evaluate(() => window.__sem());
  const blank = all.filter(n => !n.text && n.w > 200 && n.h > 200)
    .sort((a, b) => b.w * b.h - a.w * a.h);
  if (!blank.length) throw new Error('no input box in the Verify dialog');
  return blank[0];
}
