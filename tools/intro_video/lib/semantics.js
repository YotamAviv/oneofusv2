// Make the shoot script able to *see* the Flutter app.
//
// Flutter draws to a canvas, so there are no queryable elements: taps become
// hardcoded pixels, waits become tuned sleeps, and a take that hits the wrong
// dialog still records a valid-looking file. Flutter also maintains an
// accessibility tree, and that gives back all three.
//
//   tapNamed(page, cdp, /Yes, create delegate/)   // no coordinates
//   await waitFor(page, /Create Delegate Key/)     // no sleeps
//   await assertVisible(page, /Identity\s*not present/)  // fails loudly
//
// The tree is off until something activates it. Flutter renders a hidden
// "Enable accessibility" placeholder for exactly this; clicking it is enough,
// so this works against production with no build flag.
//
// Works for Flutter **web** — Playwright directly, or Chrome inside the Android
// emulator over `adb forward tcp:9222 localabstract:chrome_devtools_remote`
// (see attachToAvdChrome). The native identity app is a separate problem: its
// nodes only surface through an Android accessibility service.

const sleep = ms => new Promise(r => setTimeout(r, ms));

/// Injected before page scripts. Reports every visible semantics node with the
/// text and centre point needed to act on it.
const SEMANTICS_PROBE = `
window.__sem = () => [...document.querySelectorAll('flt-semantics')].map(e => {
  const r = e.getBoundingClientRect();
  return {
    role: e.getAttribute('role'),
    text: (e.textContent || '').replace(/\\s+/g, ' ').trim(),
    x: r.x + r.width / 2, y: r.y + r.height / 2,
    w: r.width, h: r.height,
  };
}).filter(n => n.w > 0 && n.h > 0);
`;

/// Turn the tree on. Idempotent; safe to call repeatedly.
///
/// Needs a REAL pointer event — a synthetic `.click()` works in desktop
/// Chromium but does nothing in Chrome on Android, which is why this takes a
/// CDP session.
///
/// Tap the CENTRE. The placeholder reports a viewport-sized bounding box but
/// only responds near its middle; a corner tap silently does nothing and you get
/// "semantics tree never appeared". Measured: corner -> 0 nodes, centre -> 47.
/// Call this before the app has anything tappable in the middle of the screen,
/// or the same tap lands on app UI underneath.
async function enableSemantics(page, cdp) {
  const box = await page.evaluate(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (!ph) return null;
    const r = ph.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height };
  });
  if (box && cdp) {
    const pt = { x: Math.round(box.x + box.w / 2), y: Math.round(box.y + box.h / 2),
                 radiusX: 12, radiusY: 12, force: 1 };
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [pt] });
    await sleep(120);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  }
  for (let i = 0; i < 20; i++) {
    const n = await page.evaluate(() => document.querySelectorAll('flt-semantics').length);
    if (n > 0) return n;
    await sleep(300);
  }
  throw new Error('semantics tree never appeared — is this a Flutter web build?');
}

/// Smallest node whose text matches — nesting means a label often matches the
/// whole dialog too, and the smallest match is the specific one.
async function find(page, re, { role = null } = {}) {
  return page.evaluate(([src, flags, role]) => {
    const rx = new RegExp(src, flags);
    const hits = (window.__sem ? window.__sem() : [])
      .filter(n => rx.test(n.text) && (!role || n.role === role));
    hits.sort((a, b) => a.w * a.h - b.w * b.h);
    return hits[0] || null;
  }, [re.source, re.flags, role]);
}

/// Wait until it exists. Replaces sleeps that were guesses.
async function waitFor(page, re, opts = {}, timeout = 30000) {
  const t0 = Date.now();
  for (;;) {
    const n = await find(page, re, opts);
    if (n) return n;
    if (Date.now() - t0 > timeout) {
      const seen = await page.evaluate(() => (window.__sem ? window.__sem() : [])
        .map(n => n.text).filter(Boolean).slice(0, 12));
      throw new Error(`timeout waiting for ${re}\n  on screen: ${JSON.stringify(seen)}`);
    }
    await sleep(400);
  }
}

/// Assert something is on screen. The point is to fail *loudly*: a take that
/// records the wrong dialog is worse than one that stops.
async function assertVisible(page, re, opts = {}) {
  const n = await find(page, re, opts);
  if (!n) {
    const seen = await page.evaluate(() => (window.__sem ? window.__sem() : [])
      .map(n => n.text).filter(Boolean).slice(0, 12));
    throw new Error(`ASSERT FAILED: expected ${re}\n  on screen: ${JSON.stringify(seen)}`);
  }
  return n;
}

async function assertAbsent(page, re, opts = {}) {
  const n = await find(page, re, opts);
  if (n) throw new Error(`ASSERT FAILED: did not expect ${re} (found "${n.text}")`);
}

/// Tap a node by what it says. Waits for it first, so this also removes the
/// sleep that used to precede every tap. Returns the node, for logging the
/// coordinate a post-production tap indicator needs.
async function tapNamed(page, cdp, re, opts = {}) {
  let n = await waitFor(page, re, opts);
  // Wait for it to STOP MOVING. waitFor returns as soon as the node exists, which
  // can be mid-animation while a dialog is still sliding in -- tapping then lands
  // at where the control was, not where it is. That put a tap on "QR Code"
  // instead of the sign-in link directly above it.
  for (let i = 0; i < 25; i++) {
    await sleep(120);
    const again = await find(page, re, opts);
    if (!again) continue;
    if (Math.abs(again.x - n.x) < 1.5 && Math.abs(again.y - n.y) < 1.5) { n = again; break; }
    n = again;
  }
  const pt = { x: Math.round(n.x), y: Math.round(n.y), radiusX: 20, radiusY: 20, force: 1 };
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [pt] });
  await sleep(110);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(80);
  return n;
}

/// Attach to Chrome running inside the Android emulator, so in-device takes get
/// the same sighted driving as headless ones. Requires:
///
///   adb forward tcp:9222 localabstract:chrome_devtools_remote
///
/// Note the page is already loaded when we attach, so addInitScript is too late
/// — the probe is injected directly instead.
async function attachToAvdChrome(chromium, port = 9222) {
  const browser = await chromium.connectOverCDP(`http://localhost:${port}`);
  const ctx = browser.contexts()[0];
  const page = ctx.pages().find(p => !p.url().startsWith('chrome://')) || ctx.pages()[0];
  await page.evaluate(SEMANTICS_PROBE);
  const cdp = await ctx.newCDPSession(page);
  return { browser, page, cdp };
}

module.exports = {
  SEMANTICS_PROBE, sleep, enableSemantics, find, waitFor,
  assertVisible, assertAbsent, tapNamed, attachToAvdChrome,
};
