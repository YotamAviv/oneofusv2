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
if (!src) { console.error('usage: find_snackbar.js <take.mp4>'); process.exit(1); }

// THE BOTTOM-MOST STRIP. Getting this wrong is subtle rather than obvious: a
// band 115px higher catches only the snackbar's top edge and averages the rest
// away against the grey above it, giving green-minus-red of 21 where the real
// bar gives 133. Twenty-one sits just under any sane threshold, so the bar is
// on screen, plainly visible to a person, and the scan reports nothing.
//
// Sampled at 10fps: the snackbar is up for seconds, so this cannot miss it.
const CROP = 'crop=1000:120:40:2060';
const FPS = 10;
const GREEN_OVER_RED = 25;

const raw = execFileSync('ffmpeg', ['-v', 'error', '-i', src,
  '-vf', `fps=${FPS},${CROP},scale=1:1`, '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'],
  { maxBuffer: 1 << 28 });

let appeared = null, cleared = null;
for (let i = 0; i * 3 + 2 < raw.length; i++) {
  const r = raw[i * 3], g = raw[i * 3 + 1];
  const teal = g - r > GREEN_OVER_RED;
  if (teal && appeared === null) appeared = i / FPS;
  if (!teal && appeared !== null && cleared === null && i / FPS > appeared) cleared = i / FPS;
}
if (appeared === null) {
  console.error(`no snackbar in ${src}: nothing in the bottom strip went green.`);
  process.exit(1);
}
// Not finding the end is not a failure -- a take can stop while it is still up.
console.log(JSON.stringify({ appeared: +appeared.toFixed(2),
                             cleared: cleared === null ? null : +cleared.toFixed(2) }));
