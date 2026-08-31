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
#   old footage   1080x2400, camera view from y=530 to the bottom
#   emulator      1080x2220, camera view from y=385 to the bottom
#
# Remeasure both after any reshoot, or after the app's header changes height.
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

SRC_TOP=530                             # camera view starts here in the footage
DST_TOP=385                             # ... and here on the emulator
SRC_H=$((2400 - SRC_TOP))
DST_H=$((2220 - DST_TOP))
HOLD=1.0                                # freeze the last frame this long

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FOOTAGE")
END=$(python3 -c "print(round($START + $DUR + $HOLD, 3))")
echo "$FOOTAGE (${DUR}s) into $BASE at ${START}s, held to ${END}s"

CAM="[1:v]crop=1080:${SRC_H}:0:${SRC_TOP},scale=1080:${DST_H},\
tpad=stop_mode=clone:stop_duration=${HOLD},setpts=PTS-STARTPTS+${START}/TB[cam]"

if [[ "$BASE" == *.png ]]; then
  ffmpeg -y -v error -loop 1 -t "$END" -i "$BASE" -i "$FOOTAGE" \
    -filter_complex "${CAM};[0:v][cam]overlay=0:${DST_TOP},fps=25,format=yuv420p[v]" \
    -map "[v]" -c:v libx264 -crf 19 -preset slow "$OUT"
else
  ffmpeg -y -v error -i "$BASE" -i "$FOOTAGE" \
    -filter_complex "${CAM};[0:v][cam]overlay=0:${DST_TOP}:\
enable='between(t,${START},${END})',format=yuv420p[v]" \
    -map "[v]" -c:v libx264 -crf 19 -preset slow "$OUT"
fi

echo "-> $OUT"
