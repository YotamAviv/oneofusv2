#!/usr/bin/env node
// Find the red text in a frame, and report the box it occupies.
//
//   node find_red.js <take.mp4> <seconds> [x y w h]
//   -> {"x":540,"y":1832,"w":812,"h":96}      (device pixels, centre + size)
//
// WHY MEASURE, RATHER THAN WRITE PIXELS DOWN.
//
// A beat's spotlight is a rectangle on a particular take, and the honest way to
// get one has been to look at a frame and type the numbers in. That works until
// the thing being pointed at moves -- and a line inside a scrolling JSON view
// moves every take, because where it lands depends on how far the scroll got.
// The first attempt at this spotlight was derived from the scroll view's own
// box, on the assumption the signature sat near its bottom. It did not, and the
// highlight landed on empty white below the text.
//
// The Nerdster renders the `signature` key RED and nothing else in that sheet is
// red (JsonDisplay keyColors), so the app itself is saying where to point. This
// reads that back out of the recording, which is also the only place worth
// reading it from: `adb screencap` during a take is not to be trusted.
//
// Pass a region to search in. Without one the whole frame is fair game, and the
// feed behind the sheet has red cards in it.
const { execFileSync } = require('child_process');

const [src, at, rx, ry, rw, rh] = process.argv.slice(2);
if (!src || at === undefined) {
  console.error('usage: find_red.js <take.mp4> <seconds> [x y w h]');
  process.exit(1);
}

const probe = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v',
  '-show_entries', 'stream=width,height', '-of', 'csv=p=0', src],
  { encoding: 'utf8' }).trim().split(',');
const W = +probe[0], H = +probe[1];

// One frame, at or after the moment asked for, as raw rgb.
const raw = execFileSync('ffmpeg', ['-v', 'error', '-i', src,
  '-vf', `select='gte(t,${at})'`, '-frames:v', '1', '-pix_fmt', 'rgb24',
  '-f', 'rawvideo', '-'], { maxBuffer: 1 << 28 });
if (raw.length < W * H * 3) {
  console.error(`no frame at ${at}s in ${src} (${W}x${H})`);
  process.exit(1);
}

const x0 = rx === undefined ? 0 : Math.max(0, +rx);
const y0 = ry === undefined ? 0 : Math.max(0, +ry);
const x1 = rw === undefined ? W : Math.min(W, +rx + +rw);
const y1 = rh === undefined ? H : Math.min(H, +ry + +rh);

// Red text on a near-white panel. Anti-aliasing makes the edges pale, so this
// asks for red DOMINANCE rather than a particular red.
let minX = 1e9, minY = 1e9, maxX = -1, maxY = -1, n = 0;
for (let y = y0; y < y1; y++) {
  for (let x = x0; x < x1; x++) {
    const i = (y * W + x) * 3;
    const r = raw[i], g = raw[i + 1], b = raw[i + 2];
    if (r > 110 && r - g > 55 && r - b > 55) {
      n++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
}
if (n < 40) {
  console.error(`no red text at ${at}s within ${x0},${y0} ${x1 - x0}x${y1 - y0} ` +
                `(${n} red pixels). Has the signature scrolled into view?`);
  process.exit(1);
}
// --value: take in the text that FOLLOWS the red key, not just the key.
//
// The Nerdster colours the `signature` KEY red and leaves its value black, so
// the red box alone is a highlight around the word "signature" with the actual
// signature sitting outside it -- which points at the label rather than at the
// thing. The value is 128 hex characters and wraps, so how far down it runs is
// not something to write down.
//
// Measured instead: from the key's own line, walk down while rows still carry
// ink, and stop at the first real gap. That picks up the wrapped value however
// many lines it takes, and stops before the rest of the document.
if (process.argv.includes('--value')) {
  const INK = 120;                 // luma below this is text
  const GAP = 26;                  // blank rows that end the block
  const inked = y => {
    let c = 0, lo = 1e9, hi = -1;
    for (let x = x0; x < x1; x++) {
      const i = (y * W + x) * 3;
      const lum = (raw[i] * 299 + raw[i + 1] * 587 + raw[i + 2] * 114) / 1000;
      if (lum < INK) { c++; if (x < lo) lo = x; if (x > hi) hi = x; }
    }
    return c >= 3 ? { lo, hi } : null;
  };
  let blank = 0;
  for (let y = maxY + 1; y < y1 && blank < GAP; y++) {
    const row = inked(y);
    if (!row) { blank++; continue; }
    blank = 0;
    if (row.lo < minX) minX = row.lo;
    if (row.hi > maxX) maxX = row.hi;
    maxY = y;
  }
}

console.log(JSON.stringify({
  x: Math.round((minX + maxX) / 2), y: Math.round((minY + maxY) / 2),
  w: maxX - minX + 1, h: maxY - minY + 1, pixels: n,
}));
