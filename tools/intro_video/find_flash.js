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

// Mean luma per frame over the first 15s; the flash is far brighter than any UI.
const out = execFileSync('ffmpeg', ['-v', 'error', '-t', '15', '-i', src,
  '-vf', 'scale=64:-1,signalstats,metadata=print:key=lavfi.signalstats.YAVG',
  '-f', 'null', '-'], { encoding: 'utf8', stderr: 'pipe' }) || '';
const raw = execFileSync('bash', ['-c',
  `ffmpeg -v error -t 15 -i '${src}' -vf "scale=64:-1,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null - 2>/dev/null`],
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
const first = frames.find(f => dark ? f.y <= thresh : f.y >= thresh);
if (!first || Math.abs(peak - base) < 20) {
  console.error(`no clear ${dark ? 'dark ' : ''}flash ` +
    `(${dark ? 'trough' : 'peak'} ${peak.toFixed(1)}, median ${base.toFixed(1)})`);
  process.exit(1);
}
console.log(JSON.stringify({ offset: +first.t.toFixed(3), peak: +peak.toFixed(1), median: +base.toFixed(1) }));
