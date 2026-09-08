// Where the identity app's filled confirming button is, and proof that it is
// enabled.
//
// The app's confirming action is a solid filled rectangle -- teal PUBLISH on
// "Who's Key is This?", red BLOCK KEY on "New Block". Disabled it is grey, and
// the other actions (CANCEL) are thin text, so finding a large filled area of
// the right colour both locates the button and proves it can be pressed.
//
// NOT A FIXED COORDINATE. A docked keyboard pushes a dialog up and the
// coordinate that is right without one lands on a key: a take once typed `j`
// into the moniker field instead of publishing. Gboard on this emulator docks
// about as often as it floats, so neither position can be assumed.
//
// THE LARGEST CONNECTED REGION, not the bounding box of every matching pixel. A
// FOCUSED TEXT FIELD draws a teal outline, and these dialogs have one focused
// whenever they have been typed into. Boxing all of it together spans the
// outline and the button, and the centre of that box is the gap between them --
// the tap lands in a text field, the dialog stays up, and it presents as "the
// button did not work" rather than as a measurement that was never on it. The
// pixel-count guard does not catch it either: outline plus button is well over
// the threshold.
//
// This lives here rather than in a shoot script because two takes need it, and
// a copy is how shoot_signin came to keep its own broken waitForStillScreen for
// months. One implementation, one place.
const fs = require('fs');
const { execFileSync } = require('child_process');

/// THE COLOUR IS PER ACTION, not per app. Confirming is teal on the vouch and
/// delegate dialogs and RED on "New Block" -- blocking is the destructive one and
/// the app says so in the button. Passing the wrong one does not fail cleanly by
/// accident: it finds the CANCEL text, which is teal on the block dialog too,
/// and reports a 375px "button".
const HUES = {
  teal: (r, g, b) => g - r > 55 && g > 90 && Math.abs(g - b) < 45,
  red: (r, g, b) => r - g > 60 && r - b > 60 && r > 120,
};

/// `shot` is a path to a PNG of the whole screen; it is NOT deleted here.
/// `crop` is an ffmpeg crop of the region worth searching, and `y0` its top.
function findFilledButton(shot, { crop = 'crop=1080:1400:0:820', y0 = 820,
                                  minArea = 2500, what = 'button',
                                  hue = 'teal' } = {}) {
  const isHue = HUES[hue];
  if (!isHue) throw new Error(`unknown button hue "${hue}" -- ${Object.keys(HUES).join(', ')}`);
  const m = crop.match(/crop=(\d+):(\d+)/);
  const W = +m[1], H = +m[2];
  const raw = execFileSync('ffmpeg', ['-v', 'error', '-i', shot,
    '-vf', crop, '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'],
    { maxBuffer: 1 << 26 });

  const hit = new Uint8Array(W * H);
  let n = 0;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const p = y * W + x, i = p * 3;
      const r = raw[i], g = raw[i + 1], b = raw[i + 2];
      if (isHue(r, g, b)) { hit[p] = 1; n++; }
    }
  }

  // Flood fill each region in turn and keep the biggest. An explicit stack, not
  // recursion: a filled button is tens of thousands of pixels deep.
  let best = null;
  const seen = new Uint8Array(W * H);
  const stack = new Int32Array(W * H);
  for (let p0 = 0; p0 < W * H; p0++) {
    if (!hit[p0] || seen[p0]) continue;
    let top = 0, area = 0;
    let minX = W, minY = H, maxX = -1, maxY = -1;
    stack[top++] = p0; seen[p0] = 1;
    while (top) {
      const p = stack[--top], x = p % W, y = (p - x) / W;
      area++;
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
      if (x > 0 && hit[p - 1] && !seen[p - 1]) { seen[p - 1] = 1; stack[top++] = p - 1; }
      if (x < W - 1 && hit[p + 1] && !seen[p + 1]) { seen[p + 1] = 1; stack[top++] = p + 1; }
      if (y > 0 && hit[p - W] && !seen[p - W]) { seen[p - W] = 1; stack[top++] = p - W; }
      if (y < H - 1 && hit[p + W] && !seen[p + W]) { seen[p + W] = 1; stack[top++] = p + W; }
    }
    if (!best || area > best.area) best = { area, minX, minY, maxX, maxY };
  }

  // A filled button is thousands of pixels; text and a field outline are hundreds
  // each, and now they are measured one at a time rather than together.
  if (!best || best.area < minArea) {
    throw new Error(`no enabled ${what} on screen `
      + `(largest ${hue} region ${best ? best.area : 0} px, ${n} ${hue} in all). `
      + 'It stays disabled until the dialog is complete, so whatever it is '
      + 'waiting for probably has not landed.');
  }
  return {
    x: Math.round((best.minX + best.maxX) / 2),
    y: Math.round(y0 + (best.minY + best.maxY) / 2),
    area: best.area,
  };
}

// findTealButton is the old name, kept because shoot_vouch.js reads better with
// it and the teal default is what it wants.
const findTealButton = (shot, opts = {}) => findFilledButton(shot, { ...opts, hue: 'teal' });

module.exports = { findFilledButton, findTealButton };
