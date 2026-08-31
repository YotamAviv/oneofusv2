#!/usr/bin/env bash
# Put real camera footage inside the emulator's scanner screen.
#
#   ./composite_scan.sh <base> <footage> <start> [out.mp4]
#   ./composite_scan.sh out/vouch_<stamp>.mp4 out/salvage/vouch_scan_long.mp4 14.3
#
# <base> is a take of the emulator (or a still of its scanner screen), <footage>
# is the camera picture to drop in, <start> is where in the base the scanner is
# up and waiting for it.
#
# The one shot that cannot be generated is the demo phone SEEING another phone:
# a camera, a table, a person's identity on a screen. Everything around it can
# be -- the status bar, the app header, the alignment frame, the hint. So the
# camera picture comes from footage and the rest comes from the emulator, which
# means the app version, the screen size and the styling all match.
#
# PROTOTYPE, and the numbers below are the whole trick. They are where each
# screen's camera view starts, measured off one frame of each:
#
#   footage    1080x2400, camera view from y=SRC_TOP to the bottom
#   emulator   1080x2220, camera view from y=DST_TOP to the bottom
#
# Remeasure after any reshoot, or after the app's header changes height, and
# pass the new value in the environment: SRC_TOP=530 ./composite_scan.sh ...
#
# The alignment frame and the hint box come from the FOOTAGE, not the emulator --
# they are burned into the camera region and cannot be lifted off it. They line
# up with the emulator's own well enough that the seam doesn't show, which is
# luck, and worth re-checking on a frame whenever either side changes.
#
# The footage's last frame is held for HOLD seconds after it runs out, so the
# phone stays in view until the app reacts. Without it the composite ends early
# and the viewer sees the emulator's rendered room for a beat, which gives the
# whole thing away.
set -euo pipefail
cd "$(dirname "$0")"

BASE="${1:?usage: composite_scan.sh <base> <footage> <start> [out.mp4]}"
FOOTAGE="${2:?}"
START="${3:?}"
OUT="${4:-${BASE%.mp4}_composited.mp4}"

# <start> may be a mark name instead of a number -- "scanWindow" is the one the
# vouch take writes. Resolved against the take's own marks file and shifted onto
# the trimmed video's clock, so a reshoot doesn't have to be lined up by eye.
if ! [[ "$START" =~ ^[0-9.]+$ ]]; then
  START=$(node -e "
    const { loadMarks, TRIM_PAD } = require('./lib/marks');
    const m = loadMarks(process.argv[1]);
    if (!m) { console.error('no marks file for ' + process.argv[1]); process.exit(1); }
    const v = m[process.argv[2]];
    const t = (v && typeof v === 'object') ? v.start : v;
    if (typeof t !== 'number') {
      console.error('no mark \"' + process.argv[2] + '\" in that take');
      process.exit(1);
    }
    console.log((t - TRIM_PAD).toFixed(3));
  " "$BASE" "$START")
  echo "start resolved from marks: ${START}s"
fi

# Where each screen's camera view starts, measured off one frame of each. These
# move when the app's header changes height, and they differ between the two
# batches of footage we have: 530 in the Aug 11 recording, 460 in the Aug 31 one.
SRC_TOP=${SRC_TOP:-460}                 # camera view starts here in the footage
DST_TOP=${DST_TOP:-385}                 # ... and here on the emulator
SRC_H=$((2400 - SRC_TOP))
DST_H=$((2220 - DST_TOP))
LEAD=${LEAD:-1.5}                       # freeze the FIRST frame this long before
HOLD=${HOLD:-1.0}                       # ... and the last one this long after
FADE=${FADE:-0.35}                      # dissolve out over this long at the end

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FOOTAGE")
BEGIN=$(python3 -c "print(round($START - $LEAD, 3))")
END=$(python3 -c "print(round($START + $DUR + $HOLD, 3))")
echo "$FOOTAGE (${DUR}s) into $BASE at ${START}s, held to ${END}s"

# Padded at both ends with its own first and last frames. The scanner is on
# screen a little before the footage begins and a little after it ends, and
# every uncovered moment is the emulator's rendered living room.
# Dissolved out at the end, not cut. The app cross-fades from the scanner to the
# screen behind it, and for those few frames both are on screen at once: a paste
# that simply stops shows the emulator's rendered room through the fade, and one
# that simply continues shows a camera view over a header that has already
# changed. Fading with it hides both.
FADE_AT=$(python3 -c "print(round($END - $FADE, 3))")
CAM="[1:v]crop=1080:${SRC_H}:0:${SRC_TOP},scale=1080:${DST_H},\
tpad=start_mode=clone:start_duration=${LEAD}:stop_mode=clone:stop_duration=${HOLD},\
setpts=PTS-STARTPTS+${BEGIN}/TB,format=rgba,\
fade=t=out:st=${FADE_AT}:d=${FADE}:alpha=1[cam]"

if [[ "$BASE" == *.png ]]; then
  ffmpeg -y -v error -loop 1 -t "$END" -i "$BASE" -i "$FOOTAGE" \
    -filter_complex "${CAM};[0:v][cam]overlay=0:${DST_TOP},fps=25,format=yuv420p[v]" \
    -map "[v]" -c:v libx264 -crf 19 -preset slow "$OUT"
else
  ffmpeg -y -v error -i "$BASE" -i "$FOOTAGE" \
    -filter_complex "${CAM};[0:v][cam]overlay=0:${DST_TOP}:\
enable='between(t,${BEGIN},${END})',format=yuv420p[v]" \
    -map "[v]" -c:v libx264 -crf 19 -preset slow "$OUT"
fi

echo "-> $OUT"
