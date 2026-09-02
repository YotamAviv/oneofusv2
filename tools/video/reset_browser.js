#!/usr/bin/env node
// Put the Nerdster tab back to signed-out.
//
// "Store keys" persists identity and delegate in the page, so a take that starts
// signed in never shows the "Create Delegate Key?" prompt -- it shows "Existing
// Delegate Found" or skips the app entirely. That silently ruins takes.
//
// Doing this through the UI is a trap: it takes two steps (Sign out clears only
// the delegate, then the dialog offers Forget identity where Sign out was), the
// dialog changes height between them, and the control that opens it only exists
// while signed in. Several takes were lost to half-completed UI resets.
//
// Flutter web keeps them in localStorage under FlutterSecureStorage*, so clear
// that and reload. Nothing here is on camera; it only has to be reliable.
//
//   adb forward tcp:9222 localabstract:chrome_devtools_remote
//   node reset_browser.js
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const { SEMANTICS_PROBE, sleep, enableSemantics, assertVisible } = require('./lib/semantics');

const SERIAL = process.env.AVD || 'emulator-5554';
const E = (...a) => execFileSync('adb', ['-s', SERIAL, ...a], { stdio: 'ignore' });

(async () => {
  E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
    '-d', 'https://nerdster.org/app', '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await sleep(14000);

  const b = await chromium.connectOverCDP('http://localhost:9222');
  const ctx = b.contexts()[0];
  let page = ctx.pages().find(p => p.url().includes('/app')) || ctx.pages()[0];

  const cleared = await page.evaluate(() => {
    const keys = Object.keys(localStorage).filter(k => k.startsWith('FlutterSecureStorage'));
    keys.forEach(k => localStorage.removeItem(k));
    return keys;
  });
  console.log('cleared:', cleared.join(', ') || '(nothing)');

  // AND through the storage service, because removeItem alone does not survive
  // a force-stop. Chrome keeps localStorage in memory and flushes lazily: a
  // reload after removeItem reads the in-memory map and looks clean, but the
  // take that follows force-stops Chrome, the unflushed deletes are lost, and
  // /app comes back holding a delegate key with its identity truncated out from
  // under it -- "Signed in with Identity and Delegate (not associated with
  // identity)", several steps from anything that mentions storage.
  const cdp0 = await ctx.newCDPSession(page);
  await cdp0.send('Storage.clearDataForOrigin',
                  { origin: 'https://nerdster.org', storageTypes: 'local_storage' });
  await cdp0.detach().catch(() => {});

  // Restart Chrome and verify THERE. The old check ran against the page it had
  // just cleared, which is not the state any take starts from.
  E('shell', 'am', 'force-stop', 'com.android.chrome');
  await sleep(2000);
  E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW',
    '-d', 'https://nerdster.org/app', '-n', 'com.android.chrome/com.google.android.apps.chrome.Main');
  await sleep(14000);
  try { E('forward', '--remove-all'); } catch { /* none */ }
  E('forward', 'tcp:9222', 'localabstract:chrome_devtools_remote');
  await sleep(1500);
  await b.close().catch(() => {});

  const b2 = await chromium.connectOverCDP('http://localhost:9222');
  const ctx2 = b2.contexts()[0];
  page = ctx2.pages().find(p => p.url().includes('/app')) || ctx2.pages()[0];
  const left = await page.evaluate(() => Object.keys(localStorage));
  if (left.length) {
    throw new Error('localStorage survived the restart: ' + left.join(', '));
  }
  await sleep(6000);

  // Prove it, rather than assume: signed out means the dialog auto-shows.
  const cdp = await ctx2.newCDPSession(page);
  await page.evaluate(SEMANTICS_PROBE);
  await enableSemantics(page, cdp);
  await assertVisible(page, /Identity\s*not present/);
  await assertVisible(page, /Delegate\s*not present/);
  console.log('verified: signed out, both keys absent');
  await b2.close();
})().catch(e => { console.error('RESET FAILED:', e.message.split('\n')[0]); process.exit(1); });
