#!/usr/bin/env node
// Shoot the crypto TEASER for the intro: turn Show Crypto and Show FYI on in
// shot, like something, and watch the Nerdster show its working -- what it is
// about to sign and with whose key, then the published statement with the
// signature on the end of it -- and finally a refresh, where a service reads
// those statements back.
//
// The point is that this is the USER'S OWN ACT, not an inspection of somebody
// else's data: you like a book, and the app tells you exactly what it is about
// to sign, with which key, and shows you the signature it produced. The full
// walk -- identity key, delegate key, the delegation tying them together -- is
// shoot_crypto.js, and belongs to the "How it works" video.
//
//   node shoot_crypto_teaser.js
//
// Writes out/crypto_teaser/<stamp>/crypto_teaser.mp4 + .marks.json.
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
const OUT = buildDir('crypto_teaser');
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

  // --- reset: undo what earlier takes published to nerdster.org ---
  //
  // This take has to REACT to something, and a card you have already reacted to
  // has no React button on it. Run it twice without this and the feed is all
  // "Me@nerdster.org 👍" with nothing left to like, which surfaces as "no React
  // button in the feed" several steps from the cause.
  //
  // nerdster.org only. The vouch and the delegate key live on one-of-us.net and
  // are not touched, so this costs nothing but the ratings this take makes.
  // Same command shoot_nerdster.sh runs, and named by who delegated the key
  // rather than by the key itself, which is minted fresh on every sign-in.
  {
    const token = Object.values(require('./demo_identity.json').demoTokens)[0];
    console.log('clearing what earlier takes published to nerdster.org');
    execFileSync('node', ['truncate_statements.js', '--delegate-of', token,
      '--domain', 'nerdster.org', '--project', 'nerdster', '--prod', '--all'],
      { cwd: __dirname, env: { ...process.env, I_MEAN_IT: 'yes' }, stdio: 'inherit' });
  }

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

  // At the top before recording. The app bar HIDES WHEN THE FEED SCROLLS, and
  // both the menu and the refresh this take needs live in it, so a take that
  // opens on a scrolled feed cannot reach either.
  //
  // No subject to pick any more. This section is about a statement the user
  // makes, not one somebody else made, so it acts on whatever card is on top.
  for (let i = 0; i < 14; i++) {
    if (await find(page, /^Menu$/, { role: 'button' })) break;
    await drag(cdp, 200, 300, 0, { dy: 600, holdMs: 0 });
    await sleep(500);
  }
  if (!await find(page, /^Menu$/, { role: 'button' })) {
    throw new Error('could not scroll back to the top: the app bar never reappeared');
  }

  // --- record ---
  // Chrome opens a tab per VIEW intent and nothing closed them; thirty had
  // piled up, and enough of them throttle screenrecord. Swept before the
  // camera, so a crashed take is cleaned up by the next one.
  await require('./lib/device').device().closeChromeTabs();

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

  // Open on the feed for a beat before touching anything. The section needs a
  // moment to say what it is about before the menu covers half the screen, and
  // trimming to tap_menu put the viewer inside the menu from frame one.
  mark('feed');
  await sleep(4200);

  // --- turn the crypto on, and the FYI with it ---
  // Show Crypto puts the shields on screen; Show FYI is what makes the Nerdster
  // show its working before it publishes, which is the whole subject here.
  tapped('menu', await tapNamed(page, cdp, /^Menu$/, { role: 'button' }));
  await sleep(1400);
  // The CHECKBOX, not the label: MyCheckbox renders Row([Checkbox, Text(title)])
  // and the words are not a button.
  const cryptoBox = await menuCheckbox(page, /^Show Crypto$/);
  await tapAt(cdp, cryptoBox.x, cryptoBox.y);
  tapped('show_crypto', cryptoBox);
  await sleep(900);
  if (!await showCryptoOn(page)) throw new Error('Show Crypto did not turn on in shot');
  mark('crypto_on');
  // A beat on each toggle, because each gets a line of narration saying what it
  // just did -- tapped back to back they were 1.8s apart and the second line
  // arrived before the first could be read. 3.4s is about what those lines need
  // at a readable pace; 4.6 was generous and it showed, as nine seconds of an
  // open menu that is not itself the point.
  await sleep(3400);

  const fyiBox = await menuCheckbox(page, /^Show FYI$/);
  await tapAt(cdp, fyiBox.x, fyiBox.y);
  tapped('show_fyi', fyiBox);
  mark('fyi_on');
  await sleep(3400);

  // CLOSE THE MENU, AND PROVE IT CLOSED.
  //
  // Checkbox items leave it open, and with the menu still up the React this take
  // looks for next is found in the feed BEHIND it -- the tap then lands on
  // whatever menu item sits at those coordinates. It hit "Just Verify".
  //
  // By tapping the barrier, NOT with BACK. Repeating BACK until the menu goes is
  // how the tab gets closed instead: the first one dismisses the menu, the check
  // has not caught up, and the second is Chrome's own navigation on a tab with
  // nothing behind it.
  // TAP THE MENU BUTTON AGAIN. MenuAnchor toggles on its anchor, and that is the
  // only close that proved reliable here: BACK did not shut it after two
  // checkbox taps, and a synthetic tap outside it did nothing either. BACK is
  // also the dangerous one -- press it when the menu has already gone and it is
  // Chrome's navigation, which closes a tab with no history behind it.
  await tapNamed(page, cdp, /^Menu$/, { role: 'button' });
  await sleep(1800);
  if (await find(page, /^Show Crypto$/, {})) {
    throw new Error('the feed menu would not close: taps meant for the feed would '
      + 'land on it instead.');
  }
  await sleep(1400);

  // --- like something, so there is a statement to publish ---
  // The topmost React on screen. shoot_nerdster.js is fussier about which card
  // it lands on because it swipes cards away first; nothing has moved here, so
  // the highest one in the viewport is the card the viewer is looking at.
  const reacts = (await findAll(page, /^React$/, { role: 'button' }))
    .filter(n => n.y > 110).sort((a, b) => a.y - b.y);
  if (!reacts.length) {
    throw new Error('no React button in the feed to like. Is the feed empty, or '
      + 'is something still covering it?');
  }
  // The topmost one below the toolbar. A fixed band was too fussy: once a card
  // carries "You reacted to this" its buttons sit lower, and the take then found
  // nothing at all.
  const react = reacts[0];
  await tapAt(cdp, react.x, react.y);
  tapped('react', react);
  await waitFor(page, /^Rate & Comment$/, {}, 15000);
  // Each card carries a React of its own plus one per statement on it. Landing
  // on the wrong one aims the dialog at somebody's reaction rather than the
  // book, and the take would look right and mean nothing.
  await assertAbsent(page, /Reacting to a reaction/);
  mark('rate_open');
  await sleep(1200);

  const up = await thumbsUp(page);
  await tapAt(cdp, up.x, up.y);
  tapped('like', up);
  mark('liked');
  await sleep(1400);

  tapped('publish', await tapNamed(page, cdp, /^Publish$/, { role: 'button' }));

  // --- what it is about to sign, and with whose key ---
  // If Show FYI was already on, the tap above turned it OFF and this never
  // comes. Say so rather than timing out into a shrug.
  const fyi = await waitFor(page, /^FYI: To be signed and published/, {}, 20000)
    .catch(() => { throw new Error('the FYI sheet never came. Was Show FYI already '
      + 'on before the take, so that turning it "on" turned it off?'); });
  mark('fyi_shown');
  marks.fyiText = { x: Math.round(fyi.x), y: Math.round(fyi.y),
                    w: Math.round(fyi.w), h: Math.round(fyi.h) };
  await sleep(4200);

  tapped('fyi_okay', await tapNamed(page, cdp, /^Okay$/, { role: 'button' }));
  await waitFor(page, /^Published ✓$/, {}, 25000);
  mark('published_shown');

  // The export link, measured, so a beat can point at it. It is the statement's
  // address on the open network -- anyone can fetch it and check the signature,
  // which is the whole claim this section is making.
  const link = await find(page, /export\.nerdster\.org/);
  if (link) {
    const c = toDevice(link.x, link.y);
    marks.exportLinkBox = { x: c.x, y: c.y,
      w: Math.round(link.w * VIEW2DEV.scale), h: Math.round(link.h * VIEW2DEV.scale) };
    mark('export_link_shown');
    console.log(`  exportLinkBox ${JSON.stringify(marks.exportLinkBox)}`);
  } else {
    // Loud, not silent: the cue that names this box would otherwise fail later
    // with "beat names box exportLinkBox, which this take did not measure".
    console.error('  WARNING: no export.nerdster.org link in the Published sheet.');
  }
  await sleep(4200);

  // --- the statement itself, and the signature on the end of it ---
  tapped('interpret', await tapNamed(page, cdp, /Interpreted → Raw/, { role: 'button' }));
  await waitFor(page, /"signature"|"statement"|"crv"/, {}, 15000);
  mark('raw_shown');
  await sleep(1200);

  // The sheet's JSON is a scroll view about 200px tall, so the signature -- the
  // last line, and the red one -- is below the fold. Drag inside it rather than
  // on the page, or the feed behind scrolls instead.
  // find, not findStill. The sheet is not animating by now, and findStill polls
  // for up to three seconds waiting to be sure -- three seconds of a viewer
  // watching nothing happen, on top of the drags themselves.
  const json = await find(page, /"signature"|"statement"|"crv"/);
  if (!json) throw new Error('no JSON in the published sheet to scroll');
  // ONE flick to the bottom, not four crawls. Four drags of ninety pixels with
  // half a second between them spent seconds on nothing but scrolling. The view
  // is short and a fling carries past its end and settles there, so one long
  // throw lands where four crawls did.
  await drag(cdp, Math.round(json.x), Math.round(json.y), 0, { dy: -420, holdMs: 60 });
  await sleep(800);
  mark('signature_shown');
  marks.jsonBox = { x: Math.round(json.x), y: Math.round(json.y),
                    w: Math.round(json.w), h: Math.round(json.h) };
  await sleep(4600);

  tapped('published_okay', await tapNamed(page, cdp, /^Okay$/, { role: 'button' }));
  await sleep(2200);
  mark('dismissed');
  await sleep(2600);

  // --- and the other side of it: a service reading the statements back ---
  // The refresh shows a loading bar above the toolbar for a moment. It is far
  // too brief to read at speed, so the section stops on it: `beats:` in the
  // storyboard freezes this frame and points at it.
  // No role filter. "Refresh" reaches the tree as a Tooltip label node with a
  // null role; the button beside it at the same coordinates is unnamed. "Menu"
  // happens to produce both, which is why asking for role:'button' works there
  // and silently finds nothing here.
  const refresh = await findStill(page, /^Refresh$/, {});
  await tapAt(cdp, refresh.x, refresh.y);
  tapped('refresh', refresh);
  mark('loading');
  marks.refreshBox = { x: Math.round(refresh.x), y: Math.round(refresh.y),
                       w: Math.round(refresh.w), h: Math.round(refresh.h) };
  await sleep(5200);
  mark('done');

  // Stop it on the DEVICE and wait for the file to settle. Killing the local
  // adb first severs the shell before screenrecord can write its moov atom,
  // and the pulled file is then not a video at all.
  await require('./lib/device').device().stopRecording('/sdcard/crypto_teaser.mp4');
  rec.kill();
  await browser.close();

  // The stamp is on the build directory (lib/build_dir.js), so the take
  // inside it is named for what it is and nothing else.
  const nm = 'crypto_teaser';
  E('pull', '/sdcard/crypto_teaser.mp4', path.join(OUT, `${nm}.mp4`));
  // Off the device once it is safely here. Every take used to leave its
  // recording behind, and they were quietly filling /data -- enough that an
  // apk install eventually failed for want of space.
  E('shell', 'rm', '-f', '/sdcard/crypto_teaser.mp4');
  // WHERE THE SIGNATURE ACTUALLY IS, measured off the recording.
  //
  // The storyboard used to carry a spotlight rectangle typed in by hand, and it
  // missed: a line inside a scrolling view lands wherever the scroll got to,
  // which is not the same twice. The Nerdster renders the `signature` key red
  // and nothing else in that sheet is, so find_red.js reads the box back out of
  // the frame. The storyboard then names the measurement -- `box: signatureBox`
  // -- instead of naming pixels.
  //
  // --value, because only the KEY is red. Without it the highlight goes around
  // the word "signature" while the signature itself sits outside it, which
  // points at the label rather than at the thing. --value walks down the ink
  // that follows and takes the wrapped value in too, however many lines it runs
  // to.
  try {
    const take = path.join(OUT, `${nm}.mp4`);
    const off = JSON.parse(execFileSync('node',
      [path.join(__dirname, 'find_flash.js'), take], { encoding: 'utf8' })).offset;
    const v = marks.viewportToDevice, j = marks.jsonBox;
    const region = [Math.round(j.x * v.scale - j.w * v.scale / 2),
                    Math.round(j.y * v.scale + v.offY - j.h * v.scale / 2),
                    Math.round(j.w * v.scale), Math.round(j.h * v.scale)];
    const box = JSON.parse(execFileSync('node',
      [path.join(__dirname, 'find_red.js'), take,
       String(marks.signature_shown + off), ...region.map(String), '--value'],
      { encoding: 'utf8' }));
    marks.signatureBox = box;
    console.log(`  signatureBox ${box.x},${box.y} ${box.w}x${box.h}  (from the footage)`);
  } catch (e) {
    console.error('  COULD NOT MEASURE THE SIGNATURE:', e.message.split('\n')[0]);
    console.error('  The beat aimed at it will fall back on nothing -- check the take.');
  }
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
