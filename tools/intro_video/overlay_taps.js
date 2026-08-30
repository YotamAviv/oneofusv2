#!/usr/bin/env node
// Burn the touch indicators onto a take, using the coordinates the shoot script
// logged. Marks are in device pixels (same space as the recording), so nothing
// is converted here -- an earlier version converted after the fact and put the
// circles on feed content instead of the buttons.
//
//   node overlay_taps.js out/signin_<stamp>.mp4
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { TRIM_PAD } = require('./lib/marks');

const src = process.argv[2];
if (!src) { console.error('usage: overlay_taps.js out/signin_<stamp>.mp4'); process.exit(1); }
const marks = JSON.parse(fs.readFileSync(src.replace(/\.mp4$/, '.marks.json'), 'utf8'));

// Align the script clock to the footage using the sync flash. Without this the
// indicators run ~2.5-4s early: screenrecord keeps capturing for seconds after
// the process spawns, so a clock zeroed at spawn is ahead of the video.
let OFFSET = 0;
try {
  OFFSET = JSON.parse(execFileSync('node',
    [path.join(__dirname, 'find_flash.js'), src], { encoding: 'utf8' })).offset;
  console.log(`sync flash at ${OFFSET}s — shifting marks by that much`);
} catch (e) {
  console.error('WARNING: no sync flash found; taps will be mistimed');
}
const DUR = 0.75, R = 140;   // tapfx frames are 280x280, centred

// Show the finger arriving BEFORE contact. The animation is press-then-ripple,
// so anchoring frame 0 at the tap puts most of what you see after the button has
// already reacted -- it reads as a marker chasing the click rather than causing
// it. LEAD backs the whole sequence up so contact lands on the tap instant.
const LEAD = 0.24;

const inputs = [], chain = [];
let last = '[0:v]fps=25[v0]', prev = 'v0';
marks.taps.forEach((t, i) => {
  const tt = +(t.t + OFFSET - LEAD - (OFFSET + TRIM_PAD)).toFixed(3);
  inputs.push('-itsoffset', String(tt), '-framerate', '25', '-i', 'tapfx/t%02d.png');
  const out = `v${i + 1}`;
  chain.push(`[${prev}][${i + 1}:v]overlay=${t.x - R}:${t.y - R}:` +
             `enable='between(t,${tt},${(tt + DUR).toFixed(2)})'[${out}]`);
  prev = out;
});
// Swipes get the same indicator, moving. The overlay x is an expression in t
// rather than a constant, so one input draws the whole stroke -- a start blob
// and an end blob would read as two taps, which is the opposite of the point.
//
// LAG, not LEAD. A tap indicator is backed up so contact lands on the tap; a
// swipe has to travel WITH the card, and the card starts moving a beat after
// the touch events go in -- the emulator's own pipeline. Anchored on the script
// clock alone, the indicator finishes its stroke before the card has begun.
// The tap animation is press-then-ripple over 16 frames, which is wrong for a
// drag: run it along the stroke and the finger has already let go halfway
// across. A swipe is the press frame HELD for the travel, and the ripple at the
// far end where the release actually happened -- two inputs, one gesture.
const LAG = 0.45;
let idx = marks.taps.length;
(marks.swipes || []).forEach(s => {
  const travel = (s.ms || 600) / 1000;
  const t1 = +(s.t + OFFSET - LEAD + LAG - (OFFSET + TRIM_PAD)).toFixed(3);
  const release = +(t1 + LEAD + travel).toFixed(3);

  const hold = ++idx;
  // -t bounds the looped still. Without it the input never ends and ffmpeg sits
  // there generating frames forever.
  inputs.push('-loop', '1', '-framerate', '25', '-t', (LEAD + travel + 0.1).toFixed(2),
              '-itsoffset', String(t1), '-i', 'tapfx/t02.png');
  const x = `${s.from.x - R}+(${s.to.x - s.from.x})*` +
            `min(1,max(0,(t-${(t1 + LEAD).toFixed(3)})/${travel}))`;
  chain.push(`[${prev}][${hold}:v]overlay=x='${x}':y=${s.from.y - R}:` +
             `enable='between(t,${t1},${release})'[v${hold}]`);
  prev = `v${hold}`;

  const ripple = ++idx;
  inputs.push('-itsoffset', String(release), '-framerate', '25',
              '-start_number', '8', '-i', 'tapfx/t%02d.png');
  chain.push(`[${prev}][${ripple}:v]overlay=${s.to.x - R}:${s.to.y - R}:` +
             `enable='between(t,${release},${(release + 0.32).toFixed(2)})'[v${ripple}]`);
  prev = `v${ripple}`;
});

const filter = [last, ...chain].join(';').replace(new RegExp(`\\[${prev}\\]$`), '');
// Trim everything before the sync flash: that head is staging -- app launches,
// the white flash itself -- not part of the video. Taps are already expressed in
// video time, so shift them back by the same amount after trimming.
const out = src.replace(/\.mp4$/, '_taps.mp4');
const HEAD = OFFSET + TRIM_PAD;          // past the flash and its fade
execFileSync('ffmpeg', ['-y', '-v', 'error', '-ss', HEAD.toFixed(3), '-i', src, ...inputs,
  '-filter_complex', filter, '-an', '-c:v', 'libx264', '-crf', '20',
  '-preset', 'medium', '-pix_fmt', 'yuv420p', out], { stdio: 'inherit' });
console.log(out, `(${marks.taps.length} taps, ${(marks.swipes || []).length} swipes, ` +
                 `trimmed ${HEAD.toFixed(2)}s of head)`);
