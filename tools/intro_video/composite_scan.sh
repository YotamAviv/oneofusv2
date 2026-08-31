#!/usr/bin/env bash
# Put real camera footage inside the emulator's scanner screen.
#
#   ./composite_scan.sh out/salvage/vouch_scan.mp4 out/app_scan2.png out/scan_composite.mp4
#
# The one shot that cannot be generated is the demo phone SEEING another phone:
# a camera, a table, a person's identity on a screen. Everything around it can
# be -- the status bar, the app header, the alignment frame, the hint. So the
# camera picture comes from footage and the rest comes from the emulator, which
# means the app version, the screen size and the styling all match the takes
# either side of it.
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
set -euo pipefail
cd "$(dirname "$0")"

FOOTAGE="${1:-out/salvage/vouch_scan.mp4}"
BASE="${2:-out/app_scan2.png}"          # a still of the emulator's scanner screen
OUT="${3:-out/scan_composite.mp4}"

SRC_TOP=530                             # camera view starts here in the footage
DST_TOP=385                             # ... and here on the emulator
SRC_H=$((2400 - SRC_TOP))
DST_H=$((2220 - DST_TOP))

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FOOTAGE")
echo "footage $FOOTAGE (${DUR}s) into $BASE"

ffmpeg -y -v error -loop 1 -t "$DUR" -i "$BASE" -i "$FOOTAGE" \
  -filter_complex "[1:v]crop=1080:${SRC_H}:0:${SRC_TOP},scale=1080:${DST_H}[cam];\
[0:v][cam]overlay=0:${DST_TOP},fps=25,format=yuv420p[v]" \
  -map "[v]" -c:v libx264 -crf 19 -preset slow "$OUT"

echo "-> $OUT"
