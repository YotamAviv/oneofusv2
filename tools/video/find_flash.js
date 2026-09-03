#!/usr/bin/env node
// Locate the sync flash in a take and report the offset to apply to its marks.
//
// The shoot script paints the screen white for ~0.4s and zeroes its clock at
// that instant. Whatever timestamp that frame has in the video IS the offset
// between the script clock and the footage.
//
//   node find_flash.js out/signin_<stamp>.mp4
//   node find_flash.js out/browser_<stamp>.mp4 --dark
//
// --dark looks for the darkest frame instead of the brightest. A take that is
// mostly white -- a browser -- swallows a white flash, since the flash has to
// beat the median and the median is already near white. Those takes flash black.
// The shoot script records which it used, and overlay_taps.js passes it on.
const { execFileSync } = require('child_process');
const src = process.argv[2];
if (!src) { console.error('usage: find_flash.js <take.mp4>'); process.exit(1); }

// Mean luma over the first 15s, sampled at a FIXED rate; the flash is far
// brighter (or darker) than any UI.
//
// fps=10 matters. screenrecord is variable-rate: a screen that isn't moving
// emits almost no frames, so a median taken over frames is weighted by motion
// rather than by time. On a take that sat still on a dark home screen and then
// opened an app with a white splash, that put the median at 216 against a peak
// of 233 and the flash was declared missing. Sampling evenly makes the median
// mean what it looks like it means.
const out = execFileSync('ffmpeg', ['-v', 'error', '-t', '15', '-i', src,
  '-vf', 'scale=64:-1,signalstats,metadata=print:key=lavfi.signalstats.YAVG',
  '-f', 'null', '-'], { encoding: 'utf8', stderr: 'pipe' }) || '';
const raw = execFileSync('bash', ['-c',
  `ffmpeg -v error -t 15 -i '${src}' -vf "fps=10,scale=64:-1,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null - 2>/dev/null`],
  { encoding: 'utf8' });

const frames = [];
let t = null;
for (const line of raw.split('\n')) {
  const m = line.match(/pts_time:([\d.]+)/);
  if (m) { t = parseFloat(m[1]); continue; }
  const y = line.match(/YAVG=([\d.]+)/);
  if (y && t !== null) { frames.push({ t, y: parseFloat(y[1]) }); t = null; }
}
if (!frames.length) { console.error('no luma data'); process.exit(1); }

const dark = process.argv.includes('--dark');
const peak = dark ? Math.min(...frames.map(f => f.y)) : Math.max(...frames.map(f => f.y));
const base = frames.map(f => f.y).sort((a, b) => a - b)[Math.floor(frames.length / 2)];
const thresh = base + (peak - base) * 0.75;
const over = f => (dark ? f.y <= thresh : f.y >= thresh);

// The flash is an EDGE, not a state. Every shoot script sleeps for seconds
// after starting the recorder so the flash lands well inside the take, and a
// take can legitimately OPEN on the wrong side of the threshold: invite begins
// on a dim app screen at luma 82, against a black flash at 36 and a threshold
// of 84. Taking that opening run as the flash reports offset 0 and shifts
// every mark in the section by the length of the head -- it put invite's taps
// and highlights 5.4s out of place, on a take that was otherwise perfect.
// So skip any opening run and match only where a frame CROSSES.
let first = null;
for (let i = 1; i < frames.length; i++) {
  if (over(frames[i]) && !over(frames[i - 1])) { first = frames[i]; break; }
}
if (!first || Math.abs(peak - base) < 20) {
  console.error(`no clear ${dark ? 'dark ' : ''}flash ` +
    `(${dark ? 'trough' : 'peak'} ${peak.toFixed(1)}, median ${base.toFixed(1)})`);
  process.exit(1);
}
console.log(JSON.stringify({ offset: +first.t.toFixed(3), peak: +peak.toFixed(1), median: +base.toFixed(1) }));
