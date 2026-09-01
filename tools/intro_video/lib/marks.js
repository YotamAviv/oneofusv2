// Where a moment in a take actually is.
//
// Every shoot script writes a marks file next to its video naming what happened
// and when -- tap_publish, swipe_snooze, verified. Cues written against those
// names survive a reshoot; cues written as "16.2" do not, and a reshoot is the
// normal cost of changing a word of copy.
//
//   { "at": "tap_publish", "after": 0.3 }   // a beat after the publish tap
//   { "t": 0.4 }                            // still fine where nothing is named

const fs = require('fs');

/// Seconds trimmed off the front of a take beyond the sync flash itself: the
/// flash's fade, which would otherwise open the video on a white smear.
///
/// It is also the whole difference between the two clocks in play. Marks are on
/// the script's clock, zeroed at the flash; the finished video has had the flash
/// and this pad cut off its head. So a mark at T is at T - TRIM_PAD in the
/// trimmed video, whatever the flash offset happened to be that take.
const TRIM_PAD = 0.55;

/// The marks written alongside a take, given any of its videos -- the raw one,
/// the one with touch indicators, the composited one, the annotated one.
///
/// The suffixes matter for ORDER. Compositing has to happen before annotation,
/// because annotation splices cards and beats into the timeline and everything
/// after them moves, while composite_scan resolves its window against the marks
/// as recorded. Composite first, on unshifted time, then annotate.
function loadMarks(video) {
  const file = video.replace(/(_taps|_composited|_annotated)+\.mp4$/, '.mp4')
                    .replace(/\.mp4$/, '.marks.json');
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

/// A cue's time in the trimmed video.
///
/// Fails loudly and lists what the take does name: a typo'd mark is otherwise a
/// cue that silently lands at zero, which reads as a bug in the treatment rather
/// than a typo in the cue file.
function timeOf(cue, marks, what = 'cue') {
  if (cue.at) {
    if (!marks) {
      throw new Error(`${what} refers to mark "${cue.at}" but the take has no marks file`);
    }
    const t = marks[cue.at];
    if (typeof t !== 'number') {
      const known = Object.entries(marks)
        .filter(([, v]) => typeof v === 'number').map(([k]) => k);
      throw new Error(`${what}: this take has no mark "${cue.at}".\n  it has: ${known.join(', ')}`);
    }
    return +(t - TRIM_PAD + (cue.after || 0)).toFixed(3);
  }
  if (typeof cue.t === 'number') return cue.t;
  throw new Error(`${what} has neither "at" (a mark name) nor "t" (seconds)`);
}

module.exports = { TRIM_PAD, loadMarks, timeOf };
