// Touch driving + visible finger overlay for Flutter-web screen recordings.
//
// Two halves:
//   OVERLAY  - injected into the page; draws the contact blob, its motion trail,
//              and a release ripple, driven by the page's own touch events.
//   tap/swipe - dispatch real touch events over CDP so Flutter applies its own
//              fling physics.

const sleep = ms => new Promise(r => setTimeout(r, ms));

// Injected before any page script.
const OVERLAY = `
(() => {
  const NS = '__touchviz';
  if (window[NS]) return;
  window[NS] = true;

  const R = 27;              // contact radius, CSS px
  const FOLLOW = 0.42;       // per-frame approach to the true finger position
  const TRAIL_EVERY = 20;    // ms between trail dots
  const TRAIL_LIFE = 540;    // ms for a trail dot to fade out

  const ready = () => {
    const layer = document.createElement('div');
    layer.style.cssText =
      'position:fixed;inset:0;pointer-events:none;z-index:2147483647;overflow:hidden';
    document.body.appendChild(layer);

    // The contact blob. Lit from the upper left so it reads as a soft fingertip
    // rather than a flat disc, with a light ring outside a dark one so it holds
    // contrast over both white cards and dark poster art.
    const blob = document.createElement('div');
    blob.style.cssText =
      'position:absolute;left:0;top:0;width:' + (R*2) + 'px;height:' + (R*2) + 'px;' +
      'margin:' + (-R) + 'px 0 0 ' + (-R) + 'px;border-radius:50%;' +
      'background:radial-gradient(circle at 34% 28%,' +
        'rgba(255,255,255,.92) 0%,rgba(255,255,255,.62) 40%,rgba(255,255,255,.30) 100%);' +
      'border:2px solid rgba(15,20,26,.55);' +
      'box-shadow:0 0 0 2px rgba(255,255,255,.95),0 0 20px rgba(255,255,255,.55),' +
        '0 4px 16px rgba(0,0,0,.45),inset 0 -7px 14px rgba(0,0,0,.12);' +
      'opacity:0;transform:translate(-100px,-100px) scale(.5);' +
      'transition:opacity .10s linear,transform .16s cubic-bezier(.2,1.5,.4,1);' +
      'will-change:transform,opacity';
    layer.appendChild(blob);

    let tx = 0, ty = 0;        // where the finger actually is
    let cx = 0, cy = 0;        // where we've drawn it
    let down = false, raf = 0, lastTrail = 0, primed = false;

    const paint = (scale) =>
      blob.style.transform = 'translate(' + cx + 'px,' + cy + 'px) scale(' + scale + ')';

    const trailDot = (x, y) => {
      const d = document.createElement('div');
      const r = R * 0.62;
      d.style.cssText =
        'position:absolute;left:0;top:0;width:' + (r*2) + 'px;height:' + (r*2) + 'px;' +
        'margin:' + (-r) + 'px 0 0 ' + (-r) + 'px;border-radius:50%;' +
        'background:radial-gradient(circle,rgba(255,255,255,.80),rgba(255,255,255,.24));' +
        'box-shadow:0 0 10px rgba(255,255,255,.40);' +
        'transform:translate(' + x + 'px,' + y + 'px) scale(1);opacity:.78;' +
        'transition:transform ' + TRAIL_LIFE + 'ms linear,opacity ' + TRAIL_LIFE + 'ms linear';
      layer.insertBefore(d, blob);   // trail sits under the blob
      requestAnimationFrame(() => {
        d.style.transform = 'translate(' + x + 'px,' + y + 'px) scale(.35)';
        d.style.opacity = '0';
      });
      setTimeout(() => d.remove(), TRAIL_LIFE + 60);
    };

    const ripple = (x, y) => {
      const d = document.createElement('div');
      d.style.cssText =
        'position:absolute;left:0;top:0;width:' + (R*2) + 'px;height:' + (R*2) + 'px;' +
        'margin:' + (-R) + 'px 0 0 ' + (-R) + 'px;border-radius:50%;' +
        'border:2.5px solid rgba(255,255,255,.9);' +
        'box-shadow:0 0 0 1.5px rgba(0,0,0,.35),0 0 14px rgba(255,255,255,.45);' +
        'transform:translate(' + x + 'px,' + y + 'px) scale(.55);opacity:.95;' +
        'transition:transform .52s cubic-bezier(.15,.75,.25,1),opacity .52s ease-out';
      layer.appendChild(d);
      requestAnimationFrame(() => {
        d.style.transform = 'translate(' + x + 'px,' + y + 'px) scale(2.3)';
        d.style.opacity = '0';
      });
      setTimeout(() => d.remove(), 700);
    };

    // Chase the true position instead of snapping to it. Touch events arrive in
    // discrete jumps; easing between them reads as a hand moving rather than a
    // cursor teleporting.
    const tick = () => {
      raf = requestAnimationFrame(tick);
      const dx = tx - cx, dy = ty - cy;
      const moving = Math.abs(dx) + Math.abs(dy) > 0.4;
      if (moving) { cx += dx * FOLLOW; cy += dy * FOLLOW; }
      paint(down ? 1 : 0.5);
      if (down && moving) {
        const now = performance.now();
        if (now - lastTrail > TRAIL_EVERY) { lastTrail = now; trailDot(cx, cy); }
      }
    };

    const press = (x, y) => {
      tx = x; ty = y;
      if (!primed) { cx = x; cy = y; primed = true; }   // first touch: no fly-in
      down = true;
      blob.style.opacity = '1';
      paint(1);
      if (!raf) tick();
    };
    const drag = (x, y) => { tx = x; ty = y; };
    const lift = (x, y) => {
      down = false;
      cx = tx = x; cy = ty = y;
      paint(1.18);
      blob.style.opacity = '0';
      ripple(x, y);
      setTimeout(() => { if (!down) { cancelAnimationFrame(raf); raf = 0; } }, 260);
    };

    const pt = e => (e.touches && e.touches[0]) || (e.changedTouches && e.changedTouches[0]);
    const opt = { capture: true, passive: true };
    addEventListener('touchstart', e => { const t = pt(e); if (t) press(t.clientX, t.clientY); }, opt);
    addEventListener('touchmove',  e => { const t = pt(e); if (t) drag(t.clientX, t.clientY); }, opt);
    addEventListener('touchend',   e => { const t = pt(e); if (t) lift(t.clientX, t.clientY); }, opt);

    // Fallback, if a future app version ever swallows touch events before window.
    window.__finger = (x, y, state) =>
      state === 'down' ? press(x, y) : state === 'up' ? lift(x, y) : drag(x, y);
  };
  if (document.body) ready(); else addEventListener('DOMContentLoaded', ready);
})();
`;

const P = (x, y) => ({ x: Math.round(x), y: Math.round(y), radiusX: 22, radiusY: 22, force: 1 });
const send = (cdp, type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points });

async function tap(cdp, p, x, y, hold = 120) {
  await send(cdp, 'touchStart', [P(x, y)]);
  await sleep(hold);
  await send(cdp, 'touchEnd', []);
  await sleep(70);
}

// A flick, not a linear drag: the finger lands, dwells a beat, accelerates, then
// is lifted while still moving so Flutter takes over with its own fling. The
// slight sideways drift keeps it from looking machine-drawn.
async function swipe(cdp, x, yFrom, yTo, ms = 340, steps = 26, drift = 9) {
  await send(cdp, 'touchStart', [P(x, yFrom)]);
  await sleep(55);                                  // contact before travel
  const dt = ms / steps;
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const ease = t < 0.22
      ? 2.1 * t * t                                 // push off
      : 1 - Math.pow(1 - t, 2.1);                   // then run out
    const wobble = Math.sin(t * Math.PI) * drift;   // widest mid-stroke
    await send(cdp, 'touchMove', [P(x + wobble, yFrom + (yTo - yFrom) * ease)]);
    await sleep(dt);
  }
  await send(cdp, 'touchEnd', []);                  // released in motion -> fling
}

module.exports = { OVERLAY, sleep, tap, swipe };
