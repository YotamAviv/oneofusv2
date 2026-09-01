#!/usr/bin/env bash
# The preamble, on its own: the page, a finger on the Play badge, the card, the
# home screen, a finger on the app.
#
#   ./build_preamble.sh
#
# Writes out/scene0_preamble_<stamp>.mp4, about six seconds. It wipes nothing and
# publishes nothing, so it can be re-recorded as often as the words change --
# which is why it is its own scene and its own script. build_scene1.sh calls it.
#
# The card's words come from doc/intro_video/sections.yaml, section 'preamble'.
#
# Each take opens with a sync flash and overlay_taps.js trims to it, but what is
# left is the flash page still sliding away -- so each piece starts at the first
# mark that names something worth seeing, read from the take's own marks rather
# than from a number that was true once.
set -euo pipefail
cd "$(dirname "$0")"

STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
OUT="${1:-out/scene0_preamble_${STAMP}.mp4}"

newest() { ls -t "$@" 2>/dev/null | head -1; }
at() { node -e "
  const { loadMarks, TRIM_PAD } = require('./lib/marks');
  const m = loadMarks(process.argv[1]);
  const v = m[process.argv[2]];
  console.log(((typeof v === 'object' ? v.start : v) - TRIM_PAD - (+process.argv[3])).toFixed(2));
" "$1" "$2" "$3"; }

echo "== 1/4  the page, and a finger on the Play badge =="
node shoot_browser.js >/dev/null
BROWSER=$(newest out/browser_*.mp4 | grep -v taps || newest out/browser_*.mp4)
node overlay_taps.js "$BROWSER" >/dev/null 2>&1
BROWSER_T="${BROWSER%.mp4}_taps.mp4"

echo "== 2/4  the card =="
python3 sections.py --card preamble >/dev/null

echo "== 3/4  the home screen, and a finger on the app =="
node shoot_home.js >/dev/null
HOME=$(newest out/home_*.mp4 | grep -v taps || newest out/home_*.mp4)
node overlay_taps.js "$HOME" >/dev/null 2>&1
HOME_T="${HOME%.mp4}_taps.mp4"

echo "== 4/4  joining =="
ffmpeg -y -v error -ss "$(at "$BROWSER_T" page 0.7)" -i "$BROWSER_T" \
  -i out/card_preamble.mp4 \
  -ss "$(at "$HOME_T" home_screen 0.5)" -i "$HOME_T" \
  -filter_complex "[0:v]fps=25,setsar=1[a];[1:v]fps=25,setsar=1[b];[2:v]fps=25,setsar=1[c];\
[a][b][c]concat=n=3:v=1:a=0,format=yuv420p[v]" \
  -map "[v]" -c:v libx264 -crf 19 -preset medium "$OUT"

echo
echo "  $OUT"
