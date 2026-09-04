#!/usr/bin/env node
// Find the "Trusted: Success" snackbar in a take, and report when it came and went.
//
//   node find_snackbar.js out/vouch/<stamp>/vouch.mp4
//   -> {"appeared":38.2,"cleared":44.6}      (seconds into the video)
//
// WHY THIS IS DONE AFTERWARDS, and not watched for on the live screen.
//
// `adb exec-out screencap` returns a FROZEN FRAME while `screenrecord` is
// running on this emulator. Three detectors were written against the live
// screen before that was understood -- one hashing for stillness, one for
// motion, one for colour -- and all three failed the same way: the hash never
// changed, the motion never came, the colour read a constant rgb(202,204,206)
// for 170 seconds while the snackbar visibly appeared and disappeared. The take
// itself recorded all of it.
//
// So this is the same shape as find_flash.js: the take records, and the moment
// is found in the footage afterwards. It is also more precise than a live
// sampler could be, because it sees every frame rather than one every 250ms.
//
// The snackbar is a saturated teal bar across the bottom of an otherwise
// neutral screen: measured with nothing showing, that strip is rgb(235,233,234)
// and green-minus-red sits within a couple of points of zero.
const { execFileSync } = require('child_process');

const src = process.argv[2];
if (!src) { console.error('usage: find_snackbar.js <take.mp4> [--after <seconds>]'); process.exit(1); }
// --after, because the FIRST teal bar in a take is not necessarily the one being
// looked for. Widening the search to the whole lower half (so a docked keyboard
// cannot hide the bar) also brought the app's own teal into range, and the scan
// settled on something at 13s -- sixteen seconds before the statement was even
// published. The take knows when it tapped PUBLISH; it should say so.
const afterArg = process.argv.indexOf('--after');
const AFTER = afterArg >= 0 ? parseFloat(process.argv[afterArg + 1]) : 0;

// THE BOTTOM-MOST STRIP. Getting this wrong is subtle rather than obvious: a
// band 115px higher catches only the snackbar's top edge and averages the rest
// away against the grey above it, giving green-minus-red of 21 where the real
// bar gives 133. Twenty-one sits just under any sane threshold, so the bar is
// on screen, plainly visible to a person, and the scan reports nothing.
//
// Sampled at 10fps: the snackbar is up for seconds, so this cannot miss it.
// THE WHOLE LOWER HALF, scanned row by row -- not a fixed band at the bottom.
//
// The bar is normally the bottom-most strip, and this used to crop exactly
// there. But Flutter puts a SnackBar ABOVE the soft keyboard, and Gboard on this
// emulator docks about as often as it floats. Docked, the bar is some 900px
// higher than the band, the band shows keyboard, and the scan reports nothing at
// all -- for a take where the bar was plainly on screen.
const TOP = 1100, HEIGHT = 1120;
const CROP = `crop=1000:${HEIGHT}:40:${TOP}`;
const ROWS = 140;                    // the crop, averaged into this many rows
const FPS = 10;
const GREEN_OVER_RED = 25;

const raw = execFileSync('ffmpeg', ['-v', 'error', '-i', src,
  '-vf', `fps=${FPS},${CROP},scale=1:${ROWS}`, '-pix_fmt', 'rgb24',
  '-f', 'rawvideo', '-'], { maxBuffer: 1 << 28 });

// One column of ROWS pixels per frame: each is a row average, so a bar anywhere
// in the region shows up as a run of teal rows however high it sits.
// A BAR, not a teal pixel. Scanning the whole lower half means the app's own
// teal -- its logo, its buttons -- is in range, and a single teal row matched
// the welcome screen four seconds into every take. The snackbar is ~100px of
// SATURATED teal across the full width, so it is a RUN of strongly teal rows;
// nothing else in this app is.
const STRONG = 60;                   // the real bar gives ~133
const MIN_RUN = 8;                   // rows, each ~8px here
let appeared = null, cleared = null;
const frames = Math.floor(raw.length / (3 * ROWS));
for (let f = 0; f < frames; f++) {
  let run = 0, best = 0;
  for (let y = 0; y < ROWS; y++) {
    const i = (f * ROWS + y) * 3;
    run = raw[i + 1] - raw[i] > STRONG ? run + 1 : 0;
    if (run > best) best = run;
  }
  const bar = best >= MIN_RUN;
  const t = f / FPS;
  if (t < AFTER) continue;
  if (bar && appeared === null) appeared = t;
  if (!bar && appeared !== null && cleared === null && t > appeared) cleared = t;
}
if (appeared === null) {
  console.error(`no snackbar in ${src}: nothing in the bottom strip went green.`);
  process.exit(1);
}
// WHERE it is, as well as when. A beat can point at the snackbar now that the
// prompter is a caption that comes and goes rather than a band nailed to the
// bottom of the frame -- but only if something knows the rectangle, and the bar
// is drawn by the framework, not by a widget any script can ask.
//
// Measured, not typed: one frame while the bar is up, scaled to a single column
// so each pixel is a row average, then the run of teal rows IS the bar. The
// horizontal extent is the crop's, which is the full width less its margins;
// the bar spans it.
const at = (appeared + 0.4).toFixed(2);
const col = execFileSync('ffmpeg', ['-v', 'error', '-ss', at, '-i', src,
  '-frames:v', '1', '-vf', `crop=1000:${HEIGHT}:40:${TOP},scale=1:${HEIGHT}`,
  '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'], { maxBuffer: 1 << 24 });
let top = null, bottom = null;
for (let y = 0; y < HEIGHT; y++) {
  const r = col[y * 3], g = col[y * 3 + 1];
  if (g - r > STRONG) { if (top === null) top = y; bottom = y; }
}
const box = top === null ? null : {
  x: 540, y: Math.round(TOP + (top + bottom) / 2),
  w: 1000, h: Math.max(1, bottom - top + 1),
};

// Not finding the end is not a failure -- a take can stop while it is still up.
console.log(JSON.stringify({ appeared: +appeared.toFixed(2),
                             cleared: cleared === null ? null : +cleared.toFixed(2),
                             box }));
